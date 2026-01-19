class_name GameStateDefinition extends Resource

## GameStateDefinition - Resource class for defining individual game states
##
## This resource defines a single state in the game state machine.
## Use this to configure state behavior, transitions, and callbacks.

@export var name: String = ""
@export var entry_callback: String = ""
@export var exit_callback: String = ""
@export var allowed_transitions: Array[String] = []
@export var properties: Dictionary = {}

func _init(
	p_name: String = "",
	p_entry_callback: String = "",
	p_exit_callback: String = "",
	p_allowed_transitions: Array[String] = [],
	p_properties: Dictionary = {}
) -> void:
	name = p_name
	entry_callback = p_entry_callback
	exit_callback = p_exit_callback
	allowed_transitions = p_allowed_transitions
	properties = p_properties

