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

	# Host (peer 1) can't RPC to itself in this mode; call directly when we're the server.
	var look_vec: Vector2 = _cli_look if _cli_look != null else Vector2.ZERO
	if multiplayer.is_server():
		_server_update_input(_cli_move, look_vec, _cli_jump, _cli_fire)
	else:
		_server_update_input.rpc_id(1, _cli_move, look_vec, _cli_jump, _cli_fire)

	# Clear one-frame input on the client side (don't touch _srv_*; server consumes those).
	_cli_look = Vector2.ZERO
	_cli_jump = false
	_cli_fire = false

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

@rpc("any_peer", "unreliable")
func _server_update_input(move: Vector2, look: Vector2, jump_pressed: bool, fire_pressed: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	# When called locally on the host (not via RPC), sender is 0. Treat that as the host player.
	if sender == 0:
		sender = owner_peer_id
	if sender != owner_peer_id:
		return
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

	if _srv_fire:
		_srv_fire = false
		LogManager.debug("PlayerController", "server processing fire (peer=%d owner=%d)" % [multiplayer.get_unique_id(), owner_peer_id])
		_try_fire()

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
