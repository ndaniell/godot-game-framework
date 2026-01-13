extends Control

@onready var _resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var _leave_match_button: Button = $Panel/VBoxContainer/LeaveMatchButton
@onready var _quit_game_button: Button = $Panel/VBoxContainer/QuitGameButton

func _ready() -> void:
	# Set process mode to always so we can receive input even when other things might be paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	_resume_button.pressed.connect(_on_resume_pressed)
	_leave_match_button.pressed.connect(_on_leave_match_pressed)
	_quit_game_button.pressed.connect(_on_quit_game_pressed)

func _input(event: InputEvent) -> void:
	# Handle Esc key to close the menu (same as Resume)
	if event.is_action_pressed("fps_pause"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()

func _on_resume_pressed() -> void:
	# Hide the menu and recapture mouse
	if UIManager:
		UIManager.hide_ui_element("fps_pause_menu")

	# Recapture mouse for gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_leave_match_pressed() -> void:
	# Hide the menu first
	if UIManager:
		UIManager.hide_ui_element("fps_pause_menu")

	# Disconnect from network if connected, otherwise just change state to MENU
	if NetworkManager and NetworkManager.is_network_connected():
		NetworkManager.disconnect_from_game()
	else:
		# If not connected, just go back to menu state
		if GameManager:
			GameManager.change_state("MENU")

func _on_quit_game_pressed() -> void:
	# Quit the game
	if GameManager:
		GameManager.quit_game()