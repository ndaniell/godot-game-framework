extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/fps/player/Player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/fps/ui/HUD.tscn")

@onready var _spawner: MultiplayerSpawner = $Spawner
@onready var _spawn_points_root: Node3D = $SpawnPoints

var _hud_instance: Control
var _pending_ready: Dictionary = {} # peer_id -> true

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

	if multiplayer.is_server():
		# Spawn host player immediately. Other peers will be spawned after they confirm Arena01 is loaded.
		_spawn_for_peer(1)
		for peer_id in multiplayer.get_peers():
			_pending_ready[int(peer_id)] = true
	else:
		# Tell the server we're ready so it can safely spawn our player via MultiplayerSpawner.
		if multiplayer.multiplayer_peer != null:
			_rpc_arena_ready.rpc_id(1)

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if UIManager:
		UIManager.unregister_ui_element("fps_hud")
	if _hud_instance and is_instance_valid(_hud_instance):
		_hud_instance.queue_free()

func _on_peer_connected(peer_id: int) -> void:
	if EventManager:
		EventManager.emit("peer_joined", {"peer_id": peer_id})
	if multiplayer.is_server():
		# Wait for the client to load Arena01, otherwise MultiplayerSpawner sync will fail on their side.
		_pending_ready[peer_id] = true

func _on_peer_disconnected(peer_id: int) -> void:
	if EventManager:
		EventManager.emit("peer_left", {"peer_id": peer_id})
	_pending_ready.erase(peer_id)
	# MultiplayerSpawner will automatically despawn spawned nodes when peers leave (by node ownership),
	# but we also clean up our naming convention if needed.
	var players_root := get_node_or_null("Players") as Node
	if players_root:
		var node_name := "Player_%d" % peer_id
		var player := players_root.get_node_or_null(node_name)
		if player:
			player.queue_free()

func _spawn_for_peer(peer_id: int) -> void:
	# Data travels to all peers; each creates the node locally using spawn_function.
	_spawner.spawn({"peer_id": peer_id})

@rpc("any_peer", "reliable")
func _rpc_arena_ready() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	if not _pending_ready.has(sender):
		return
	_pending_ready.erase(sender)
	_spawn_for_peer(sender)

func _spawn_player(data: Variant) -> Node:
	var d := data as Dictionary
	var peer_id := int(d.get("peer_id", 0))
	var player := PLAYER_SCENE.instantiate() as Node
	player.name = "Player_%d" % peer_id

	# Server-authoritative player logic for this sample.
	player.set_multiplayer_authority(1)
	if player.has_method("set_owner_peer_id"):
		player.call("set_owner_peer_id", peer_id)

	_place_at_spawn(player, peer_id)
	return player

func _place_at_spawn(player: Node, peer_id: int) -> void:
	var points := _get_spawn_points()
	if points.is_empty():
		return
	var idx: int = int(abs(peer_id)) % int(points.size())
	var marker: Marker3D = points[idx]
	if marker and player is Node3D:
		var p3d := player as Node3D
		# When called from MultiplayerSpawner.spawn_function, the node may not be inside the tree yet.
		# Setting global transforms in that case can error; set local position first.
		if p3d.is_inside_tree():
			p3d.global_position = marker.global_position
		else:
			p3d.position = marker.global_position

func _get_spawn_points() -> Array[Marker3D]:
	var out: Array[Marker3D] = []
	for c in _spawn_points_root.get_children():
		if c is Marker3D:
			out.append(c)
	return out
