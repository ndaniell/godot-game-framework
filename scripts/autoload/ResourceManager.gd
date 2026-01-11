extends Node

## ResourceManager - Extensible resource management system for the Godot Game Framework
##
## This manager handles resource loading, unloading, caching, and pooling.
## Extend this class to add custom resource functionality.

signal resource_loaded(resource_path: String, resource: Resource)
signal resource_unloaded(resource_path: String)
signal resource_preloaded(resource_path: String, resource: Resource)
signal cache_cleared()

# Resource caching
@export_group("Resource Configuration")
@export var enable_caching: bool = true
@export var max_cache_size: int = 100
@export var auto_unload_unused: bool = false
@export var unload_check_interval: float = 60.0  # seconds

# Resource storage
var _resource_cache: Dictionary = {}  # path -> Resource
var _resource_refs: Dictionary = {}  # path -> ref_count
var _preloaded_resources: Dictionary = {}  # path -> Resource

# Unload timer
var _unload_timer: Timer


## Initialize the resource manager
## Override this method to add custom initialization
func _ready() -> void:
	# Get LogManager reference

	LogManager.info("ResourceManager", "ResourceManager initializing...")
	_initialize_resource_manager()
	_on_resource_manager_ready()
	LogManager.info("ResourceManager", "ResourceManager ready")

## Initialize resource manager
## Override this method to customize initialization
func _initialize_resource_manager() -> void:
	if auto_unload_unused:
		_unload_timer = Timer.new()
		_unload_timer.wait_time = unload_check_interval
		_unload_timer.timeout.connect(_on_unload_timer_timeout)
		_unload_timer.autostart = true
		add_child(_unload_timer)

## Load a resource
## Override this method to add custom load logic
func load_resource(resource_path: String, use_cache: bool = true) -> Resource:
	if resource_path.is_empty():
		LogManager.error("ResourceManager", "Cannot load empty resource path")
		return null

	# Check cache first
	if use_cache and enable_caching and _resource_cache.has(resource_path):
		var cached_resource := _resource_cache[resource_path] as Resource
		if cached_resource != null:
			_increment_ref_count(resource_path)
			LogManager.trace("ResourceManager", "Cache hit for resource: " + resource_path)
			_on_resource_loaded_from_cache(resource_path, cached_resource)
			return cached_resource

	# Load resource
	if not ResourceLoader.exists(resource_path):
		LogManager.error("ResourceManager", "Resource does not exist: " + resource_path)
		return null

	LogManager.debug("ResourceManager", "Loading resource: " + resource_path)
	var resource := load(resource_path) as Resource
	if resource == null:
		LogManager.error("ResourceManager", "Failed to load resource: " + resource_path)
		return null

	LogManager.debug("ResourceManager", "Successfully loaded resource: " + resource_path)

	# Cache resource if enabled
	if use_cache and enable_caching:
		_cache_resource(resource_path, resource)

	resource_loaded.emit(resource_path, resource)
	_on_resource_loaded(resource_path, resource)

	return resource

## Load a resource asynchronously
## Override this method to add custom async load logic
func load_resource_async(resource_path: String, use_cache: bool = true) -> Resource:
	if resource_path.is_empty():
		LogManager.error("ResourceManager", "Cannot load empty resource path")
		return null
	
	# Check cache first
	if use_cache and enable_caching and _resource_cache.has(resource_path):
		var cached_resource := _resource_cache[resource_path] as Resource
		if cached_resource != null:
			_increment_ref_count(resource_path)
			return cached_resource
	
	# Start async load
	if not ResourceLoader.exists(resource_path):
		LogManager.error("ResourceManager", "Resource does not exist: " + resource_path)
		return null
	
	var loader := ResourceLoader.load_threaded_request(resource_path)
	if loader == null:
		LogManager.error("ResourceManager", "Failed to start async load: " + resource_path)
		return null
	
	# Wait for load to complete
	while ResourceLoader.load_threaded_get_status(resource_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	
	var status := ResourceLoader.load_threaded_get_status(resource_path)
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		LogManager.error("ResourceManager", "Async load failed: " + resource_path)
		return null
	
	var resource := ResourceLoader.load_threaded_get(resource_path) as Resource
	if resource == null:
		LogManager.error("ResourceManager", "Failed to get async loaded resource: " + resource_path)
		return null
	
	# Cache resource if enabled
	if use_cache and enable_caching:
		_cache_resource(resource_path, resource)
	
	resource_loaded.emit(resource_path, resource)
	_on_resource_loaded(resource_path, resource)
	
	return resource

## Unload a resource
## Override this method to add custom unload logic
func unload_resource(resource_path: String, force: bool = false) -> bool:
	if not _resource_cache.has(resource_path):
		return false
	
	# Decrement ref count
	if not force:
		_decrement_ref_count(resource_path)
		if _resource_refs.get(resource_path, 0) > 0:
			return false  # Still referenced
	
	# Remove from cache
	_resource_cache.erase(resource_path)
	_resource_refs.erase(resource_path)
	
	resource_unloaded.emit(resource_path)
	_on_resource_unloaded(resource_path)
	
	return true

## Preload a resource
## Override this method to add custom preload logic
func preload_resource(resource_path: String) -> Resource:
	if resource_path.is_empty():
		LogManager.error("ResourceManager", "Cannot preload empty resource path")
		return null
	
	# Check if already preloaded
	if _preloaded_resources.has(resource_path):
		return _preloaded_resources[resource_path] as Resource
	
	# Load resource
	var resource := load_resource(resource_path, true)
	if resource == null:
		return null
	
	# Store as preloaded
	_preloaded_resources[resource_path] = resource
	
	resource_preloaded.emit(resource_path, resource)
	_on_resource_preloaded(resource_path, resource)
	
	return resource

## Unpreload a resource
func unpreload_resource(resource_path: String) -> bool:
	if not _preloaded_resources.has(resource_path):
		return false
	
	_preloaded_resources.erase(resource_path)
	_on_resource_unpreloaded(resource_path)
	return true

## Get a cached resource
func get_cached_resource(resource_path: String) -> Resource:
	if not _resource_cache.has(resource_path):
		return null
	return _resource_cache[resource_path] as Resource

## Check if a resource is cached
func is_resource_cached(resource_path: String) -> bool:
	return _resource_cache.has(resource_path)

## Check if a resource is preloaded
func is_resource_preloaded(resource_path: String) -> bool:
	return _preloaded_resources.has(resource_path)

## Increment reference count
func _increment_ref_count(resource_path: String) -> void:
	if not _resource_refs.has(resource_path):
		_resource_refs[resource_path] = 0
	_resource_refs[resource_path] += 1

## Decrement reference count
func _decrement_ref_count(resource_path: String) -> void:
	if not _resource_refs.has(resource_path):
		return
	
	_resource_refs[resource_path] -= 1
	if _resource_refs[resource_path] < 0:
		_resource_refs[resource_path] = 0

## Get reference count
func get_ref_count(resource_path: String) -> int:
	return _resource_refs.get(resource_path, 0)

## Cache a resource
func _cache_resource(resource_path: String, resource: Resource) -> void:
	_resource_cache[resource_path] = resource
	_increment_ref_count(resource_path)
	
	# Manage cache size
	_manage_cache_size()

## Manage cache size
func _manage_cache_size() -> void:
	if _resource_cache.size() <= max_cache_size:
		return
	
	# Remove least recently used resources (simple implementation)
	# Override for more sophisticated LRU
	var keys: Array = _resource_cache.keys()
	var to_remove: int = keys.size() - max_cache_size
	
	for i in range(to_remove):
		var key_val: Variant = keys[i]
		var key: String = key_val if key_val is String else ""
		# Only remove if not referenced
		if _resource_refs.get(key, 0) <= 0:
			unload_resource(key, true)

## Clear resource cache
func clear_cache() -> void:
	_resource_cache.clear()
	_resource_refs.clear()
	cache_cleared.emit()
	_on_cache_cleared()

## Clear preloaded resources
func clear_preloaded() -> void:
	_preloaded_resources.clear()
	_on_preloaded_cleared()

## Get cache size
func get_cache_size() -> int:
	return _resource_cache.size()

## Get cached resource paths
func get_cached_paths() -> Array[String]:
	return _resource_cache.keys()

## Get preloaded resource paths
func get_preloaded_paths() -> Array[String]:
	return _preloaded_resources.keys()

## Called when unload timer times out
func _on_unload_timer_timeout() -> void:
	_unload_unused_resources()

## Unload unused resources
func _unload_unused_resources() -> void:
	var to_unload: Array[String] = []
	
	for resource_path in _resource_cache:
		if _resource_refs.get(resource_path, 0) <= 0:
			to_unload.append(resource_path)
	
	for resource_path in to_unload:
		unload_resource(resource_path, true)
	
	_on_unused_resources_unloaded(to_unload.size())

## Virtual methods - Override these in extended classes

## Called when resource manager is ready
## Override to add initialization logic
func _on_resource_manager_ready() -> void:
	pass

## Called when a resource is loaded
## Override to handle resource loading
func _on_resource_loaded(_resource_path: String, _resource: Resource) -> void:
	pass

## Called when a resource is loaded from cache
## Override to handle cache hits
func _on_resource_loaded_from_cache(_resource_path: String, _resource: Resource) -> void:
	pass

## Called when a resource is unloaded
## Override to handle resource unloading
func _on_resource_unloaded(_resource_path: String) -> void:
	pass

## Called when a resource is preloaded
## Override to handle resource preloading
func _on_resource_preloaded(_resource_path: String, _resource: Resource) -> void:
	pass

## Called when a resource is unpreloaded
## Override to handle resource unpreloading
func _on_resource_unpreloaded(_resource_path: String) -> void:
	pass

## Called when cache is cleared
## Override to handle cache clearing
func _on_cache_cleared() -> void:
	pass

## Called when preloaded resources are cleared
## Override to handle preloaded clearing
func _on_preloaded_cleared() -> void:
	pass

## Called when unused resources are unloaded
## Override to handle unused resource cleanup
func _on_unused_resources_unloaded(_count: int) -> void:
	pass
