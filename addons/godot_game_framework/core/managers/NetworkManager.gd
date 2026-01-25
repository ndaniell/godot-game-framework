class_name GGF_NetworkManager
extends Node

## NetworkManager - Generic ENet networking helper for the Godot Game Framework
##
## This manager owns the active `MultiplayerPeer` (ENet) and exposes convenience methods
## for hosting/joining/disconnecting. Game-specific code should react to events rather
## than being hardcoded into this manager.
##
## Integration:
## - Emits its own signals
## - Mirrors key lifecycle events onto EventManager (if present)

signal network_host_started(port: int)
signal network_connecting(ip: String, port: int)
signal network_connected(mode: String)  # "server" | "client"
signal network_disconnected(reason: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

## Generic, game-defined events broadcast from the server to all peers.
signal session_event_received(event_name: StringName, data: Dictionary)

@export var default_port: int = 8910
@export var max_clients: int = 16

var _peer: ENetMultiplayerPeer


func _ready() -> void:
	# Get LogManager reference

	GGF.log().info("NetworkManager", "NetworkManager initializing...")
	# Initialize logging context
	_update_logging_context()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	GGF.log().info("NetworkManager", "NetworkManager ready")


func _is_offline_peer(peer: MultiplayerPeer) -> bool:
	# Godot's SceneMultiplayer defaults to an OfflineMultiplayerPeer (always "connected").
	# Treat this as offline for user-facing state and tests.
	return peer == null or peer is OfflineMultiplayerPeer


func is_network_connected() -> bool:
	return not _is_offline_peer(multiplayer.multiplayer_peer)


func is_host() -> bool:
	return not _is_offline_peer(multiplayer.multiplayer_peer) and multiplayer.is_server()


## Best-effort server peer-id lookup.
## - On the host, this is always `multiplayer.get_unique_id()`.
## - On ENet clients, the server is always peer id `1`.
## - For non-ENet peers, we fall back to inference (smallest connected peer-id).
func get_server_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1
	if multiplayer.is_server():
		return multiplayer.get_unique_id()
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return 1
	var peers := multiplayer.get_peers()
	if peers.is_empty():
		return 1
	var server_id := int(peers[0])
	for p in peers:
		server_id = mini(server_id, int(p))
	return server_id


func host(port: int = -1) -> bool:
	if port <= 0:
		port = default_port

	GGF.log().info("NetworkManager", "Attempting to host on port " + str(port))
	disconnect_from_game()

	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, max_clients)
	if err != OK:
		_peer = null
		GGF.log().error(
			"NetworkManager",
			"Failed to create server on port " + str(port) + " (err=" + str(err) + ")"
		)
		_emit_disconnected("host_failed_%d" % err)
		_notify_error("Failed to host (err=%d)" % err)
		return false

	multiplayer.multiplayer_peer = _peer

	GGF.log().info(
		"NetworkManager",
		"Successfully hosting on port " + str(port) + " (max clients: " + str(max_clients) + ")"
	)
	network_host_started.emit(port)
	_emit_eventmanager("network_host_started", {"port": port})
	network_connected.emit("server")
	_emit_eventmanager("network_connected", {"mode": "server", "port": port})
	_notify_success("Hosting on port %d" % port)
	return true


func join(ip: String, port: int = -1) -> bool:
	if port <= 0:
		port = default_port

	GGF.log().info("NetworkManager", "Attempting to join " + ip + ":" + str(port))
	disconnect_from_game()

	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(ip, port)
	if err != OK:
		_peer = null
		GGF.log().error(
			"NetworkManager",
			"Failed to create client for " + ip + ":" + str(port) + " (err=" + str(err) + ")"
		)
		_emit_disconnected("join_failed_%d" % err)
		_notify_error("Failed to join (err=%d)" % err)
		return false

	multiplayer.multiplayer_peer = _peer
	GGF.log().debug("NetworkManager", "Client created, waiting for connection...")
	network_connecting.emit(ip, port)
	_emit_eventmanager("network_connecting", {"ip": ip, "port": port})
	_notify_success("Connecting to %s:%d..." % [ip, port])
	return true


func disconnect_from_game() -> void:
	if (
		multiplayer.multiplayer_peer == null
		or multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	):
		GGF.log().debug("NetworkManager", "Disconnect called but already offline")
		return

	GGF.log().info("NetworkManager", "Disconnecting from game")
	if _peer:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = null
	_emit_disconnected("manual")
	_notify_success("Disconnected")


## Server-only: broadcast a game-defined event to all peers (including host).
func broadcast_session_event(event_name: StringName, data: Dictionary = {}) -> void:
	if multiplayer.multiplayer_peer == null:
		GGF.log().warn("NetworkManager", "broadcast_session_event called while offline")
		return
	if not multiplayer.is_server():
		GGF.log().warn("NetworkManager", "only the host can broadcast session events")
		return

	GGF.log().trace("NetworkManager", "Broadcasting session event: " + event_name)
	_rpc_session_event(event_name, data)  # local on server
	_rpc_session_event.rpc(event_name, data)  # remote on clients


## Server-only: send a game-defined event to one peer.
func send_session_event_to_peer(
	peer_id: int, event_name: StringName, data: Dictionary = {}
) -> void:
	if multiplayer.multiplayer_peer == null:
		GGF.log().warn("NetworkManager", "send_session_event_to_peer called while offline")
		return
	if not multiplayer.is_server():
		GGF.log().warn("NetworkManager", "only the host can send session events")
		return
	if peer_id <= 0:
		GGF.log().warn("NetworkManager", "invalid peer_id for send_session_event_to_peer")
		return

	GGF.log().trace(
		"NetworkManager", "Sending session event '" + event_name + "' to peer " + str(peer_id)
	)
	_rpc_session_event.rpc_id(peer_id, event_name, data)


@rpc("any_peer", "reliable")
func _rpc_session_event(event_name: StringName, data: Dictionary) -> void:
	# Accept local server call (sender=0) and server->client calls (sender=<server peer id>).
	var sender := multiplayer.get_remote_sender_id()
	var server_id := get_server_peer_id()
	if sender != 0 and sender != server_id:
		return

	session_event_received.emit(event_name, data)
	_emit_eventmanager(String(event_name), data)


func _on_peer_connected(peer_id: int) -> void:
	GGF.log().info("NetworkManager", "Peer connected: " + str(peer_id))
	peer_joined.emit(peer_id)
	_emit_eventmanager("peer_joined", {"peer_id": peer_id})


func _on_peer_disconnected(peer_id: int) -> void:
	GGF.log().info("NetworkManager", "Peer disconnected: " + str(peer_id))
	peer_left.emit(peer_id)
	_emit_eventmanager("peer_left", {"peer_id": peer_id})


func _on_connected_to_server() -> void:
	# This signal is meant for clients; hosts should rely on `host()` success messaging.
	if multiplayer.is_server():
		return
	network_connected.emit("client")
	_emit_eventmanager("network_connected", {"mode": "client"})
	_notify_success("Connected")


func _on_connection_failed() -> void:
	_notify_error("Connection failed")
	disconnect_from_game()


func _on_server_disconnected() -> void:
	_notify_error("Server disconnected")
	disconnect_from_game()


func _emit_disconnected(reason: String) -> void:
	network_disconnected.emit(reason)
	_emit_eventmanager("network_disconnected", {"reason": reason})


func _emit_eventmanager(event_name: String, data: Dictionary) -> void:
	var event_manager := GGF.events()
	if event_manager and event_manager.has_method("emit"):
		event_manager.emit(event_name, data)


func _notify_success(msg: String) -> void:
	var notifications := GGF.notifications()
	if notifications and notifications.has_method("show_success"):
		notifications.show_success(msg)


func _notify_error(msg: String) -> void:
	var notifications := GGF.notifications()
	if notifications and notifications.has_method("show_error"):
		notifications.show_error(msg)


## Update LogManager with current network context
func _update_logging_context() -> void:
	var logger := GGF.log()
	if logger and logger.has_method("update_network_context"):
		var peer := multiplayer.multiplayer_peer
		var peer_id := multiplayer.get_unique_id() if not _is_offline_peer(peer) else 0
		var is_server := multiplayer.is_server() if not _is_offline_peer(peer) else false
		logger.update_network_context(peer_id, is_server)
