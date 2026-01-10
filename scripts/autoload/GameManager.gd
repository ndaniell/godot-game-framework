extends Node

## GameManager - Extensible game state management system for the Godot Game Framework
##
## This manager handles game state, scene transitions, and game lifecycle.
## Extend this class to add custom game management functionality.

signal game_state_changed(old_state: String, new_state: String)
signal scene_changed(scene_path: String)
signal game_paused(is_paused: bool)
signal game_quit()

# Game states enum - extend this in your game
enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER,
	VICTORY,
	LOADING
}

# Current game state
var current_state: GameState = GameState.MENU:
	set(value):
		var state_keys := GameState.keys()
		var old_state_name: String = state_keys[current_state]
		var new_state_name: String = state_keys[value]
		current_state = value
		game_state_changed.emit(old_state_name, new_state_name)
		_on_state_changed(old_state_name, new_state_name)

# Pause state
var is_paused: bool = false:
	set(value):
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
	_initialize_game()
	_on_game_ready()

## Initialize game systems
## Override this method to customize initialization
func _initialize_game() -> void:
	# Connect to scene tree signals
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

## Change game state
## Override this method to add custom state change logic
func change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	
	var old_state := current_state
	current_state = new_state
	_handle_state_transition(old_state, new_state)

## Handle state transition
## Override this method to customize state transitions
func _handle_state_transition(old_state: GameState, new_state: GameState) -> void:
	match new_state:
		GameState.PAUSED:
			pause_game()
		GameState.PLAYING:
			if old_state == GameState.PAUSED:
				unpause_game()
		GameState.GAME_OVER:
			_on_game_over()
		GameState.VICTORY:
			_on_victory()
		GameState.MENU:
			_on_menu_entered()
		GameState.LOADING:
			_on_loading_started()

## Pause the game
## Override this method to add custom pause logic
func pause_game() -> void:
	if is_paused:
		return
	is_paused = true
	change_state(GameState.PAUSED)

## Unpause the game
## Override this method to add custom unpause logic
func unpause_game() -> void:
	if not is_paused:
		return
	is_paused = false
	change_state(GameState.PLAYING)

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
		push_warning("GameManager: Scene transition already in progress")
		return
	
	if not ResourceLoader.exists(scene_path):
		push_error("GameManager: Scene path does not exist: " + scene_path)
		return
	
	_scene_transition_in_progress = true
	_on_scene_change_started(scene_path, transition_type)
	
	# Perform transition if specified
	if transition_type != "":
		await _perform_transition(scene_path, transition_type)
	else:
		get_tree().change_scene_to_file(scene_path)
	
	current_scene_path = scene_path
	_scene_transition_in_progress = false
	scene_changed.emit(scene_path)
	_on_scene_changed(scene_path)

## Perform scene transition
## Override this method to implement custom transitions
func _perform_transition(scene_path: String, transition_type: String) -> void:
	# Default: immediate transition
	# Override to add fade, slide, etc.
	get_tree().change_scene_to_file(scene_path)

## Reload current scene
func reload_current_scene() -> void:
	if current_scene_path.is_empty():
		push_warning("GameManager: No current scene to reload")
		return
	change_scene(current_scene_path)

## Quit the game
## Override this method to add custom quit logic
func quit_game() -> void:
	_on_game_quit()
	game_quit.emit()
	get_tree().quit()

## Restart the game
## Override this method to add custom restart logic
func restart_game() -> void:
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
	pass

## Called when pause state changes
## Override to handle pause-specific logic
func _on_pause_changed(is_paused: bool) -> void:
	pass

## Called when a node is added to the scene tree
## Override to handle node additions
func _on_node_added(node: Node) -> void:
	pass

## Called when a node is removed from the scene tree
## Override to handle node removals
func _on_node_removed(node: Node) -> void:
	pass

## Called when scene change starts
## Override to add pre-transition logic
func _on_scene_change_started(scene_path: String, transition_type: String) -> void:
	pass

## Called when scene has changed
## Override to add post-transition logic
func _on_scene_changed(scene_path: String) -> void:
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
	return GameState.keys()[current_state]

## Check if game is in a specific state
func is_in_state(state: GameState) -> bool:
	return current_state == state
