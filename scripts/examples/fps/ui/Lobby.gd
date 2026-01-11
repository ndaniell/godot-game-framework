extends Control

var _mode: String = "host"
const SCENE_ARENA := "res://scenes/fps/levels/Arena01.tscn"

@onready var _ip_edit: LineEdit = $Panel/VBox/ConnectionRow/IpEdit
@onready var _port_edit: LineEdit = $Panel/VBox/ConnectionRow/PortEdit
@onready var _host_button: Button = $Panel/VBox/ButtonsRow/HostButton
@onready var _join_button: Button = $Panel/VBox/ButtonsRow/JoinButton
@onready var _start_match_button: Button = $Panel/VBox/ButtonsRow/StartMatchButton
@onready var _disconnect_button: Button = $Panel/VBox/ButtonsRow/DisconnectButton
@onready var _players_list: ItemList = $Panel/VBox/PlayersList

func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_disconnect_button.pressed.connect(_on_disconnect_pressed)
	_start_match_button.pressed.connect(_on_start_match_pressed)

	_refresh_buttons()
	_refresh_players()

	# Network updates will be wired in once NetworkManager exists
	if EventManager:
		EventManager.subscribe("network_connected", _on_network_changed)
		EventManager.subscribe("network_disconnected", _on_network_changed)
		EventManager.subscribe("peer_joined", _on_network_changed)
		EventManager.subscribe("peer_left", _on_network_changed)

func _exit_tree() -> void:
	if EventManager:
		EventManager.unsubscribe("network_connected", _on_network_changed)
		EventManager.unsubscribe("network_disconnected", _on_network_changed)
		EventManager.unsubscribe("peer_joined", _on_network_changed)
		EventManager.unsubscribe("peer_left", _on_network_changed)

func set_mode(mode: String) -> void:
	_mode = mode
	_refresh_buttons()

func _parse_port() -> int:
	var port := int(_port_edit.text)
	if port <= 0:
		port = 8910
	return port

func _on_host_pressed() -> void:
	_mode = "host"
	_refresh_buttons()
	if NetworkManager:
		NetworkManager.host(_parse_port())

func _on_join_pressed() -> void:
	_mode = "join"
	_refresh_buttons()
	if NetworkManager:
		NetworkManager.join(_ip_edit.text.strip_edges(), _parse_port())

func _on_disconnect_pressed() -> void:
	if NetworkManager:
		NetworkManager.disconnect_from_game()

func _on_start_match_pressed() -> void:
	if NetworkManager:
		# Generic: ask the host to broadcast a game-defined event.
		NetworkManager.broadcast_session_event(&"fps_match_start", {})

func _on_network_changed(_data: Dictionary) -> void:
	_refresh_buttons()
	_refresh_players()

func _refresh_buttons() -> void:
	var connected := multiplayer.multiplayer_peer != null
	var is_server := connected and multiplayer.is_server()
	_start_match_button.disabled = not is_server
	_disconnect_button.disabled = not connected

func _refresh_players() -> void:
	_players_list.clear()
	if multiplayer.multiplayer_peer == null:
		_players_list.add_item("Offline")
		return

	var server_id := 1
	_players_list.add_item("Peer %d (server)" % server_id)
	for peer_id in multiplayer.get_peers():
		_players_list.add_item("Peer %d" % int(peer_id))

