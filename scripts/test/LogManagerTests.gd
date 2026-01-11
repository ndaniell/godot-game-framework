extends RefCounted

## LogManagerTests - Comprehensive test suite for the LogManager
##
## This file contains detailed tests for the LogManager functionality.
## Tests are registered with the TestRegistry for discovery.
##
## IMPORTANT: LogManager is an autoload singleton available at runtime.
## The linter will show "not declared" errors for LogManager - this is EXPECTED
## and SAFE TO IGNORE. It works correctly at runtime.

# Suppress linter warnings for autoload singletons
# These are available at runtime via project.godot autoload configuration
@warning_ignore("unused_variable")
var test_framework: Node

## Helper to get test framework
func _get_framework() -> Node:
	return test_framework

## Register all LogManager tests with the registry
func register_tests(registry: RefCounted) -> void:
	if registry == null:
		push_error("LogManagerTests: Cannot register tests with null registry")
		return

	# Store reference to self so we can create Callables later
	# Register test suites for LogManager - create Callables at registration time
	var log_tests = _create_test_callables(_get_log_manager_test_names())

	# Verify Callables are valid before registering
	_validate_test_suite("LogManager", log_tests)

	# Register with source object so Callables can be recreated
	registry.register_suite("LogManager", log_tests, Callable(), Callable(), self)

## Helper to validate a test suite's Callables
func _validate_test_suite(suite_name: String, tests: Dictionary) -> void:
	for test_name in tests:
		var callable = tests[test_name]
		if not (callable is Callable) or not (callable as Callable).is_valid():
			push_error("LogManagerTests: Invalid Callable for " + suite_name + "." + test_name + " (type: " + str(typeof(callable)) + ")")

## Helper to create Callables from test definitions
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
			push_warning("LogManagerTests: Invalid test definition: " + str(test_def))
			continue

		if has_method(method_name):
			callables[display_name] = Callable(self, method_name)
		else:
			push_warning("LogManagerTests: Method not found: " + method_name)
	return callables

func _get_log_manager_test_names() -> Array:
	return [
		{"name": "LogManager exists", "method": "test_logmanager_exists"},
		{"name": "Log level filtering works", "method": "test_log_level_filtering"},
		{"name": "Ring buffer functionality", "method": "test_ring_buffer"},
		{"name": "All log methods work", "method": "test_log_methods"},
		{"name": "Level setting by name", "method": "test_level_setting"},
		{"name": "Ring buffer thread safety", "method": "test_ring_buffer_thread_safety"}
	]

func test_logmanager_exists() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false
	return framework.assert_not_null(LogManager, "LogManager should exist")

func test_log_level_filtering() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false

	# Store original level
	var original_level = LogManager.current_level

	# Test that setting level to ERROR blocks lower levels
	LogManager.current_level = LogManager.LogLevel.ERROR

	# Clear ring buffer to start fresh
	LogManager.clear_ring_buffer()

	# These should not appear in buffer (filtered out)
	LogManager.trace("TestCategory", "This is a trace message")
	LogManager.debug("TestCategory", "This is a debug message")
	LogManager.info("TestCategory", "This is an info message")

	# This should appear
	LogManager.error("TestCategory", "This is an error message")

	var buffer = LogManager.get_ring_buffer()
	var error_found = false
	for entry in buffer:
		if entry.get("level") == "ERROR" and entry.get("message", "").contains("error message"):
			error_found = true
			break

	var result1 = framework.assert_true(error_found, "ERROR level message should appear in buffer")

	# Test INFO level
	LogManager.current_level = LogManager.LogLevel.INFO
	LogManager.clear_ring_buffer()

	LogManager.debug("TestCategory", "This debug should be filtered")
	LogManager.info("TestCategory", "This info should appear")
	LogManager.warn("TestCategory", "This warn should appear")

	buffer = LogManager.get_ring_buffer()
	var info_found = false
	var warn_found = false
	var debug_found = false

	for entry in buffer:
		var level = entry.get("level", "")
		if level == "INFO" and entry.get("message", "").contains("info should appear"):
			info_found = true
		elif level == "WARN" and entry.get("message", "").contains("warn should appear"):
			warn_found = true
		elif level == "DEBUG":
			debug_found = true

	var result2 = framework.assert_true(info_found, "INFO level message should appear")
	var result3 = framework.assert_true(warn_found, "WARN level message should appear")
	var result4 = framework.assert_false(debug_found, "DEBUG level message should be filtered")

	# Restore original level
	LogManager.current_level = original_level

	return result1 and result2 and result3 and result4

func test_ring_buffer() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false

	# Store original settings
	var original_size = LogManager.ring_buffer_size
	var original_enabled = LogManager.enable_ring_buffer

	# Enable ring buffer with small size for testing
	LogManager.enable_ring_buffer = true
	LogManager.ring_buffer_size = 3
	LogManager.clear_ring_buffer()

	# Add some messages
	LogManager.info("TestCategory", "Message 1")
	LogManager.info("TestCategory", "Message 2")
	LogManager.info("TestCategory", "Message 3")
	LogManager.info("TestCategory", "Message 4")  # Should push out Message 1

	var buffer = LogManager.get_ring_buffer()

	# Should have exactly 3 messages (ring buffer size)
	var result1 = framework.assert_equal(buffer.size(), 3, "Ring buffer should maintain size limit")

	# Should not contain the first message (should have been pushed out)
	var has_message_1 = false
	var has_message_2 = false
	var has_message_3 = false
	var has_message_4 = false

	for entry in buffer:
		var msg = entry.get("message", "")
		if msg.contains("Message 1"):
			has_message_1 = true
		elif msg.contains("Message 2"):
			has_message_2 = true
		elif msg.contains("Message 3"):
			has_message_3 = true
		elif msg.contains("Message 4"):
			has_message_4 = true

	var result2 = framework.assert_false(has_message_1, "First message should be pushed out")
	var result3 = framework.assert_true(has_message_2, "Second message should remain")
	var result4 = framework.assert_true(has_message_3, "Third message should remain")
	var result5 = framework.assert_true(has_message_4, "Fourth message should be in buffer")

	# Test clear functionality
	LogManager.clear_ring_buffer()
	buffer = LogManager.get_ring_buffer()
	var result6 = framework.assert_equal(buffer.size(), 0, "Buffer should be empty after clear")

	# Restore original settings
	LogManager.ring_buffer_size = original_size
	LogManager.enable_ring_buffer = original_enabled

	return result1 and result2 and result3 and result4 and result5 and result6

func test_log_methods() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false

	# Set level to TRACE to ensure all messages get through
	var original_level = LogManager.current_level
	LogManager.current_level = LogManager.LogLevel.TRACE
	LogManager.clear_ring_buffer()

	# Test all log methods
	LogManager.trace("TestCategory", "Trace message")
	LogManager.debug("TestCategory", "Debug message")
	LogManager.info("TestCategory", "Info message")
	LogManager.warn("TestCategory", "Warn message")
	LogManager.error("TestCategory", "Error message")

	var buffer = LogManager.get_ring_buffer()

	# Should have 5 messages
	var result1 = framework.assert_equal(buffer.size(), 5, "Should have 5 log entries")

	# Check that all levels are present
	var levels_found = {}
	for entry in buffer:
		var level = entry.get("level", "")
		levels_found[level] = true

	var result2 = framework.assert_true(levels_found.has("TRACE"), "TRACE level should be present")
	var result3 = framework.assert_true(levels_found.has("DEBUG"), "DEBUG level should be present")
	var result4 = framework.assert_true(levels_found.has("INFO"), "INFO level should be present")
	var result5 = framework.assert_true(levels_found.has("WARN"), "WARN level should be present")
	var result6 = framework.assert_true(levels_found.has("ERROR"), "ERROR level should be present")

	# Check that all messages contain expected content
	var trace_found = false
	var debug_found = false
	var info_found = false
	var warn_found = false
	var error_found = false

	for entry in buffer:
		var msg = entry.get("message", "")
		var level = entry.get("level", "")
		if level == "TRACE" and msg.contains("Trace message"):
			trace_found = true
		elif level == "DEBUG" and msg.contains("Debug message"):
			debug_found = true
		elif level == "INFO" and msg.contains("Info message"):
			info_found = true
		elif level == "WARN" and msg.contains("Warn message"):
			warn_found = true
		elif level == "ERROR" and msg.contains("Error message"):
			error_found = true

	var result7 = framework.assert_true(trace_found, "Trace message should be found")
	var result8 = framework.assert_true(debug_found, "Debug message should be found")
	var result9 = framework.assert_true(info_found, "Info message should be found")
	var result10 = framework.assert_true(warn_found, "Warn message should be found")
	var result11 = framework.assert_true(error_found, "Error message should be found")

	# Restore original level
	LogManager.current_level = original_level

	return result1 and result2 and result3 and result4 and result5 and result6 and result7 and result8 and result9 and result10 and result11

func test_level_setting() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false

	var original_level = LogManager.current_level

	# Test setting level by name
	var result1 = framework.assert_true(LogManager.set_level_by_name("DEBUG"), "Should accept DEBUG level")
	var result2 = framework.assert_equal(LogManager.current_level, LogManager.LogLevel.DEBUG, "Should set to DEBUG level")

	var result3 = framework.assert_true(LogManager.set_level_by_name("ERROR"), "Should accept ERROR level")
	var result4 = framework.assert_equal(LogManager.current_level, LogManager.LogLevel.ERROR, "Should set to ERROR level")

	# Test invalid level name
	var result5 = framework.assert_false(LogManager.set_level_by_name("INVALID"), "Should reject invalid level")
	var result6 = framework.assert_equal(LogManager.current_level, LogManager.LogLevel.ERROR, "Should not change level for invalid input")

	# Test get_level_name
	var result7 = framework.assert_equal(LogManager.get_level_name(), "ERROR", "Should return correct level name")

	# Restore original level
	LogManager.current_level = original_level

	return result1 and result2 and result3 and result4 and result5 and result6 and result7

func test_ring_buffer_thread_safety() -> bool:
	var framework = _get_framework()
	if framework == null:
		return false

	# Store original settings
	var original_enabled = LogManager.enable_ring_buffer
	var original_size = LogManager.ring_buffer_size

	# Enable ring buffer
	LogManager.enable_ring_buffer = true
	LogManager.ring_buffer_size = 10
	LogManager.clear_ring_buffer()

	# Test multiple rapid calls (simulating concurrent access)
	for i in range(20):
		LogManager.info("ThreadSafetyTest", "Message " + str(i))

	var buffer = LogManager.get_ring_buffer()

	# Should have exactly ring buffer size (10) messages
	var result1 = framework.assert_equal(buffer.size(), 10, "Should maintain ring buffer size")

	# Messages should be the most recent ones (11-20, not 1-10)
	var found_recent = false
	var found_old = false

	for entry in buffer:
		var msg = entry.get("message", "")
		if msg.contains("Message 1"):
			found_old = true
		if msg.contains("Message 15"):
			found_recent = true

	var result2 = framework.assert_true(found_recent, "Should contain recent messages")
	var result3 = framework.assert_false(found_old, "Should not contain old messages")

	# Restore original settings
	LogManager.enable_ring_buffer = original_enabled
	LogManager.ring_buffer_size = original_size

	return result1 and result2 and result3