extends Node

@onready var _main_menu: Control = $MainMenu
@onready var _lobby: Control = $Lobby

func _ready() -> void:
	# Register UI elements with the framework UIManager
	if UIManager:
		UIManager.register_ui_element("fps_main_menu", _main_menu, UIManager.menu_layer)
		UIManager.register_ui_element("fps_lobby", _lobby, UIManager.menu_layer)
		UIManager.open_menu("fps_main_menu", true)

	# Route UI flow via the EventManager (template-friendly)
	if EventManager:
		EventManager.subscribe("fps_lobby_open", _on_lobby_open)
		EventManager.subscribe("fps_menu_open", _on_menu_open)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _exit_tree() -> void:
	if EventManager:
		EventManager.unsubscribe("fps_lobby_open", _on_lobby_open)
		EventManager.unsubscribe("fps_menu_open", _on_menu_open)

func _on_lobby_open(data: Dictionary) -> void:
	if UIManager:
		UIManager.open_menu("fps_lobby", true)
	# Forward mode selection to the lobby if it supports it
	if _lobby and _lobby.has_method("set_mode"):
		_lobby.call("set_mode", data.get("mode", "host"))

func _on_menu_open(_data: Dictionary) -> void:
	if UIManager:
		UIManager.open_menu("fps_main_menu", true)
