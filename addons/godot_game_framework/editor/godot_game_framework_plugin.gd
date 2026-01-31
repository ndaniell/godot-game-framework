@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GGF"
const GGF_BASE_SCRIPT := "res://addons/godot_game_framework/GGF.gd"
const DEFAULT_STATES_CONFIG := "res://addons/godot_game_framework/resources/data/game_states.tres"


func _enter_tree() -> void:
	# This editor plugin does NOT install or modify autoloads.
	# The framework must be loaded via a project autoload named `GGF`.
	_validate_setup()


func _exit_tree() -> void:
	# Intentionally do nothing: we never create/remove autoloads.
	return


## Validate the framework setup
func _validate_setup() -> void:
	var validation_passed := true

	# Check 1: Autoload exists
	if not _has_autoload(AUTOLOAD_NAME):
		push_error(
			(
				(
					"GGF: Missing required autoload '%s'. "
					+ "Add an autoload named '%s' pointing to your bootstrapper (e.g. `res://src/ExampleGGF.gd`)."
				)
				% [AUTOLOAD_NAME, AUTOLOAD_NAME]
			)
		)
		validation_passed = false
		return  # Can't continue without autoload

	# Check 2: Autoload script extends GGF
	var autoload_path := _get_autoload_path(AUTOLOAD_NAME)
	if not autoload_path.is_empty():
		if not _validate_autoload_script(autoload_path):
			validation_passed = false

	# Check 3: Validate framework base script exists
	if not ResourceLoader.exists(GGF_BASE_SCRIPT):
		push_error("GGF: Framework base script not found at: " + GGF_BASE_SCRIPT)
		validation_passed = false

	# Check 4: Validate default state machine config
	if not ResourceLoader.exists(DEFAULT_STATES_CONFIG):
		push_warning(
			(
				"GGF: Default state machine config not found at: "
				+ DEFAULT_STATES_CONFIG
				+ ". Ensure GameManager has a valid states_config_path."
			)
		)

	# Check 5: Validate config resources if accessible
	_validate_project_configs()

	if validation_passed:
		print("GGF: Framework validation passed ✓")


## Check if autoload exists
func _has_autoload(autoload_name: String) -> bool:
	var setting_key := "autoload/%s" % autoload_name
	return ProjectSettings.has_setting(setting_key)


## Get autoload script path
func _get_autoload_path(autoload_name: String) -> String:
	var setting_key := "autoload/%s" % autoload_name
	if not ProjectSettings.has_setting(setting_key):
		return ""

	var autoload_value: String = ProjectSettings.get_setting(setting_key)
	# Remove the "*" prefix if present (enabled autoload)
	if autoload_value.begins_with("*"):
		autoload_value = autoload_value.substr(1)
	return autoload_value


## Validate that the autoload script extends GGF
func _validate_autoload_script(script_path: String) -> bool:
	if not ResourceLoader.exists(script_path):
		push_error("GGF: Autoload script not found: " + script_path)
		return false

	var script := load(script_path) as Script
	if script == null:
		push_error("GGF: Failed to load autoload script: " + script_path)
		return false

	# Check if it extends the base GGF script
	var base_script := load(GGF_BASE_SCRIPT) as Script
	if base_script == null:
		push_error("GGF: Failed to load base GGF script")
		return false

	# Walk up the inheritance chain
	var current_script := script
	var extends_ggf := false
	while current_script != null:
		if current_script == base_script:
			extends_ggf = true
			break
		current_script = current_script.get_base_script()

	if not extends_ggf:
		push_error(
			(
				"GGF: Autoload script at '"
				+ script_path
				+ "' does not extend GGF.gd. "
				+ "Extend 'res://addons/godot_game_framework/GGF.gd' in your bootstrapper."
			)
		)
		return false

	return true


## Validate project configuration resources
func _validate_project_configs() -> void:
	# Check for common config files in the project root
	var common_configs := [
		"res://ggf_ui_config.tres",
		"res://ggf_settings_config.tres",
		"res://resources/game_states.tres",
	]

	for config_path in common_configs:
		if ResourceLoader.exists(config_path):
			_validate_config_resource(config_path)


## Validate a specific config resource
func _validate_config_resource(path: String) -> void:
	var resource := load(path) as Resource
	if resource == null:
		push_warning("GGF: Failed to load config resource: " + path)
		return

	# If resource has a validate() method, call it
	if resource.has_method("validate"):
		var is_valid: bool = resource.validate()
		if not is_valid:
			push_warning("GGF: Config resource validation failed: " + path)
	else:
		# Basic validation: check if it's a valid resource
		print("GGF: Config resource loaded successfully: " + path)
