extends Node

## TestFramework - Generic testing framework for the Godot Game Framework

class_name TestFramework
##
## This framework provides utilities for testing any part of the framework.
## It's designed to be extensible and can test managers, utilities, or any framework component.

signal test_started(test_name: String)
signal test_completed(test_name: String, passed: bool, message: String)
signal test_suite_completed(passed: int, failed: int, total: int)
signal all_tests_completed(passed: int, failed: int, total: int)

# Test results
var _test_results: Dictionary = {}  # test_name -> {passed: bool, message: String}
var _current_test: String = ""
var _test_count: int = 0
var _passed_count: int = 0
var _failed_count: int = 0

# Test configuration
@export_group("Test Configuration")
@export var stop_on_first_failure: bool = false
@export var verbose_output: bool = true

## Initialize test framework
func _ready() -> void:
	_initialize_test_framework()

func _initialize_test_framework() -> void:
	pass

## Run a single test
func run_test(test_name: String, test_func: Callable) -> bool:
	_current_test = test_name
	_test_count += 1
	
	test_started.emit(test_name)
	
	if verbose_output:
		print("[TEST] Starting: ", test_name)
	
	var start_time := Time.get_ticks_msec()
	var passed := false
	var message := ""
	
	# Setup
	_setup_test()
	
	# Run test with error handling
	var result: Variant = test_func.call()
	
	# Process result
	if result is bool:
		passed = result as bool
	elif result is Dictionary:
		var result_dict: Dictionary = result as Dictionary
		var passed_val = result_dict.get("passed", false)
		if passed_val is bool:
			passed = passed_val
		else:
			passed = false
		var msg_val = result_dict.get("message", "")
		if msg_val is String:
			message = msg_val
		else:
			message = ""
	else:
		# Default to pass if no explicit result
		passed = true
	
	var end_time := Time.get_ticks_msec()
	var duration := end_time - start_time
	
	# Store result
	_test_results[test_name] = {
		"passed": passed,
		"message": message,
		"duration": duration
	}
	
	# Cleanup
	_cleanup_test()
	
	if passed:
		_passed_count += 1
		if verbose_output:
			print("[PASS] ", test_name, " (", duration, "ms)")
	else:
		_failed_count += 1
		if verbose_output:
			print("[FAIL] ", test_name, ": ", message, " (", duration, "ms)")
	
	test_completed.emit(test_name, passed, message)
	
	if not passed and stop_on_first_failure:
		print("[TEST] Stopping on first failure")
		return false
	
	return passed

## Assert that a condition is true
func assert_true(condition: bool, message: String = "") -> bool:
	if not condition:
		_fail_test(message if not message.is_empty() else "Expected true, got false")
		return false
	return true

## Assert that a condition is false
func assert_false(condition: bool, message: String = "") -> bool:
	if condition:
		_fail_test(message if not message.is_empty() else "Expected false, got true")
		return false
	return true

## Assert that two values are equal
func assert_equal(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual != expected:
		var msg := message if not message.is_empty() else "Expected %s, got %s" % [expected, actual]
		_fail_test(msg)
		return false
	return true

## Assert that two values are not equal
func assert_not_equal(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual == expected:
		var msg := message if not message.is_empty() else "Expected values to differ, both are %s" % actual
		_fail_test(msg)
		return false
	return true

## Assert that a value is null
func assert_null(value: Variant, message: String = "") -> bool:
	if value != null:
		var msg := message if not message.is_empty() else "Expected null, got %s" % value
		_fail_test(msg)
		return false
	return true

## Assert that a value is not null
func assert_not_null(value: Variant, message: String = "") -> bool:
	if value == null:
		var msg := message if not message.is_empty() else "Expected non-null value"
		_fail_test(msg)
		return false
	return true

## Assert that a value is approximately equal (for floats)
func assert_almost_equal(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> bool:
	var diff: float = abs(actual - expected)
	if diff > tolerance:
		var msg: String = message if not message.is_empty() else "Expected %s, got %s (diff: %s)" % [expected, actual, diff]
		_fail_test(msg)
		return false
	return true

## Fail the current test
func fail(message: String = "Test failed") -> void:
	_fail_test(message)

## Pass the current test
func pass_test(_message: String = "Test passed") -> void:
	# Test passes by default, this is just for clarity
	pass

## Setup before each test
func _setup_test() -> void:
	# Override to add setup logic
	pass

## Cleanup after each test
func _cleanup_test() -> void:
	# Override to add cleanup logic
	pass

## Fail the current test
func _fail_test(message: String) -> void:
	# This will be caught by the test runner
	push_error("[TEST FAIL] " + _current_test + ": " + message)
	_test_results[_current_test] = {
		"passed": false,
		"message": message,
		"duration": 0
	}

## Get test results
func get_test_results() -> Dictionary:
	return _test_results.duplicate()

## Cleanup method for proper resource management
func _cleanup() -> void:
	_test_results.clear()
	_current_test = ""
	_test_count = 0
	_passed_count = 0
	_failed_count = 0

## Get test statistics
func get_test_stats() -> Dictionary:
	return {
		"total": _test_count,
		"passed": _passed_count,
		"failed": _failed_count,
		"success_rate": float(_passed_count) / float(_test_count) if _test_count > 0 else 0.0
	}

## Reset test framework
func reset() -> void:
	_test_results.clear()
	_current_test = ""
	_test_count = 0
	_passed_count = 0
	_failed_count = 0

## Print test summary
func print_summary() -> void:
	var stats := get_test_stats()
	print("\n" + "=".repeat(50))
	print("TEST SUMMARY")
	print("=".repeat(50))
	print("Total tests: ", stats["total"])
	print("Passed: ", stats["passed"])
	print("Failed: ", stats["failed"])
	print("Success rate: ", "%.1f%%" % (stats["success_rate"] * 100.0))
	print("=".repeat(50))
	
	if _failed_count > 0:
		print("\nFailed tests:")
		for test_name in _test_results:
			var result := _test_results[test_name] as Dictionary
			if not result.get("passed", false):
				print("  - ", test_name, ": ", result.get("message", ""))

## Run all tests in a test suite
func run_test_suite(suite_name: String, tests: Dictionary, setup: Callable = Callable(), teardown: Callable = Callable()) -> Dictionary:
	print("\n" + "=".repeat(50))
	print("Running test suite: ", suite_name)
	print("=".repeat(50))
	
	var suite_start_count := _test_count
	var suite_start_passed := _passed_count
	var suite_start_failed := _failed_count
	
	# Run setup if provided
	if setup.is_valid():
		setup.call()
	
	# Run tests
	for test_name in tests:
		var test_value = tests[test_name]
		var test_func: Callable
		
		# Handle different types of test functions
		if test_value is Callable:
			test_func = test_value as Callable
		elif test_value is String:
			# String method name - not supported in this context
			push_warning("TestFramework: String method names not supported for: " + test_name)
			continue
		else:
			# Try to cast to Callable
			test_func = test_value as Callable
		
		if not test_func.is_valid():
			push_warning("TestFramework: Invalid test function for: " + test_name + " (type: " + str(typeof(test_value)) + ")")
			continue
		run_test(suite_name + "::" + test_name, test_func)
	
	# Run teardown if provided
	if teardown.is_valid():
		teardown.call()
	
	# Calculate suite stats
	var suite_total := _test_count - suite_start_count
	var suite_passed := _passed_count - suite_start_passed
	var suite_failed := _failed_count - suite_start_failed
	
	print("\nSuite Summary: ", suite_name)
	print("  Passed: ", suite_passed, " / ", suite_total)
	print("  Failed: ", suite_failed, " / ", suite_total)
	
	var suite_stats := {
		"total": suite_total,
		"passed": suite_passed,
		"failed": suite_failed,
		"success_rate": float(suite_passed) / float(suite_total) if suite_total > 0 else 0.0
	}
	
	test_suite_completed.emit(suite_passed, suite_failed, suite_total)
	
	return suite_stats

## Run a test suite object (FrameworkTestSuite)
func run_test_suite_object(test_suite: RefCounted) -> Dictionary:
	if test_suite == null:
		push_error("TestFramework: Cannot run null test suite")
		return {}
	
	if not test_suite.has_method("get_suite_name") or not test_suite.has_method("get_tests"):
		push_error("TestFramework: Test suite must have get_suite_name() and get_tests() methods")
		return {}
	
	var setup := Callable(test_suite, "setup") if test_suite.has_method("setup") else Callable()
	var teardown := Callable(test_suite, "teardown") if test_suite.has_method("teardown") else Callable()
	
	return run_test_suite(
		test_suite.get_suite_name(),
		test_suite.get_tests(),
		setup,
		teardown
	)

## Run all registered test suites from a registry
func run_registered_suites(registry: RefCounted) -> Dictionary:
	if registry == null:
		push_error("TestFramework: Cannot run tests from null registry")
		return {}
	
	if not registry.has_method("get_suites") or not registry.has_method("get_suite"):
		push_error("TestFramework: Registry must have get_suites() and get_suite() methods")
		return {}
	
	print("\n" + "=".repeat(60))
	print("GODOT GAME FRAMEWORK - TEST SUITE")
	print("=".repeat(60))
	
	var all_passed := true
	var total_passed := 0
	var total_failed := 0
	var total_tests := 0
	
	var suites: Array[String] = registry.get_suites()
	for suite_name in suites:
		var suite: Dictionary = registry.get_suite(suite_name)
		var tests_raw = suite.get("tests", {})
		
		# Convert tests to proper Callables if needed
		# Tests might be stored as method names or Callables
		var tests: Dictionary = {}
		if tests_raw is Dictionary:
			for test_name in tests_raw:
				var test_value = tests_raw[test_name]
				if test_value is Callable:
					tests[test_name] = test_value
				elif test_value is String:
					# Method name - try to create Callable from registry context
					# This won't work without the original object, so skip
					push_warning("TestFramework: Cannot create Callable from method name: " + test_name)
				else:
					# Try to cast
					var callable = test_value as Callable
					if callable.is_valid():
						tests[test_name] = callable
					else:
						push_warning("TestFramework: Invalid test value for: " + test_name + " (type: " + str(typeof(test_value)) + ")")
		
		var setup: Callable = suite.get("setup", Callable())
		var teardown: Callable = suite.get("teardown", Callable())
		
		var stats := run_test_suite(suite_name, tests, setup, teardown)
		total_passed += stats["passed"]
		total_failed += stats["failed"]
		total_tests += stats["total"]
		
		if stats["failed"] > 0:
			all_passed = false
	
	# Final summary
	print("\n" + "=".repeat(60))
	print("FINAL SUMMARY")
	print("=".repeat(60))
	print("Total tests: ", total_tests)
	print("Passed: ", total_passed)
	print("Failed: ", total_failed)
	print("Success rate: ", "%.1f%%" % (float(total_passed) / float(total_tests) * 100.0) if total_tests > 0 else "0.0%")
	print("=".repeat(60))
	
	if all_passed:
		print("ALL TESTS PASSED!")
	else:
		print("SOME TESTS FAILED!")
	
	all_tests_completed.emit(total_passed, total_failed, total_tests)
	
	return {
		"total": total_tests,
		"passed": total_passed,
		"failed": total_failed,
		"all_passed": all_passed
	}
