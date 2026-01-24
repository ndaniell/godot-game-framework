class_name GGF_GameManager
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
signal game_quit

const _DEFAULT_STATES_CONFIG_PATH := (
	"res://addons/godot_game_framework/resources/data/" + "game_states.tres"
)

# State machine configuration
@export_group("State Machine Configuration")
@export var states_config_path: String = _DEFAULT_STATES_CONFIG_PATH

@export_group("State Properties Overrides")
## Optional per-state properties merged on top of the loaded state definitions.
## Useful for host projects that want to reuse the framework's default states but
## still add project-specific behavior (e.g. open a menu on MENU state).
##
## Structure:
##   {
##     "MENU": { "ui": { "open_menu": "main_menu" } },
##     "PLAYING": { "change_scene": "res://scenes/World.tscn", "ui": { "close_all_menus": true } },
##   }
@export var state_property_overrides: Dictionary = {}

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
		var event_manager := GGF.events()
		if event_manager and event_manager.has_method("emit"):
			event_manager.emit("game_paused", {"is_paused": value})
		_on_pause_changed(value)

# Scene management
var current_scene_path: String = ""
var _scene_transition_in_progress: bool = false

# State machine configuration resource
var _state_config: Resource = null
var _default_state: String = "MENU"
var _state_machine_started := false
var _initial_state_to_start: String = ""


## Initialize the game manager
## Override this method to add custom initialization
func _ready() -> void:
	# Get LogManager reference

	GGF.log().info("GameManager", "GameManager initializing...")
	_initialize_game()
	_bind_and_maybe_start_state_machine()
	_on_game_ready()
	GGF.log().info("GameManager", "GameManager ready")


## Initialize game systems
## Override this method to customize initialization
func _initialize_game() -> void:
	GGF.log().debug("GameManager", "Loading state machine configuration...")
	# Load state machine configuration
	_load_state_definitions()
	# Connect to scene tree signals
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	GGF.log().debug("GameManager", "Game systems initialized")


## Load state definitions from Resource file
## Override this method to customize state loading
func _load_state_definitions() -> void:
	if states_config_path.is_empty():
		GGF.log().error(
			"GameManager", "States config path is empty. Cannot initialize state machine."
		)
		return

	if not ResourceLoader.exists(states_config_path):
		GGF.log().error(
			"GameManager",
			(
				"States config resource not found: "
				+ states_config_path
				+ ". Cannot initialize state machine."
			)
		)
		return

	GGF.log().debug("GameManager", "Loading state config from: " + states_config_path)

	# Load the state machine configuration resource
	var config_resource: Resource = null
	var load_result: Resource = ResourceLoader.load(states_config_path)
	if load_result == null:
		GGF.log().error(
			"GameManager",
			(
				"Failed to load states config resource: "
				+ states_config_path
				+ ". Cannot initialize state machine."
			)
		)
		return
	config_resource = load_result

	# Check if it's the right type (has the methods we need)
	if (
		not config_resource.has_method("validate")
		or not config_resource.has_method("get_state")
		or not config_resource.has_method("has_state")
	):
		(
			GGF
			. log()
			. error(
				"GameManager",
				"Loaded resource is not a valid GameStateMachineConfig. Cannot initialize state machine."
			)
		)
		return

	# Validate the configuration
	if not config_resource.validate():
		GGF.log().error(
			"GameManager",
			"State machine configuration validation failed. Cannot initialize state machine."
		)
		return

	_state_config = config_resource
	if config_resource.has_method("get") and config_resource.get("default_state") != null:
		_default_state = config_resource.get("default_state")
	else:
		_default_state = "MENU"

	GGF.log().info("GameManager", "State machine initialized with default state: " + _default_state)

	# Defer initial state transition until the framework signals readiness.
	# This keeps startup deterministic for UI-driven games (menus are pre-registered by UIManager).
	if current_state.is_empty():
		_initial_state_to_start = _default_state


## Change game state
## Override this method to add custom state change logic
## @param new_state: String name of the new state (must be defined in state machine config)
func change_state(new_state: String) -> void:
	if current_state == new_state:
		GGF.log().debug("GameManager", "State change ignored - already in state: " + new_state)
		return

	if _state_config == null:
		GGF.log().error("GameManager", "State machine configuration not loaded")
		return

	# Validate state exists
	if not _state_config.has_method("has_state") or not _state_config.has_state(new_state):
		GGF.log().error("GameManager", "Attempted to change to invalid state: " + new_state)
		return

	# Validate transition is allowed
	var current_state_def: Resource = _state_config.get_state(current_state) as Resource
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
			GGF.log().warn(
				"GameManager",
				"Transition from '" + current_state + "' to '" + new_state + "' is not allowed"
			)
			return

	GGF.log().info("GameManager", "Changing state: " + current_state + " -> " + new_state)
	var old_state := current_state
	current_state = new_state
	# Handle state transition immediately (synchronous)
	_handle_state_transition(old_state, new_state)


## Handle state transition
## Override this method to customize state transitions
func _handle_state_transition(old_state: String, new_state: String) -> void:
	if _state_config == null:
		return

	var new_state_def: Resource = _state_config.get_state(new_state) as Resource
	var old_state_def: Resource = _state_config.get_state(old_state) as Resource

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

	# Apply optional state properties (data-driven behavior).
	_apply_state_properties(new_state_def)


## Call a state callback method by name
func _call_state_callback(callback_name: String, state_name: String) -> void:
	if callback_name.is_empty():
		return

	if has_method(callback_name):
		call(callback_name)
	else:
		GGF.log().warn(
			"GameManager",
			"State callback method '" + callback_name + "' not found for state '" + state_name + "'"
		)


## Apply state properties for the active state definition.
## This enables data-driven behavior without requiring per-project GameManager overrides.
##
## Supported keys under `properties`:
## - change_scene: String (path)
## - transition_type: String (optional; used with change_scene)
## - ui: Dictionary (optional namespace). If present, UI keys are read from here.
##
## Supported UI keys (either directly in `properties` or under `properties.ui`):
## - close_all_menus: bool
## - close_all_dialogs: bool
## - open_menu: String
## - open_menu_close_others: bool (optional, default true)
## - open_dialog: String
## - open_dialog_modal: bool (optional, default true)
## - show_ui_element: String
## - hide_ui_element: String
func _apply_state_properties(state_def: Resource) -> void:
	if state_def == null:
		return

	var props_val: Variant = state_def.get("properties")
	var props: Dictionary = props_val if props_val is Dictionary else {}
	props = _merge_state_property_overrides(state_def, props)

	# Scene change.
	var scene_val: Variant = props.get("change_scene", "")
	var scene_path: String = scene_val if scene_val is String else ""
	if not scene_path.is_empty():
		var transition_val: Variant = props.get("transition_type", "")
		var transition_type: String = transition_val if transition_val is String else ""
		change_scene(scene_path, transition_type)

	_apply_state_ui_properties(props)


func _apply_state_ui_properties(props: Dictionary) -> void:
	var ui_props: Dictionary = props
	var ui_sub: Variant = props.get("ui", null)
	if ui_sub is Dictionary:
		ui_props = ui_sub as Dictionary

	var close_menus_val: Variant = ui_props.get("close_all_menus", false)
	var close_menus: bool = close_menus_val is bool and (close_menus_val as bool)

	var close_dialogs_val: Variant = ui_props.get("close_all_dialogs", false)
	var close_dialogs: bool = close_dialogs_val is bool and (close_dialogs_val as bool)

	var open_menu_val: Variant = ui_props.get("open_menu", "")
	var open_menu: String = open_menu_val if open_menu_val is String else ""

	var open_dialog_val: Variant = ui_props.get("open_dialog", "")
	var open_dialog: String = open_dialog_val if open_dialog_val is String else ""

	var show_element_val: Variant = ui_props.get("show_ui_element", "")
	var show_element: String = show_element_val if show_element_val is String else ""

	var hide_element_val: Variant = ui_props.get("hide_ui_element", "")
	var hide_element: String = hide_element_val if hide_element_val is String else ""

	var has_ui_actions := (
		close_menus
		or close_dialogs
		or not open_menu.is_empty()
		or not open_dialog.is_empty()
		or not show_element.is_empty()
		or not hide_element.is_empty()
	)

	if not has_ui_actions:
		return

	var ui := GGF.get_manager(&"UIManager")
	if ui == null:
		return

	# Apply UI actions (UI is ready).
	if close_menus and ui.has_method("close_all_menus"):
		ui.call("close_all_menus")

	if close_dialogs and ui.has_method("close_all_dialogs"):
		ui.call("close_all_dialogs")

	if not open_menu.is_empty() and ui.has_method("open_menu"):
		var close_others_val: Variant = ui_props.get("open_menu_close_others", true)
		var close_others: bool = close_others_val is bool and (close_others_val as bool)
		ui.call("open_menu", open_menu, close_others)

	if not open_dialog.is_empty() and ui.has_method("open_dialog"):
		var modal_val: Variant = ui_props.get("open_dialog_modal", true)
		var modal: bool = modal_val is bool and (modal_val as bool)
		ui.call("open_dialog", open_dialog, modal)

	if not show_element.is_empty() and ui.has_method("show_ui_element"):
		ui.call("show_ui_element", show_element)

	if not hide_element.is_empty() and ui.has_method("hide_ui_element"):
		ui.call("hide_ui_element", hide_element)


func _merge_state_property_overrides(state_def: Resource, base_props: Dictionary) -> Dictionary:
	var name_val: Variant = state_def.get("name") if state_def != null else ""
	var state_name: String = name_val if name_val is String else ""
	if state_name.is_empty():
		return base_props

	var override_val: Variant = state_property_overrides.get(state_name, null)
	if not (override_val is Dictionary):
		return base_props

	var override := override_val as Dictionary
	if override.is_empty():
		return base_props

	var merged := base_props.duplicate(true)
	for k in override.keys():
		var ov: Variant = override[k]
		if merged.has(k) and merged[k] is Dictionary and ov is Dictionary:
			var inner := (merged[k] as Dictionary).duplicate(true)
			for ik in (ov as Dictionary).keys():
				inner[ik] = (ov as Dictionary)[ik]
			merged[k] = inner
		else:
			merged[k] = ov
	return merged


func _bind_and_maybe_start_state_machine() -> void:
	if _state_machine_started:
		return
	if _initial_state_to_start.is_empty():
		return

	# If the framework exposes a readiness signal, start deterministically after it fires.
	if GGF != null and GGF.has_method("is_ready"):
		var ready_val: Variant = GGF.call("is_ready")
		if ready_val is bool and (ready_val as bool):
			_start_state_machine()
			return

	if GGF != null and GGF.has_signal("ggf_ready"):
		var cb := Callable(self, "_start_state_machine")
		if not GGF.is_connected("ggf_ready", cb):
			GGF.connect("ggf_ready", cb, CONNECT_ONE_SHOT)
		return

	# Fallback: start next frame.
	call_deferred("_start_state_machine")


func _start_state_machine() -> void:
	if _state_machine_started:
		return
	if _initial_state_to_start.is_empty():
		return

	_state_machine_started = true
	var start_state := _initial_state_to_start
	_initial_state_to_start = ""

	if current_state.is_empty():
		current_state = start_state
		_handle_state_transition("", start_state)


## Pause the game
## Override this method to add custom pause logic
func pause_game() -> void:
	if is_paused:
		GGF.log().debug("GameManager", "Pause ignored - game already paused")
		return
	GGF.log().info("GameManager", "Pausing game")
	is_paused = true
	change_state("PAUSED")


## Unpause the game
## Override this method to add custom unpause logic
func unpause_game() -> void:
	if not is_paused:
		GGF.log().debug("GameManager", "Unpause ignored - game not paused")
		return
	GGF.log().info("GameManager", "Unpausing game")
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
		GGF.log().warn("GameManager", "Scene transition already in progress")
		return

	if not ResourceLoader.exists(scene_path):
		GGF.log().error("GameManager", "Scene path does not exist: " + scene_path)
		return

	GGF.log().info(
		"GameManager",
		(
			"Changing scene to: "
			+ scene_path
			+ (" with transition: " + transition_type if transition_type else "")
		)
	)

	_scene_transition_in_progress = true
	_on_scene_change_started(scene_path, transition_type)

	# Perform transition if specified
	if transition_type != "":
		_perform_transition(scene_path, transition_type)
	else:
		# Defer the actual scene swap to avoid "Parent node is busy" errors
		# during _ready()/tree mutations.
		get_tree().call_deferred("change_scene_to_file", scene_path)

	# Always defer completion to ensure scene change happens first
	call_deferred("_complete_scene_change", scene_path)


## Complete scene change (called deferred after change_scene_to_file)
func _complete_scene_change(scene_path: String) -> void:
	current_scene_path = scene_path
	_scene_transition_in_progress = false
	scene_changed.emit(scene_path)
	_on_scene_changed(scene_path)
	GGF.log().debug("GameManager", "Scene change completed")


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
		GGF.log().warn("GameManager", "No current scene to reload")
		return
	change_scene(current_scene_path)


## Quit the game
## Override this method to add custom quit logic
func quit_game() -> void:
	GGF.log().info("GameManager", "Game quitting...")
	_on_game_quit()
	game_quit.emit()
	get_tree().quit()


## Restart the game
## Override this method to add custom restart logic
func restart_game() -> void:
	GGF.log().info("GameManager", "Game restarting...")
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
	GGF.log().debug("GameManager", "State changed from '" + old_state + "' to '" + new_state + "'")


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
	GGF.log().debug("GameManager", "Entered paused state")


## Called when paused state is exited
## Override to handle unpause logic
func _on_paused_exited() -> void:
	is_paused = false
	GGF.log().debug("GameManager", "Exited paused state")


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
	var time_manager := GGF.get_manager(&"TimeManager")
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
func get_state_definition(state_name: String) -> Resource:
	if _state_config == null:
		return null
	return _state_config.get_state(state_name) as Resource


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

	var current_state_def: Resource = _state_config.get_state(current_state) as Resource
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
