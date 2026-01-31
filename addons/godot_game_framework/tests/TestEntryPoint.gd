extends SceneTree

## TestEntryPoint
##
## Godot CLI entrypoint for running framework tests in headless mode.
##
## Why this exists:
## - `TestRunner.gd` extends `Node`, but `godot --script` expects an entrypoint script
##   that can act as the main loop (commonly `extends SceneTree`).
## - This script boots the scene tree, adds `TestRunner`, then quits with a CI-friendly
##   exit code when done.

var _test_runner: Node = null
var _done := false


func _initialize() -> void:
	var ggf_ok := await _ensure_ggf_bootstrapped()
	if not ggf_ok:
		quit(1)
		return

	# Give the autoload/managers a moment to bootstrap.
	# (When extending SceneTree, we *are* the tree.)
	await process_frame
	await process_frame

	var test_runner_script := load("res://addons/godot_game_framework/tests/TestRunner.gd")
	if test_runner_script == null:
		print("ERROR: Could not load TestRunner.gd")
		quit(1)
		return

	_test_runner = test_runner_script.new() as Node
	if _test_runner == null:
		print("ERROR: Could not instantiate TestRunner.gd")
		quit(1)
		return

	# In CLI runs, we manage quitting so we can free the runner cleanly first.
	if _test_runner.has_method("set"):
		_test_runner.set("quit_tree_on_complete", false)

	if _test_runner.has_signal("tests_finished"):
		_test_runner.connect(
			"tests_finished", Callable(self, "_on_tests_finished"), CONNECT_ONE_SHOT
		)

	root.add_child(_test_runner)
	test_runner_script = null

	# Safety net: time out and fail if something hangs.
	var max_wait := 30.0
	var elapsed := 0.0
	var delta := 1.0 / 60.0

	while (not _done) and elapsed < max_wait:
		await process_frame
		elapsed += delta

	# If tests finished, `_on_tests_finished()` will quit the tree.
	if _done:
		return

	# Timeout: attempt cleanup then force failure.
	if is_instance_valid(_test_runner):
		root.remove_child(_test_runner)
		_test_runner.queue_free()
		for _i in range(5):
			await process_frame
	_test_runner = null
	quit(1)


func _on_tests_finished(exit_code: int, _results: Dictionary) -> void:
	_done = true

	# Ensure the runner is freed before quitting, otherwise Godot may report its script
	# resource (`TestRunner.gd`) as "still in use" at process exit.
	if is_instance_valid(_test_runner):
		root.remove_child(_test_runner)
		_test_runner.queue_free()
		_test_runner = null

	# Kill in-flight tweens and let queued frees flush.
	for tween in get_processed_tweens():
		if tween != null and tween.is_valid():
			tween.kill()
	for _i in range(5):
		await process_frame

	quit(exit_code)


func _ensure_ggf_bootstrapped() -> bool:
	# Tests (e.g. ManagerTests) assume an autoload named `GGF` exists.
	# In CLI runs, host projects may not have configured autoloads, so we do it here.
	if not ProjectSettings.has_setting("autoload/GGF"):
		ProjectSettings.set_setting("autoload/GGF", "*res://addons/godot_game_framework/GGF.gd")

	# Ensure a `/root/GGF` node exists even if autoload initialization didn't run.
	var ggf_existing := root.get_node_or_null("GGF")
	if ggf_existing != null:
		# Give `_enter_tree()` / `_ready()` a chance to run.
		await process_frame
		await process_frame
		return _validate_ggf(ggf_existing)

	var autoload_val: Variant = ProjectSettings.get_setting(
		"autoload/GGF", "*res://addons/godot_game_framework/GGF.gd"
	)
	if not (autoload_val is String):
		print("ERROR: autoload/GGF is not a String")
		return false

	var autoload_path := autoload_val as String
	if autoload_path.begins_with("*"):
		autoload_path = autoload_path.substr(1)

	var ggf_script := load(autoload_path)
	if ggf_script == null:
		print("ERROR: Could not load GGF autoload script: " + autoload_path)
		return false

	var ggf := ggf_script.new() as Node
	if ggf == null:
		print("ERROR: Could not instantiate GGF from: " + autoload_path)
		return false

	ggf.name = "GGF"
	root.add_child(ggf)

	# Give `_enter_tree()` / `_ready()` a chance to run.
	await process_frame
	await process_frame
	return _validate_ggf(ggf)


func _validate_ggf(ggf: Node) -> bool:
	if ggf == null or not is_instance_valid(ggf):
		print("ERROR: GGF node is invalid")
		return false
	if not ggf.has_method("get_manager"):
		print("ERROR: GGF is missing get_manager(); wrong script?")
		return false

	# Consider bootstrap failed if any core manager is missing.
	var required := [
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
	for key in required:
		var m: Variant = ggf.call("get_manager", key)
		if m == null:
			print("ERROR: GGF bootstrap incomplete; missing manager: " + String(key))
			return false
	return true
