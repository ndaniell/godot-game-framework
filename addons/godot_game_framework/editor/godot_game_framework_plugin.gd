@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GGF"
const GGF_BASE_SCRIPT := "res://addons/godot_game_framework/GGF.gd"
const _DEFAULT_DATA_DIR := "res://addons/godot_game_framework/resources/data"
const _DEFAULT_UI_DIR := "res://addons/godot_game_framework/resources/ui"

const DEFAULT_STATES_CONFIG := _DEFAULT_DATA_DIR + "/game_states.tres"
const DEFAULT_SETTINGS_CONFIG := _DEFAULT_DATA_DIR + "/ggf_settings_config_default.tres"
const DEFAULT_UI_CONFIG := _DEFAULT_UI_DIR + "/ggf_ui_config_default.tres"

const PROJECT_CONFIG_PATH := "res://ggf_project_config.tres"

const _PREFERRED_BOOTSTRAP_DIR := "res://ggf"
const _PREFERRED_BOOTSTRAP_SCRIPT := "res://ggf/GGF.gd"
const _FALLBACK_BOOTSTRAP_SCRIPT := "res://GGF.gd"


func _enter_tree() -> void:
	# Enabling this plugin should be enough to "install" the framework:
	# - Create a project bootstrapper (if missing)
	# - Register the `GGF` autoload (if missing)
	# - Optionally create a project config resource (if missing)
	_ensure_framework_installed()
	_validate_setup()


func _exit_tree() -> void:
	# Intentionally do nothing: disabling the editor plugin should not uninstall
	# runtime framework bits (autoload/config), as that would break host projects.
	return


## Install / register framework bits in the host project (idempotent).
func _ensure_framework_installed() -> void:
	# Ensure framework base script exists
	if not ResourceLoader.exists(GGF_BASE_SCRIPT):
		push_error("GGF: Framework base script not found at: " + GGF_BASE_SCRIPT)
		return

	# Ensure project config exists (optional)
	_ensure_project_config_resource()

	# Ensure autoload exists
	if _has_autoload(AUTOLOAD_NAME):
		return

	var bootstrap_path := _ensure_bootstrapper_script()
	if bootstrap_path.is_empty():
		# Fallback to base script if we couldn't create a bootstrapper.
		bootstrap_path = GGF_BASE_SCRIPT

	add_autoload_singleton(AUTOLOAD_NAME, bootstrap_path)
	ProjectSettings.save()
	print("GGF: Installed autoload '%s' at %s" % [AUTOLOAD_NAME, bootstrap_path])


## Create a simple project bootstrapper script (if missing) and return its path.
func _ensure_bootstrapper_script() -> String:
	var bootstrap_path := _select_bootstrapper_path()
	if bootstrap_path.is_empty():
		return ""

	if ResourceLoader.exists(bootstrap_path):
		return bootstrap_path

	if bootstrap_path.begins_with(_PREFERRED_BOOTSTRAP_DIR):
		if not _ensure_dir_exists(_PREFERRED_BOOTSTRAP_DIR):
			# If we couldn't create the preferred directory, try the fallback path.
			bootstrap_path = _FALLBACK_BOOTSTRAP_SCRIPT
			if ResourceLoader.exists(bootstrap_path):
				return bootstrap_path

	var file := FileAccess.open(bootstrap_path, FileAccess.WRITE)
	if file == null:
		push_warning("GGF: Failed to create bootstrapper script at: " + bootstrap_path)
		return ""

	file.store_string(_get_bootstrapper_source())
	file.flush()
	file.close()

	return bootstrap_path


func _select_bootstrapper_path() -> String:
	# Prefer `res://ggf/GGF.gd`, but fall back if `res://ggf` is a file.
	if FileAccess.file_exists(_PREFERRED_BOOTSTRAP_DIR):
		return _FALLBACK_BOOTSTRAP_SCRIPT
	return _PREFERRED_BOOTSTRAP_SCRIPT


func _ensure_dir_exists(dir_path: String) -> bool:
	if DirAccess.dir_exists_absolute(dir_path):
		return true

	# If a file exists at the directory path, we can't create a directory there.
	if FileAccess.file_exists(dir_path):
		push_warning("GGF: Cannot create directory, file exists at: " + dir_path)
		return false

	var err := DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK:
		push_warning("GGF: Failed to create directory: %s (err=%s)" % [dir_path, err])
		return false
	return true


func _get_bootstrapper_source() -> String:
	return (
		'extends "res://addons/godot_game_framework/GGF.gd"\n'
		+ "\n"
		+ "## Project bootstrapper for Godot Game Framework (GGF).\n"
		+ "##\n"
		+ "## This file is generated automatically when enabling the GGF plugin.\n"
		+ "## You can safely customize it (override methods, add project-specific managers, etc.).\n"
		+ "\n"
	)


## Create a unified project config resource at `res://ggf_project_config.tres` (if missing).
func _ensure_project_config_resource() -> void:
	if ResourceLoader.exists(PROJECT_CONFIG_PATH):
		return

	# Load scripts directly (avoid reliance on global class_name scanning order).
	var project_config_script := (
		load("res://addons/godot_game_framework/core/types/GGFProjectConfig.gd") as Script
	)
	if project_config_script == null:
		push_warning("GGF: Failed to load GGFProjectConfig script")
		return

	var project_config := project_config_script.new() as Resource
	if project_config == null:
		push_warning("GGF: Failed to instantiate GGFProjectConfig")
		return

	# Link the framework default resources (host projects can override by editing this file).
	if ResourceLoader.exists(DEFAULT_SETTINGS_CONFIG):
		project_config.set("settings_config", load(DEFAULT_SETTINGS_CONFIG))
	if ResourceLoader.exists(DEFAULT_UI_CONFIG):
		project_config.set("ui_config", load(DEFAULT_UI_CONFIG))
	if ResourceLoader.exists(DEFAULT_STATES_CONFIG):
		project_config.set("state_machine_config", load(DEFAULT_STATES_CONFIG))

	var err := ResourceSaver.save(project_config, PROJECT_CONFIG_PATH)
	if err != OK:
		push_warning(
			"GGF: Failed to save project config at %s (err=%s)" % [PROJECT_CONFIG_PATH, err]
		)
		return

	print("GGF: Created default project config at: " + PROJECT_CONFIG_PATH)


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
		"res://ggf_project_config.tres",
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
