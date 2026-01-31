extends Node

## GGF - Godot Game Framework bootstrapper + service locator.
##
## This script is intended to be installed as a *single* autoload named `GGF`.
## On startup, it instantiates all framework managers (as children of this node)
## with prefixed names like `GGF_LogManager`, avoiding collisions in host projects.

signal ggf_ready

const MANAGER_GROUP_PREFIX := &"ggf.manager."
const MANAGER_NODE_PREFIX := "GGF_"

const _TYPE_SCRIPTS: Array[Script] = [
	preload("res://addons/godot_game_framework/core/types/GameStateDefinition.gd"),
	preload("res://addons/godot_game_framework/core/types/GameStateMachineConfig.gd"),
	preload("res://addons/godot_game_framework/core/types/UIConfig.gd"),
	preload("res://addons/godot_game_framework/core/types/SettingsConfig.gd"),
]

const _LOG_MANAGER_SCRIPT := preload(
	"res://addons/godot_game_framework/core/managers/LogManager.gd"
)
const _EVENT_MANAGER_SCRIPT := preload(
	"res://addons/godot_game_framework/core/managers/EventManager.gd"
)
const _NOTIFICATION_MANAGER_SCRIPT := preload(
	"res://addons/godot_game_framework/core/managers/NotificationManager.gd"
)
const _SETTINGS_MANAGER_SCRIPT := preload(
	"res://addons/godot_game_framework/core/managers/SettingsManager.gd"
)
const _AUDIO_MANAGER_SCRIPT := preload(
	"res://addons/godot_game_framework/core/managers/AudioManager.gd"
)
const _TIME_MANAGER_SCRIPT := preload(
	"res://addons/godot_game_framework/core/managers/TimeManager.gd"
)
const _RESOURCE_MANAGER_SCRIPT := preload(
	"res://addons/godot_game_framework/core/managers/ResourceManager.gd"
)
const _POOL_MANAGER_SCRIPT := preload(
	"res://addons/godot_game_framework/core/managers/PoolManager.gd"
)
const _SCENE_MANAGER_SCRIPT := preload(
	"res://addons/godot_game_framework/core/managers/SceneManager.gd"
)
const _SAVE_MANAGER_SCRIPT := preload(
	"res://addons/godot_game_framework/core/managers/SaveManager.gd"
)
const _NETWORK_MANAGER_SCRIPT := preload(
	"res://addons/godot_game_framework/core/managers/NetworkManager.gd"
)
const _INPUT_MANAGER_SCRIPT := preload(
	"res://addons/godot_game_framework/core/managers/InputManager.gd"
)
const _GAME_MANAGER_SCRIPT := preload(
	"res://addons/godot_game_framework/core/managers/GameManager.gd"
)
const _UI_MANAGER_SCRIPT := preload("res://addons/godot_game_framework/core/managers/UIManager.gd")

# Type constants for typed accessors (avoids reliance on global class_name scanning).
const GAME_MANAGER_TYPE := _GAME_MANAGER_SCRIPT
const UI_MANAGER_TYPE := _UI_MANAGER_SCRIPT
const NETWORK_MANAGER_TYPE := _NETWORK_MANAGER_SCRIPT
const SETTINGS_MANAGER_TYPE := _SETTINGS_MANAGER_SCRIPT
const AUDIO_MANAGER_TYPE := _AUDIO_MANAGER_SCRIPT
const TIME_MANAGER_TYPE := _TIME_MANAGER_SCRIPT
const SCENE_MANAGER_TYPE := _SCENE_MANAGER_SCRIPT
const SAVE_MANAGER_TYPE := _SAVE_MANAGER_SCRIPT
const INPUT_MANAGER_TYPE := _INPUT_MANAGER_SCRIPT
const RESOURCE_MANAGER_TYPE := _RESOURCE_MANAGER_SCRIPT
const POOL_MANAGER_TYPE := _POOL_MANAGER_SCRIPT

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
	_ensure_manager(&"LogManager", _LOG_MANAGER_SCRIPT)
	_ensure_manager(&"EventManager", _EVENT_MANAGER_SCRIPT)
	_ensure_manager(&"NotificationManager", _NOTIFICATION_MANAGER_SCRIPT)
	_ensure_manager(&"SettingsManager", _SETTINGS_MANAGER_SCRIPT)
	_ensure_manager(&"AudioManager", _AUDIO_MANAGER_SCRIPT)
	_ensure_manager(&"TimeManager", _TIME_MANAGER_SCRIPT)
	_ensure_manager(&"ResourceManager", _RESOURCE_MANAGER_SCRIPT)
	_ensure_manager(&"PoolManager", _POOL_MANAGER_SCRIPT)
	_ensure_manager(&"SceneManager", _SCENE_MANAGER_SCRIPT)
	_ensure_manager(&"SaveManager", _SAVE_MANAGER_SCRIPT)
	_ensure_manager(&"NetworkManager", _NETWORK_MANAGER_SCRIPT)
	_ensure_manager(&"InputManager", _INPUT_MANAGER_SCRIPT)
	_ensure_manager(&"GameManager", _GAME_MANAGER_SCRIPT)
	_ensure_manager(&"UIManager", _UI_MANAGER_SCRIPT)

	_bind_ready_signal()


func is_ready() -> bool:
	return _is_ready


func _bind_ready_signal() -> void:
	# Emit `ggf_ready` deterministically once UIManager has finished initializing.
	# This is useful for starting state machines only after UI is available.
	if _is_ready:
		return

	var ui_manager := ui()
	if ui_manager == null:
		call_deferred("_emit_ready")
		return

	if ui_manager.has_method("is_ready"):
		var ready_val: Variant = ui_manager.call("is_ready")
		if ready_val is bool and (ready_val as bool):
			call_deferred("_emit_ready")
			return

	if ui_manager.has_signal("ui_ready"):
		var cb := Callable(self, "_emit_ready")
		if not ui_manager.is_connected("ui_ready", cb):
			ui_manager.connect("ui_ready", cb, CONNECT_ONE_SHOT)
	else:
		call_deferred("_emit_ready")


func _emit_ready() -> void:
	if _is_ready:
		return
	_is_ready = true
	ggf_ready.emit()


func _load_type_scripts() -> void:
	# Type scripts are preloaded above. This function remains to preserve behavior and
	# ensure these scripts are referenced in headless/scripted runs.
	for s in _TYPE_SCRIPTS:
		if s == null:
			push_warning("GGF: Preloaded type script is null (unexpected).")


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
	var cached: Variant = _managers.get(key, null)
	if cached != null and is_instance_valid(cached):
		return cached as Node

	# Fallback: group-based lookup (in case something reloaded).
	var group := MANAGER_GROUP_PREFIX + key
	if not is_inside_tree():
		return null
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


## Typed accessors - Better IDE autocomplete and type safety.
## Returns typed managers or null if not available.
func game() -> GAME_MANAGER_TYPE:
	return get_manager(&"GameManager") as GAME_MANAGER_TYPE


func ui() -> UI_MANAGER_TYPE:
	return get_manager(&"UIManager") as UI_MANAGER_TYPE


func network() -> NETWORK_MANAGER_TYPE:
	return get_manager(&"NetworkManager") as NETWORK_MANAGER_TYPE


func settings() -> SETTINGS_MANAGER_TYPE:
	return get_manager(&"SettingsManager") as SETTINGS_MANAGER_TYPE


func audio() -> AUDIO_MANAGER_TYPE:
	return get_manager(&"AudioManager") as AUDIO_MANAGER_TYPE


func time() -> TIME_MANAGER_TYPE:
	return get_manager(&"TimeManager") as TIME_MANAGER_TYPE


func scene() -> SCENE_MANAGER_TYPE:
	return get_manager(&"SceneManager") as SCENE_MANAGER_TYPE


func save() -> SAVE_MANAGER_TYPE:
	return get_manager(&"SaveManager") as SAVE_MANAGER_TYPE


func input() -> INPUT_MANAGER_TYPE:
	return get_manager(&"InputManager") as INPUT_MANAGER_TYPE


func resources() -> RESOURCE_MANAGER_TYPE:
	return get_manager(&"ResourceManager") as RESOURCE_MANAGER_TYPE


func pool() -> POOL_MANAGER_TYPE:
	return get_manager(&"PoolManager") as POOL_MANAGER_TYPE
