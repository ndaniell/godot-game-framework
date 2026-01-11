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

# Note: Managers are autoload singletons, so they're available at runtime
# but may show linter warnings - this is expected

@export var auto_run_on_ready: bool = true
@export var stop_on_first_failure: bool = false
@export var discover_tests: bool = true  # Automatically discover test suites

var test_framework: Node
var test_registry: RefCounted

func _ready() -> void:
	# Wait for all managers to be ready
	var tree = get_tree()
	if tree:
		await tree.process_frame
		# Only wait one frame in headless mode
		if not DisplayServer.get_name() == "headless":
			await tree.process_frame
	
	# Initialize test framework
	var framework_script = load("res://scripts/test/TestFramework.gd")
	if framework_script == null:
		push_error("TestRunner: Failed to load TestFramework.gd")
		return
	test_framework = framework_script.new() as Node
	if test_framework != null:
		if test_framework.has_method("set"):
			test_framework.set("stop_on_first_failure", stop_on_first_failure)
		add_child(test_framework)
	
	# Initialize test registry
	var registry_script = load("res://scripts/test/TestRegistry.gd")
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
	# Register manager tests if ManagerTests exists
	if ResourceLoader.exists("res://scripts/test/ManagerTests.gd"):
		var manager_tests_script = load("res://scripts/test/ManagerTests.gd")
		if manager_tests_script != null:
			_manager_tests = manager_tests_script.new()
			if _manager_tests != null and _manager_tests.has_method("register_tests"):
				# Set test framework reference - use direct assignment
				_manager_tests.test_framework = test_framework
				_manager_tests.register_tests(test_registry)
			else:
				# Fallback: register tests manually
				_register_manager_tests()
		else:
			# Fallback: register tests manually
			_register_manager_tests()

## Register manager tests (fallback method)
func _register_manager_tests() -> void:
	# This will be populated by ManagerTests if it exists
	# Or you can manually register tests here
	pass

## Run all registered tests
func run_all_tests() -> Dictionary:
	var results = test_framework.run_registered_suites(test_registry)
	# Quit immediately after tests complete (for headless mode)
	# Use call_deferred to ensure all output is flushed first
	call_deferred("_quit_tree")
	return results

func _quit_tree() -> void:
	# Clean up resources before quitting
	_cleanup_resources()
	
	# Get tree reference before we might remove ourselves
	var tree = get_tree()
	if tree == null:
		return
	
	# Wait for all queued operations to complete
	await tree.process_frame
	await tree.process_frame
	
	# Free ourselves before quitting to prevent node leak
	# Remove from tree first, then free
	if get_parent() != null:
		get_parent().remove_child(self)
	# Free immediately (we're quitting anyway)
	free()
	
	# Wait a frame for cleanup
	await tree.process_frame
	
	# Quit the tree
	# Note: Script resources (GDScript) loaded with load() are cached by ResourceLoader
	# and may show as "leaked" - this is expected as they're managed by Godot's resource system
	# Autoload singletons (managers) are also managed by Godot and will show as "leaked"
	# in headless mode - this is expected behavior and not an actual leak
	tree.quit(0)

func _cleanup_resources() -> void:
	# Clear manager tests reference first
	if _manager_tests != null:
		# Clear any references it might have
		if _manager_tests.has_method("set"):
			_manager_tests.set("test_framework", null)
		_manager_tests = null
	
	# Clear test registry
	if test_registry != null:
		if test_registry.has_method("clear"):
			test_registry.clear()
		test_registry = null
	
	# Remove test framework from tree and free it properly
	if test_framework != null and is_instance_valid(test_framework):
		# Clear test framework's internal data
		if test_framework.has_method("_cleanup"):
			test_framework._cleanup()
		
		# Remove from tree first
		if test_framework.get_parent() == self:
			remove_child(test_framework)
		
		# Free the node immediately (we're quitting anyway, so immediate free is fine)
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
