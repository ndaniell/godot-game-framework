class_name GameStateMachineConfig extends Resource

## GameStateMachineConfig - Resource class for the complete state machine configuration
##
## This resource contains all state definitions and the default state.
## Load this resource in GameManager to configure the state machine.

# NOTE: In headless/scripted runs, Godot may not have scanned addon `class_name` globals yet.
# Avoid hard type annotations against custom classes here; validate via script path instead.
const _GAME_STATE_DEFINITION_SCRIPT := preload(
	"res://addons/godot_game_framework/core/types/GameStateDefinition.gd"
)

@export var states: Dictionary = {}  # String -> Resource (GameStateDefinition)
@export var default_state: String = "MENU"


func _init(p_states: Dictionary = {}, p_default_state: String = "MENU") -> void:
	states = p_states
	default_state = p_default_state


## Get a state definition by name
func get_state(state_name: String) -> Resource:
	return states.get(state_name, null) as Resource


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
		var state_def := states[state_name] as Resource
		if state_def == null:
			return false
		if state_def.get_script() != _GAME_STATE_DEFINITION_SCRIPT:
			return false
		var name_val: Variant = state_def.get("name")
		if not (name_val is String) or String(name_val).is_empty():
			return false

		# Validate transitions reference existing states.
		# Use push_warning so this Resource can validate in-editor without requiring the addon autoload.
		var allowed_transitions_val: Variant = state_def.get("allowed_transitions")
		if allowed_transitions_val is Array:
			for transition_state in allowed_transitions_val:
				if transition_state is String and not states.has(transition_state):
					push_warning(
						(
							"GameStateMachineConfig: State '%s' has transition to non-existent state: %s"
							% [state_name, transition_state]
						)
					)
		elif allowed_transitions_val is PackedStringArray:
			for transition_state in allowed_transitions_val:
				if not states.has(transition_state):
					push_warning(
						(
							"GameStateMachineConfig: State '%s' has transition to non-existent state: %s"
							% [state_name, transition_state]
						)
					)

	return true
