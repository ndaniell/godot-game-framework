@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GGF"
const AUTOLOAD_PATH := "res://addons/godot_game_framework/GGF.gd"


func _enter_tree() -> void:
	# Install a single autoload singleton that bootstraps all managers.
	# If the host project already has an autoload named GGF, do not override it.
	if _has_autoload(AUTOLOAD_NAME):
		push_warning(
			"Godot Game Framework: autoload '%s' already exists; not overriding." % AUTOLOAD_NAME
		)
		return
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _exit_tree() -> void:
	# Only remove the autoload if it still points at our path.
	# This avoids deleting a user-defined autoload with the same name.
	if not _has_autoload(AUTOLOAD_NAME):
		return
	var setting_key := "autoload/%s" % AUTOLOAD_NAME
	var val: Variant = ProjectSettings.get_setting(setting_key, null)
	if val is String and (val as String).ends_with(AUTOLOAD_PATH):
		remove_autoload_singleton(AUTOLOAD_NAME)


func _has_autoload(name: String) -> bool:
	var setting_key := "autoload/%s" % name
	return ProjectSettings.has_setting(setting_key)
