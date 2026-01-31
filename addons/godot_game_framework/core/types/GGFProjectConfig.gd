@tool
class_name GGFProjectConfig extends Resource

## GGFProjectConfig - Unified configuration resource for the Godot Game Framework
##
## This resource consolidates all framework configuration into a single place:
## - Settings defaults (graphics, audio, gameplay)
## - UI configuration (theme, pre-registered elements)
## - State machine configuration
## - Manager-specific options
##
## Host projects can create `res://ggf_project_config.tres` to override defaults.

# Type constants (avoid reliance on global class_name scanning)
const SETTINGS_CONFIG_TYPE := preload(
	"res://addons/godot_game_framework/core/types/SettingsConfig.gd"
)
const UI_CONFIG_TYPE := preload("res://addons/godot_game_framework/core/types/UIConfig.gd")
const STATE_MACHINE_CONFIG_TYPE := preload(
	"res://addons/godot_game_framework/core/types/GameStateMachineConfig.gd"
)

# Sub-configuration references
@export_group("Configuration References")
@export var settings_config: SETTINGS_CONFIG_TYPE
@export var ui_config: UI_CONFIG_TYPE
@export var state_machine_config: STATE_MACHINE_CONFIG_TYPE

# Manager options
@export_group("Manager Configuration")
@export var enable_all_managers: bool = true
@export var disabled_managers: Array[String] = []  # Manager keys to skip
@export var log_level: String = "INFO"  # TRACE, DEBUG, INFO, WARN, ERROR

# Paths configuration
@export_group("Paths Configuration")
@export var save_directory: String = "user://saves"
@export var settings_file_path: String = "user://settings.save"
@export var log_directory: String = "user://logs"

# Feature flags
@export_group("Feature Flags")
@export var enable_diagnostics_overlay: bool = true
@export var enable_file_logging: bool = true
@export var enable_event_history: bool = false


## Validate the configuration
func validate() -> bool:
	# Settings config is optional
	if settings_config != null:
		if settings_config.get_script() != SETTINGS_CONFIG_TYPE:
			push_warning("GGFProjectConfig: settings_config is not a valid SettingsConfig")
			return false

	# UI config is optional
	if ui_config != null:
		if ui_config.get_script() != UI_CONFIG_TYPE:
			push_warning("GGFProjectConfig: ui_config is not a valid UIConfig")
			return false

	# State machine config is optional
	if state_machine_config != null:
		if state_machine_config.get_script() != STATE_MACHINE_CONFIG_TYPE:
			push_warning(
				"GGFProjectConfig: state_machine_config is not a valid GameStateMachineConfig"
			)
			return false
		if not state_machine_config.validate():
			push_warning("GGFProjectConfig: state_machine_config validation failed")
			return false

	return true


## Get settings config (or null if not set)
func get_settings_config() -> Resource:
	return settings_config


## Get UI config (or null if not set)
func get_ui_config() -> Resource:
	return ui_config


## Get state machine config (or null if not set)
func get_state_machine_config() -> Resource:
	return state_machine_config


## Check if a manager is enabled
func is_manager_enabled(manager_key: String) -> bool:
	if not enable_all_managers:
		return false
	return manager_key not in disabled_managers
