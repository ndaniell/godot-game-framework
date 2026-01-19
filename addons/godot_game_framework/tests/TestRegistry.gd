extends RefCounted

## TestRegistry - Generic test registry for the framework
##
## This class allows any part of the framework to register tests dynamically.

# Registered test suites
# Structure: suite_name -> {tests: Dictionary, setup: Callable, teardown: Callable, source: RefCounted}
# source is optional - if provided, tests can be recreated from method names
var _test_suites: Dictionary = {}

## Register a test suite
func register_suite(suite_name: String, tests: Dictionary, setup: Callable = Callable(), teardown: Callable = Callable(), source: RefCounted = null) -> void:
	if suite_name.is_empty():
		push_error("TestRegistry: Cannot register suite with empty name")
		return
	
	# Convert Callables to method names for storage (Callables don't serialize well)
	var test_methods: Dictionary = {}
	for test_name in tests:
		var test_value = tests[test_name]
		if test_value is Callable:
			var callable = test_value as Callable
			# Try to get method name from Callable
			var method_info = callable.get_method()
			if method_info != null:
				# Convert StringName to String
				test_methods[test_name] = String(method_info)
			else:
				# Fallback: store as-is (might not work)
				test_methods[test_name] = test_value
		else:
			test_methods[test_name] = test_value
	
	_test_suites[suite_name] = {
		"tests": test_methods,
		"setup": setup,
		"teardown": teardown,
		"source": source,
	}

## Unregister a test suite
func unregister_suite(suite_name: String) -> void:
	_test_suites.erase(suite_name)

## Get all registered suites
func get_suites() -> Array[String]:
	var result: Array[String] = []
	var keys = _test_suites.keys()
	for i in range(keys.size()):
		var key = keys[i]
		if key is String:
			result.append(key as String)
	return result

## Get a test suite
func get_suite(suite_name: String) -> Dictionary:
	if not _test_suites.has(suite_name):
		return {}
	
	var suite = _test_suites[suite_name] as Dictionary
	var test_methods: Dictionary = suite.get("tests", {})
	var source: RefCounted = suite.get("source", null)
	
	# Recreate Callables from method names if source is available
	var tests: Dictionary = {}
	if source != null:
		for test_name in test_methods:
			var method_name = test_methods[test_name]
			if method_name is String and source.has_method(method_name):
				tests[test_name] = Callable(source, method_name)
			else:
				# Fallback: use as-is
				tests[test_name] = method_name
	else:
		# No source - return method names as-is (won't work but preserves structure)
		tests = test_methods
	
	return {
		"tests": tests,
		"setup": suite.get("setup", Callable()),
		"teardown": suite.get("teardown", Callable()),
	}

## Check if suite exists
func has_suite(suite_name: String) -> bool:
	return _test_suites.has(suite_name)

## Add tests to an existing suite
func add_tests_to_suite(suite_name: String, tests: Dictionary) -> void:
	if not _test_suites.has(suite_name):
		register_suite(suite_name, tests)
		return
	
	var suite := _test_suites[suite_name] as Dictionary
	var existing_tests := suite["tests"] as Dictionary
	for test_name in tests:
		existing_tests[test_name] = tests[test_name]

## Clear all suites
func clear() -> void:
	_test_suites.clear()

## Get suite count
func get_suite_count() -> int:
	return _test_suites.size()

