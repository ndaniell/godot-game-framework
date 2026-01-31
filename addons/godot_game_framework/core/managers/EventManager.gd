class_name GGF_EventManager
extends "res://addons/godot_game_framework/core/managers/BaseManager.gd"

## EventManager - Extensible event system for the Godot Game Framework
##
## This manager provides a global event bus using pub/sub pattern.
## Extend this class to add custom event functionality.

signal event_emitted(event_name: String, data: Dictionary)
signal listener_added(event_name: String)
signal listener_removed(event_name: String)

# Event history (optional, for debugging)
@export_group("Event Configuration")
@export var enable_event_history: bool = false
@export var max_history_size: int = 100

# Event listeners storage
# Structure: event_name -> Array[{callable: Callable, priority: int}]
var _listeners: Dictionary = {}

# One-shot subscriptions (removed after first emit)
var _one_shot_listeners: Dictionary = {}  # event_name -> Array[Callable]

var _event_history: Array[Dictionary] = []

# Owned subscriptions for auto-cleanup
# Structure: owner_instance_id -> Array[{event_name: String, callable: Callable}]
var _owned_subscriptions: Dictionary = {}

# LogManager reference


## Initialize the event manager
## Override this method to add custom initialization
func _ready() -> void:
	# Get LogManager reference

	GGF.log().info("EventManager", "EventManager initializing...")
	_initialize_event_manager()
	_on_event_manager_ready()
	GGF.log().info("EventManager", "EventManager ready")
	_set_manager_ready()  # Mark manager as ready


## Initialize event manager
## Override this method to customize initialization
func _initialize_event_manager() -> void:
	pass


## Subscribe to an event with optional priority
## Higher priority listeners are called first (default: 0)
## Override this method to add custom subscription logic
func subscribe(event_name: String, callable: Callable, priority: int = 0) -> void:
	if event_name.is_empty():
		GGF.log().error("EventManager", "Cannot subscribe to empty event name")
		return

	if not callable.is_valid():
		GGF.log().error("EventManager", "Cannot subscribe with invalid callable")
		return

	# Initialize array if event doesn't exist
	if not _listeners.has(event_name):
		_listeners[event_name] = []

	# Add listener if not already present
	var listeners := _listeners[event_name] as Array
	var found := false
	for entry_var in listeners:
		var entry: Variant = entry_var
		if entry is Dictionary:
			var entry_dict := entry as Dictionary
			var entry_callable: Callable = entry_dict.get("callable", Callable())
			if entry_callable == callable:
				found = true
				break

	if not found:
		listeners.append({"callable": callable, "priority": priority})
		# Sort by priority (higher first)
		listeners.sort_custom(
			func(a, b):
				return (a as Dictionary).get("priority", 0) > (b as Dictionary).get("priority", 0)
		)
		GGF.log().debug(
			"EventManager",
			"Added listener for event: " + event_name + " (priority: " + str(priority) + ")"
		)
		listener_added.emit(event_name)
		_on_listener_added(event_name, callable)


## Subscribe to an event once (auto-unsubscribe after first emission)
func subscribe_once(event_name: String, callable: Callable, priority: int = 0) -> void:
	if event_name.is_empty():
		GGF.log().error("EventManager", "Cannot subscribe to empty event name")
		return

	if not callable.is_valid():
		GGF.log().error("EventManager", "Cannot subscribe with invalid callable")
		return

	# Track as one-shot
	if not _one_shot_listeners.has(event_name):
		_one_shot_listeners[event_name] = []

	var one_shots := _one_shot_listeners[event_name] as Array
	if callable not in one_shots:
		one_shots.append(callable)

	# Subscribe normally with priority
	subscribe(event_name, callable, priority)


## Unsubscribe all events for a specific owner node
## Useful for cleanup when nodes are destroyed
func unsubscribe_all_for_owner(node_owner: Node) -> void:
	if node_owner == null:
		return

	var owner_id := node_owner.get_instance_id()
	if not _owned_subscriptions.has(owner_id):
		return

	var subscriptions := _owned_subscriptions[owner_id] as Array
	for sub_info in subscriptions.duplicate():  # Duplicate to avoid modification during iteration
		var event_name: String = sub_info.get("event_name", "")
		var callable: Callable = sub_info.get("callable", Callable())
		if not event_name.is_empty() and callable.is_valid():
			unsubscribe(event_name, callable)

	_owned_subscriptions.erase(owner_id)
	GGF.log().debug("EventManager", "Unsubscribed all events for owner")


## Unsubscribe from an event
## Override this method to add custom unsubscription logic
func unsubscribe(event_name: String, callable: Callable) -> void:
	if not _listeners.has(event_name):
		return

	var listeners := _listeners[event_name] as Array
	var found_index := -1
	for i in range(listeners.size()):
		var entry: Variant = listeners[i]
		if entry is Dictionary:
			var entry_dict := entry as Dictionary
			var entry_callable: Callable = entry_dict.get("callable", Callable())
			if entry_callable == callable:
				found_index = i
				break

	if found_index >= 0:
		listeners.remove_at(found_index)
		listener_removed.emit(event_name)
		_on_listener_removed(event_name, callable)

		# Clean up empty event arrays
		if listeners.is_empty():
			_listeners.erase(event_name)

	# Remove from one-shot if present
	if _one_shot_listeners.has(event_name):
		var one_shots := _one_shot_listeners[event_name] as Array
		one_shots.erase(callable)
		if one_shots.is_empty():
			_one_shot_listeners.erase(event_name)


## Unsubscribe all listeners for an event
func unsubscribe_all(event_name: String) -> void:
	if not _listeners.has(event_name):
		return

	var listeners := _listeners[event_name] as Array
	for callable in listeners:
		_on_listener_removed(event_name, callable)

	_listeners.erase(event_name)
	listener_removed.emit(event_name)


## Emit an event
## Override this method to add custom emission logic
## Supports wildcard subscriptions:
## - "network.*" matches "network.connected", "network.disconnected", etc.
func emit(event_name: String, data: Dictionary = {}) -> void:
	if event_name.is_empty():
		GGF.log().warn("EventManager", "Cannot emit empty event name")
		return

	# Add to history if enabled
	if enable_event_history:
		_add_to_history(event_name, data)

	# Emit signal
	event_emitted.emit(event_name, data)

	# Collect all matching listeners (exact + wildcard)
	var all_listeners: Array = []

	# Direct listeners
	if _listeners.has(event_name):
		all_listeners.append_array(_listeners[event_name] as Array)

	# Wildcard listeners (e.g. "network.*" matches "network.connected")
	for listener_key in _listeners.keys():
		var key_str := String(listener_key)
		if key_str.ends_with(".*"):
			var prefix := key_str.substr(0, key_str.length() - 2)
			if event_name.begins_with(prefix + "."):
				all_listeners.append_array(_listeners[listener_key] as Array)

	if all_listeners.is_empty():
		GGF.log().trace("EventManager", "Emitted event '" + event_name + "' (no listeners)")
		_on_event_emitted(event_name, data)
		return

	# Sort by priority (already sorted when added, but merge in case of wildcards)
	all_listeners.sort_custom(
		func(a, b):
			var a_priority := 0
			var b_priority := 0
			if a is Dictionary:
				a_priority = (a as Dictionary).get("priority", 0)
			if b is Dictionary:
				b_priority = (b as Dictionary).get("priority", 0)
			return a_priority > b_priority
	)

	GGF.log().trace(
		"EventManager",
		"Emitting event '" + event_name + "' to " + str(all_listeners.size()) + " listener(s)"
	)

	# Track one-shots to remove after emission
	var one_shots_to_remove: Array[Callable] = []

	# Notify all listeners
	for entry in all_listeners:
		var callable: Callable
		if entry is Dictionary:
			callable = (entry as Dictionary).get("callable", Callable())
		else:
			callable = entry as Callable  # Legacy support

		if callable.is_valid():
			callable.call(data)

			# Check if this is a one-shot
			if _one_shot_listeners.has(event_name):
				var one_shots := _one_shot_listeners[event_name] as Array
				if callable in one_shots:
					one_shots_to_remove.append(callable)
		else:
			# Remove invalid callables
			if _listeners.has(event_name):
				(_listeners[event_name] as Array).erase(entry)

	# Clean up one-shot listeners
	for callable in one_shots_to_remove:
		unsubscribe(event_name, callable)

	_on_event_emitted(event_name, data)


## Check if an event has listeners
func has_listeners(event_name: String) -> bool:
	if not _listeners.has(event_name):
		return false
	var listeners := _listeners[event_name] as Array
	return not listeners.is_empty()


## Get listener count for an event
func get_listener_count(event_name: String) -> int:
	if not _listeners.has(event_name):
		return 0
	return (_listeners[event_name] as Array).size()


## Get all event names with listeners
func get_registered_events() -> Array[String]:
	return _listeners.keys()


## Get debug info for all registered events (for diagnostics/inspector)
func get_events_debug_info() -> Array[Dictionary]:
	var info: Array[Dictionary] = []
	for event_name in _listeners.keys():
		var listeners := _listeners[event_name] as Array
		var one_shot_count := 0
		if _one_shot_listeners.has(event_name):
			one_shot_count = (_one_shot_listeners[event_name] as Array).size()

		(
			info
			. append(
				{
					"event": event_name,
					"listener_count": listeners.size(),
					"one_shot_count": one_shot_count,
				}
			)
		)
	return info


## Clear all listeners
func clear_all_listeners() -> void:
	_listeners.clear()
	_on_all_listeners_cleared()


## Clear event history
func clear_event_history() -> void:
	_event_history.clear()
	_on_event_history_cleared()


## Get event history
func get_event_history() -> Array[Dictionary]:
	return _event_history.duplicate()


## Add event to history
func _add_to_history(event_name: String, data: Dictionary) -> void:
	(
		_event_history
		. append(
			{
				"event": event_name,
				"data": data.duplicate(),
				"time": Time.get_ticks_msec(),
			}
		)
	)

	# Limit history size
	if _event_history.size() > max_history_size:
		_event_history.pop_front()


## Subscribe using a method name (convenience method)
func subscribe_method(event_name: String, target: Object, method: String) -> void:
	if target == null:
		GGF.log().error("EventManager", "Cannot subscribe with null target")
		return

	if not target.has_method(method):
		GGF.log().error("EventManager", "Target does not have method: " + method)
		return

	var callable := Callable(target, method)
	subscribe(event_name, callable)


## Unsubscribe using a method name (convenience method)
func unsubscribe_method(event_name: String, target: Object, method: String) -> void:
	if target == null:
		return

	var callable := Callable(target, method)
	unsubscribe(event_name, callable)


## Subscribe with automatic cleanup when owner exits tree
## This prevents memory leaks by auto-unsubscribing when the owner node is freed
func subscribe_owned(event_name: String, node_owner: Node, method: String) -> void:
	if node_owner == null:
		GGF.log().error("EventManager", "Cannot subscribe_owned with null owner")
		return

	if not node_owner.has_method(method):
		GGF.log().error("EventManager", "Owner does not have method: " + method)
		return

	var callable := Callable(node_owner, method)
	subscribe(event_name, callable)

	# Track this subscription for auto-cleanup
	var owner_id := node_owner.get_instance_id()
	if not _owned_subscriptions.has(owner_id):
		_owned_subscriptions[owner_id] = []
		# Connect to tree_exiting signal for auto-cleanup
		if not node_owner.is_connected("tree_exiting", _on_owner_exiting):
			node_owner.tree_exiting.connect(_on_owner_exiting.bind(owner_id))

	var subscription_info := {"event_name": event_name, "callable": callable}
	(_owned_subscriptions[owner_id] as Array).append(subscription_info)

	GGF.log().debug(
		"EventManager",
		"Added owned subscription for event '" + event_name + "' (owner will auto-cleanup)"
	)


## Internal: Handle owner node exiting tree
func _on_owner_exiting(owner_id: int) -> void:
	if not _owned_subscriptions.has(owner_id):
		return

	var subscriptions := _owned_subscriptions[owner_id] as Array
	for sub_info in subscriptions:
		var event_name: String = sub_info.get("event_name", "")
		var callable: Callable = sub_info.get("callable", Callable())
		if not event_name.is_empty() and callable.is_valid():
			unsubscribe(event_name, callable)

	_owned_subscriptions.erase(owner_id)
	GGF.log().debug("EventManager", "Auto-cleaned up subscriptions for freed owner")


## Virtual methods - Override these in extended classes


## Called when event manager is ready
## Override to add initialization logic
func _on_event_manager_ready() -> void:
	pass


## Called when an event is emitted
## Override to handle event emission
func _on_event_emitted(_event_name: String, _data: Dictionary) -> void:
	pass


## Called when a listener is added
## Override to handle listener addition
func _on_listener_added(_event_name: String, _callable: Callable) -> void:
	pass


## Called when a listener is removed
## Override to handle listener removal
func _on_listener_removed(_event_name: String, _callable: Callable) -> void:
	pass


## Called when all listeners are cleared
## Override to handle listener clearing
func _on_all_listeners_cleared() -> void:
	pass


## Called when event history is cleared
## Override to handle history clearing
func _on_event_history_cleared() -> void:
	pass
