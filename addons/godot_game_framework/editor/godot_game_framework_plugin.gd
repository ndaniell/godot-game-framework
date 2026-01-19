@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GGF"


func _enter_tree() -> void:
	# This editor plugin does NOT install or modify autoloads.
	# The framework must be loaded via a project autoload named `GGF`.
	if not _has_autoload(AUTOLOAD_NAME):
		push_error(
			"Godot Game Framework: missing required autoload '%s'. "
			+ "Add an autoload named '%s' pointing to your bootstrapper (e.g. `res://src/ExampleGGF.gd`)."
			% [AUTOLOAD_NAME, AUTOLOAD_NAME]
		)
		return


func _exit_tree() -> void:
	# Intentionally do nothing: we never create/remove autoloads.
	return


func _has_autoload(autoload_name: String) -> bool:
	var setting_key := "autoload/%s" % autoload_name
	return ProjectSettings.has_setting(setting_key)
