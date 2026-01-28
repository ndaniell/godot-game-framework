extends Node

## GGF - Godot Game Framework bootstrapper + service locator.
##
## This script is intended to be installed as a *single* autoload named `GGF`.
## On startup, it instantiates all framework managers (as children of this node)
## with prefixed names like `GGF_LogManager`, avoiding collisions in host projects.

signal ggf_ready

const MANAGER_GROUP_PREFIX := &"ggf.manager."
const MANAGER_NODE_PREFIX := "GGF_"

const _TYPE_SCRIPTS: Array[String] = [
	"res://addons/godot_game_framework/core/types/GameStateDefinition.gd",
	"res://addons/godot_game_framework/core/types/GameStateMachineConfig.gd",
	"res://addons/godot_game_framework/core/types/UIConfig.gd",
	"res://addons/godot_game_framework/core/types/SettingsConfig.gd",
]

var _managers: Dictionary = {}  # StringName -> Node
var _bootstrapped := false
var _is_ready := false


func _enter_tree() -> void:
	_bootstrap()
	# Ensure readiness binding happens even if host overrides `_bootstrap()`.
	call_deferred("_bind_ready_signal")


func _bootstrap() -> void:
	if _bootstrapped:
		return
	_bootstrapped = true

	# Ensure addon `class_name` types are registered before managers that reference them.
	# In headless/scripted runs, Godot may not have scanned addon global classes yet.
	_load_type_scripts()

	# Instantiate managers in a dependency-friendly order.
	# - Logging first (used by most others)
	# - Events early (used for cross-manager communication)
	_ensure_manager(
		&"LogManager", _load_script("res://addons/godot_game_framework/core/managers/LogManager.gd")
	)
	_ensure_manager(
		&"EventManager",
		_load_script("res://addons/godot_game_framework/core/managers/EventManager.gd")
	)
	_ensure_manager(
		&"NotificationManager",
		_load_script("res://addons/godot_game_framework/core/managers/NotificationManager.gd")
	)
	_ensure_manager(
		&"SettingsManager",
		_load_script("res://addons/godot_game_framework/core/managers/SettingsManager.gd")
	)
	_ensure_manager(
		&"AudioManager",
		_load_script("res://addons/godot_game_framework/core/managers/AudioManager.gd")
	)
	_ensure_manager(
		&"TimeManager",
		_load_script("res://addons/godot_game_framework/core/managers/TimeManager.gd")
	)
	_ensure_manager(
		&"ResourceManager",
		_load_script("res://addons/godot_game_framework/core/managers/ResourceManager.gd")
	)
	_ensure_manager(
		&"PoolManager",
		_load_script("res://addons/godot_game_framework/core/managers/PoolManager.gd")
	)
	_ensure_manager(
		&"SceneManager",
		_load_script("res://addons/godot_game_framework/core/managers/SceneManager.gd")
	)
	_ensure_manager(
		&"SaveManager",
		_load_script("res://addons/godot_game_framework/core/managers/SaveManager.gd")
	)
	_ensure_manager(
		&"NetworkManager",
		_load_script("res://addons/godot_game_framework/core/managers/NetworkManager.gd")
	)
	_ensure_manager(
		&"InputManager",
		_load_script("res://addons/godot_game_framework/core/managers/InputManager.gd")
	)
	_ensure_manager(
		&"GameManager",
		_load_script("res://addons/godot_game_framework/core/managers/GameManager.gd")
	)
	_ensure_manager(
		&"UIManager", _load_script("res://addons/godot_game_framework/core/managers/UIManager.gd")
	)

	_bind_ready_signal()


func is_ready() -> bool:
	return _is_ready


func _bind_ready_signal() -> void:
	# Emit `ggf_ready` deterministically once UIManager has finished initializing.
	# This is useful for starting state machines only after UI is available.
	if _is_ready:
		return

	var ui := get_manager(&"UIManager")
	if ui == null:
		call_deferred("_emit_ready")
		return

	if ui.has_method("is_ready"):
		var ready_val: Variant = ui.call("is_ready")
		if ready_val is bool and (ready_val as bool):
			call_deferred("_emit_ready")
			return

	if ui.has_signal("ui_ready"):
		var cb := Callable(self, "_emit_ready")
		if not ui.is_connected("ui_ready", cb):
			ui.connect("ui_ready", cb, CONNECT_ONE_SHOT)
	else:
		call_deferred("_emit_ready")


func _emit_ready() -> void:
	if _is_ready:
		return
	_is_ready = true
	ggf_ready.emit()


func _load_script(path: String) -> Script:
	if not ResourceLoader.exists(path):
		push_error("GGF: Manager script not found: %s" % path)
		return null
	return load(path) as Script


func _load_type_scripts() -> void:
	for p in _TYPE_SCRIPTS:
		if ResourceLoader.exists(p):
			# Load to register `class_name` globals.
			load(p)
		else:
			push_warning("GGF: Type script not found: %s" % p)


func _ensure_manager(key: StringName, script: Script) -> Node:
	if _managers.has(key):
		return _managers[key] as Node
	if script == null:
		return null
	if script.has_method("can_instantiate") and not script.can_instantiate():
		push_error("GGF: Manager script cannot be instantiated: %s" % String(key))
		return null

	var node := script.new() as Node
	if node == null:
		push_error("GGF: Failed to instantiate manager: %s" % String(key))
		return null

	node.name = MANAGER_NODE_PREFIX + String(key)
	add_child(node)
	node.add_to_group(MANAGER_GROUP_PREFIX + key)

	_managers[key] = node
	return node


## Generic manager lookup.
## Prefer this over hardcoded `/root/...` paths.
func get_manager(key: StringName) -> Node:
	var cached := _managers.get(key, null)
	if cached != null and is_instance_valid(cached):
		return cached as Node

	# Fallback: group-based lookup (in case something reloaded).
	var group := MANAGER_GROUP_PREFIX + key
	var nodes := get_tree().get_nodes_in_group(group)
	if nodes.size() > 0:
		var n := nodes[0] as Node
		if n != null:
			_managers[key] = n
			return n
	return null


## Convenience accessors (untyped Node returns to avoid requiring `class_name`).
func log() -> Node:
	return get_manager(&"LogManager")


func events() -> Node:
	return get_manager(&"EventManager")


func notifications() -> Node:
	return get_manager(&"NotificationManager")
