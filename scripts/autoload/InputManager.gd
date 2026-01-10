extends Node

## InputManager - Extensible input management system for the Godot Game Framework
##
## This manager handles input actions, remapping, and input validation.
## Extend this class to add custom input functionality.

signal input_action_pressed(action: String)
signal input_action_released(action: String)
signal input_remapped(action: String, old_event: InputEvent, new_event: InputEvent)
signal input_mode_changed(mode: String)

# Input modes
enum InputMode {
	KEYBOARD_MOUSE,
	GAMEPAD,
	TOUCH,
	AUTO
}

# Current input mode
var current_input_mode: InputMode = InputMode.AUTO:
	set(value):
		current_input_mode = value
		var mode_keys := InputMode.keys()
		var mode_name: String = mode_keys[value]
		input_mode_changed.emit(mode_name)
		_on_input_mode_changed(value)

# Input remapping data
var _input_remaps: Dictionary = {}
var _remap_file_path: String = "user://input_remaps.save"

## Initialize the input manager
## Override this method to add custom initialization
func _ready() -> void:
	# Skip input detection in headless mode to avoid "Unrecognized output string" warnings
	if DisplayServer.get_name() == "headless":
		current_input_mode = InputMode.KEYBOARD_MOUSE
		_initialize_input_actions()
		_on_input_manager_ready()
		return
	
	_load_input_remaps()
	_detect_input_mode()
	_initialize_input_actions()
	_on_input_manager_ready()

## Initialize input actions
## Override this method to set up default input actions
func _initialize_input_actions() -> void:
	# Override to register default input actions
	pass

## Detect current input mode
## Override this method to customize input mode detection
func _detect_input_mode() -> void:
	if current_input_mode == InputMode.AUTO:
		_auto_detect_input_mode()

## Auto-detect input mode based on current input
func _auto_detect_input_mode() -> void:
	# Skip gamepad detection in headless mode to avoid "Unrecognized output string" warnings
	if DisplayServer.get_name() == "headless":
		current_input_mode = InputMode.KEYBOARD_MOUSE
		return
	
	# Check for gamepad input
	for i in range(8):  # Check up to 8 gamepads
		if Input.is_joy_known(i):
			current_input_mode = InputMode.GAMEPAD
			return
	
	# Check for touch input
	if DisplayServer.is_touchscreen_available():
		current_input_mode = InputMode.TOUCH
		return
	
	# Default to keyboard/mouse
	current_input_mode = InputMode.KEYBOARD_MOUSE

## Check if an input action is pressed
## Override this method to add custom press detection
func is_action_pressed(action: String) -> bool:
	if not InputMap.has_action(action):
		push_warning("InputManager: Action does not exist: " + action)
		return false
	
	var pressed := Input.is_action_pressed(action)
	if pressed:
		input_action_pressed.emit(action)
		_on_action_pressed(action)
	return pressed

## Check if an input action was just pressed this frame
func is_action_just_pressed(action: String) -> bool:
	if not InputMap.has_action(action):
		push_warning("InputManager: Action does not exist: " + action)
		return false
	
	var just_pressed := Input.is_action_just_pressed(action)
	if just_pressed:
		input_action_pressed.emit(action)
		_on_action_just_pressed(action)
	return just_pressed

## Check if an input action was just released this frame
func is_action_just_released(action: String) -> bool:
	if not InputMap.has_action(action):
		push_warning("InputManager: Action does not exist: " + action)
		return false
	
	var just_released := Input.is_action_just_released(action)
	if just_released:
		input_action_released.emit(action)
		_on_action_just_released(action)
	return just_released

## Get action strength (0.0 to 1.0)
func get_action_strength(action: String) -> float:
	if not InputMap.has_action(action):
		push_warning("InputManager: Action does not exist: " + action)
		return 0.0
	return Input.get_action_strength(action)

## Get action raw strength (can be negative for axes)
func get_action_raw_strength(action: String, exact: bool = false) -> float:
	if not InputMap.has_action(action):
		push_warning("InputManager: Action does not exist: " + action)
		return 0.0
	return Input.get_axis(action, action) if exact else Input.get_action_strength(action)

## Get action vector (for 2D movement)
func get_action_vector(negative_x: String, positive_x: String, negative_y: String, positive_y: String, exact: bool = false) -> Vector2:
	if not InputMap.has_action(negative_x) or not InputMap.has_action(positive_x) or \
	   not InputMap.has_action(negative_y) or not InputMap.has_action(positive_y):
		push_warning("InputManager: One or more actions do not exist")
		return Vector2.ZERO
	return Input.get_vector(negative_x, positive_x, negative_y, positive_y, 0.5 if exact else 0.0)

## Remap an input action
## Override this method to add custom remapping logic
func remap_action(action: String, event: InputEvent, remove_old: bool = true) -> bool:
	if not InputMap.has_action(action):
		push_error("InputManager: Cannot remap non-existent action: " + action)
		return false
	
	# Get old events
	var old_events := InputMap.action_get_events(action)
	
	# Remove old event if specified
	if remove_old and old_events.size() > 0:
		# Check if we should remove conflicting events
		_remove_conflicting_events(event)
	
	# Add new event
	InputMap.action_add_event(action, event)
	
	# Store remap
	if not _input_remaps.has(action):
		_input_remaps[action] = []
	_input_remaps[action].append(event)
	
	# Emit signal
	if old_events.size() > 0:
		input_remapped.emit(action, old_events[0], event)
	_on_action_remapped(action, old_events[0] if old_events.size() > 0 else null, event)
	
	# Save remaps
	_save_input_remaps()
	
	return true

## Remove conflicting events from other actions
func _remove_conflicting_events(event: InputEvent) -> void:
	for action_name in InputMap.get_actions():
		var events := InputMap.action_get_events(action_name)
		for existing_event in events:
			if _events_match(existing_event, event):
				InputMap.action_erase_event(action_name, existing_event)

## Check if two input events match
func _events_match(event1: InputEvent, event2: InputEvent) -> bool:
	if event1.get_class() != event2.get_class():
		return false
	
	match event1.get_class():
		"InputEventKey":
			return event1.keycode == event2.keycode
		"InputEventMouseButton":
			return event1.button_index == event2.button_index
		"InputEventJoypadButton":
			return event1.button_index == event2.button_index
		"InputEventJoypadMotion":
			return event1.axis == event2.axis
		_:
			return false

## Reset action to default mapping
func reset_action(action: String) -> bool:
	if not InputMap.has_action(action):
		push_error("InputManager: Cannot reset non-existent action: " + action)
		return false
	
	# Clear current events
	InputMap.action_erase_events(action)
	
	# Remove from remaps
	_input_remaps.erase(action)
	
	# Restore default (override to implement default restoration)
	_restore_default_action(action)
	
	# Save remaps
	_save_input_remaps()
	
	_on_action_reset(action)
	
	return true

## Restore default action mapping
## Override this method to restore default input mappings
func _restore_default_action(action: String) -> void:
	# Override to implement default action restoration
	pass

## Reset all actions to defaults
func reset_all_actions() -> void:
	for action in InputMap.get_actions():
		reset_action(action)
	_on_all_actions_reset()

## Get remapped events for an action
func get_action_remaps(action: String) -> Array:
	if not _input_remaps.has(action):
		return []
	return _input_remaps[action].duplicate()

## Check if action has remaps
func has_remaps(action: String) -> bool:
	return _input_remaps.has(action) and _input_remaps[action].size() > 0

## Save input remaps to file
## Override this method to customize save format
func _save_input_remaps() -> void:
	var file := FileAccess.open(_remap_file_path, FileAccess.WRITE)
	if file == null:
		push_warning("InputManager: Failed to save input remaps")
		return
	
	# Convert events to dictionary format
	var remap_data := {}
	for action in _input_remaps:
		var events_val: Variant = _input_remaps[action]
		var events: Array = events_val if events_val is Array else []
		var event_data := []
		for event in events:
			event_data.append(_event_to_dict(event as InputEvent))
		remap_data[action] = event_data
	
	file.store_string(JSON.stringify(remap_data))
	file.close()
	_on_remaps_saved()

## Load input remaps from file
## Override this method to customize load format
func _load_input_remaps() -> void:
	if not FileAccess.file_exists(_remap_file_path):
		return
	
	var file := FileAccess.open(_remap_file_path, FileAccess.READ)
	if file == null:
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_warning("InputManager: Failed to parse input remaps")
		return
	
	var remap_data := json.data as Dictionary
	_input_remaps = {}
	
	for action in remap_data:
		if not InputMap.has_action(action):
			continue
		
		var event_data_array := remap_data[action] as Array
		_input_remaps[action] = []
		
		for event_data in event_data_array:
			var event := _dict_to_event(event_data as Dictionary)
			if event != null:
				InputMap.action_add_event(action, event)
				_input_remaps[action].append(event)
	
	_on_remaps_loaded()

## Convert InputEvent to Dictionary
func _event_to_dict(event: InputEvent) -> Dictionary:
	var dict := {"type": event.get_class()}
	
	match event.get_class():
		"InputEventKey":
			dict["keycode"] = event.keycode
			dict["physical_keycode"] = event.physical_keycode
		"InputEventMouseButton":
			dict["button_index"] = event.button_index
		"InputEventJoypadButton":
			dict["button_index"] = event.button_index
		"InputEventJoypadMotion":
			dict["axis"] = event.axis
			dict["axis_value"] = event.axis_value
	
	return dict

## Convert Dictionary to InputEvent
func _dict_to_event(dict: Dictionary) -> InputEvent:
	var event_type_val: Variant = dict.get("type", "")
	var event_type: String = event_type_val if event_type_val is String else ""
	var event: InputEvent = null
	
	match event_type:
		"InputEventKey":
			var key_event := InputEventKey.new()
			key_event.keycode = dict.get("keycode", 0) as Key
			key_event.physical_keycode = dict.get("physical_keycode", 0) as Key
			event = key_event
		"InputEventMouseButton":
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = dict.get("button_index", 0) as MouseButton
			event = mouse_event
		"InputEventJoypadButton":
			var joypad_event := InputEventJoypadButton.new()
			joypad_event.button_index = dict.get("button_index", 0) as JoyButton
			event = joypad_event
		"InputEventJoypadMotion":
			var motion_event := InputEventJoypadMotion.new()
			motion_event.axis = dict.get("axis", 0) as JoyAxis
			motion_event.axis_value = dict.get("axis_value", 0.0) as float
			event = motion_event
	
	return event

## Get current input device name
func get_input_device_name() -> String:
	match current_input_mode:
		InputMode.KEYBOARD_MOUSE:
			return "Keyboard & Mouse"
		InputMode.GAMEPAD:
			# Skip gamepad name lookup in headless mode to avoid warnings
			if DisplayServer.get_name() == "headless":
				return "Gamepad"
			var joy_name := ""
			for i in range(8):
				if Input.is_joy_known(i):
					joy_name = Input.get_joy_name(i)
					break
			return joy_name if not joy_name.is_empty() else "Gamepad"
		InputMode.TOUCH:
			return "Touch"
		_:
			return "Unknown"

## Check if using gamepad
func is_using_gamepad() -> bool:
	return current_input_mode == InputMode.GAMEPAD

## Check if using keyboard/mouse
func is_using_keyboard_mouse() -> bool:
	return current_input_mode == InputMode.KEYBOARD_MOUSE

## Check if using touch
func is_using_touch() -> bool:
	return current_input_mode == InputMode.TOUCH

## Virtual methods - Override these in extended classes

## Called when input manager is ready
## Override to add initialization logic
func _on_input_manager_ready() -> void:
	pass

## Called when input mode changes
## Override to handle input mode changes
func _on_input_mode_changed(_mode: InputMode) -> void:
	pass

## Called when an action is pressed
## Override to handle action press
func _on_action_pressed(_action: String) -> void:
	pass

## Called when an action is just pressed
## Override to handle action just pressed
func _on_action_just_pressed(_action: String) -> void:
	pass

## Called when an action is just released
## Override to handle action just released
func _on_action_just_released(_action: String) -> void:
	pass

## Called when an action is remapped
## Override to handle action remapping
func _on_action_remapped(_action: String, _old_event: InputEvent, _new_event: InputEvent) -> void:
	pass

## Called when an action is reset
## Override to handle action reset
func _on_action_reset(_action: String) -> void:
	pass

## Called when all actions are reset
## Override to handle all actions reset
func _on_all_actions_reset() -> void:
	pass

## Called when remaps are saved
## Override to handle remap save
func _on_remaps_saved() -> void:
	pass

## Called when remaps are loaded
## Override to handle remap load
func _on_remaps_loaded() -> void:
	pass
