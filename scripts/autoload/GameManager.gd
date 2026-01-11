extends Node

## GameManager - Extensible game state management system for the Godot Game Framework
##
## This manager handles game state, scene transitions, and game lifecycle.
## Extend this class to add custom game management functionality.
##
## States are defined in states.json and can be extended without modifying code.

signal game_state_changed(old_state: String, new_state: String)
signal scene_changed(scene_path: String)
signal game_paused(is_paused: bool)
signal game_quit()


# State machine configuration
@export_group("State Machine Configuration")
@export var states_config_path: String = "res://resources/data/game_states.tres"

# State machine configuration resource
var _state_config: GameStateMachineConfig = null
var _default_state: String = "MENU"

# Current game state (string-based, loaded from configuration)
var current_state: String = "":
	set(value):
		if current_state == value:
			return
		var old_state_name: String = current_state
		current_state = value
		game_state_changed.emit(old_state_name, current_state)
		_on_state_changed(old_state_name, current_state)

# Pause state
var is_paused: bool = false:
	set(value):
		if is_paused == value:
			return
		is_paused = value
		get_tree().paused = value
		game_paused.emit(value)
		# Notify TimeManager about pause state
		_notify_time_manager_pause(value)
		# Emit event for other managers
		if EventManager:
			EventManager.emit("game_paused", {"is_paused": value})
		_on_pause_changed(value)

# Scene management
var current_scene_path: String = ""
var _scene_transition_in_progress: bool = false

## Initialize the game manager
## Override this method to add custom initialization
func _ready() -> void:
	# Get LogManager reference

	LogManager.info("GameManager", "GameManager initializing...")
	_initialize_game()
	_on_game_ready()
	LogManager.info("GameManager", "GameManager ready")

## Initialize game systems
## Override this method to customize initialization
func _initialize_game() -> void:
	LogManager.debug("GameManager", "Loading state machine configuration...")
	# Load state machine configuration
	_load_state_definitions()
	# Connect to scene tree signals
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	LogManager.debug("GameManager", "Game systems initialized")

## Load state definitions from Resource file
## Override this method to customize state loading
func _load_state_definitions() -> void:
	if states_config_path.is_empty():
		LogManager.error("GameManager", "States config path is empty. Cannot initialize state machine.")
		return

	if not ResourceLoader.exists(states_config_path):
		LogManager.error("GameManager", "States config resource not found: " + states_config_path + ". Cannot initialize state machine.")
		return

	LogManager.debug("GameManager", "Loading state config from: " + states_config_path)

	# Load the state machine configuration resource
	var config_resource: GameStateMachineConfig = null
	var load_result = ResourceLoader.load(states_config_path) as GameStateMachineConfig
	if load_result == null:
		LogManager.error("GameManager", "Failed to load states config resource: " + states_config_path + ". Cannot initialize state machine.")
		return
	config_resource = load_result

	# Check if it's the right type (has the methods we need)
	if not config_resource.has_method("validate") or not config_resource.has_method("get_state") or not config_resource.has_method("has_state"):
		LogManager.error("GameManager", "Loaded resource is not a valid GameStateMachineConfig. Cannot initialize state machine.")
		return

	# Validate the configuration
	if not config_resource.validate():
		LogManager.error("GameManager", "State machine configuration validation failed. Cannot initialize state machine.")
		return

	_state_config = config_resource
	if config_resource.has_method("get") and config_resource.get("default_state") != null:
		_default_state = config_resource.get("default_state")
	else:
		_default_state = "MENU"

	LogManager.info("GameManager", "State machine initialized with default state: " + _default_state)

	# Set initial state
	if current_state.is_empty():
		current_state = _default_state
		# Trigger initial state transition to call entry callbacks and apply properties
		_handle_state_transition("", _default_state)

## Change game state
## Override this method to add custom state change logic
## @param new_state: String name of the new state (must be defined in state machine config)
func change_state(new_state: String) -> void:
	if current_state == new_state:
		LogManager.debug("GameManager", "State change ignored - already in state: " + new_state)
		return

	if _state_config == null:
		LogManager.error("GameManager", "State machine configuration not loaded")
		return

	# Validate state exists
	if not _state_config.has_method("has_state") or not _state_config.has_state(new_state):
		LogManager.error("GameManager", "Attempted to change to invalid state: " + new_state)
		return

	# Validate transition is allowed
	var current_state_def: GameStateDefinition = _state_config.get_state(current_state)
	if current_state_def != null:
		var allowed_transitions_val = current_state_def.get("allowed_transitions")
		# Convert to Array[String] - handle both Array and PackedStringArray
		var allowed_transitions: Array[String] = []
		if allowed_transitions_val is Array:
			for item in allowed_transitions_val:
				if item is String:
					allowed_transitions.append(item)
		elif allowed_transitions_val is PackedStringArray:
			for item in allowed_transitions_val:
				allowed_transitions.append(item)
		if not allowed_transitions.is_empty() and not allowed_transitions.has(new_state):
			LogManager.warn("GameManager", "Transition from '" + current_state + "' to '" + new_state + "' is not allowed")
			return

	LogManager.info("GameManager", "Changing state: " + current_state + " -> " + new_state)
	var old_state := current_state
	current_state = new_state
	# Handle state transition immediately (synchronous)
	_handle_state_transition(old_state, new_state)

## Handle state transition
## Override this method to customize state transitions
func _handle_state_transition(old_state: String, new_state: String) -> void:
	if _state_config == null:
		return
	
	var new_state_def: GameStateDefinition = _state_config.get_state(new_state)
	var old_state_def: GameStateDefinition = _state_config.get_state(old_state)
	
	if new_state_def == null:
		return
	
	# Call exit callback for old state
	if old_state_def != null:
		var exit_callback_val = old_state_def.get("exit_callback")
		var exit_callback: String = exit_callback_val if exit_callback_val is String else ""
		if not exit_callback.is_empty():
			_call_state_callback(exit_callback, old_state)
	
	# Call entry callback for new state
	# Entry callbacks handle state-specific behavior (e.g., pausing in PAUSED state)
	var entry_callback_val = new_state_def.get("entry_callback")
	var entry_callback: String = entry_callback_val if entry_callback_val is String else ""
	if not entry_callback.is_empty():
		_call_state_callback(entry_callback, new_state)

## Call a state callback method by name
func _call_state_callback(callback_name: String, state_name: String) -> void:
	if callback_name.is_empty():
		return
	
	if has_method(callback_name):
		call(callback_name)
	else:
		LogManager.warn("GameManager", "State callback method '" + callback_name + "' not found for state '" + state_name + "'")

## Pause the game
## Override this method to add custom pause logic
func pause_game() -> void:
	if is_paused:
		LogManager.debug("GameManager", "Pause ignored - game already paused")
		return
	LogManager.info("GameManager", "Pausing game")
	is_paused = true
	change_state("PAUSED")

## Unpause the game
## Override this method to add custom unpause logic
func unpause_game() -> void:
	if not is_paused:
		LogManager.debug("GameManager", "Unpause ignored - game not paused")
		return
	LogManager.info("GameManager", "Unpausing game")
	is_paused = false
	change_state("PLAYING")

## Toggle pause state
func toggle_pause() -> void:
	if is_paused:
		unpause_game()
	else:
		pause_game()

## Change scene
## Override this method to add custom scene transition logic
func change_scene(scene_path: String, transition_type: String = "") -> void:
	if _scene_transition_in_progress:
		LogManager.warn("GameManager", "Scene transition already in progress")
		return

	if not ResourceLoader.exists(scene_path):
		LogManager.error("GameManager", "Scene path does not exist: " + scene_path)
		return

	LogManager.info("GameManager", "Changing scene to: " + scene_path + (" with transition: " + transition_type if transition_type else ""))

	_scene_transition_in_progress = true
	_on_scene_change_started(scene_path, transition_type)

	# Perform transition if specified
	if transition_type != "":
		_perform_transition(scene_path, transition_type)
	else:
		# Defer the actual scene swap to avoid \"Parent node is busy\" errors during _ready()/tree mutations.
		get_tree().call_deferred("change_scene_to_file", scene_path)

	# Always defer completion to ensure scene change happens first
	call_deferred("_complete_scene_change", scene_path)

## Complete scene change (called deferred after change_scene_to_file)
func _complete_scene_change(scene_path: String) -> void:
	current_scene_path = scene_path
	_scene_transition_in_progress = false
	scene_changed.emit(scene_path)
	_on_scene_changed(scene_path)
	LogManager.debug("GameManager", "Scene change completed")

## Perform scene transition
## Override this method to implement custom transitions
func _perform_transition(scene_path: String, _transition_type: String) -> void:
	# Default: immediate transition
	# Override to add fade, slide, etc.
	# Note: Completion is handled by the caller via _complete_scene_change
	get_tree().call_deferred("change_scene_to_file", scene_path)

## Reload current scene
func reload_current_scene() -> void:
	if current_scene_path.is_empty():
		LogManager.warn("GameManager", "No current scene to reload")
		return
	change_scene(current_scene_path)

## Quit the game
## Override this method to add custom quit logic
func quit_game() -> void:
	LogManager.info("GameManager", "Game quitting...")
	_on_game_quit()
	game_quit.emit()
	get_tree().quit()

## Restart the game
## Override this method to add custom restart logic
func restart_game() -> void:
	LogManager.info("GameManager", "Game restarting...")
	_on_game_restart()
	# Reload the main scene
	var main_scene_setting: Variant = ProjectSettings.get_setting("application/run/main_scene", "")
	var main_scene: String = main_scene_setting if main_scene_setting is String else ""
	if main_scene:
		change_scene(main_scene)
	else:
		reload_current_scene()

## Virtual methods - Override these in extended classes

## Called when the game manager is ready
## Override to add initialization logic
func _on_game_ready() -> void:
	pass

## Called when game state changes
## Override to handle state-specific logic
func _on_state_changed(old_state: String, new_state: String) -> void:
	LogManager.debug("GameManager", "State changed from '" + old_state + "' to '" + new_state + "'")

## Called when pause state changes
## Override to handle pause-specific logic
func _on_pause_changed(_is_paused: bool) -> void:
	pass

## Called when a node is added to the scene tree
## Override to handle node additions
func _on_node_added(_node: Node) -> void:
	pass

## Called when a node is removed from the scene tree
## Override to handle node removals
func _on_node_removed(_node: Node) -> void:
	pass

## Called when scene change starts
## Override to add pre-transition logic
func _on_scene_change_started(_scene_path: String, _transition_type: String) -> void:
	pass

## Called when scene has changed
## Override to add post-transition logic
func _on_scene_changed(_scene_path: String) -> void:
	pass

## Called when game over state is entered
## Override to handle game over logic
func _on_game_over() -> void:
	pass

## Called when victory state is entered
## Override to handle victory logic
func _on_victory() -> void:
	pass

## Called when menu state is entered
## Override to handle menu logic
func _on_menu_entered() -> void:
	pass

## Called when loading state is entered
## Override to handle loading logic
func _on_loading_started() -> void:
	pass

## Called when paused state is entered
## Override to handle pause logic
func _on_paused_entered() -> void:
	is_paused = true
	LogManager.debug("GameManager", "Entered paused state")

## Called when paused state is exited
## Override to handle unpause logic
func _on_paused_exited() -> void:
	is_paused = false
	LogManager.debug("GameManager", "Exited paused state")

## Called when game is quitting
## Override to add cleanup logic
func _on_game_quit() -> void:
	pass

## Called when game is restarting
## Override to add reset logic
func _on_game_restart() -> void:
	pass

## Notify TimeManager about pause state
func _notify_time_manager_pause(paused: bool) -> void:
	if not has_node("/root/TimeManager"):
		return
	
	var time_manager := get_node("/root/TimeManager") as Node
	if time_manager and time_manager.has_method("set_time_scale"):
		if paused:
			# Store current time scale before pausing
			if not time_manager.get("_pre_pause_time_scale") != null:
				time_manager.set("_pre_pause_time_scale", time_manager.get("time_scale"))
			time_manager.set_time_scale(0.0)
		else:
			# Restore time scale after unpausing
			var pre_pause_scale_val = time_manager.get("_pre_pause_time_scale")
			if pre_pause_scale_val != null:
				var pre_pause_scale := pre_pause_scale_val as float
				time_manager.set_time_scale(pre_pause_scale)
				time_manager.set("_pre_pause_time_scale", null)

## Get current state name as string
func get_state_name() -> String:
	return current_state

## Check if game is in a specific state
## @param state: String name of the state to check
func is_in_state(state: String) -> bool:
	return current_state == state

## Get state definition for a given state
## @param state_name: String name of the state
## @return: GameStateDefinition resource, or null if not found
func get_state_definition(state_name: String) -> GameStateDefinition:
	if _state_config == null:
		return null
	return _state_config.get_state(state_name)

## Get all available state names
## @return: Array of state name strings
func get_all_states() -> Array:
	if _state_config == null:
		return []
	return _state_config.get_state_names()

## Check if a transition is allowed from current state to target state
## @param target_state: String name of the target state
## @return: bool indicating if transition is allowed
func can_transition_to(target_state: String) -> bool:
	if _state_config == null:
		return false
	
	if not _state_config.has_state(target_state):
		return false
	
	var current_state_def: GameStateDefinition = _state_config.get_state(current_state)
	if current_state_def == null:
		return false
	
	var allowed_transitions_val = current_state_def.get("allowed_transitions")
	# Convert to Array[String] - handle both Array and PackedStringArray
	var allowed_transitions: Array[String] = []
	if allowed_transitions_val is Array:
		for item in allowed_transitions_val:
			if item is String:
				allowed_transitions.append(item)
	elif allowed_transitions_val is PackedStringArray:
		for item in allowed_transitions_val:
			allowed_transitions.append(item)
	
	# If allowed_transitions is empty, allow all transitions
	if allowed_transitions.is_empty():
		return true
	
	return allowed_transitions.has(target_state)

## Reload state definitions from file
## Useful for hot-reloading during development
func reload_state_definitions() -> void:
	_load_state_definitions()
