extends "res://scripts/autoload/NetworkManager.gd"

## FPSNetworkManager - Specialized network manager for FPS example
##
## Extends the base NetworkManager with FPS-specific functionality:
## - Arena ready coordination for level loading synchronization
## - Late-join handling for matchmaking

## Arena ready signals for game-level scene loading coordination.
signal arena_ready(peer_id: int)  # Emitted when a peer reports its arena is loaded

## Arena ready state tracking (server-side only).
var _arena_ready_peers: Dictionary = {}  # peer_id -> true


func _ready() -> void:
	# Get LogManager reference

	if LogManager:
		LogManager.info("NetworkManager", "NetworkManager initializing...")

	# Initialize logging context
	_update_logging_context()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if LogManager:
		LogManager.info("NetworkManager", "NetworkManager ready")

func is_network_connected() -> bool:
	return multiplayer.multiplayer_peer != null

func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()

func host(port: int = -1) -> bool:
	if port <= 0:
		port = default_port

	if LogManager:
		LogManager.info("NetworkManager", "Attempting to host on port " + str(port))
	disconnect_from_game()

	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, max_clients)
	if err != OK:
		_peer = null
		if LogManager:
			LogManager.error("NetworkManager", "Failed to create server on port " + str(port) + " (err=" + str(err) + ")")
		_emit_disconnected("host_failed_%d" % err)
		_notify_error("Failed to host (err=%d)" % err)
		return false

	multiplayer.multiplayer_peer = _peer

	if LogManager:
		LogManager.info("NetworkManager", "Successfully hosting on port " + str(port) + " (max clients: " + str(max_clients) + ")")
	network_host_started.emit(port)
	_emit_eventmanager("network_host_started", {"port": port})
	network_connected.emit("server")
	_emit_eventmanager("network_connected", {"mode": "server", "port": port})
	_notify_success("Hosting on port %d" % port)
	return true

func join(ip: String, port: int = -1) -> bool:
	if port <= 0:
		port = default_port

	if LogManager:
		LogManager.info("NetworkManager", "Attempting to join " + ip + ":" + str(port))
	disconnect_from_game()

	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(ip, port)
	if err != OK:
		_peer = null
		if LogManager:
			LogManager.error("NetworkManager", "Failed to create client for " + ip + ":" + str(port) + " (err=" + str(err) + ")")
		_emit_disconnected("join_failed_%d" % err)
		_notify_error("Failed to join (err=%d)" % err)
		return false

	multiplayer.multiplayer_peer = _peer
	if LogManager:
		LogManager.debug("NetworkManager", "Client created, waiting for connection...")
	network_connecting.emit(ip, port)
	_emit_eventmanager("network_connecting", {"ip": ip, "port": port})
	_notify_success("Connecting to %s:%d..." % [ip, port])
	return true

func disconnect_from_game() -> void:
	if multiplayer.multiplayer_peer == null:
		if LogManager:
			LogManager.debug("NetworkManager", "Disconnect called but already offline")
		return

	if LogManager:
		LogManager.info("NetworkManager", "Disconnecting from game")
	if _peer:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = null
	_emit_disconnected("manual")
	_notify_success("Disconnected")

## Server-only: broadcast a game-defined event to all peers (including host).
func broadcast_session_event(event_name: StringName, data: Dictionary = {}) -> void:
	if multiplayer.multiplayer_peer == null:
		if LogManager:
			LogManager.warn("NetworkManager", "broadcast_session_event called while offline")
		return
	if not multiplayer.is_server():
		if LogManager:
			LogManager.warn("NetworkManager", "only the host can broadcast session events")
		return

	if LogManager:
		LogManager.trace("NetworkManager", "Broadcasting session event: " + event_name)
	_rpc_session_event(event_name, data) # local on server
	_rpc_session_event.rpc(event_name, data) # remote on clients

## Server-only: send a game-defined event to one peer.
func send_session_event_to_peer(peer_id: int, event_name: StringName, data: Dictionary = {}) -> void:
	if multiplayer.multiplayer_peer == null:
		if LogManager:
			LogManager.warn("NetworkManager", "send_session_event_to_peer called while offline")
		return
	if not multiplayer.is_server():
		if LogManager:
			LogManager.warn("NetworkManager", "only the host can send session events")
		return
	if peer_id <= 0:
		if LogManager:
			LogManager.warn("NetworkManager", "invalid peer_id for send_session_event_to_peer")
		return

	if LogManager:
		LogManager.trace("NetworkManager", "Sending session event '" + event_name + "' to peer " + str(peer_id))
	_rpc_session_event.rpc_id(peer_id, event_name, data)

## Check if a peer has reported its arena as ready.
func is_peer_arena_ready(peer_id: int) -> bool:
	return _arena_ready_peers.has(peer_id)

## Get all peers that have reported arena ready.
func get_ready_peers() -> Array[int]:
	var ready_peers: Array[int] = []
	for peer_id in _arena_ready_peers:
		ready_peers.append(int(peer_id))
	return ready_peers

## Server-only: mark the local (host) arena as ready.
func report_local_arena_ready() -> void:
	# In test environments or offline, allow reporting as ready
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		if LogManager:
			LogManager.warn("NetworkManager", "report_local_arena_ready called on non-server")
		return
	var host_id := get_server_peer_id()
	_arena_ready_peers[host_id] = true
	if LogManager:
		LogManager.debug("NetworkManager", "Local (host) arena marked as ready")
	arena_ready.emit(host_id)
	_emit_eventmanager("arena_ready", {"peer_id": host_id})

## Client -> Server RPC: report that this peer's arena is loaded and ready.
@rpc("any_peer", "reliable")
func _rpc_report_arena_ready() -> void:
	if not multiplayer.is_server():
		if LogManager:
			LogManager.warn("NetworkManager", "_rpc_report_arena_ready called on non-server")
		return

	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return

	_arena_ready_peers[sender] = true
	if LogManager:
		LogManager.debug("NetworkManager", "Peer " + str(sender) + " reported arena ready")
	arena_ready.emit(sender)
	_emit_eventmanager("arena_ready", {"peer_id": sender})

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
	if LogManager:
		LogManager.info("NetworkManager", "Peer connected: " + str(peer_id))
	peer_joined.emit(peer_id)
	_emit_eventmanager("peer_joined", {"peer_id": peer_id})

func _on_peer_disconnected(peer_id: int) -> void:
	if LogManager:
		LogManager.info("NetworkManager", "Peer disconnected: " + str(peer_id))
	peer_left.emit(peer_id)
	_emit_eventmanager("peer_left", {"peer_id": peer_id})

	# Clean up arena ready state
	_arena_ready_peers.erase(peer_id)

func _on_connected_to_server() -> void:
	_update_logging_context()
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
	if EventManager:
		EventManager.emit(event_name, data)

func _notify_success(msg: String) -> void:
	if NotificationManager:
		NotificationManager.show_success(msg)

func _notify_error(msg: String) -> void:
	if NotificationManager:
		NotificationManager.show_error(msg)

## Update LogManager with current network context
func _update_logging_context() -> void:
	if LogManager:
		var peer_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 0
		var is_server := multiplayer.is_server() if multiplayer.multiplayer_peer else false
		LogManager.update_network_context(peer_id, is_server)