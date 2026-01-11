extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/fps/player/Player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/fps/ui/HUD.tscn")

@onready var _spawner: MultiplayerSpawner = $Spawner
@onready var _spawn_points_root: Node3D = $SpawnPoints

var _hud_instance: Control
var _pending_ready: Dictionary = {} # peer_id -> true

# Spawn de-overlap settings.
const SPAWN_MIN_SEPARATION: float = 2.5
const SPAWN_RING_COUNT: int = 6
const SPAWN_RING_STEPS: int = 8

# Server-side spawn reservations (to avoid double-allocating the same position).
var _reserved_spawn_pos: Dictionary = {} # peer_id -> Vector3

func _ready() -> void:
	# HUD is purely local UI; we register it into UIManager for consistent layering.
	_hud_instance = HUD_SCENE.instantiate() as Control
	if UIManager and _hud_instance:
		UIManager.register_ui_element("fps_hud", _hud_instance, UIManager.game_layer)
		UIManager.show_ui_element("fps_hud")

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# MultiplayerSpawner setup (server triggers spawn; all peers instantiate via spawn_function).
	_spawner.spawn_function = Callable(self, "_spawn_player")
	# Godot 4.5 MultiplayerSpawner expects spawnable scenes to be registered by path.
	_spawner.add_spawnable_scene("res://scenes/fps/player/Player.tscn")

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Connect to NetworkManager signals for arena ready coordination
	_connect_network_manager_signals()

	if multiplayer.multiplayer_peer and multiplayer.is_server():
		# Spawn host player immediately. Other peers will be spawned after they confirm Arena01 is loaded.
		_spawn_for_peer(1)
		# Mark the host's arena as ready (server-side tracking)
		if NetworkManager:
			NetworkManager.report_local_arena_ready()
		for peer_id in multiplayer.get_peers():
			_pending_ready[int(peer_id)] = true
	else:
		# Tell NetworkManager we're ready so it can safely spawn our player via MultiplayerSpawner.
		if NetworkManager and multiplayer.multiplayer_peer != null:
			NetworkManager._rpc_report_arena_ready.rpc_id(1)

func _exit_tree() -> void:
	# Disconnect NetworkManager signals to prevent accumulation on scene reload
	if NetworkManager:
		if NetworkManager.arena_ready.is_connected(_on_peer_arena_ready):
			NetworkManager.arena_ready.disconnect(_on_peer_arena_ready)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if UIManager:
		UIManager.unregister_ui_element("fps_hud")
	if _hud_instance and is_instance_valid(_hud_instance):
		_hud_instance.queue_free()

func _on_peer_connected(peer_id: int) -> void:
	if EventManager:
		EventManager.emit("peer_joined", {"peer_id": peer_id})
	if multiplayer.multiplayer_peer and multiplayer.is_server():
		# Wait for the client to report arena ready via NetworkManager, otherwise MultiplayerSpawner sync will fail.
		_pending_ready[peer_id] = true

func _on_peer_disconnected(peer_id: int) -> void:
	if EventManager:
		EventManager.emit("peer_left", {"peer_id": peer_id})
	_pending_ready.erase(peer_id)
	_reserved_spawn_pos.erase(peer_id)
	# MultiplayerSpawner will automatically despawn spawned nodes when peers leave (by node ownership),
	# but we also clean up our naming convention if needed.
	var players_root := get_node_or_null("Players") as Node
	if players_root:
		var node_name := "Player_%d" % peer_id
		var player := players_root.get_node_or_null(node_name)
		if player:
			player.queue_free()

func _spawn_for_peer(peer_id: int) -> void:
	# Server chooses the spawn position so all peers instantiate consistently.
	var data := {"peer_id": peer_id}
	if multiplayer.multiplayer_peer and multiplayer.is_server():
		var pos := _choose_spawn_position(peer_id)
		data["spawn_pos"] = pos
	# Data travels to all peers; each creates the node locally using spawn_function.
	_spawner.spawn(data)

# Connect to NetworkManager's arena_ready signal instead of direct RPC
func _connect_network_manager_signals() -> void:
	if NetworkManager:
		NetworkManager.arena_ready.connect(_on_peer_arena_ready)

func _on_peer_arena_ready(peer_id: int) -> void:
	if not multiplayer.multiplayer_peer or not multiplayer.is_server():
		return
	if not _pending_ready.has(peer_id):
		return
	_pending_ready.erase(peer_id)
	_spawn_for_peer(peer_id)

func _spawn_player(data: Variant) -> Node:
	var d := data as Dictionary
	var peer_id := int(d.get("peer_id", 0))
	var player := PLAYER_SCENE.instantiate() as Node
	player.name = "Player_%d" % peer_id

	# Server-authoritative player logic for this sample.
	player.set_multiplayer_authority(1)
	if player.has_method("set_owner_peer_id"):
		player.call("set_owner_peer_id", peer_id)

	_place_at_spawn(player, peer_id, d)
	return player

func _place_at_spawn(player: Node, peer_id: int, data: Dictionary = {}) -> void:
	if not (player is Node3D):
		return
	var p3d := player as Node3D

	var pos: Variant = data.get("spawn_pos", null)
	if pos is Vector3:
		_set_node3d_world_position_safe(p3d, pos)
		return

	# Fallback (offline/editor): keep the old deterministic marker-based spawn.
	var points := _get_spawn_points()
	if points.is_empty():
		return
	var idx: int = int(abs(peer_id)) % int(points.size())
	var marker: Marker3D = points[idx]
	if marker:
		_set_node3d_world_position_safe(p3d, marker.global_position)

func _get_spawn_points() -> Array[Marker3D]:
	var out: Array[Marker3D] = []
	for c in _spawn_points_root.get_children():
		if c is Marker3D:
			out.append(c)
	return out

func _set_node3d_world_position_safe(n: Node3D, world_pos: Vector3) -> void:
	# When called from MultiplayerSpawner.spawn_function, the node may not be inside the tree yet.
	# Setting global transforms in that case can error; set local position first.
	if n.is_inside_tree():
		n.global_position = world_pos
	else:
		n.position = world_pos

func _choose_spawn_position(peer_id: int) -> Vector3:
	# Server-only intention, but safe to call anywhere.
	# Try markers first, then expand outward in rings to avoid overlapping spawns.
	var points := _get_spawn_points()
	if points.is_empty():
		return Vector3.ZERO

	var occupied := _get_occupied_positions()

	# If we already reserved a position for this peer (e.g. re-entrant call), reuse it.
	if _reserved_spawn_pos.has(peer_id):
		return _reserved_spawn_pos[peer_id]

	# 1) Exact marker positions.
	for m in points:
		if m and _is_position_clear(m.global_position, occupied):
			_reserved_spawn_pos[peer_id] = m.global_position
			return m.global_position

	# 2) Marker + ring offsets.
	for ring in range(1, SPAWN_RING_COUNT + 1):
		var r := float(ring) * SPAWN_MIN_SEPARATION
		for m in points:
			if not m:
				continue
			var base := m.global_position
			for step in range(SPAWN_RING_STEPS):
				var a := (TAU * float(step)) / float(SPAWN_RING_STEPS)
				var offset := Vector3(cos(a), 0.0, sin(a)) * r
				var candidate := base + offset
				if _is_position_clear(candidate, occupied):
					_reserved_spawn_pos[peer_id] = candidate
					return candidate

	# 3) Worst case fallback: deterministic marker selection (may overlap, but only if arena is extremely crowded).
	var idx: int = int(abs(peer_id)) % int(points.size())
	var fallback := points[idx].global_position
	_reserved_spawn_pos[peer_id] = fallback
	return fallback

func _get_occupied_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []

	# Existing spawned players.
	var players_root := get_node_or_null("Players") as Node
	if players_root:
		for c in players_root.get_children():
			if c is Node3D:
				out.append((c as Node3D).global_position)

	# Also include reserved positions for peers about to spawn.
	for k in _reserved_spawn_pos.keys():
		var v := _reserved_spawn_pos[k]
		if v is Vector3:
			out.append(v)

	return out

func _is_position_clear(pos: Vector3, occupied: Array[Vector3]) -> bool:
	for p in occupied:
		if p.distance_to(pos) < SPAWN_MIN_SEPARATION:
			return false
	return true
