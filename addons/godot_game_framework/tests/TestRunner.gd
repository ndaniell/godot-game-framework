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

@export var auto_run_on_ready: bool = true
@export var stop_on_first_failure: bool = false
@export var discover_tests: bool = true  # Automatically discover test suites

var test_framework: Node
var test_registry: RefCounted
var _exit_code: int = 0

func _ready() -> void:
	# Wait for GGF to bootstrap managers
	var tree = get_tree()
	if tree:
		await tree.process_frame
		# Only wait one frame in headless mode
		if not DisplayServer.get_name() == "headless":
			await tree.process_frame
	
	# Initialize test framework
	var framework_script = load("res://addons/godot_game_framework/tests/TestFramework.gd")
	if framework_script == null:
		push_error("TestRunner: Failed to load TestFramework.gd")
		return
	test_framework = framework_script.new() as Node
	if test_framework != null:
		if test_framework.has_method("set"):
			test_framework.set("stop_on_first_failure", stop_on_first_failure)
		add_child(test_framework)
	
	# Initialize test registry
	var registry_script = load("res://addons/godot_game_framework/tests/TestRegistry.gd")
	if registry_script == null:
		push_error("TestRunner: Failed to load TestRegistry.gd")
		return
	test_registry = registry_script.new() as RefCounted
	
	# Register default test suites
	if discover_tests:
		_register_default_test_suites()

	if auto_run_on_ready:
		run_all_tests()

# Store reference to manager_tests for cleanup
var _manager_tests: RefCounted = null

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

	# Propagate failure to the process exit code (CI-friendly).
	_exit_code = 0
	var failed_val: Variant = results.get("failed", 0)
	if failed_val is int and failed_val > 0:
		_exit_code = 1
	else:
		var all_passed_val: Variant = results.get("all_passed", true)
		if all_passed_val is bool and not all_passed_val:
			_exit_code = 1
	# Quit immediately after tests complete (for headless mode)
	# Use call_deferred to ensure all output is flushed first
	call_deferred("_quit_tree")
	return results

func _quit_tree() -> void:
	_cleanup_resources()
	
	var tree = get_tree()
	if tree == null:
		return

	# Kill any in-flight tweens before quitting.
	# In headless runs, we can exit while short UI tweens are still active (e.g. notifications),
	# which triggers "ObjectDB instances leaked at exit".
	for tween in tree.get_processed_tweens():
		if tween != null and tween.is_valid():
			tween.kill()
	
	# Give queued frees/timers a chance to flush before exiting (helps avoid leak warnings).
	for _i in range(5):
		await tree.process_frame
	tree.quit(_exit_code)

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
func register_suite(suite_name: String, tests: Dictionary, setup: Callable = Callable(), teardown: Callable = Callable(), source: RefCounted = null) -> void:
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
		var teardown := Callable(test_suite, "teardown") if test_suite.has_method("teardown") else Callable()
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

