extends "res://scripts/autoload/InputManager.gd"


const ACTIONS := {
	"fps_move_forward": {
		"keys": [KEY_W],
	},
	"fps_move_back": {
		"keys": [KEY_S],
	},
	"fps_move_left": {
		"keys": [KEY_A],
	},
	"fps_move_right": {
		"keys": [KEY_D],
	},
	"fps_jump": {
		"keys": [KEY_SPACE],
	},
	"fps_shoot": {
		"mouse_buttons": [MOUSE_BUTTON_LEFT],
	},
	"fps_toggle_view": {
		"keys": [KEY_V],
	},
}

func _ready() -> void:
	# Get LogManager reference

	LogManager.info("FpsInputManager", "FpsInputManager initializing...")
	super._ready()
	LogManager.info("FpsInputManager", "FpsInputManager ready")

func _initialize_input_actions() -> void:
	for action_name in ACTIONS.keys():
		_ensure_action(action_name)
	_restore_all_defaults()

func _restore_default_action(action: String) -> void:
	if not ACTIONS.has(action):
		return
	_apply_defaults_for(action)

func _ensure_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

func _restore_all_defaults() -> void:
	for action_name in ACTIONS.keys():
		InputMap.action_erase_events(action_name)
		_apply_defaults_for(action_name)

func _apply_defaults_for(action_name: String) -> void:
	var spec := ACTIONS[action_name] as Dictionary

	var keys: Array = spec.get("keys", [])
	for k in keys:
		var ev := InputEventKey.new()
		ev.keycode = k as Key
		InputMap.action_add_event(action_name, ev)

	var mouse_buttons: Array = spec.get("mouse_buttons", [])
	for b in mouse_buttons:
		var mev := InputEventMouseButton.new()
		mev.button_index = b as MouseButton
		InputMap.action_add_event(action_name, mev)

