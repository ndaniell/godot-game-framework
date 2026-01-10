extends RefCounted

## TestSuite - Base class for test suites
##
## Extend this class to create test suites for any part of the framework.

class_name FrameworkTestSuite

var test_framework: TestFramework
var suite_name: String

## Initialize the test suite
func _init(name: String, framework: TestFramework) -> void:
	suite_name = name
	test_framework = framework

## Get the test suite name
func get_suite_name() -> String:
	return suite_name

## Get all tests in this suite
## Override this method to return your tests
func get_tests() -> Dictionary:
	return {}

## Setup before suite runs
## Override to add suite-level setup
func setup() -> void:
	pass

## Teardown after suite runs
## Override to add suite-level teardown
func teardown() -> void:
	pass

## Setup before each test
## Override to add per-test setup
func setup_test() -> void:
	pass

## Teardown after each test
## Override to add per-test teardown
func teardown_test() -> void:
	pass

## Run this test suite
func run() -> Dictionary:
	setup()
	
	var tests := get_tests()
	var results := {}
	
	for test_name in tests:
		setup_test()
		var test_func := tests[test_name] as Callable
		var passed := test_framework.run_test(suite_name + "::" + test_name, test_func)
		results[test_name] = passed
		teardown_test()
	
	teardown()
	return results
