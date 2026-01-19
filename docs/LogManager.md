# LogManager

Provides centralized logging functionality with configurable verbosity, ring buffer storage, and multi-instance support.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Methods](#methods)
- [Multi-Instance Logging](#multi-instance-logging)
- [Usage Examples](#usage-examples)
- [Integration](#integration)

## Overview

The `LogManager` provides structured logging across the framework with:

- **Configurable log levels** (TRACE, DEBUG, INFO, WARN, ERROR)
- **Ring buffer storage** for recent log entries
- **Multi-instance support** with PID-based instance identification
- **Network context awareness** (peer ID and server/client role)
- **File logging** to per-instance log files
- **Godot integration** with custom logger for engine messages

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `current_level` | LogLevel | INFO | Minimum log level to output |
| `ring_buffer_size` | int | 1000 | Maximum entries in ring buffer |
| `enable_ring_buffer` | bool | true | Whether to store logs in memory |
| `enable_file_logging` | bool | true | Whether to write logs to files |
| `log_directory` | String | "user://logs" | Directory for log files |
| `log_filename_pattern` | String | "{project}_{instance}.log" | Log filename template |

## Methods

### Logging Methods

#### `trace(category: String, message: String) -> void`

Log a trace message (highest verbosity).

#### `debug(category: String, message: String) -> void`

Log a debug message.

#### `info(category: String, message: String) -> void`

Log an info message.

#### `warn(category: String, message: String) -> void`

Log a warning message.

#### `error(category: String, message: String) -> void`

Log an error message.

### Ring Buffer

#### `get_ring_buffer() -> Array[Dictionary]`

Get all entries from the ring buffer.

**Returns:** Array of log entry dictionaries with keys: `message`, `level`, `category`, `timestamp`

#### `clear_ring_buffer() -> void`

Clear all entries from the ring buffer.

### Level Management

#### `set_level_by_name(level_name: String) -> bool`

Set log level by name ("TRACE", "DEBUG", "INFO", "WARN", "ERROR").

**Parameters:**
- `level_name`: Name of the log level

**Returns:** true if level was set successfully

#### `get_level_name() -> String`

Get current log level name.

**Returns:** Current log level name

### Network Context

#### `update_network_context(peer_id: int = 0, is_server: bool = false) -> void`

Update network context for logging prefixes.

**Parameters:**
- `peer_id`: Current peer ID (0 for offline)
- `is_server`: Whether this instance is the server

## Multi-Instance Logging

LogManager supports running multiple game instances simultaneously with distinct log identification:

### Instance Identification

- **Instance Tag**: Automatically generated from OS process ID (`pid={PID}`)
- **Network Context**: Includes peer ID and role when connected
- **Log Prefix**: Format: `[pid=12345] [peer=2] [role=client]`

### File Logging

- **Per-Instance Files**: Logs written to `user://logs/{project}_{instance}.log`
- **Automatic Directory Creation**: `user://logs/` created if needed
- **Concurrent Safety**: Each instance writes to its own file

### Example Log Output

```
[15:30:22] [INFO] [pid=12345] [peer=1] [role=server] GameManager: State changed to PLAYING
[15:30:23] [DEBUG] [pid=67890] [peer=2] [role=client] NetworkManager: Connected to server
[15:30:24] [WARN] [pid=12345] [peer=1] [role=server] PlayerController: Invalid input received
```

## Usage Examples

### Basic Logging

```gdscript
func _ready() -> void:
    LogManager.info("MyScript", "Script initialized")
    LogManager.debug("MyScript", "Debug information: " + str(some_value))
    LogManager.warn("MyScript", "Potential issue detected")
    LogManager.error("MyScript", "Critical error occurred")
```

### Level Filtering

```gdscript
# Set to DEBUG level to see debug messages
LogManager.set_level_by_name("DEBUG")

# Only INFO, WARN, and ERROR will show
LogManager.set_level_by_name("INFO")
```

### Ring Buffer Access

```gdscript
# Get recent logs for debugging UI
var recent_logs = LogManager.get_ring_buffer()
for entry in recent_logs:
    debug_label.text += entry.message + "\n"

# Clear buffer when no longer needed
LogManager.clear_ring_buffer()
```

### Custom Log Analysis

```gdscript
func get_error_count() -> int:
    var logs = LogManager.get_ring_buffer()
    var error_count = 0
    for entry in logs:
        if entry.level == "ERROR":
            error_count += 1
    return error_count
```

## Integration

### With NetworkManager

NetworkManager automatically updates LogManager's network context:

```gdscript
# NetworkManager handles this automatically
# When connected as server with peer_id=1:
# Logs will include: [pid=12345] [peer=1] [role=server]

# When connected as client with peer_id=2:
# Logs will include: [pid=67890] [peer=2] [role=client]
```

### With Other Managers

LogManager integrates with all framework managers:

```gdscript
# GameManager state changes
LogManager.info("GameManager", "State changed from MENU to PLAYING")

# NetworkManager connections
LogManager.info("NetworkManager", "Peer 2 connected")

# ResourceManager loading
LogManager.debug("ResourceManager", "Loaded texture: player_sprite.png")
```

### Custom Categories

Use descriptive categories for better log filtering:

```gdscript
LogManager.info("PlayerMovement", "Player jumped")
LogManager.debug("InventorySystem", "Item added: " + item_name)
LogManager.warn("SaveSystem", "Failed to save game: " + error_message)
```

## Best Practices

1. **Use appropriate log levels** - TRACE for high-frequency operations, ERROR for serious issues
2. **Include context** - Use descriptive categories and clear messages
3. **Avoid sensitive data** - Don't log passwords, personal information, or debug secrets
4. **Performance considerations** - TRACE/DEBUG logging can impact performance in production
5. **File management** - Monitor log file sizes for long-running applications

## Configuration

### Export Variables

Configure LogManager through the Godot editor:

- Set `current_level` to control verbosity
- Adjust `ring_buffer_size` based on memory constraints
- Customize `log_filename_pattern` for different naming schemes

### Runtime Configuration

```gdscript
# Adjust settings at runtime
LogManager.current_level = LogManager.LogLevel.DEBUG
LogManager.ring_buffer_size = 500
LogManager.enable_file_logging = false  # Disable file logging if needed
```

## Troubleshooting

### Logs Not Appearing

- Check `current_level` is set appropriately
- Verify category names match expectations
- Ensure LogManager autoload is enabled

### File Logging Issues

- Check write permissions for `user://logs/` directory
- Verify `log_filename_pattern` is valid
- Ensure sufficient disk space

### Performance Issues

- Reduce `ring_buffer_size` for memory-constrained environments
- Use higher log levels (INFO+) in production
- Disable file logging if not needed

## See Also

- [NetworkManager](NetworkManager.md) - For multiplayer networking
- [GameManager](GameManager.md) - For game state management