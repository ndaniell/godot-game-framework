extends Node

## GGF - Godot Game Framework bootstrapper + service locator.
##
## This script is intended to be installed as a *single* autoload named `GGF`.
## On startup, it instantiates all framework managers (as children of this node)
## with prefixed names like `GGF_LogManager`, avoiding collisions in host projects.

signal ggf_ready

const MANAGER_GROUP_PREFIX := &"ggf.manager."
const MANAGER_NODE_PREFIX := "GGF_"

# Preload BaseManager first - all other managers extend this
const BASE_MANAGER_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/core/managers/BaseManager.gd"
)

# Preload type scripts - ensures class_name types are registered in headless/scripted runs
const GAME_STATE_DEFINITION_TYPE: Script = preload(
	"res://addons/godot_game_framework/core/types/GameStateDefinition.gd"
)
const GAME_STATE_MACHINE_CONFIG_TYPE: Script = preload(
	"res://addons/godot_game_framework/core/types/GameStateMachineConfig.gd"
)
const UI_CONFIG_TYPE: Script = preload("res://addons/godot_game_framework/core/types/UIConfig.gd")
const SETTINGS_CONFIG_TYPE: Script = preload(
	"res://addons/godot_game_framework/core/types/SettingsConfig.gd"
)
const PROJECT_CONFIG_TYPE: Script = preload(
	"res://addons/godot_game_framework/core/types/GGFProjectConfig.gd"
)
const _PROJECT_CONFIG_PATH := "res://ggf_project_config.tres"

const _LOG_MANAGER_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/core/managers/LogManager.gd"
)
const _EVENT_MANAGER_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/core/managers/EventManager.gd"
)
const _NOTIFICATION_MANAGER_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/core/managers/NotificationManager.gd"
)
const _SETTINGS_MANAGER_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/core/managers/SettingsManager.gd"
)
const _AUDIO_MANAGER_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/core/managers/AudioManager.gd"
)
const _TIME_MANAGER_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/core/managers/TimeManager.gd"
)
const _RESOURCE_MANAGER_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/core/managers/ResourceManager.gd"
)
const _POOL_MANAGER_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/core/managers/PoolManager.gd"
)
const _SCENE_MANAGER_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/core/managers/SceneManager.gd"
)
const _SAVE_MANAGER_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/core/managers/SaveManager.gd"
)
const _NETWORK_MANAGER_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/core/managers/NetworkManager.gd"
)
const _INPUT_MANAGER_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/core/managers/InputManager.gd"
)
const _STATE_MANAGER_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/core/managers/StateManager.gd"
)
const _UI_MANAGER_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/core/managers/UIManager.gd"
)

var _managers: Dictionary = {}  # StringName -> Node
var _bootstrapped := false
var _is_ready := false
var _project_config: GGFProjectConfig = null


func _enter_tree() -> void:
	_load_project_config()
	_bootstrap()
	# Ensure readiness binding happens even if host overrides `_bootstrap()`.
	call_deferred("_bind_ready_signal")


## Load unified project configuration if it exists
func _load_project_config() -> void:
	if ResourceLoader.exists(_PROJECT_CONFIG_PATH):
		var config := load(_PROJECT_CONFIG_PATH) as GGFProjectConfig
		if config != null and config.validate():
			_project_config = config
			push_warning("GGF: Loaded project config from: " + _PROJECT_CONFIG_PATH)
		else:
			push_warning(
				"GGF: Project config exists but failed validation: " + _PROJECT_CONFIG_PATH
			)


## Get the loaded project configuration (or null if not present)
func get_project_config() -> GGFProjectConfig:
	return _project_config


func _bootstrap() -> void:
	if _bootstrapped:
		return
	_bootstrapped = true

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
	_ensure_manager(&"StateManager", _STATE_MANAGER_SCRIPT)
	_ensure_manager(&"UIManager", _UI_MANAGER_SCRIPT)

	_bind_ready_signal()


func is_ready() -> bool:
	return _is_ready


## Wait for a specific manager to be ready.
## All managers extend GGFBaseManager and emit a standard "manager_ready" signal.
## If the manager is already ready (is_manager_ready() returns true), returns immediately.
## Otherwise, waits for the manager's "manager_ready" signal.
## Usage: await GGF.await_ready(&"UIManager")
func await_ready(manager_key: StringName) -> void:
	var manager := get_manager(manager_key)
	if manager == null:
		push_warning("GGF.await_ready: Manager not found: %s" % String(manager_key))
		return

	# Check if manager has is_manager_ready() method and is already ready
	if manager.has_method("is_manager_ready"):
		var ready_val: Variant = manager.call("is_manager_ready")
		if ready_val is bool and (ready_val as bool):
			return  # Already ready

	# Wait for standard manager_ready signal
	if manager.has_signal("manager_ready"):
		await manager.manager_ready
	else:
		# Fallback: wait one frame if manager doesn't have standard signal
		push_warning(
			(
				"GGF.await_ready: Manager %s doesn't have standard manager_ready signal"
				% String(manager_key)
			)
		)
		await get_tree().process_frame


func _bind_ready_signal() -> void:
	# Emit `ggf_ready` deterministically once UIManager has finished initializing.
	# This is useful for starting state machines only after UI is available.
	if _is_ready:
		return

	var ui_manager := ui()
	if ui_manager == null:
		call_deferred("_emit_ready")
		return

	# Use standard is_manager_ready() and manager_ready signal
	if ui_manager.has_method("is_manager_ready"):
		var ready_val: Variant = ui_manager.call("is_manager_ready")
		if ready_val is bool and (ready_val as bool):
			call_deferred("_emit_ready")
			return

	if ui_manager.has_signal("manager_ready"):
		var cb := Callable(self, "_emit_ready")
		if not ui_manager.is_connected("manager_ready", cb):
			ui_manager.connect("manager_ready", cb, CONNECT_ONE_SHOT)
	else:
		call_deferred("_emit_ready")


func _emit_ready() -> void:
	if _is_ready:
		return
	_is_ready = true
	ggf_ready.emit()


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
func state() -> GGF_StateManager:
	return get_manager(&"StateManager") as GGF_StateManager


func ui() -> GGF_UIManager:
	return get_manager(&"UIManager") as GGF_UIManager


func network() -> GGF_NetworkManager:
	return get_manager(&"NetworkManager") as GGF_NetworkManager


func settings() -> GGF_SettingsManager:
	return get_manager(&"SettingsManager") as GGF_SettingsManager


func audio() -> GGF_AudioManager:
	return get_manager(&"AudioManager") as GGF_AudioManager


func time() -> GGF_TimeManager:
	return get_manager(&"TimeManager") as GGF_TimeManager


func scene() -> GGF_SceneManager:
	return get_manager(&"SceneManager") as GGF_SceneManager


func save() -> GGF_SaveManager:
	return get_manager(&"SaveManager") as GGF_SaveManager


func input() -> GGF_InputManager:
	return get_manager(&"InputManager") as GGF_InputManager


func resources() -> GGF_ResourceManager:
	return get_manager(&"ResourceManager") as GGF_ResourceManager


func pool() -> GGF_PoolManager:
	return get_manager(&"PoolManager") as GGF_PoolManager
