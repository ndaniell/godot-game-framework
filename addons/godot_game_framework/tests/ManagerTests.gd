extends RefCounted

## ManagerTests - Minimal test suite for addon managers
##
## Managers are created by the single autoload `GGF`. Tests should access them via `GGF.get_manager(...)`.

var test_framework: Node

func _get_framework() -> Node:
	return test_framework

func _m(key: StringName) -> Node:
	return GGF.get_manager(key)

func register_tests(registry: RefCounted) -> void:
	if registry == null:
		push_error("ManagerTests: Cannot register tests with null registry")
		return

	registry.register_suite("CoreManagers", {
		"GGF exists": Callable(self, "test_ggf_exists"),
		"LogManager exists": Callable(self, "test_logmanager_exists"),
		"EventManager exists": Callable(self, "test_eventmanager_exists"),
		"AudioManager exists": Callable(self, "test_audiomanager_exists"),
		"GameManager exists": Callable(self, "test_gamemanager_exists"),
		"SaveManager exists": Callable(self, "test_savemanager_exists"),
		"SceneManager exists": Callable(self, "test_scenemanager_exists"),
		"UIManager exists": Callable(self, "test_uimanager_exists"),
		"SettingsManager exists": Callable(self, "test_settingsmanager_exists"),
		"TimeManager exists": Callable(self, "test_timemanager_exists"),
		"ResourceManager exists": Callable(self, "test_resourcemanager_exists"),
		"PoolManager exists": Callable(self, "test_poolmanager_exists"),
		"NetworkManager exists": Callable(self, "test_networkmanager_exists"),
		"NotificationManager exists": Callable(self, "test_notificationmanager_exists"),
	}, Callable(), Callable(), self)

	registry.register_suite("Smoke", {
		"Audio volume set/clamp": Callable(self, "test_audio_volume_set_clamp"),
		"Game state transitions": Callable(self, "test_game_state_transitions"),
		"Event emit/subscribe": Callable(self, "test_event_emit_subscribe"),
		"TimeManager timers": Callable(self, "test_time_timer_create_remove"),
		"NetworkManager offline state": Callable(self, "test_network_offline_state"),
	}, Callable(), Callable(), self)

func test_ggf_exists() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(GGF, "GGF autoload should exist")

func test_logmanager_exists() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(_m(&"LogManager"), "LogManager should exist")

func test_eventmanager_exists() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(_m(&"EventManager"), "EventManager should exist")

func test_audiomanager_exists() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(_m(&"AudioManager"), "AudioManager should exist")

func test_gamemanager_exists() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(_m(&"GameManager"), "GameManager should exist")

func test_savemanager_exists() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(_m(&"SaveManager"), "SaveManager should exist")

func test_scenemanager_exists() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(_m(&"SceneManager"), "SceneManager should exist")

func test_uimanager_exists() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(_m(&"UIManager"), "UIManager should exist")

func test_settingsmanager_exists() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(_m(&"SettingsManager"), "SettingsManager should exist")

func test_timemanager_exists() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(_m(&"TimeManager"), "TimeManager should exist")

func test_resourcemanager_exists() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(_m(&"ResourceManager"), "ResourceManager should exist")

func test_poolmanager_exists() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(_m(&"PoolManager"), "PoolManager should exist")

func test_networkmanager_exists() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(_m(&"NetworkManager"), "NetworkManager should exist")

func test_notificationmanager_exists() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(_m(&"NotificationManager"), "NotificationManager should exist")

func test_audio_volume_set_clamp() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	var audio := _m(&"AudioManager")
	if audio == null:
		return false

	var original_master: float = audio.master_volume
	audio.set_master_volume(0.7)
	var ok: bool = framework.assert_almost_equal(audio.master_volume, 0.7, 0.01, "master_volume should update")

	audio.set_master_volume(2.0)
	ok = framework.assert_almost_equal(audio.master_volume, 1.0, 0.01, "master_volume should clamp to 1.0") and ok
	audio.set_master_volume(-1.0)
	ok = framework.assert_almost_equal(audio.master_volume, 0.0, 0.01, "master_volume should clamp to 0.0") and ok

	audio.set_master_volume(original_master)
	return ok

func test_game_state_transitions() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	var gm := _m(&"GameManager")
	if gm == null:
		return false

	# Ensure state definitions loaded (may be empty if resource missing).
	var states: Array = gm.get_all_states()
	if states.is_empty():
		return framework.assert_true(false, "Expected GameManager states to be loaded")

	var original: String = gm.current_state
	gm.change_state("PLAYING")
	var ok: bool = framework.assert_equal(gm.current_state, "PLAYING", "Should transition to PLAYING")
	gm.change_state(original)
	return ok

var _event_received := false

func _on_test_event(_data: Dictionary) -> void:
	_event_received = true

func test_event_emit_subscribe() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	var ev := _m(&"EventManager")
	if ev == null:
		return false

	_event_received = false
	var cb := Callable(self, "_on_test_event")
	ev.subscribe("ggf_test_event", cb)
	ev.emit("ggf_test_event", {"x": 1})
	ev.unsubscribe("ggf_test_event", cb)

	return framework.assert_true(_event_received, "Expected event callback to run")

func test_time_timer_create_remove() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	var tm := _m(&"TimeManager")
	if tm == null:
		return false

	tm.create_timer("ggf_test_timer", 1.0, false)
	var ok: bool = framework.assert_true(tm.timer_exists("ggf_test_timer"), "Timer should exist after create_timer")
	tm.remove_timer("ggf_test_timer")
	ok = framework.assert_false(tm.timer_exists("ggf_test_timer"), "Timer should not exist after remove_timer") and ok
	return ok

func test_network_offline_state() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	var nm := _m(&"NetworkManager")
	if nm == null:
		return false

	nm.disconnect_from_game()
	var ok: bool = framework.assert_false(nm.is_network_connected(), "Should be offline")
	ok = framework.assert_false(nm.is_host(), "Should not be host while offline") and ok
	return ok

