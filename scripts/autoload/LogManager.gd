extends Node

## LogManager - Centralized logging service for the Godot Game Framework
##
## This manager provides structured logging across all autoload managers with
## configurable verbosity levels, file output, and an in-memory ring buffer
## for potential in-game console integration.
##
## Log levels (in order of verbosity):
## - TRACE: Very detailed, high-frequency operations
## - DEBUG: Development details, state transitions
## - INFO: Important lifecycle events, user actions
## - WARN: Potential issues that don't break functionality
## - ERROR: Serious problems requiring attention

# Log levels enum
enum LogLevel {
	TRACE = 0,
	DEBUG = 1,
	INFO = 2,
	WARN = 3,
	ERROR = 4
}

# Configuration
@export var current_level: LogLevel = LogLevel.INFO:
	set(value):
		current_level = value
		_on_level_changed(value)

@export var ring_buffer_size: int = 1000
@export var enable_ring_buffer: bool = true

# Internal state
var _ring_buffer: Array[Dictionary] = []
var _buffer_mutex: Mutex = Mutex.new()

# Custom logger implementation
class GameLogger extends Logger:
	var _log_manager_ref: WeakRef

	func _init(log_manager: LogManager) -> void:
		_log_manager_ref = weakref(log_manager)

	func _log_message(message: String, error: bool) -> void:
		# Only capture and store - don't print to avoid recursion
		var log_manager := _log_manager_ref.get_ref() as LogManager
		if log_manager and log_manager.enable_ring_buffer:
			log_manager._add_to_ring_buffer({
				"message": message,
				"level": "ERROR" if error else "INFO",
				"timestamp": Time.get_ticks_msec(),
				"source": "engine"
			})

	func _log_error(
			function: String,
			file: String,
			line: int,
			code: String,
			rationale: String,
			editor_notify: bool,
			error_type: int,
			script_backtraces: Array[ScriptBacktrace]
	) -> void:
		# Only capture and store - don't print to avoid recursion
		var log_manager := _log_manager_ref.get_ref() as LogManager
		if log_manager and log_manager.enable_ring_buffer:
			# Build detailed error message
			var error_message := rationale
			if not code.is_empty():
				error_message += " (Code: %s)" % code

			# Format script backtraces
			var backtrace_info := ""
			if script_backtraces.size() > 0:
				backtrace_info = "\nStack trace:"
				for i in script_backtraces.size():
					var bt: ScriptBacktrace = script_backtraces[i]
					backtrace_info += "\n  %d - %s:%d in function %s()" % [
						i + 1,
						bt.file,
						bt.line,
						bt.function
					]

			# Get error type name - use basic mapping for common errors
			var error_type_name := "UNKNOWN"
			match error_type:
				Error.OK: error_type_name = "OK"
				Error.FAILED: error_type_name = "FAILED"
				Error.ERR_UNAVAILABLE: error_type_name = "UNAVAILABLE"
				Error.ERR_UNCONFIGURED: error_type_name = "UNCONFIGURED"
				Error.ERR_UNAUTHORIZED: error_type_name = "UNAUTHORIZED"
				Error.ERR_PARAMETER_RANGE_ERROR: error_type_name = "PARAMETER_RANGE_ERROR"
				Error.ERR_OUT_OF_MEMORY: error_type_name = "OUT_OF_MEMORY"
				Error.ERR_FILE_NOT_FOUND: error_type_name = "FILE_NOT_FOUND"
				Error.ERR_FILE_BAD_DRIVE: error_type_name = "FILE_BAD_DRIVE"
				Error.ERR_FILE_BAD_PATH: error_type_name = "FILE_BAD_PATH"
				Error.ERR_FILE_NO_PERMISSION: error_type_name = "FILE_NO_PERMISSION"
				Error.ERR_FILE_ALREADY_IN_USE: error_type_name = "FILE_ALREADY_IN_USE"
				Error.ERR_FILE_CANT_OPEN: error_type_name = "FILE_CANT_OPEN"
				Error.ERR_FILE_CANT_WRITE: error_type_name = "FILE_CANT_WRITE"
				Error.ERR_FILE_CANT_READ: error_type_name = "FILE_CANT_READ"
				Error.ERR_FILE_UNRECOGNIZED: error_type_name = "FILE_UNRECOGNIZED"
				Error.ERR_FILE_CORRUPT: error_type_name = "FILE_CORRUPT"
				Error.ERR_FILE_MISSING_DEPENDENCIES: error_type_name = "FILE_MISSING_DEPENDENCIES"
				Error.ERR_FILE_EOF: error_type_name = "FILE_EOF"
				Error.ERR_CANT_OPEN: error_type_name = "CANT_OPEN"
				Error.ERR_CANT_CREATE: error_type_name = "CANT_CREATE"
				Error.ERR_QUERY_FAILED: error_type_name = "QUERY_FAILED"
				Error.ERR_ALREADY_IN_USE: error_type_name = "ALREADY_IN_USE"
				Error.ERR_LOCKED: error_type_name = "LOCKED"
				Error.ERR_TIMEOUT: error_type_name = "TIMEOUT"
				Error.ERR_CANT_CONNECT: error_type_name = "CANT_CONNECT"
				Error.ERR_CANT_RESOLVE: error_type_name = "CANT_RESOLVE"
				Error.ERR_CONNECTION_ERROR: error_type_name = "CONNECTION_ERROR"
				Error.ERR_CANT_ACQUIRE_RESOURCE: error_type_name = "CANT_ACQUIRE_RESOURCE"
				Error.ERR_CANT_FORK: error_type_name = "CANT_FORK"
				Error.ERR_INVALID_DATA: error_type_name = "INVALID_DATA"
				Error.ERR_INVALID_PARAMETER: error_type_name = "INVALID_PARAMETER"
				Error.ERR_ALREADY_EXISTS: error_type_name = "ALREADY_EXISTS"
				Error.ERR_DOES_NOT_EXIST: error_type_name = "DOES_NOT_EXIST"
				Error.ERR_DATABASE_CANT_READ: error_type_name = "DATABASE_CANT_READ"
				Error.ERR_DATABASE_CANT_WRITE: error_type_name = "DATABASE_CANT_WRITE"
				Error.ERR_COMPILATION_FAILED: error_type_name = "COMPILATION_FAILED"
				Error.ERR_METHOD_NOT_FOUND: error_type_name = "METHOD_NOT_FOUND"
				Error.ERR_LINK_FAILED: error_type_name = "LINK_FAILED"
				Error.ERR_SCRIPT_FAILED: error_type_name = "SCRIPT_FAILED"
				Error.ERR_CYCLIC_LINK: error_type_name = "CYCLIC_LINK"
				Error.ERR_INVALID_DECLARATION: error_type_name = "INVALID_DECLARATION"
				Error.ERR_DUPLICATE_SYMBOL: error_type_name = "DUPLICATE_SYMBOL"
				Error.ERR_PARSE_ERROR: error_type_name = "PARSE_ERROR"
				Error.ERR_BUSY: error_type_name = "BUSY"
				Error.ERR_SKIP: error_type_name = "SKIP"
				Error.ERR_HELP: error_type_name = "HELP"
				Error.ERR_BUG: error_type_name = "BUG"
				Error.ERR_PRINTER_ON_FIRE: error_type_name = "PRINTER_ON_FIRE"

			log_manager._add_to_ring_buffer({
				"message": error_message + backtrace_info,
				"level": "ERROR",
				"timestamp": Time.get_ticks_msec(),
				"source": "engine",
				"function": function,
				"file": file,
				"line": line,
				"error_code": code,
				"error_type": error_type_name,
				"editor_notify": editor_notify,
				"backtrace_count": script_backtraces.size()
			})

## Initialize the log manager
func _init() -> void:
	# Register custom logger for capturing engine messages
	OS.add_logger(GameLogger.new(self))

	# Initialize ring buffer as empty
	_ring_buffer = []

	info("LogManager", "LogManager initialized with level: %s" % LogLevel.keys()[current_level])

## Log a trace message
func trace(category: String, message: String) -> void:
	if current_level <= LogLevel.TRACE:
		_log(LogLevel.TRACE, category, message)

## Log a debug message
func debug(category: String, message: String) -> void:
	if current_level <= LogLevel.DEBUG:
		_log(LogLevel.DEBUG, category, message)

## Log an info message
func info(category: String, message: String) -> void:
	if current_level <= LogLevel.INFO:
		_log(LogLevel.INFO, category, message)

## Log a warning message
func warn(category: String, message: String) -> void:
	if current_level <= LogLevel.WARN:
		_log(LogLevel.WARN, category, message)

## Log an error message
func error(category: String, message: String) -> void:
	_log(LogLevel.ERROR, category, message)

## Internal logging function
func _log(level: LogLevel, category: String, message: String) -> void:
	var level_name: String = LogLevel.keys()[level]
	var timestamp := Time.get_time_string_from_system()
	var formatted_message := "[%s] [%s] %s: %s" % [timestamp, level_name, category, message]

	# Route based on level
	match level:
		LogLevel.TRACE:
			print_verbose(formatted_message)
		LogLevel.DEBUG:
			print_debug(formatted_message)
		LogLevel.INFO:
			print(formatted_message)
		LogLevel.WARN:
			push_warning(formatted_message)
		LogLevel.ERROR:
			push_error(formatted_message)

	# Add to ring buffer
	if enable_ring_buffer:
		_add_to_ring_buffer({
			"message": formatted_message,
			"level": level_name,
			"category": category,
			"timestamp": Time.get_ticks_msec()
		})

## Add entry to ring buffer (thread-safe)
func _add_to_ring_buffer(entry: Dictionary) -> void:
	_buffer_mutex.lock()
	_ring_buffer.push_back(entry)
	if _ring_buffer.size() > ring_buffer_size:
		_ring_buffer.pop_front()
	_buffer_mutex.unlock()

## Get ring buffer contents (thread-safe copy)
func get_ring_buffer() -> Array[Dictionary]:
	_buffer_mutex.lock()
	var copy := _ring_buffer.duplicate()
	_buffer_mutex.unlock()
	return copy

## Clear ring buffer
func clear_ring_buffer() -> void:
	_buffer_mutex.lock()
	_ring_buffer.clear()
	_buffer_mutex.unlock()

## Get current log level name
func get_level_name() -> String:
	return LogLevel.keys()[current_level]

## Set log level by name
func set_level_by_name(level_name: String) -> bool:
	if not LogLevel.has(level_name.to_upper()):
		warn("LogManager", "Invalid log level name: %s" % level_name)
		return false

	current_level = LogLevel[level_name.to_upper()]
	return true

## Called when log level changes
func _on_level_changed(_new_level: LogLevel) -> void:
	info("LogManager", "Log level changed to: %s" % get_level_name())