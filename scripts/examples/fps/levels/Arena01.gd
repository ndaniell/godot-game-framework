extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/fps/player/Player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/fps/ui/HUD.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/fps/ui/PauseMenu.tscn")

var _spawner: MultiplayerSpawner
@onready var _spawn_points_root: Node3D = $SpawnPoints

var _hud_instance: Control
var _pause_menu_instance: Control
var _pending_ready: Dictionary = {} # peer_id -> true

# Spawn de-overlap settings.
const SPAWN_MIN_SEPARATION: float = 2.5
const SPAWN_RING_COUNT: int = 6
const SPAWN_RING_STEPS: int = 8

# Server-side spawn reservations (to avoid double-allocating the same position).
var _reserved_spawn_pos: Dictionary = {} # peer_id -> Vector3

func _ready() -> void:
	LogManager.info("Arena01", "Arena01 _ready called for peer %d" % multiplayer.get_unique_id())
	LogManager.info("Arena01", "Available child nodes: %s" % str(get_children().map(func(n): return n.name)))

	# Get the spawner node with error checking
	_spawner = $Spawner as MultiplayerSpawner
	if not _spawner:
		LogManager.error("Arena01", "Failed to find Spawner node!")
		return

	# HUD is purely local UI; we register it into UIManager for consistent layering.
	_hud_instance = HUD_SCENE.instantiate() as Control
	if UIManager and _hud_instance:
		UIManager.register_ui_element("fps_hud", _hud_instance, UIManager.game_layer)
		UIManager.show_ui_element("fps_hud")

	# Pause menu is an overlay that can be toggled with Esc
	_pause_menu_instance = PAUSE_MENU_SCENE.instantiate() as Control
	if UIManager and _pause_menu_instance:
		UIManager.register_ui_element("fps_pause_menu", _pause_menu_instance, UIManager.overlay_layer)
		UIManager.hide_ui_element("fps_pause_menu") # Keep it hidden initially

	# Mouse capture is handled by individual PlayerController instances for local players

	# Using manual RPC spawning instead of MultiplayerSpawner to avoid synchronization issues
	LogManager.info("Arena01", "Manual RPC spawning configured for peer %d" % multiplayer.get_unique_id())

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Connect to game state changes to spawn players when game starts
	if GameManager:
		GameManager.game_state_changed.connect(_on_game_state_changed)

	# Connect to NetworkManager signals for arena ready coordination
	_connect_network_manager_signals()

	if multiplayer.multiplayer_peer and multiplayer.is_server():
		# Server spawns its own player immediately (do not assume server peer id == 1)
		var host_id := multiplayer.get_unique_id()
		_spawn_for_peer(host_id)
		# Mark the host's arena as ready (server-side tracking)
		if NetworkManager:
			NetworkManager.report_local_arena_ready()
		for peer_id in multiplayer.get_peers():
			_pending_ready[int(peer_id)] = true
	else:
		# Client spawns itself locally
		_spawn_player_local(multiplayer.get_unique_id())
		# Tell NetworkManager we're ready so server can spawn our player for others
		if NetworkManager and multiplayer.multiplayer_peer != null:
			LogManager.info("Arena01", "Client reporting arena ready")
			NetworkManager._rpc_report_arena_ready.rpc_id(NetworkManager.get_server_peer_id())

func _process(_delta: float) -> void:
	# Handle pause menu toggle
	if InputManager and InputManager.is_action_just_pressed("fps_pause"):
		_toggle_pause_menu()

func _toggle_pause_menu() -> void:
	if not UIManager or not _pause_menu_instance:
		return

	var pause_menu_visible := UIManager.is_ui_element_visible("fps_pause_menu")

	if pause_menu_visible:
		# Hide menu and recapture mouse
		UIManager.hide_ui_element("fps_pause_menu")
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		# Show menu and release mouse
		UIManager.show_ui_element("fps_pause_menu")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _exit_tree() -> void:
	# Disconnect NetworkManager signals to prevent accumulation on scene reload
	if NetworkManager:
		if NetworkManager.arena_ready.is_connected(_on_peer_arena_ready):
			NetworkManager.arena_ready.disconnect(_on_peer_arena_ready)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if UIManager:
		UIManager.unregister_ui_element("fps_hud")
		UIManager.unregister_ui_element("fps_pause_menu")
	if _hud_instance and is_instance_valid(_hud_instance):
		_hud_instance.queue_free()
	if _pause_menu_instance and is_instance_valid(_pause_menu_instance):
		_pause_menu_instance.queue_free()

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

func _spawn_player_local(peer_id: int) -> void:
	# Spawn player locally with appropriate spawn position
	LogManager.info("Arena01", "Spawning player locally for peer %d" % peer_id)
	var data := {"peer_id": peer_id}

	# Choose spawn position (server chooses for all, client uses default)
	if multiplayer.multiplayer_peer and multiplayer.is_server():
		var pos := _choose_spawn_position(peer_id)
		data["spawn_pos"] = pos
		LogManager.info("Arena01", "Spawn position for peer %d: %s" % [peer_id, str(pos)])

	var player := _spawn_player(data)
	if player:
		# Add to Players node
		var players_node = get_node_or_null("Players")
		if players_node:
			players_node.add_child(player)

func _spawn_for_peer(peer_id: int) -> void:
	# Server spawns the player locally first
	LogManager.info("Arena01", "Spawning player %d locally on server" % peer_id)
	var data := {"peer_id": peer_id, "server_peer_id": multiplayer.get_unique_id()}
	if multiplayer.multiplayer_peer and multiplayer.is_server():
		var pos := _choose_spawn_position(peer_id)
		data["spawn_pos"] = pos
		LogManager.info("Arena01", "Spawn position for peer %d: %s" % [peer_id, str(pos)])

	# Spawn locally on server
	var player := _spawn_player(data)
	if player:
		var players_node = get_node_or_null("Players")
		if players_node:
			players_node.add_child(player)

	# Use RPC to spawn on all clients
	_spawn_player_remote.rpc(data)

@rpc("authority", "reliable")
func _spawn_player_remote(data: Dictionary) -> void:
	var peer_id = data.get("peer_id", 0)
	LogManager.info("Arena01", "Received remote spawn RPC for peer %d on peer %d" % [peer_id, multiplayer.get_unique_id()])

	# Don't spawn if this player already exists locally
	var players_node = get_node_or_null("Players")
	if players_node:
		var existing_player = players_node.get_node_or_null("Player_%d" % peer_id)
		if existing_player:
			# Client may have spawned locally; reconcile authority + spawn position with server data.
			if existing_player.has_method("set_multiplayer_authority"):
				existing_player.set_multiplayer_authority(int(data.get("server_peer_id", NetworkManager.get_server_peer_id() if NetworkManager else 1)))
			if existing_player.has_method("set_owner_peer_id"):
				existing_player.call("set_owner_peer_id", peer_id)
			_place_at_spawn(existing_player, peer_id, data)
			LogManager.info("Arena01", "Player %d already exists locally; reconciled from server spawn" % peer_id)
			return

	var player := _spawn_player(data)
	if player:
		# Add to Players node
		if players_node:
			players_node.add_child(player)

func _on_game_state_changed(_old_state: String, new_state: String) -> void:
	if not multiplayer.multiplayer_peer or not multiplayer.is_server():
		return

	if new_state == "PLAYING":
		LogManager.info("Arena01", "Game started - spawning all ready clients")
		# Spawn any clients that reported ready but haven't been spawned yet
		for peer_id in _pending_ready.keys():
			LogManager.info("Arena01", "Spawning pending client %d" % peer_id)
			_spawn_for_peer(peer_id)
			_pending_ready.erase(peer_id)

# Connect to NetworkManager's arena_ready signal instead of direct RPC
func _connect_network_manager_signals() -> void:
	if NetworkManager:
		NetworkManager.arena_ready.connect(_on_peer_arena_ready)

func _on_peer_arena_ready(peer_id: int) -> void:
	if not multiplayer.multiplayer_peer or not multiplayer.is_server():
		return
	if not _pending_ready.has(peer_id):
		LogManager.warn("Arena01", "Peer %d reported arena ready but was not in pending list" % peer_id)
		return
	_pending_ready.erase(peer_id)
	LogManager.info("Arena01", "Client %d is ready - spawning player for everyone" % peer_id)
	_spawn_for_peer(peer_id)

func _spawn_player(data: Variant) -> Node:
	var d := data as Dictionary
	var peer_id := int(d.get("peer_id", 0))
	LogManager.info("Arena01", "Instantiating player for peer %d (local peer: %d)" % [peer_id, multiplayer.get_unique_id()])
	var player := PLAYER_SCENE.instantiate() as Node
	player.name = "Player_%d" % peer_id

	# Server has authority over all players for synchronization
	var server_peer_id := int(d.get("server_peer_id", NetworkManager.get_server_peer_id() if NetworkManager else 1))
	player.set_multiplayer_authority(server_peer_id)
	if player.has_method("set_owner_peer_id"):
		player.call("set_owner_peer_id", peer_id)

	_place_at_spawn(player, peer_id, d)
	# Log position after placement (can't access global_position until node is in tree)
	var spawn_pos = data.get("spawn_pos", Vector3.ZERO)
	LogManager.info("Arena01", "Player spawned for peer %d at spawn position %s" % [peer_id, str(spawn_pos)])
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
		var v: Vector3 = _reserved_spawn_pos[k]
		if v is Vector3:
			out.append(v)

	return out

func _is_position_clear(pos: Vector3, occupied: Array[Vector3]) -> bool:
	for p in occupied:
		if p.distance_to(pos) < SPAWN_MIN_SEPARATION:
			return false
	return true
