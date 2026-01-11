class_name GameStateMachineConfig extends Resource

## GameStateMachineConfig - Resource class for the complete state machine configuration
##
## This resource contains all state definitions and the default state.
## Load this resource in GameManager to configure the state machine.

@export var states: Dictionary = {}  # String -> GameStateDefinition
@export var default_state: String = "MENU"

func _init(
	p_states: Dictionary = {},
	p_default_state: String = "MENU"
) -> void:
	states = p_states
	default_state = p_default_state

## Get a state definition by name
func get_state(state_name: String) -> GameStateDefinition:
	return states.get(state_name, null)

## Check if a state exists
func has_state(state_name: String) -> bool:
	return states.has(state_name)

## Get all state names
func get_state_names() -> Array:
	return states.keys()

## Validate the configuration
func validate() -> bool:
	if states.is_empty():
		return false
	
	if not states.has(default_state):
		return false
	
	for state_name in states:
		var state_def = states[state_name]
		if not state_def is GameStateDefinition:
			return false
		if state_def.name.is_empty():
			return false
		
		# Validate transitions reference existing states
		for transition_state in state_def.allowed_transitions:
			if not states.has(transition_state):
				LogManager.warn("GameStateMachineConfig", "State '" + state_name + "' has transition to non-existent state: " + transition_state)
	
	return true
