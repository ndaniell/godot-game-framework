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

	registry.register_suite("Bootstrap", {
		"Managers are prefixed + grouped": Callable(self, "test_bootstrap_names_and_groups"),
		"Manager scripts expose GGF_* global names": Callable(self, "test_manager_script_global_names"),
	}, Callable(), Callable(), self)

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
		"Event unsubscribe": Callable(self, "test_event_unsubscribe"),
		"Save roundtrip + delete": Callable(self, "test_save_roundtrip_delete"),
		"Resource cache + unload": Callable(self, "test_resource_cache_unload"),
		"Pool exhausted (no auto-expand) + reuse": Callable(self, "test_pool_exhausted_reuse"),
		"Scene preload + load/unload": Callable(self, "test_scene_preload_load_unload"),
		"UI register/show/hide": Callable(self, "test_ui_register_show_hide"),
		"Notification show/hide": Callable(self, "test_notification_show_hide"),
		"TimeManager timers": Callable(self, "test_time_timer_create_remove"),
		"Game pause/unpause": Callable(self, "test_game_pause_unpause"),
		"NetworkManager offline state": Callable(self, "test_network_offline_state"),
	}, Callable(), Callable(), self)

func test_bootstrap_names_and_groups() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false

	var keys: Array[StringName] = [
		&"LogManager",
		&"EventManager",
		&"NotificationManager",
		&"SettingsManager",
		&"AudioManager",
		&"TimeManager",
		&"ResourceManager",
		&"PoolManager",
		&"SceneManager",
		&"SaveManager",
		&"NetworkManager",
		&"InputManager",
		&"GameManager",
		&"UIManager",
	]

	var ok := true
	for key in keys:
		var n := _m(key)
		ok = framework.assert_not_null(n, "Expected manager to exist: %s" % String(key)) and ok
		if n == null:
			continue

		ok = framework.assert_equal(n.name, "GGF_" + String(key), "Expected prefixed node name for %s" % String(key)) and ok

		var group := "ggf.manager." + String(key)
		ok = framework.assert_true(n.is_in_group(group), "Expected %s in group %s" % [n.name, group]) and ok

	return ok

func test_manager_script_global_names() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false

	var expected: Dictionary = {
		&"AudioManager": "GGF_AudioManager",
		&"EventManager": "GGF_EventManager",
		&"GameManager": "GGF_GameManager",
		&"InputManager": "GGF_InputManager",
		&"LogManager": "GGF_LogManager",
		&"NetworkManager": "GGF_NetworkManager",
		&"NotificationManager": "GGF_NotificationManager",
		&"PoolManager": "GGF_PoolManager",
		&"ResourceManager": "GGF_ResourceManager",
		&"SaveManager": "GGF_SaveManager",
		&"SceneManager": "GGF_SceneManager",
		&"SettingsManager": "GGF_SettingsManager",
		&"TimeManager": "GGF_TimeManager",
		&"UIManager": "GGF_UIManager",
	}

	var ok := true
	for key in expected.keys():
		var n := _m(key)
		ok = framework.assert_not_null(n, "Expected manager to exist: %s" % String(key)) and ok
		if n == null:
			continue

		var script := n.get_script()
		ok = framework.assert_not_null(script, "Expected %s to have a script" % String(key)) and ok
		if script == null:
			continue

		# `Script.get_global_name()` returns the registered `class_name` (or "" if none).
		var global_name := ""
		if script.has_method("get_global_name"):
			global_name = script.get_global_name()
		ok = framework.assert_equal(global_name, expected[key], "Expected global class for %s" % String(key)) and ok

	return ok

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

var _event_received_count := 0

func _on_test_event_counted(_data: Dictionary) -> void:
	_event_received_count += 1

func test_event_unsubscribe() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	var ev := _m(&"EventManager")
	if ev == null:
		return false

	_event_received_count = 0
	var cb := Callable(self, "_on_test_event_counted")
	ev.subscribe("ggf_test_event_unsub", cb)
	ev.emit("ggf_test_event_unsub", {})
	ev.unsubscribe("ggf_test_event_unsub", cb)
	ev.emit("ggf_test_event_unsub", {})

	return framework.assert_equal(_event_received_count, 1, "Expected callback to run once before unsubscribe")

func test_save_roundtrip_delete() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	var sm := _m(&"SaveManager")
	if sm == null:
		return false

	var slot := 9
	# Ensure clean slate (ignore result).
	sm.delete_save(slot)

	var metadata := {"test_key": "test_value", "slot": slot}
	var ok: bool = framework.assert_true(sm.save_game(slot, metadata), "Expected save_game to succeed")
	ok = framework.assert_true(sm.save_exists(slot), "Expected save file to exist after save") and ok

	ok = framework.assert_true(sm.load_game(slot), "Expected load_game to succeed") and ok
	var loaded: Dictionary = sm.get_current_save_data()
	ok = framework.assert_equal(loaded.get("slot", -1), slot, "Expected loaded slot to match") and ok
	ok = framework.assert_equal((loaded.get("metadata", {}) as Dictionary).get("test_key", ""), "test_value", "Expected metadata to roundtrip") and ok

	ok = framework.assert_true(sm.delete_save(slot), "Expected delete_save to succeed") and ok
	ok = framework.assert_false(sm.save_exists(slot), "Expected save file to be removed after delete") and ok
	return ok

func test_resource_cache_unload() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	var rm := _m(&"ResourceManager")
	if rm == null:
		return false

	var path := "res://addons/godot_game_framework/resources/data/game_states.tres"
	rm.enable_caching = true

	var r1: Resource = rm.load_resource(path, true)
	var ok: bool = framework.assert_not_null(r1, "Expected resource to load")
	var r2: Resource = rm.load_resource(path, true)
	ok = framework.assert_true(r1 == r2, "Expected cached resource instance to be reused") and ok

	ok = framework.assert_equal(rm.get_ref_count(path), 2, "Expected ref count to increment on cache hits") and ok

	# First unload decrements ref count but should keep cached.
	var unloaded: bool = rm.unload_resource(path, false)
	ok = framework.assert_false(unloaded, "Expected unload to keep resource cached while referenced") and ok
	ok = framework.assert_equal(rm.get_ref_count(path), 1, "Expected ref count to decrement") and ok

	# Second unload should remove from cache.
	unloaded = rm.unload_resource(path, false)
	ok = framework.assert_true(unloaded, "Expected unload to remove resource when ref count reaches 0") and ok
	ok = framework.assert_false(rm.is_resource_cached(path), "Expected resource to no longer be cached") and ok
	ok = framework.assert_equal(rm.get_ref_count(path), 0, "Expected ref count cleared") and ok

	return ok

func test_pool_exhausted_reuse() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	var pm := _m(&"PoolManager")
	if pm == null:
		return false

	var tree := GGF.get_tree()
	var root: Node = tree.current_scene
	if root == null:
		root = tree.root
	if root == null:
		return framework.assert_true(false, "Expected SceneTree.root to exist for pooling test")

	var pool_name := "ggf_test_pool"

	# Build a simple PackedScene at runtime.
	var proto := Node3D.new()
	var packed := PackedScene.new()
	var pack_ok := packed.pack(proto)
	proto.free()
	if pack_ok != OK:
		return framework.assert_true(false, "Failed to pack test scene")

	# Ensure clean slate.
	pm.remove_pool(pool_name)

	pm.auto_expand_pools = false
	pm.max_pool_size = 1
	var created: bool = pm.create_pool(pool_name, packed, 1)
	var ok: bool = framework.assert_true(created, "Expected pool to be created")

	var parent := Node3D.new()
	root.add_child(parent)

	var a: Node = pm.spawn(pool_name, Vector3.ZERO, parent)
	ok = framework.assert_not_null(a, "Expected first spawn to succeed") and ok
	var b: Node = pm.spawn(pool_name, Vector3.ZERO, parent)
	ok = framework.assert_true(b == null, "Expected second spawn to fail when exhausted and auto-expand disabled") and ok

	ok = framework.assert_true(pm.despawn(pool_name, a), "Expected despawn to succeed") and ok
	var c: Node = pm.spawn(pool_name, Vector3.ZERO, parent)
	ok = framework.assert_not_null(c, "Expected spawn after despawn to succeed") and ok
	if a != null and c != null:
		ok = framework.assert_equal(a.get_instance_id(), c.get_instance_id(), "Expected pooled object to be reused") and ok

	pm.despawn(pool_name, c)
	parent.queue_free()
	pm.remove_pool(pool_name)
	return ok

func test_scene_preload_load_unload() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	var sm := _m(&"SceneManager")
	if sm == null:
		return false

	var path := "res://addons/godot_game_framework/tests/TestScene.tscn"
	var packed: PackedScene = sm.preload_scene(path)
	var ok: bool = framework.assert_not_null(packed, "Expected preload_scene to return a PackedScene")
	ok = framework.assert_true(sm.is_scene_preloaded(path), "Expected scene to be marked preloaded") and ok
	ok = framework.assert_true(sm.unpreload_scene(path), "Expected unpreload_scene to succeed") and ok
	ok = framework.assert_false(sm.is_scene_preloaded(path), "Expected scene to no longer be preloaded") and ok

	# Load without making current.
	var tree := GGF.get_tree()
	var root: Node = tree.current_scene
	if root == null:
		root = tree.root
	if root == null:
		return framework.assert_true(false, "Expected SceneTree.root to exist for load_scene test")

	var parent := Node.new()
	root.add_child(parent)

	var inst: Node = sm.load_scene(path, parent, false)
	ok = framework.assert_not_null(inst, "Expected load_scene to instance") and ok
	if inst != null:
		ok = framework.assert_true(inst.get_parent() == parent, "Expected loaded scene to be parented under provided node") and ok

	ok = framework.assert_true(sm.unload_scene(path, true), "Expected unload_scene to succeed") and ok
	parent.queue_free()
	return ok

func test_ui_register_show_hide() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	var ui := _m(&"UIManager")
	if ui == null:
		return false

	var element_name := "ggf_test_ui"
	ui.unregister_ui_element(element_name)

	var ctrl := Control.new()
	ctrl.visible = false
	ui.register_ui_element(element_name, ctrl, ui.ui_layer)
	ui.show_ui_element(element_name)
	var ok: bool = framework.assert_true(ctrl.visible, "Expected UI element to become visible after show_ui_element")
	ui.hide_ui_element(element_name, false)
	ok = framework.assert_false(ctrl.visible, "Expected UI element to be hidden after hide_ui_element") and ok

	ui.unregister_ui_element(element_name)
	ctrl.queue_free()
	return ok

func test_notification_show_hide() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	var nm := _m(&"NotificationManager")
	if nm == null:
		return false

	var id: String = nm.show_info("ggf test notification", 0.5)
	var ok: bool = framework.assert_true(not id.is_empty(), "Expected show_info to return a notification id")
	if not id.is_empty():
		ok = framework.assert_true(nm.hide_notification(id), "Expected hide_notification to succeed") and ok
	return ok

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

func test_game_pause_unpause() -> bool:
	var framework := _get_framework()
	if framework == null:
		return false
	var gm := _m(&"GameManager")
	if gm == null:
		return false

	# Preserve original state.
	var original: bool = gm.is_paused
	gm.pause_game()
	var ok: bool = framework.assert_true(gm.is_paused, "Expected pause_game to set is_paused")
	gm.unpause_game()
	ok = framework.assert_false(gm.is_paused, "Expected unpause_game to clear is_paused") and ok

	# Restore original (best-effort).
	if original:
		gm.pause_game()
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

