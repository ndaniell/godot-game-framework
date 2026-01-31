extends Node

## TestRunner - Generic test runner for the entire framework
##
## This script discovers and runs all registered tests.
## Tests can be registered from any part of the framework.
##
## Usage:
##   1. Attach this script to a Node in a scene
##   2. Register your test suites (or use pre-registered ones)
##   3. Run the scene
##   4. Tests will automatically execute
##
## Note: With the addon architecture, only `GGF` is an autoload. Managers are created by `GGF`.

signal tests_finished(exit_code: int, results: Dictionary)

const _GGF_SCRIPT: Script = preload("res://addons/godot_game_framework/GGF.gd")
const _TEST_FRAMEWORK_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/tests/TestFramework.gd"
)
const _TEST_REGISTRY_SCRIPT: Script = preload(
	"res://addons/godot_game_framework/tests/TestRegistry.gd"
)

@export var auto_run_on_ready: bool = true
@export var stop_on_first_failure: bool = false
@export var discover_tests: bool = true  # Automatically discover test suites
@export var quit_tree_on_complete: bool = true  # For headless runs

var test_framework: Node
var test_registry: RefCounted
var _exit_code: int = 0
var _last_results: Dictionary = {}

# Store reference to manager_tests for cleanup
var _manager_tests: RefCounted = null


func _ready() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		push_error("TestRunner: No SceneTree/root available to run tests")
		_exit_code = 1
		_last_results = {
			"total": 0,
			"passed": 0,
			"failed": 0,
			"all_passed": false,
			"message": "No SceneTree/root; tests skipped.",
		}
		call_deferred("_finish")
		return

	var ggf := get_node_or_null("/root/GGF")
	if ggf == null:
		# If there is no autoload, create a `GGF` instance for the test run.
		# We intentionally do NOT mutate ProjectSettings at runtime.
		if not _GGF_SCRIPT.can_instantiate():
			push_error("TestRunner: Preloaded GGF.gd is not instantiable (parse error?)")
			_exit_code = 1
			_last_results = {
				"total": 0,
				"passed": 0,
				"failed": 0,
				"all_passed": false,
				"message": "GGF script not instantiable; tests skipped.",
			}
			call_deferred("_finish")
			return

		ggf = _GGF_SCRIPT.new() as Node
		if ggf == null:
			push_error("TestRunner: Failed to instantiate GGF from preloaded script")
			_exit_code = 1
			_last_results = {
				"total": 0,
				"passed": 0,
				"failed": 0,
				"all_passed": false,
				"message": "GGF instantiation failed; tests skipped.",
			}
			call_deferred("_finish")
			return

		ggf.name = "GGF"
		tree.root.add_child(ggf)

	# Give GGF `_enter_tree()` / `_ready()` a chance to run.
	await tree.process_frame
	await tree.process_frame

	# If GGF isn't ready yet, wait for its readiness signal.
	await _await_ggf_ready(ggf)

	if not _validate_ggf(ggf):
		# If GGF can't be brought up, don't run any tests (they assume managers exist).
		_exit_code = 1
		_last_results = {
			"total": 0,
			"passed": 0,
			"failed": 0,
			"all_passed": false,
			"message": "GGF failed to bootstrap; tests skipped.",
		}
		call_deferred("_finish")
		return

	# Wait for GGF to bootstrap managers
	if tree:
		await tree.process_frame
		# Only wait one frame in headless mode
		if DisplayServer.get_name() != "headless":
			await tree.process_frame

	# Avoid engine WARNING output during tests (AssetLib recommendation: no warnings).
	if ggf != null and ggf.has_method("get_manager"):
		var log_manager: Node = ggf.get_manager(&"LogManager") as Node
		if log_manager != null and log_manager.has_method("set"):
			log_manager.set("emit_engine_warnings", false)

	# Initialize test framework
	test_framework = _TEST_FRAMEWORK_SCRIPT.new() as Node
	if test_framework != null:
		if test_framework.has_method("set"):
			test_framework.set("stop_on_first_failure", stop_on_first_failure)
		add_child(test_framework)

	# Initialize test registry
	test_registry = _TEST_REGISTRY_SCRIPT.new() as RefCounted

	# Register default test suites
	if discover_tests:
		_register_default_test_suites()

	if auto_run_on_ready:
		run_all_tests()


func _await_ggf_ready(ggf: Node) -> void:
	if ggf == null or not is_instance_valid(ggf):
		return

	# Prefer an immediate readiness check to avoid hanging.
	if ggf.has_method("is_ready"):
		var ready_val: Variant = ggf.call("is_ready")
		if ready_val is bool and (ready_val as bool):
			return

	# Otherwise, wait for the signal if present.
	if ggf.has_signal("ggf_ready"):
		await ggf.ggf_ready


func _validate_ggf(ggf: Node) -> bool:
	if ggf == null or not is_instance_valid(ggf):
		push_error("TestRunner: GGF node is invalid")
		return false
	# Ensure `GGF.gd` is at least referenced (preloaded) in test runs, and warn
	# if the autoload isn't using the framework's expected script.
	if ggf.get_script() != _GGF_SCRIPT:
		push_warning("TestRunner: /root/GGF is not using the expected GGF.gd script.")
	if not ggf.has_method("get_manager"):
		push_error("TestRunner: GGF is missing get_manager(); wrong script?")
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
			push_error("TestRunner: GGF bootstrap incomplete; missing manager: %s" % String(key))
			return false

	return true


## Register default test suites
## Override this to add your own test discovery
func _register_default_test_suites() -> void:
	# Register manager tests if present
	var manager_tests_path := "res://addons/godot_game_framework/tests/ManagerTests.gd"
	if ResourceLoader.exists(manager_tests_path):
		var manager_tests_script = load(manager_tests_path)
		if manager_tests_script != null:
			_manager_tests = manager_tests_script.new()
			if _manager_tests != null and _manager_tests.has_method("register_tests"):
				# Set test framework reference - use direct assignment
				_manager_tests.test_framework = test_framework
				_manager_tests.register_tests(test_registry)
			else:
				_register_manager_tests()
		else:
			_register_manager_tests()


## Register manager tests (fallback method)
func _register_manager_tests() -> void:
	# This will be populated by ManagerTests if it exists
	pass


## Run all registered tests
func run_all_tests() -> Dictionary:
	var results: Dictionary = test_framework.run_registered_suites(test_registry)
	_last_results = results

	# Propagate failure to the process exit code (CI-friendly).
	_exit_code = 0
	var failed_val: Variant = results.get("failed", 0)
	if failed_val is int and failed_val > 0:
		_exit_code = 1
	else:
		var all_passed_val: Variant = results.get("all_passed", true)
		if all_passed_val is bool and not all_passed_val:
			_exit_code = 1

	# Finish asynchronously after tests complete (flush output + cleanup).
	call_deferred("_finish")
	return results


func _quit_tree() -> void:
	# Backwards-compatible alias for older callers.
	_finish()


func _finish() -> void:
	_cleanup_resources()

	var tree = get_tree()
	if tree != null:
		# Kill any in-flight tweens before quitting.
		# In headless runs, we can exit while short UI tweens are still active (e.g. notifications),
		# which triggers "ObjectDB instances leaked at exit".
		for tween in tree.get_processed_tweens():
			if tween != null and tween.is_valid():
				tween.kill()

		# Give queued frees/timers a chance to flush before exiting (helps avoid leak warnings).
		for _i in range(5):
			await tree.process_frame

	tests_finished.emit(_exit_code, _last_results)

	if quit_tree_on_complete and tree != null:
		# Free this runner before quitting so the `TestRunner.gd` script isn't reported as "still in use".
		queue_free()
		tree.call_deferred("quit", _exit_code)


func _cleanup_resources() -> void:
	if _manager_tests != null:
		if _manager_tests.has_method("set"):
			_manager_tests.set("test_framework", null)
		_manager_tests = null

	if test_registry != null:
		if test_registry.has_method("clear"):
			test_registry.clear()
		test_registry = null

	if test_framework != null and is_instance_valid(test_framework):
		if test_framework.has_method("_cleanup"):
			test_framework._cleanup()
		if test_framework.get_parent() == self:
			remove_child(test_framework)
		test_framework.free()
		test_framework = null


## Register a test suite
func register_suite(
	suite_name: String,
	tests: Dictionary,
	setup: Callable = Callable(),
	teardown: Callable = Callable(),
	source: RefCounted = null
) -> void:
	test_registry.register_suite(suite_name, tests, setup, teardown, source)


## Register a test suite object
func register_suite_object(test_suite: RefCounted) -> void:
	if test_suite == null:
		push_error("TestRunner: Cannot register null test suite")
		return

	if test_suite.has_method("get_suite_name") and test_suite.has_method("get_tests"):
		test_suite.set("test_framework", test_framework)
		var tests: Dictionary = test_suite.get_tests()
		var setup := Callable(test_suite, "setup") if test_suite.has_method("setup") else Callable()
		var teardown := (
			Callable(test_suite, "teardown") if test_suite.has_method("teardown") else Callable()
		)
		test_registry.register_suite(test_suite.get_suite_name(), tests, setup, teardown)
	else:
		push_error("TestRunner: Test suite must have get_suite_name() and get_tests() methods")


## Run a specific test suite
func run_suite(suite_name: String) -> Dictionary:
	var suite: Dictionary = test_registry.get_suite(suite_name)
	if suite.is_empty():
		push_error("TestRunner: Suite not found: " + suite_name)
		return {}

	var tests: Dictionary = suite.get("tests", {})
	var setup: Callable = suite.get("setup", Callable())
	var teardown: Callable = suite.get("teardown", Callable())

	return test_framework.run_test_suite(suite_name, tests, setup, teardown)


## Get test registry (for external registration)
func get_registry() -> RefCounted:
	return test_registry


## Get test framework (for external use)
func get_framework() -> Node:
	return test_framework
