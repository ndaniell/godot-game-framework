extends Node

## EventManager - Extensible event system for the Godot Game Framework
##
## This manager provides a global event bus using pub/sub pattern.
## Extend this class to add custom event functionality.

signal event_emitted(event_name: String, data: Dictionary)
signal listener_added(event_name: String)
signal listener_removed(event_name: String)

# Event listeners storage
# Structure: event_name -> Array[Callable>
var _listeners: Dictionary = {}

# Event history (optional, for debugging)
@export_group("Event Configuration")
@export var enable_event_history: bool = false
@export var max_history_size: int = 100

var _event_history: Array[Dictionary] = []

# LogManager reference

## Initialize the event manager
## Override this method to add custom initialization
func _ready() -> void:
	# Get LogManager reference

	GGF.log().info("EventManager", "EventManager initializing...")
	_initialize_event_manager()
	_on_event_manager_ready()
	GGF.log().info("EventManager", "EventManager ready")

## Initialize event manager
## Override this method to customize initialization
func _initialize_event_manager() -> void:
	pass

## Subscribe to an event
## Override this method to add custom subscription logic
func subscribe(event_name: String, callable: Callable) -> void:
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
	if callable not in listeners:
		listeners.append(callable)
		GGF.log().debug("EventManager", "Added listener for event: " + event_name)
		listener_added.emit(event_name)
		_on_listener_added(event_name, callable)

## Unsubscribe from an event
## Override this method to add custom unsubscription logic
func unsubscribe(event_name: String, callable: Callable) -> void:
	if not _listeners.has(event_name):
		return
	
	var listeners := _listeners[event_name] as Array
	var index := listeners.find(callable)
	if index >= 0:
		listeners.remove_at(index)
		listener_removed.emit(event_name)
		_on_listener_removed(event_name, callable)
		
		# Clean up empty event arrays
		if listeners.is_empty():
			_listeners.erase(event_name)

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
func emit(event_name: String, data: Dictionary = {}) -> void:
	if event_name.is_empty():
		GGF.log().warn("EventManager", "Cannot emit empty event name")
		return

	# Add to history if enabled
	if enable_event_history:
		_add_to_history(event_name, data)

	# Emit signal
	event_emitted.emit(event_name, data)

	# Notify listeners
	if _listeners.has(event_name):
		var listeners := _listeners[event_name] as Array
		var listener_count := listeners.size()
		GGF.log().trace("EventManager", "Emitting event '" + event_name + "' to " + str(listener_count) + " listener(s)")

		# Create a copy to avoid issues if listeners modify the array
		var listeners_copy := listeners.duplicate()

		for callable in listeners_copy:
			if callable.is_valid():
				# Call with data - GDScript callables can handle extra args being ignored
				# If the function doesn't accept args, they'll be ignored
				callable.call(data)
			else:
				# Remove invalid callables
				listeners.erase(callable)
	else:
		GGF.log().trace("EventManager", "Emitted event '" + event_name + "' (no listeners)")

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
	_event_history.append({
		"event": event_name,
		"data": data.duplicate(),
		"time": Time.get_ticks_msec()
	})
	
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

