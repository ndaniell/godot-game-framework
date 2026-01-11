extends Control

@onready var _host_button: Button = $Panel/VBox/HostButton
@onready var _join_button: Button = $Panel/VBox/JoinButton
@onready var _quit_button: Button = $Panel/VBox/QuitButton

func _ready() -> void:
	_host_button.pressed.connect(func(): _open_lobby("host"))
	_join_button.pressed.connect(func(): _open_lobby("join"))
	_quit_button.pressed.connect(_on_quit_pressed)

func _open_lobby(mode: String) -> void:
	if EventManager:
		EventManager.emit("fps_lobby_open", {"mode": mode})

func _on_quit_pressed() -> void:
	if GameManager:
		GameManager.quit_game()
