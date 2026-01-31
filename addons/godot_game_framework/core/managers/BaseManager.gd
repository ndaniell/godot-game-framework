extends Node

## GGFBaseManager - Base class for all Godot Game Framework managers
## Note: No class_name to avoid conflicts with symlinked addon structure
##
## Provides standardized lifecycle and ready state management.
## All framework managers should extend this class.
##
## Usage in derived managers:
##   func _ready() -> void:
##       # Do all initialization here
##       _initialize_stuff()
##       # Call _set_manager_ready() at the END when fully initialized
##       _set_manager_ready()

## Emitted when the manager is fully initialized and ready to use
signal manager_ready

## Whether this manager has completed initialization
var _is_manager_ready: bool = false


## Check if this manager is ready
func is_manager_ready() -> bool:
	return _is_manager_ready


## Mark this manager as ready and emit signal
## Call this at the end of your _ready() override
func _set_manager_ready() -> void:
	if _is_manager_ready:
		return
	_is_manager_ready = true
	manager_ready.emit()


## Get the manager's type name (e.g., "LogManager", "UIManager")
## Override to provide specific manager name
func get_manager_name() -> String:
	return get_script().get_global_name()
