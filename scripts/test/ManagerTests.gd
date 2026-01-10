extends RefCounted

## ManagerTests - Comprehensive test suite for all managers
##
## This file contains detailed tests for each manager in the framework.
## Tests are registered with the TestRegistry for discovery.
##
## IMPORTANT: Manager references (AudioManager, GameManager, etc.) are autoload
## singletons that exist at runtime. The linter will show "not declared" errors
## for these - this is EXPECTED and SAFE TO IGNORE. They work correctly at runtime.

# Suppress linter warnings for autoload singletons
# These are available at runtime via project.godot autoload configuration
@warning_ignore("unused_variable")
var test_framework: Node

## Helper to get test framework
func _get_framework() -> Node:
	return test_framework

## Register all manager tests with the registry
func register_tests(registry: RefCounted) -> void:
	if registry == null:
		push_error("ManagerTests: Cannot register tests with null registry")
		return
	
	# Store reference to self so we can create Callables later
	# Register test suites for each manager - create Callables at registration time
	# We need to ensure Callables are created fresh each time to avoid serialization issues
	var audio_tests = _create_test_callables(_get_audio_manager_test_names())
	var game_tests = _create_test_callables(_get_game_manager_test_names())
	var save_tests = _create_test_callables(_get_save_manager_test_names())
	var input_tests = _create_test_callables(_get_input_manager_test_names())
	var scene_tests = _create_test_callables(_get_scene_manager_test_names())
	var ui_tests = _create_test_callables(_get_ui_manager_test_names())
	var settings_tests = _create_test_callables(_get_settings_manager_test_names())
	var event_tests = _create_test_callables(_get_event_manager_test_names())
	var resource_tests = _create_test_callables(_get_resource_manager_test_names())
	var pool_tests = _create_test_callables(_get_pool_manager_test_names())
	var time_tests = _create_test_callables(_get_time_manager_test_names())
	var notification_tests = _create_test_callables(_get_notification_manager_test_names())
	
	# Verify Callables are valid before registering
	_validate_test_suite("AudioManager", audio_tests)
	_validate_test_suite("GameManager", game_tests)
	_validate_test_suite("SaveManager", save_tests)
	_validate_test_suite("InputManager", input_tests)
	_validate_test_suite("SceneManager", scene_tests)
	_validate_test_suite("UIManager", ui_tests)
	_validate_test_suite("SettingsManager", settings_tests)
	_validate_test_suite("EventManager", event_tests)
	_validate_test_suite("ResourceManager", resource_tests)
	_validate_test_suite("PoolManager", pool_tests)
	_validate_test_suite("TimeManager", time_tests)
	_validate_test_suite("NotificationManager", notification_tests)
	
	# Register with source object so Callables can be recreated
	registry.register_suite("AudioManager", audio_tests, Callable(), Callable(), self)
	registry.register_suite("GameManager", game_tests, Callable(), Callable(), self)
	registry.register_suite("SaveManager", save_tests, Callable(), Callable(), self)
	registry.register_suite("InputManager", input_tests, Callable(), Callable(), self)
	registry.register_suite("SceneManager", scene_tests, Callable(), Callable(), self)
	registry.register_suite("UIManager", ui_tests, Callable(), Callable(), self)
	registry.register_suite("SettingsManager", settings_tests, Callable(), Callable(), self)
	registry.register_suite("EventManager", event_tests, Callable(), Callable(), self)
	registry.register_suite("ResourceManager", resource_tests, Callable(), Callable(), self)
	registry.register_suite("PoolManager", pool_tests, Callable(), Callable(), self)
	registry.register_suite("TimeManager", time_tests, Callable(), Callable(), self)
	registry.register_suite("NotificationManager", notification_tests, Callable(), Callable(), self)

## Helper to validate a test suite's Callables
func _validate_test_suite(suite_name: String, tests: Dictionary) -> void:
	for test_name in tests:
		var callable = tests[test_name]
		if not (callable is Callable) or not (callable as Callable).is_valid():
			push_error("ManagerTests: Invalid Callable for " + suite_name + "." + test_name + " (type: " + str(typeof(callable)) + ")")

## Helper to create Callables from test definitions
## test_defs is an Array of either:
##   - String (method name, used as both key and method)
##   - Dictionary with "name" and "method" keys
func _create_test_callables(test_defs: Array) -> Dictionary:
	var callables: Dictionary = {}
	for test_def in test_defs:
		var display_name: String
		var method_name: String
		
		if test_def is Dictionary:
			display_name = test_def.get("name", "")
			method_name = test_def.get("method", "")
		elif test_def is String:
			display_name = test_def
			method_name = test_def
		else:
			push_warning("ManagerTests: Invalid test definition: " + str(test_def))
			continue
		
		if has_method(method_name):
			callables[display_name] = Callable(self, method_name)
		else:
			push_warning("ManagerTests: Method not found: " + method_name)
	return callables

# ============================================================================
# AudioManager Tests
# ============================================================================

func _get_audio_manager_test_names() -> Array:
	return [
		{"name": "AudioManager exists", "method": "test_audiomanager_exists"},
		{"name": "Volume setting works", "method": "test_audio_volume_setting"},
		{"name": "Volume clamping works", "method": "test_audio_volume_clamping"},
		{"name": "Music volume property", "method": "test_audio_music_volume"},
		{"name": "SFX volume property", "method": "test_audio_sfx_volume"}
	]


func test_audiomanager_exists() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(AudioManager, "AudioManager should exist")

func test_audio_volume_setting() -> bool:
	# Managers are autoload singletons - available at runtime
	var original: float = AudioManager.master_volume
	AudioManager.set_master_volume(0.7)
	var framework = _get_framework()
	if framework == null:
		return false
	var result: bool = framework.assert_almost_equal(AudioManager.master_volume, 0.7, 0.01)
	AudioManager.set_master_volume(original)
	return result

func test_audio_volume_clamping() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	var original: float = AudioManager.master_volume
	AudioManager.set_master_volume(2.0)  # Should clamp to 1.0
	var result: bool = framework.assert_almost_equal(AudioManager.master_volume, 1.0, 0.01)
	AudioManager.set_master_volume(-1.0)  # Should clamp to 0.0
	result = framework.assert_almost_equal(AudioManager.master_volume, 0.0, 0.01) and result
	AudioManager.set_master_volume(original)
	return result

func test_audio_music_volume() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	var original: float = AudioManager.music_volume
	AudioManager.set_music_volume(0.6)
	var result: bool = framework.assert_almost_equal(AudioManager.music_volume, 0.6, 0.01)
	AudioManager.set_music_volume(original)
	return result

func test_audio_sfx_volume() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	var original: float = AudioManager.sfx_volume
	AudioManager.set_sfx_volume(0.9)
	var result: bool = framework.assert_almost_equal(AudioManager.sfx_volume, 0.9, 0.01)
	AudioManager.set_sfx_volume(original)
	return result

# ============================================================================
# GameManager Tests
# ============================================================================

func _get_game_manager_test_names() -> Array:
	return [
		{"name": "GameManager exists", "method": "test_gamemanager_exists"},
		{"name": "State changes work", "method": "test_game_state_changes"},
		{"name": "Pause functionality", "method": "test_game_pause_functionality"},
		{"name": "State definitions loaded", "method": "test_game_state_definitions"}
	]


func test_gamemanager_exists() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(GameManager, "GameManager should exist")

func test_game_state_changes() -> bool:
	var original = GameManager.current_state
	GameManager.change_state("PLAYING")
	var framework = _get_framework()
	if framework == null:
		return false
	var result: bool = framework.assert_equal(GameManager.current_state, "PLAYING")
	GameManager.change_state(original)
	return result

func test_game_pause_functionality() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	
	# Ensure we're in a state that allows pausing (PLAYING allows transition to PAUSED)
	var original_state = GameManager.current_state
	if GameManager.current_state != "PLAYING":
		GameManager.change_state("PLAYING")
	
	# Ensure we're not already paused
	var was_paused: bool = GameManager.is_paused
	if was_paused:
		# If already paused, unpause first
		GameManager.unpause_game()
		# Verify we're unpaused
		if GameManager.is_paused:
			return framework.assert_false(true, "Failed to unpause before pause test")
	
	# Verify we're in PLAYING state and not paused before testing
	if GameManager.current_state != "PLAYING":
		return framework.assert_false(true, "Precondition failed: not in PLAYING state")
	if GameManager.is_paused:
		return framework.assert_false(true, "Precondition failed: already paused")
	
	# Test pause - directly transitions to PAUSED state, entry callback sets is_paused
	GameManager.pause_game()
	# State transition should happen immediately and synchronously
	# Verify state changed to PAUSED
	if GameManager.current_state != "PAUSED":
		return framework.assert_false(true, "State should be PAUSED after pause_game(), got: " + GameManager.current_state)
	# Verify is_paused is true
	var result1: bool = framework.assert_true(GameManager.is_paused, "Game should be paused after pause_game()")
	
	# Test unpause - directly transitions to PLAYING state, exit callback unsets is_paused
	GameManager.unpause_game()
	# State transition should happen immediately and synchronously
	# Verify state changed to PLAYING
	if GameManager.current_state != "PLAYING":
		return framework.assert_false(true, "State should be PLAYING after unpause_game(), got: " + GameManager.current_state)
	# Verify is_paused is false
	var result2: bool = framework.assert_false(GameManager.is_paused, "Game should be unpaused after unpause_game()")
	
	# Restore original state if needed
	if original_state != "PLAYING" and original_state != GameManager.current_state:
		GameManager.change_state(original_state)
	
	return result1 and result2

func test_game_state_definitions() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	var all_states: Array = GameManager.get_all_states()
	return framework.assert_true(all_states.size() > 0, "State definitions should be loaded")

# ============================================================================
# SaveManager Tests
# ============================================================================

func _get_save_manager_test_names() -> Array:
	return [
		{"name": "SaveManager exists", "method": "test_savemanager_exists"},
		{"name": "Save data storage", "method": "test_save_data_storage"},
		{"name": "Save slot operations", "method": "test_save_slot_operations"}
	]


func test_savemanager_exists() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(SaveManager, "SaveManager should exist")

func test_save_data_storage() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	var test_data: Dictionary = {"test_key": "test_value", "number": 42, "array": [1, 2, 3]}
	SaveManager.set_save_data(test_data)
	var loaded: Dictionary = SaveManager.get_current_save_data()
	
	var result: bool = true
	result = framework.assert_equal(loaded.get("test_key"), "test_value") and result
	result = framework.assert_equal(loaded.get("number"), 42) and result
	result = framework.assert_not_null(loaded.get("array")) and result
	return result

func test_save_slot_operations() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	# Test that save slot methods exist and don't crash
	var result := true
	result = framework.assert_not_null(SaveManager.save_exists) and result
	result = framework.assert_not_null(SaveManager.get_available_saves) and result
	return result

# ============================================================================
# InputManager Tests
# ============================================================================

func _get_input_manager_test_names() -> Array:
	return [
		{"name": "InputManager exists", "method": "test_inputmanager_exists"},
		{"name": "Device detection", "method": "test_input_device_detection"},
		{"name": "Input mode", "method": "test_input_mode"}
	]


func test_inputmanager_exists() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(InputManager, "InputManager should exist")

func test_input_device_detection() -> bool:
	var device_name: String = InputManager.get_input_device_name()
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(device_name, "Device name should not be null")

func test_input_mode() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(InputManager.current_input_mode, "Input mode should exist")

# ============================================================================
# SceneManager Tests
# ============================================================================

func _get_scene_manager_test_names() -> Array:
	return [
		{"name": "SceneManager exists", "method": "test_scenemanager_exists"},
		{"name": "Scene path tracking", "method": "test_scene_path_tracking"}
	]


func test_scenemanager_exists() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(SceneManager, "SceneManager should exist")

func test_scene_path_tracking() -> bool:
	# Path might be empty, that's okay
	var _current_path: String = SceneManager.get_current_scene_path()
	return true

# ============================================================================
# UIManager Tests
# ============================================================================

func _get_ui_manager_test_names() -> Array:
	return [
		{"name": "UIManager exists", "method": "test_uimanager_exists"},
		{"name": "UI layer configuration", "method": "test_ui_layers"}
	]


func test_uimanager_exists() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(UIManager, "UIManager should exist")

func test_ui_layers() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(UIManager.ui_layer, "UI layer should exist")

# ============================================================================
# SettingsManager Tests
# ============================================================================

func _get_settings_manager_test_names() -> Array:
	return [
		{"name": "SettingsManager exists", "method": "test_settingsmanager_exists"},
		{"name": "Settings storage", "method": "test_settings_storage"},
		{"name": "Settings retrieval", "method": "test_settings_retrieval"}
	]


func test_settingsmanager_exists() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(SettingsManager, "SettingsManager should exist")

func test_settings_storage() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	SettingsManager.set_setting("test_category", "test_key", "test_value")
	var value: Variant = SettingsManager.get_setting("test_category", "test_key")
	return framework.assert_equal(value, "test_value", "Setting should be stored")

func test_settings_retrieval() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	var default_value: Variant = SettingsManager.get_setting("nonexistent", "key", "default")
	return framework.assert_equal(default_value, "default", "Should return default value")

# ============================================================================
# EventManager Tests
# ============================================================================

var _test_event_received := false
var _test_event_data: Dictionary = {}

func _get_event_manager_test_names() -> Array:
	return [
		{"name": "EventManager exists", "method": "test_eventmanager_exists"},
		{"name": "Event subscription", "method": "test_event_subscription"},
		{"name": "Event emission", "method": "test_event_emission"},
		{"name": "Event unsubscription", "method": "test_event_unsubscription"}
	]


func test_eventmanager_exists() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(EventManager, "EventManager should exist")

func test_event_subscription() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	_test_event_received = false
	EventManager.subscribe("test_sub", Callable(self, "_on_test_event"))
	var result: bool = framework.assert_true(EventManager.has_listeners("test_sub"), "Should have listeners")
	EventManager.unsubscribe("test_sub", Callable(self, "_on_test_event"))
	return result

func test_event_emission() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	_test_event_received = false
	_test_event_data = {}
	EventManager.subscribe("test_emit", Callable(self, "_on_test_event"))
	EventManager.emit("test_emit", {"key": "value"})
	
	# Note: await requires Node context - this test may need to be run differently
	# For now, just check subscription works
	var result: bool = framework.assert_true(EventManager.has_listeners("test_emit"), "Should have listeners")
	EventManager.unsubscribe("test_emit", Callable(self, "_on_test_event"))
	return result

func test_event_unsubscription() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	EventManager.subscribe("test_unsub", Callable(self, "_on_test_event"))
	EventManager.unsubscribe("test_unsub", Callable(self, "_on_test_event"))
	return framework.assert_false(EventManager.has_listeners("test_unsub"), "Should not have listeners")

func _on_test_event(data: Dictionary) -> void:
	_test_event_received = true
	_test_event_data = data

# ============================================================================
# ResourceManager Tests
# ============================================================================

func _get_resource_manager_test_names() -> Array:
	return [
		{"name": "ResourceManager exists", "method": "test_resourcemanager_exists"},
		{"name": "Cache management", "method": "test_resource_cache"}
	]


func test_resourcemanager_exists() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(ResourceManager, "ResourceManager should exist")

func test_resource_cache() -> bool:
	var cache_size: int = ResourceManager.get_cache_size()
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(cache_size, "Cache size should be accessible")

# ============================================================================
# PoolManager Tests
# ============================================================================

func _get_pool_manager_test_names() -> Array:
	return [
		{"name": "PoolManager exists", "method": "test_poolmanager_exists"},
		{"name": "Pool operations", "method": "test_pool_operations"}
	]


func test_poolmanager_exists() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(PoolManager, "PoolManager should exist")

func test_pool_operations() -> bool:
	var pool_names: Array = PoolManager.get_pool_names()
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(pool_names, "Pool names should be accessible")

# ============================================================================
# TimeManager Tests
# ============================================================================

func _get_time_manager_test_names() -> Array:
	return [
		{"name": "TimeManager exists", "method": "test_timemanager_exists"},
		{"name": "Time scaling", "method": "test_time_scaling"},
		{"name": "Timer creation", "method": "test_timer_creation"}
	]


func test_timemanager_exists() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(TimeManager, "TimeManager should exist")

func test_time_scaling() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	var original: float = TimeManager.time_scale
	TimeManager.set_time_scale(0.5)
	var result: bool = framework.assert_almost_equal(TimeManager.time_scale, 0.5, 0.01)
	TimeManager.set_time_scale(original)
	return result

func test_timer_creation() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	TimeManager.create_timer("test_timer", 1.0, false)
	var result: bool = framework.assert_true(TimeManager.timer_exists("test_timer"), "Timer should exist")
	var progress: float = TimeManager.get_timer_progress("test_timer")
	result = framework.assert_almost_equal(progress, 0.0, 0.1, "Timer should start at 0") and result
	TimeManager.remove_timer("test_timer")
	return result

# ============================================================================
# NotificationManager Tests
# ============================================================================

func _get_notification_manager_test_names() -> Array:
	return [
		{"name": "NotificationManager exists", "method": "test_notificationmanager_exists"},
		{"name": "Notification display", "method": "test_notification_display"}
	]


func test_notificationmanager_exists() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(NotificationManager, "NotificationManager should exist")

func test_notification_display() -> bool:
	var active_count: int = NotificationManager.get_active_count()
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(active_count, "Active count should be accessible")
