extends Node

## SceneManager - Extensible scene management system for the Godot Game Framework
##
## This manager handles scene loading, unloading, preloading, and transitions.
## Extend this class to add custom scene management functionality.

signal scene_loaded(scene_path: String, scene_instance: Node)
signal scene_unloaded(scene_path: String)
signal scene_preloaded(scene_path: String, packed_scene: PackedScene)
signal transition_started(from_scene: String, to_scene: String, transition_type: String)
signal transition_completed(scene_path: String)

# Scene management
var _loaded_scenes: Dictionary = {}  # path -> Node
var _preloaded_scenes: Dictionary = {}  # path -> PackedScene
var _current_scene_path: String = ""
var _transition_in_progress: bool = false

# Transition configuration
@export_group("Transition Settings")
@export var default_transition_duration: float = 0.5
@export var enable_scene_caching: bool = true
@export var max_cached_scenes: int = 5

## Initialize the scene manager
## Override this method to add custom initialization
func _ready() -> void:
	_initialize_scene_manager()
	_on_scene_manager_ready()

## Initialize scene manager
## Override this method to customize initialization
func _initialize_scene_manager() -> void:
	# Track the current scene
	_current_scene_path = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	pass

## Load a scene and add it to the scene tree
## Override this method to add custom load logic
func load_scene(scene_path: String, parent: Node = null, make_current: bool = false) -> Node:
	if scene_path.is_empty():
		GGF.log().error("SceneManager", "Cannot load empty scene path")
		return null
	
	if not ResourceLoader.exists(scene_path):
		GGF.log().error("SceneManager", "Scene does not exist: " + scene_path)
		return null
	
	# Check if already loaded
	if _loaded_scenes.has(scene_path) and enable_scene_caching:
		var existing_scene := _loaded_scenes[scene_path] as Node
		if is_instance_valid(existing_scene):
			scene_loaded.emit(scene_path, existing_scene)
			_on_scene_loaded(scene_path, existing_scene)
			return existing_scene
	
	# Load the scene
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		GGF.log().error("SceneManager", "Failed to load scene: " + scene_path)
		return null
	
	# Instance the scene
	var scene_instance := packed_scene.instantiate()
	if scene_instance == null:
		GGF.log().error("SceneManager", "Failed to instantiate scene: " + scene_path)
		return null
	
	# Add to scene tree
	var target_parent := parent if parent != null else get_tree().root
	target_parent.add_child(scene_instance)
	
	# Make current if requested
	if make_current:
		get_tree().current_scene = scene_instance
		_current_scene_path = scene_path
	
	# Cache the scene
	if enable_scene_caching:
		_loaded_scenes[scene_path] = scene_instance
		_manage_scene_cache()
	
	scene_loaded.emit(scene_path, scene_instance)
	_on_scene_loaded(scene_path, scene_instance)
	
	return scene_instance

## Unload a scene from the scene tree
## Override this method to add custom unload logic
func unload_scene(scene_path: String, remove_from_cache: bool = true) -> bool:
	if not _loaded_scenes.has(scene_path):
		GGF.log().warn("SceneManager", "Scene not loaded: " + scene_path)
		return false
	
	var scene_instance := _loaded_scenes[scene_path] as Node
	if not is_instance_valid(scene_instance):
		_loaded_scenes.erase(scene_path)
		return false
	
	# Remove from scene tree
	if scene_instance.get_parent():
		scene_instance.get_parent().remove_child(scene_instance)
	scene_instance.queue_free()
	
	# Remove from cache
	if remove_from_cache:
		_loaded_scenes.erase(scene_path)
	
	# Update current scene path
	if _current_scene_path == scene_path:
		_current_scene_path = ""
	
	scene_unloaded.emit(scene_path)
	_on_scene_unloaded(scene_path)
	
	return true

## Change to a new scene (replaces current scene)
## Override this method to add custom change logic
func change_scene(scene_path: String, transition_type: String = "") -> void:
	if _transition_in_progress:
		GGF.log().warn("SceneManager", "Transition already in progress")
		return
	
	if scene_path.is_empty():
		GGF.log().error("SceneManager", "Cannot change to empty scene path")
		return
	
	if not ResourceLoader.exists(scene_path):
		GGF.log().error("SceneManager", "Scene does not exist: " + scene_path)
		return
	
	var from_scene := _current_scene_path
	_transition_in_progress = true
	
	transition_started.emit(from_scene, scene_path, transition_type)
	_on_transition_started(from_scene, scene_path, transition_type)
	
	# Perform transition if specified
	if transition_type != "":
		await _perform_transition(from_scene, scene_path, transition_type)
	else:
		get_tree().change_scene_to_file(scene_path)
	
	_current_scene_path = scene_path
	_transition_in_progress = false
	
	transition_completed.emit(scene_path)
	_on_transition_completed(scene_path)

## Preload a scene (load into memory without instancing)
## Override this method to add custom preload logic
func preload_scene(scene_path: String) -> PackedScene:
	if scene_path.is_empty():
		GGF.log().error("SceneManager", "Cannot preload empty scene path")
		return null
	
	if not ResourceLoader.exists(scene_path):
		GGF.log().error("SceneManager", "Scene does not exist: " + scene_path)
		return null
	
	# Check if already preloaded
	if _preloaded_scenes.has(scene_path):
		return _preloaded_scenes[scene_path] as PackedScene
	
	# Preload the scene
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		GGF.log().error("SceneManager", "Failed to preload scene: " + scene_path)
		return null
	
	_preloaded_scenes[scene_path] = packed_scene
	scene_preloaded.emit(scene_path, packed_scene)
	_on_scene_preloaded(scene_path, packed_scene)
	
	return packed_scene

## Unpreload a scene (remove from preloaded cache)
func unpreload_scene(scene_path: String) -> bool:
	if not _preloaded_scenes.has(scene_path):
		return false
	
	_preloaded_scenes.erase(scene_path)
	_on_scene_unpreloaded(scene_path)
	return true

## Get a loaded scene instance
func get_loaded_scene(scene_path: String) -> Node:
	if not _loaded_scenes.has(scene_path):
		return null
	
	var scene := _loaded_scenes[scene_path] as Node
	if not is_instance_valid(scene):
		_loaded_scenes.erase(scene_path)
		return null
	
	return scene

## Check if a scene is loaded
func is_scene_loaded(scene_path: String) -> bool:
	if not _loaded_scenes.has(scene_path):
		return false
	
	var scene := _loaded_scenes[scene_path] as Node
	return is_instance_valid(scene)

## Check if a scene is preloaded
func is_scene_preloaded(scene_path: String) -> bool:
	return _preloaded_scenes.has(scene_path)

## Get current scene path
func get_current_scene_path() -> String:
	return _current_scene_path

## Get all loaded scene paths
func get_loaded_scene_paths() -> Array[String]:
	var paths: Array[String] = []
	for path in _loaded_scenes:
		var scene := _loaded_scenes[path] as Node
		if is_instance_valid(scene):
			paths.append(path)
	return paths

## Get all preloaded scene paths
func get_preloaded_scene_paths() -> Array[String]:
	return _preloaded_scenes.keys()

## Clear all loaded scenes
func clear_loaded_scenes() -> void:
	for scene_path in _loaded_scenes.keys():
		unload_scene(scene_path, false)
	_loaded_scenes.clear()
	_on_all_scenes_cleared()

## Clear all preloaded scenes
func clear_preloaded_scenes() -> void:
	_preloaded_scenes.clear()
	_on_all_preloaded_scenes_cleared()

## Manage scene cache size
func _manage_scene_cache() -> void:
	if not enable_scene_caching:
		return
	
	# Remove oldest scenes if over limit
	while _loaded_scenes.size() > max_cached_scenes:
		var scene_keys := _loaded_scenes.keys()
		var oldest_path: String = scene_keys[0]
		unload_scene(oldest_path, true)

## Perform scene transition
## Override this method to implement custom transitions
func _perform_transition(from_scene: String, to_scene: String, transition_type: String) -> void:
	match transition_type:
		"fade":
			await _fade_transition(from_scene, to_scene)
		"slide":
			await _slide_transition(from_scene, to_scene)
		"instant":
			get_tree().change_scene_to_file(to_scene)
		_:
			# Default: instant transition
			get_tree().change_scene_to_file(to_scene)

## Fade transition
## Override this method to customize fade transition
func _fade_transition(_from_scene: String, to_scene: String) -> void:
	# Create a simple fade effect
	# Override to implement custom fade
	var fade_duration := default_transition_duration
	
	# Fade out
	# (Override to add actual fade effect)
	await get_tree().create_timer(fade_duration / 2.0).timeout
	
	# Change scene
	get_tree().change_scene_to_file(to_scene)
	
	# Fade in
	await get_tree().create_timer(fade_duration / 2.0).timeout

## Slide transition
## Override this method to customize slide transition
func _slide_transition(_from_scene: String, to_scene: String) -> void:
	# Create a simple slide effect
	# Override to implement custom slide
	var slide_duration := default_transition_duration
	
	# Slide out
	# (Override to add actual slide effect)
	await get_tree().create_timer(slide_duration / 2.0).timeout
	
	# Change scene
	get_tree().change_scene_to_file(to_scene)
	
	# Slide in
	await get_tree().create_timer(slide_duration / 2.0).timeout

## Reload current scene
func reload_current_scene() -> void:
	if _current_scene_path.is_empty():
		GGF.log().warn("SceneManager", "No current scene to reload")
		return
	change_scene(_current_scene_path)

## Virtual methods - Override these in extended classes

## Called when scene manager is ready
## Override to add initialization logic
func _on_scene_manager_ready() -> void:
	pass

## Called when a scene is loaded
## Override to handle scene loading
func _on_scene_loaded(_scene_path: String, _scene_instance: Node) -> void:
	pass

## Called when a scene is unloaded
## Override to handle scene unloading
func _on_scene_unloaded(_scene_path: String) -> void:
	pass

## Called when a scene is preloaded
## Override to handle scene preloading
func _on_scene_preloaded(_scene_path: String, _packed_scene: PackedScene) -> void:
	pass

## Called when a scene is unpreloaded
## Override to handle scene unpreloading
func _on_scene_unpreloaded(_scene_path: String) -> void:
	pass

## Called when transition starts
## Override to handle transition start
func _on_transition_started(_from_scene: String, _to_scene: String, _transition_type: String) -> void:
	pass

## Called when transition completes
## Override to handle transition completion
func _on_transition_completed(_scene_path: String) -> void:
	pass

## Called when all scenes are cleared
## Override to handle scene clearing
func _on_all_scenes_cleared() -> void:
	pass

## Called when all preloaded scenes are cleared
## Override to handle preloaded scene clearing
func _on_all_preloaded_scenes_cleared() -> void:
	pass

