extends CharacterBody3D

@export var move_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0025
@export var max_health: int = 100
@export var magazine_size: int = 60
@export var show_first_person_arms: bool = false

var owner_peer_id: int = 0
var health: int = 100
var ammo: int = 0

var _yaw: float = 0.0
var _pitch: float = 0.0

# Local-only view mode
enum ViewMode { FIRST_PERSON, THIRD_PERSON }
var _view_mode: ViewMode = ViewMode.FIRST_PERSON

# Debug (throttled)
var _dbg_last_fire_ms: int = 0
var _dbg_last_tracer_ms: int = 0

# Client-captured input (owning peer).
var _cli_move: Vector2 = Vector2.ZERO
var _cli_look: Vector2 = Vector2.ZERO
var _cli_jump: bool = false
var _cli_fire: bool = false

# Server-consumed input (server is authoritative).
var _srv_move: Vector2 = Vector2.ZERO
var _srv_look: Vector2 = Vector2.ZERO
var _srv_jump: bool = false
var _srv_fire: bool = false

# Prediction + reconciliation state
var _input_sequence: int = 0
var _last_processed_sequence: int = 0

# Server-side: last sequence processed per client (for reconciliation)
var _last_client_sequence: int = 0

# Client prediction buffers
var _pending_inputs: Array[Dictionary] = []  # {seq, move, look, jump, fire, timestamp}
var _prediction_states: Array[Dictionary] = []  # {seq, position, yaw, pitch, velocity}

# Server snapshots for reconciliation
var _server_snapshots: Array[Dictionary] = []  # {seq, position, yaw, pitch, velocity, timestamp}

# Remote player interpolation
var _remote_target_state: Dictionary = {}  # Server state to interpolate toward
var _remote_interp_t: float = 1.0  # Interpolation parameter (1.0 = at target)

# Throttling for remote state broadcasts (~15 Hz to reduce bandwidth)
var _last_remote_broadcast_ms: int = 0

@onready var _head: Node3D = $Head
@onready var _camera_fp: Camera3D = $Head/Camera
@onready var _camera_tp: Camera3D = $Head/ThirdPersonArm/ThirdPersonCamera
@onready var _weapon: Node = $Weapon
@onready var _body_mesh: MeshInstance3D = $BodyMesh
@onready var _arm_left: MeshInstance3D = $Head/Camera/ArmsViewModel/ArmLeft
@onready var _arm_right: MeshInstance3D = $Head/Camera/ArmsViewModel/ArmRight
@onready var _gun_viewmodel: MeshInstance3D = $Head/Camera/GunViewModel
@onready var _world_gun: MeshInstance3D = $WorldGunPivot/WorldGun

func _ready() -> void:
	# This example uses server-authoritative simulation + RPC input.
	# We intentionally do not use MultiplayerSynchronizer-based replication here.

	health = max_health
	if _weapon and _weapon.has_method("setup"):
		_weapon.call("setup", magazine_size)
		ammo = int(_weapon.get("ammo"))
	else:
		ammo = magazine_size
	_update_hud()

	var is_local := (multiplayer.get_unique_id() == owner_peer_id)
	_camera_fp.current = is_local
	_camera_tp.current = false
	if is_local:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_set_view_mode(ViewMode.FIRST_PERSON)
	else:
		# Remote players should never render first-person viewmodels as world geometry.
		_set_viewmodel_visible(false)
		if _body_mesh:
			_body_mesh.visible = true
		if _world_gun:
			_world_gun.visible = true

func set_owner_peer_id(peer_id: int) -> void:
	owner_peer_id = peer_id

func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.get_unique_id() != owner_peer_id:
		return

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_cli_look += mm.relative * mouse_sensitivity

func _process(_delta: float) -> void:
	# Only the owning peer gathers input; the server simulates.
	if multiplayer.get_unique_id() != owner_peer_id:
		return
	if InputManager == null:
		return

	if InputManager.is_action_just_pressed("fps_toggle_view"):
		_toggle_view()

	var move := Vector2.ZERO
	if InputManager.is_action_pressed("fps_move_forward"):
		move.y -= 1.0
	if InputManager.is_action_pressed("fps_move_back"):
		move.y += 1.0
	if InputManager.is_action_pressed("fps_move_left"):
		move.x -= 1.0
	if InputManager.is_action_pressed("fps_move_right"):
		move.x += 1.0

	_cli_move = move.normalized()
	_cli_jump = InputManager.is_action_just_pressed("fps_jump")
	_cli_fire = InputManager.is_action_just_pressed("fps_shoot")

	# Immediate local feedback (clients don't run server-side _try_fire()).
	if _cli_fire and EventManager:
		var now_ms := Time.get_ticks_msec()
		if now_ms - _dbg_last_fire_ms > 400:
			_dbg_last_fire_ms = now_ms
			LogManager.debug("PlayerController", "fps_shoot pressed. Emitting fps_shot_fired (peer=%d owner=%d server=%s)" % [
				multiplayer.get_unique_id(),
				owner_peer_id,
				str(multiplayer.is_server())
			])
		EventManager.emit("fps_shot_fired", {})

	# Client prediction: simulate locally first, then send to server
	var look_vec: Vector2 = _cli_look if _cli_look != null else Vector2.ZERO
	var input_data := {
		"move": _cli_move,
		"look": look_vec,
		"jump": _cli_jump,
		"fire": _cli_fire
	}

	# Client prediction: simulate locally for immediate feedback
	if multiplayer.get_unique_id() == owner_peer_id and not multiplayer.is_server():
		_client_predict(input_data)

	# Send to server (increment sequence number)
	_input_sequence += 1
	var current_sequence := _input_sequence

	# Store input for potential reconciliation
	_pending_inputs.append({
		"seq": current_sequence,
		"move": _cli_move,
		"look": look_vec,
		"jump": _cli_jump,
		"fire": _cli_fire,
		"timestamp": Time.get_ticks_msec()
	})

	# Send to server
	if multiplayer.is_server():
		_server_update_input(current_sequence, _cli_move, look_vec, _cli_jump, _cli_fire)
	else:
		_server_update_input.rpc_id(1, current_sequence, _cli_move, look_vec, _cli_jump, _cli_fire)

	# Clear one-frame input on the client side (don't touch _srv_*; server consumes those).
	_cli_look = Vector2.ZERO
	_cli_jump = false
	_cli_fire = false

	# Remote player smoothing: interpolate toward server state
	if multiplayer.get_unique_id() != owner_peer_id and not _remote_target_state.is_empty():
		_remote_interp_t = min(_remote_interp_t + _delta * 10.0, 1.0)  # Smooth over ~100ms
		if _remote_interp_t <= 1.0:
			# Debug: Check if we're actually interpolating
			var debug_now := Time.get_ticks_msec()
			if debug_now - _dbg_last_tracer_ms > 500:  # Less frequent debug
				LogManager.info("PlayerController", "INTERPOLATING: peer %d (my_peer=%d), interp_t=%.3f" % [
					owner_peer_id, multiplayer.get_unique_id(), _remote_interp_t
				])
			var current_state: Dictionary = _get_current_state()
			var interp_position: Vector3 = current_state.position.lerp(_remote_target_state.position, _remote_interp_t)
			var interp_yaw: float = lerp_angle(current_state.yaw, _remote_target_state.yaw, _remote_interp_t)
			var interp_pitch: float = lerp(current_state.pitch, _remote_target_state.pitch, _remote_interp_t)

			global_position = interp_position
			_yaw = interp_yaw
			_pitch = interp_pitch
			rotation.y = _yaw
			_head.rotation.x = _pitch

			# Debug: Log position updates occasionally
			var now_ms := Time.get_ticks_msec()
			if now_ms - _dbg_last_tracer_ms > 200:  # Every 200ms
				LogManager.info("PlayerController", "Interpolating peer %d: current=%s target=%s interp_t=%.2f" % [
					owner_peer_id, str(current_state.position), str(_remote_target_state.position), _remote_interp_t
				])
				_dbg_last_tracer_ms = now_ms

func _toggle_view() -> void:
	if _view_mode == ViewMode.FIRST_PERSON:
		_set_view_mode(ViewMode.THIRD_PERSON)
	else:
		_set_view_mode(ViewMode.FIRST_PERSON)

func _set_view_mode(mode: ViewMode) -> void:
	_view_mode = mode
	var is_local := (multiplayer.get_unique_id() == owner_peer_id)
	if not is_local:
		return

	match _view_mode:
		ViewMode.FIRST_PERSON:
			_camera_fp.current = true
			_camera_tp.current = false
			if _body_mesh:
				_body_mesh.visible = false
			if _world_gun:
				_world_gun.visible = false
			_set_viewmodel_visible(true)
		ViewMode.THIRD_PERSON:
			_camera_fp.current = false
			_camera_tp.current = true
			if _body_mesh:
				_body_mesh.visible = true
			if _world_gun:
				_world_gun.visible = true
			_set_viewmodel_visible(false)

func _set_viewmodel_visible(visible_now: bool) -> void:
	if _arm_left:
		_arm_left.visible = visible_now and show_first_person_arms
	if _arm_right:
		_arm_right.visible = visible_now and show_first_person_arms
	if _gun_viewmodel:
		_gun_viewmodel.visible = visible_now

# Shared simulation step (deterministic, used by both prediction and server authority)
func _simulate_step(delta: float, input: Dictionary, current_state: Dictionary) -> Dictionary:
	var new_state := current_state.duplicate()

	# Look rotation
	new_state.yaw -= input.look.x
	new_state.pitch = clamp(new_state.pitch - input.look.y, -1.3, 1.3)

	# Movement
	if not is_on_floor():
		new_state.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	var dir3 := Vector3(input.move.x, 0.0, input.move.y)
	if dir3.length() > 0.0:
		# Create a temporary transform to get the correct movement direction
		var temp_transform := Transform3D()
		temp_transform = temp_transform.rotated(Vector3.UP, new_state.yaw)
		dir3 = (temp_transform.basis * dir3).normalized()
		new_state.velocity.x = dir3.x * move_speed
		new_state.velocity.z = dir3.z * move_speed

	if input.jump and is_on_floor():
		new_state.velocity.y = jump_velocity

	# Simple position integration (we'll handle collision in the calling context)
	new_state.position += new_state.velocity * delta

	return new_state

# Get current simulation state
func _get_current_state() -> Dictionary:
	return {
		"position": global_position,
		"yaw": _yaw,
		"pitch": _pitch,
		"velocity": velocity
	}

# Apply a simulation state
func _apply_state(state: Dictionary) -> void:
	global_position = state.position
	_yaw = state.yaw
	_pitch = state.pitch
	rotation.y = _yaw
	_head.rotation.x = _pitch
	velocity = state.velocity

# Client prediction: simulate locally for immediate feedback
func _client_predict(input: Dictionary) -> void:
	var delta := get_physics_process_delta_time()
	var current_state := _get_current_state()

	# Simulate the step
	var new_state := _simulate_step(delta, input, current_state)

	# Apply the predicted state
	_apply_state(new_state)

	# Store prediction state for potential reconciliation
	_prediction_states.append({
		"seq": _input_sequence + 1,  # This prediction is for the next sequence
		"position": new_state.position,
		"yaw": new_state.yaw,
		"pitch": new_state.pitch,
		"velocity": new_state.velocity
	})

	# Keep prediction buffer bounded
	if _prediction_states.size() > 60:  # ~1 second at 60fps
		_prediction_states.pop_front()

# Server sends authoritative snapshots back to clients
@rpc("any_peer", "unreliable", "call_local")
func _receive_server_snapshot(sequence: int, snapshot_position: Vector3, yaw: float, pitch: float, snapshot_velocity: Vector3) -> void:
	if multiplayer.get_unique_id() != owner_peer_id:
		return

	var snapshot := {
		"seq": sequence,
		"position": snapshot_position,
		"yaw": yaw,
		"pitch": pitch,
		"velocity": snapshot_velocity,
		"timestamp": Time.get_ticks_msec()
	}

	_server_snapshots.append(snapshot)

	# Keep snapshot buffer bounded
	if _server_snapshots.size() > 32:
		_server_snapshots.pop_front()

	# Reconcile with latest snapshot
	_reconcile_with_server()

# Server broadcasts authoritative state to all peers for remote player interpolation
@rpc("any_peer", "unreliable")
func _rpc_remote_state(state_position: Vector3, yaw: float, pitch: float, state_velocity: Vector3) -> void:
	# Only accept from server (local call sender=0 or server peer sender=1)
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return

	# Only update remote state for non-owning peers
	if multiplayer.get_unique_id() == owner_peer_id:
		return

	LogManager.info("PlayerController", "Received remote state for peer %d: pos=%s (my peer=%d)" % [owner_peer_id, str(state_position), multiplayer.get_unique_id()])
	# Update target state for interpolation
	_remote_target_state = {
		"position": state_position,
		"yaw": yaw,
		"pitch": pitch,
		"velocity": state_velocity
	}
	_remote_interp_t = 0.0

# Client reconciliation: rewind and replay from authoritative server state
func _reconcile_with_server() -> void:
	if _server_snapshots.is_empty():
		return

	# Find the most recent snapshot
	var latest_snapshot: Dictionary = _server_snapshots.back()

	# Find the corresponding prediction state
	var prediction_index := -1
	for i in range(_prediction_states.size()):
		if _prediction_states[i].seq == latest_snapshot.seq:
			prediction_index = i
			break

	if prediction_index == -1:
		# No matching prediction, just apply the snapshot
		_apply_state(latest_snapshot)
		_last_processed_sequence = latest_snapshot.seq
		return

	# Apply the authoritative state
	_apply_state(latest_snapshot)
	_last_processed_sequence = latest_snapshot.seq

	# Remove processed snapshots and predictions
	_server_snapshots.clear()
	while not _prediction_states.is_empty() and _prediction_states[0].seq <= latest_snapshot.seq:
		_prediction_states.pop_front()

	# Remove processed inputs
	while not _pending_inputs.is_empty() and _pending_inputs[0].seq <= latest_snapshot.seq:
		_pending_inputs.pop_front()

	# Replay unprocessed inputs from the authoritative state
	var current_state: Dictionary = latest_snapshot
	var delta := get_physics_process_delta_time()

	for input_data in _pending_inputs:
		current_state = _simulate_step(delta, input_data, current_state)

	# Apply the reconciled state
	_apply_state(current_state)

@rpc("any_peer", "unreliable")
func _server_update_input(sequence: int, move: Vector2, look: Vector2, jump_pressed: bool, fire_pressed: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	# When called locally on the host (not via RPC), sender is 0. Treat that as the host player.
	if sender == 0:
		sender = owner_peer_id
	if sender != owner_peer_id:
		return

	# Store the client's sequence for reconciliation snapshots
	_last_client_sequence = sequence

	# Store input for processing
	var _input_data := {
		"sequence": sequence,
		"move": move,
		"look": look,
		"jump": jump_pressed,
		"fire": fire_pressed,
		"timestamp": Time.get_ticks_msec()
	}

	# Process input immediately on server
	_srv_move = move
	_srv_look = look
	_srv_jump = jump_pressed
	_srv_fire = fire_pressed

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	# Look (server-authoritative)
	_yaw -= _srv_look.x
	_pitch = clamp(_pitch - _srv_look.y, -1.3, 1.3)
	rotation.y = _yaw
	_head.rotation.x = _pitch
	_srv_look = Vector2.ZERO

	# Move (server-authoritative)
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	var dir3 := Vector3(_srv_move.x, 0.0, _srv_move.y)
	if dir3.length() > 0.0:
		dir3 = (global_transform.basis * dir3).normalized()
	velocity.x = dir3.x * move_speed
	velocity.z = dir3.z * move_speed

	if _srv_jump and is_on_floor():
		velocity.y = jump_velocity
	_srv_jump = false

	move_and_slide()

	# Send periodic snapshots to owning client for reconciliation
	if multiplayer.get_unique_id() != owner_peer_id:  # Only for remote players
		_send_snapshot_to_client()

	# Broadcast authoritative state to all peers for remote interpolation (throttled to ~30 Hz)
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_remote_broadcast_ms > 33:  # ~30 Hz (1000ms/30)
		_last_remote_broadcast_ms = now_ms
		LogManager.info("PlayerController", "Broadcasting remote state for peer %d: pos=%s" % [owner_peer_id, str(global_position)])
		# Send to all peers except ourselves (we don't need to receive our own state)
		for peer_id in multiplayer.get_peers():
			_rpc_remote_state.rpc_id(peer_id, global_position, _yaw, _pitch, velocity)

	# For remote players, store server state for interpolation
	if multiplayer.get_unique_id() != owner_peer_id:
		_remote_target_state = _get_current_state()
		_remote_interp_t = 0.0

	if _srv_fire:
		_srv_fire = false
		LogManager.debug("PlayerController", "server processing fire (peer=%d owner=%d)" % [multiplayer.get_unique_id(), owner_peer_id])
		_try_fire()

# Send authoritative state snapshots to the owning client
func _send_snapshot_to_client() -> void:
	if owner_peer_id <= 0 or owner_peer_id == multiplayer.get_unique_id():
		return

	_receive_server_snapshot.rpc_id(owner_peer_id,
		_last_client_sequence,  # Send the client's sequence for proper reconciliation
		global_position,
		_yaw,
		_pitch,
		velocity
	)

func _try_fire() -> void:
	if _weapon and _weapon.has_method("try_consume_shot"):
		if not bool(_weapon.call("try_consume_shot")):
			return
		ammo = int(_weapon.get("ammo"))
	else:
		if ammo <= 0:
			return
		ammo -= 1
	
	if ammo < 0:
		return
	_update_hud()
	if EventManager and multiplayer.get_unique_id() == owner_peer_id:
		EventManager.emit("fps_shot_fired", {})

	# Server does the hit-scan from the server-side camera/head transform.
	var origin := _head.global_position
	var forward := -_head.global_transform.basis.z
	_server_fire(origin, forward)

func _server_fire(origin: Vector3, direction: Vector3) -> void:
	if not multiplayer.is_server():
		return

	var space := get_world_3d().direct_space_state
	var max_range := 200.0
	if _weapon and _weapon.has_method("get"):
		var mr: Variant = _weapon.get("max_range")
		if mr is float:
			max_range = mr
	var dir_n := direction.normalized()
	# Start slightly in front of the camera/head to avoid near-plane clipping and self-overlap.
	var start_point := origin + dir_n * 0.35
	var end_point := start_point + dir_n * max_range
	var query := PhysicsRayQueryParameters3D.create(start_point, end_point)
	query.exclude = [self]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		end_point = hit.get("position", end_point)

	var collider := hit.get("collider") as Object
	if collider and collider is Node:
		var target: Node = collider as Node
		# Damage player roots (CharacterBody3D) or children by walking up a bit.
		var p: Node = target
		for _i in range(4):
			if p and p.has_method("_server_apply_damage"):
				p.call("_server_apply_damage", 25, owner_peer_id)
				break
			p = p.get_parent() if p else null

	# Visual feedback (server-authoritative) for all peers.
	# call_local ensures the host also runs the RPC handler (and gets debug logs).
	_rpc_tracer_fx.rpc(start_point, end_point)

func _spawn_tracer_fx(origin: Vector3, end_point: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var dir := end_point - origin
	var seg_len := dir.length()
	if seg_len < 0.05:
		return

	var dir_n := dir / seg_len

	# Material (semi-transparent red tracer)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1, 0.1, 0.1, 1)
	mat.emission_energy_multiplier = 2.5
	mat.albedo_color = Color(1, 0.0, 0.0, 0.35)

	# Moving tracer streak (short cylinder segment that travels forward)
	var streak_len: float = min(3.0, seg_len)
	var start_mid := origin + dir_n * (streak_len * 0.5)
	var end_mid := end_point - dir_n * (streak_len * 0.5)

	var streak_mesh := CylinderMesh.new()
	streak_mesh.top_radius = 0.05
	streak_mesh.bottom_radius = 0.05
	streak_mesh.height = streak_len

	var streak := MeshInstance3D.new()
	streak.name = "TracerFx"
	streak.mesh = streak_mesh
	streak.material_override = mat
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	streak.top_level = true
	scene.add_child(streak)
	streak.global_position = start_mid

	# Orient the cylinder along the shot direction (CylinderMesh is Y-axis aligned by default).
	var up: Vector3 = dir_n
	var forward: Vector3 = Vector3.RIGHT if abs(up.dot(Vector3.FORWARD)) > 0.95 else Vector3.FORWARD
	var right: Vector3 = forward.cross(up).normalized()
	forward = up.cross(right).normalized()
	streak.global_basis = Basis(right, up, forward)

	var travel_time: float = clamp(seg_len / 140.0, 0.04, 0.16)
	var tween: Tween = create_tween()
	tween.tween_property(streak, "global_position", end_mid, travel_time)

	# Add a small "hit dot" to confirm the end point visually.
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.08
	dot_mesh.height = 0.16
	var dot := MeshInstance3D.new()
	dot.mesh = dot_mesh
	dot.material_override = mat
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dot.top_level = true
	scene.add_child(dot)
	dot.global_position = end_point

	var timer := get_tree().create_timer(0.35)
	timer.timeout.connect(func():
		if is_instance_valid(streak):
			streak.queue_free()
		if is_instance_valid(dot):
			dot.queue_free()
	)

@rpc("any_peer", "unreliable", "call_local")
func _rpc_tracer_fx(origin: Vector3, end_point: Vector3) -> void:
	# Only accept local server call (sender=0) and server->client calls (sender=1).
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	var now_ms := Time.get_ticks_msec()
	if now_ms - _dbg_last_tracer_ms > 500:
		_dbg_last_tracer_ms = now_ms
		LogManager.debug("TracerFx", "received (sender=%d) origin=%s end=%s" % [sender, str(origin), str(end_point)])
	_spawn_tracer_fx(origin, end_point)

func _server_apply_damage(amount: int, _from_peer: int) -> void:
	if not multiplayer.is_server():
		return
	health = max(0, health - amount)
	_sync_health.rpc(health)
	if health <= 0:
		_server_respawn()

@rpc("any_peer", "reliable", "call_local")
func _sync_health(new_health: int) -> void:
	health = new_health
	_update_hud()

func _server_respawn() -> void:
	if not multiplayer.is_server():
		return
	health = max_health
	if _weapon and _weapon.has_method("reload"):
		_weapon.call("reload")
		ammo = int(_weapon.get("ammo"))
	else:
		ammo = magazine_size
	_sync_health.rpc(health)
	_sync_ammo.rpc(ammo)

	# Ask the arena to place us at a spawn point again if possible.
	var arena := get_tree().current_scene
	if arena and arena.has_method("_place_at_spawn"):
		arena.call("_place_at_spawn", self, owner_peer_id)

@rpc("any_peer", "reliable", "call_local")
func _sync_ammo(new_ammo: int) -> void:
	ammo = new_ammo
	if _weapon:
		_weapon.set("ammo", new_ammo)
	_update_hud()

func _update_hud() -> void:
	if EventManager and multiplayer.get_unique_id() == owner_peer_id:
		EventManager.emit("fps_health_changed", {"hp": health})
		EventManager.emit("fps_ammo_changed", {"ammo": ammo})
