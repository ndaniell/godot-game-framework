class_name GGF_PoolManager
extends "res://addons/godot_game_framework/core/managers/BaseManager.gd"

## PoolManager - Extensible object pooling system for the Godot Game Framework
##
## This manager handles object pooling to improve performance by reusing objects.
## Extend this class to add custom pooling functionality.

signal object_spawned(pool_name: String, object: Node)
signal object_despawned(pool_name: String, object: Node)
signal pool_created(pool_name: String, size: int)
signal pool_cleared(pool_name: String)

# Pool configuration
@export_group("Pool Configuration")
@export var default_pool_size: int = 10
@export var auto_expand_pools: bool = true
@export var max_pool_size: int = 100

# Pool storage
# Structure: pool_name -> { "active": Array[Node], "inactive": Array[Node], "prefab": PackedScene }
var _pools: Dictionary = {}


## Initialize the pool manager
## Override this method to add custom initialization
func _ready() -> void:
	_initialize_pool_manager()
	_on_pool_manager_ready()
	_set_manager_ready()  # Mark manager as ready


## Initialize pool manager
## Override this method to customize initialization
func _initialize_pool_manager() -> void:
	pass


## Create a new object pool
## Override this method to add custom pool creation logic
func create_pool(pool_name: String, prefab: PackedScene, initial_size: int = -1) -> bool:
	if pool_name.is_empty():
		GGF.log().error("PoolManager", "Cannot create pool with empty name")
		return false

	if prefab == null:
		GGF.log().error("PoolManager", "Cannot create pool with null prefab")
		return false

	if _pools.has(pool_name):
		GGF.log().warn("PoolManager", "Pool already exists: " + pool_name)
		return false

	var size := initial_size if initial_size > 0 else default_pool_size

	# Create pool structure
	_pools[pool_name] = {
		"active": [],
		"inactive": [],
		"prefab": prefab,
		"size": size,
	}

	# Pre-populate pool
	_expand_pool(pool_name, size)

	pool_created.emit(pool_name, size)
	_on_pool_created(pool_name, size)

	return true


## Spawn an object from a pool
## Override this method to add custom spawn logic
func spawn(pool_name: String, position: Vector3 = Vector3.ZERO, parent: Node = null) -> Node:
	if not _pools.has(pool_name):
		GGF.log().error("PoolManager", "Pool does not exist: " + pool_name)
		return null

	var pool := _pools[pool_name] as Dictionary
	var inactive := pool["inactive"] as Array
	var active := pool["active"] as Array
	var prefab := pool["prefab"] as PackedScene

	var obj: Node = null

	# Get object from inactive pool or create new one
	if inactive.size() > 0:
		obj = inactive.pop_back() as Node
	else:
		# Auto-expand if enabled
		if auto_expand_pools:
			if active.size() < max_pool_size:
				obj = prefab.instantiate()
				if obj == null:
					GGF.log().error(
						"PoolManager", "Failed to instantiate prefab for pool: " + pool_name
					)
					return null
			else:
				GGF.log().warn("PoolManager", "Pool at max size, cannot spawn: " + pool_name)
				return null
		else:
			GGF.log().warn("PoolManager", "Pool exhausted, cannot spawn: " + pool_name)
			return null

	# Add to active pool
	active.append(obj)

	# Set parent if specified
	if parent != null:
		parent.add_child(obj)
	elif not obj.get_parent():
		# Add to scene tree if no parent
		get_tree().current_scene.add_child(obj)

	# Set position if specified
	if obj is Node3D:
		(obj as Node3D).global_position = position
	elif obj is Node2D:
		(obj as Node2D).global_position = Vector2(position.x, position.y)

	# Reset object state
	_reset_object(obj)

	# Make visible and enable
	obj.visible = true
	if obj.has_method("set_process"):
		obj.set_process(true)
	if obj.has_method("set_physics_process"):
		obj.set_physics_process(true)

	object_spawned.emit(pool_name, obj)
	_on_object_spawned(pool_name, obj)

	return obj


## Despawn an object back to the pool
## Override this method to add custom despawn logic
func despawn(pool_name: String, obj: Node) -> bool:
	if not _pools.has(pool_name):
		GGF.log().error("PoolManager", "Pool does not exist: " + pool_name)
		return false

	var pool := _pools[pool_name] as Dictionary
	var inactive := pool["inactive"] as Array
	var active := pool["active"] as Array

	# Check if object is in active pool
	var index := active.find(obj)
	if index < 0:
		GGF.log().warn("PoolManager", "Object not in active pool: " + pool_name)
		return false

	# Remove from active
	active.remove_at(index)

	# Add to inactive
	inactive.append(obj)

	# Clean up object
	_cleanup_object(obj)

	# Hide and disable
	obj.visible = false
	if obj.has_method("set_process"):
		obj.set_process(false)
	if obj.has_method("set_physics_process"):
		obj.set_physics_process(false)

	# Remove from scene tree but keep in memory
	if obj.get_parent():
		obj.get_parent().remove_child(obj)

	object_despawned.emit(pool_name, obj)
	_on_object_despawned(pool_name, obj)

	return true


## Expand a pool by creating additional objects
func expand_pool(pool_name: String, count: int) -> void:
	if not _pools.has(pool_name):
		GGF.log().error("PoolManager", "Pool does not exist: " + pool_name)
		return

	_expand_pool(pool_name, count)


## Internal method to expand pool
func _expand_pool(pool_name: String, count: int) -> void:
	var pool := _pools[pool_name] as Dictionary
	var inactive := pool["inactive"] as Array
	var prefab := pool["prefab"] as PackedScene

	for i in range(count):
		var obj := prefab.instantiate()
		if obj == null:
			GGF.log().error("PoolManager", "Failed to instantiate prefab for pool: " + pool_name)
			continue

		# Initialize object as inactive
		obj.visible = false
		if obj.has_method("set_process"):
			obj.set_process(false)
		if obj.has_method("set_physics_process"):
			obj.set_physics_process(false)

		inactive.append(obj)
		_initialize_object(obj)


## Reset object state when spawning
## Override this method to customize object reset
func _reset_object(obj: Node) -> void:
	# Override to reset object properties
	if obj.has_method("reset"):
		obj.reset()


## Initialize object when added to pool
## Override this method to customize object initialization
func _initialize_object(_obj: Node) -> void:
	# Override to initialize object properties
	pass


## Cleanup object when despawning
## Override this method to customize object cleanup
func _cleanup_object(obj: Node) -> void:
	# Override to cleanup object properties
	if obj.has_method("cleanup"):
		obj.cleanup()


## Clear a pool (despawn all active objects)
func clear_pool(pool_name: String) -> void:
	if not _pools.has(pool_name):
		return

	var pool := _pools[pool_name] as Dictionary
	var active := pool["active"] as Array

	# Despawn all active objects
	for obj in active.duplicate():
		despawn(pool_name, obj)

	pool_cleared.emit(pool_name)
	_on_pool_cleared(pool_name)


## Remove a pool entirely
func remove_pool(pool_name: String) -> void:
	if not _pools.has(pool_name):
		return

	# Clear pool first (moves active objects to inactive).
	var pool := _pools[pool_name] as Dictionary
	clear_pool(pool_name)

	# Free pooled objects (Nodes are not refcounted; dropping references is not enough).
	var inactive := pool.get("inactive", []) as Array
	for obj in inactive:
		if obj != null and is_instance_valid(obj):
			if obj.get_parent():
				obj.get_parent().remove_child(obj)
			obj.queue_free()
	inactive.clear()

	# Remove pool record.
	_pools.erase(pool_name)
	_on_pool_removed(pool_name)


## Get pool statistics
func get_pool_stats(pool_name: String) -> Dictionary:
	if not _pools.has(pool_name):
		return {}

	var pool := _pools[pool_name] as Dictionary
	return {
		"active_count": (pool["active"] as Array).size(),
		"inactive_count": (pool["inactive"] as Array).size(),
		"total_count": (pool["active"] as Array).size() + (pool["inactive"] as Array).size(),
		"size": pool["size"],
	}


## Check if a pool exists
func pool_exists(pool_name: String) -> bool:
	return _pools.has(pool_name)


## Get all pool names
func get_pool_names() -> Array[String]:
	var result: Array[String] = []
	var keys = _pools.keys()
	for key in keys:
		if key is String:
			result.append(key as String)
	return result


## Get active objects from a pool
func get_active_objects(pool_name: String) -> Array[Node]:
	if not _pools.has(pool_name):
		return []

	var pool := _pools[pool_name] as Dictionary
	return (pool["active"] as Array).duplicate()


## Get inactive objects from a pool
func get_inactive_objects(pool_name: String) -> Array[Node]:
	if not _pools.has(pool_name):
		return []

	var pool := _pools[pool_name] as Dictionary
	return (pool["inactive"] as Array).duplicate()


## Clear all pools
func clear_all_pools() -> void:
	for pool_name in _pools.keys():
		clear_pool(pool_name)
	_on_all_pools_cleared()


## Virtual methods - Override these in extended classes


## Called when pool manager is ready
## Override to add initialization logic
func _on_pool_manager_ready() -> void:
	pass


## Called when a pool is created
## Override to handle pool creation
func _on_pool_created(_pool_name: String, _size: int) -> void:
	pass


## Called when an object is spawned
## Override to handle object spawning
func _on_object_spawned(_pool_name: String, _obj: Node) -> void:
	pass


## Called when an object is despawned
## Override to handle object despawning
func _on_object_despawned(_pool_name: String, _obj: Node) -> void:
	pass


## Called when a pool is cleared
## Override to handle pool clearing
func _on_pool_cleared(_pool_name: String) -> void:
	pass


## Called when a pool is removed
## Override to handle pool removal
func _on_pool_removed(_pool_name: String) -> void:
	pass


## Called when all pools are cleared
## Override to handle all pools clearing
func _on_all_pools_cleared() -> void:
	pass
