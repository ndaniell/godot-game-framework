# NetworkManager

Provides multiplayer networking functionality using ENet, with support for hosting/joining games and session event broadcasting.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Signals](#signals)
- [Methods](#methods)
- [Usage Examples](#usage-examples)

## Overview

The `NetworkManager` handles ENet-based multiplayer networking including:

- **Server hosting** with configurable port and max clients
- **Client connections** with automatic reconnection handling
- **Peer management** with join/leave notifications
- **Session events** for game-specific multiplayer communication
- **Integration** with EventManager for cross-manager communication

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `default_port` | int | 8910 | Default port for hosting |
| `max_clients` | int | 16 | Maximum number of clients |

## Signals

```gdscript
signal network_host_started(port: int)
```
Emitted when server starts hosting successfully.

```gdscript
signal network_connecting(ip: String, port: int)
```
Emitted when attempting to connect to a server.

```gdscript
signal network_connected(mode: String)
```
Emitted when connected (mode is "server" or "client").

```gdscript
signal network_disconnected(reason: String)
```
Emitted when disconnected.

```gdscript
signal peer_joined(peer_id: int)
```
Emitted when a new peer joins.

```gdscript
signal peer_left(peer_id: int)
```
Emitted when a peer disconnects.

```gdscript
signal session_event_received(event_name: StringName, data: Dictionary)
```
Emitted when receiving a session event from server.

## Methods

### Connection Management

#### `host(port: int = -1) -> bool`

Start hosting a server on the specified port.

**Parameters:**
- `port`: Port to host on (uses default_port if -1)

**Returns:** true if hosting started successfully

#### `join(ip: String, port: int = -1) -> bool`

Connect to a server.

**Parameters:**
- `ip`: Server IP address
- `port`: Server port (uses default_port if -1)

**Returns:** true if connection attempt started

#### `disconnect() -> void`

Disconnect from current session.

### Status Checks

#### `is_network_connected() -> bool`

Check if currently connected to a network session.

#### `is_host() -> bool`

Check if this instance is the server/host.

#### `get_peer_id() -> int`

Get the current peer ID.

#### `get_peer_ids() -> Array[int]`

Get all connected peer IDs.

### Session Events

#### `broadcast_session_event(event_name: StringName, data: Dictionary = {}) -> void`

Broadcast a custom event to all connected peers (server only).

**Parameters:**
- `event_name`: Name of the event
- `data`: Event data dictionary

#### `send_session_event_to_peer(peer_id: int, event_name: StringName, data: Dictionary = {}) -> void`

Send a custom event to a specific peer (server only).

## Usage Examples

### Basic Hosting

```gdscript
func _on_host_button_pressed() -> void:
    if GGF.get_manager(&"NetworkManager").host(8910):
        print("Hosting on port 8910")
    else:
        print("Failed to host")

func _on_network_host_started(port: int) -> void:
    print("Server started on port: ", port)
    # Load game scene, show lobby, etc.
```

### Joining a Game

```gdscript
func _on_join_button_pressed() -> void:
    var ip = $IPEdit.text
    var port = int($PortEdit.text)
    if GGF.get_manager(&"NetworkManager").join(ip, port):
        print("Connecting to ", ip, ":", port)
    else:
        print("Failed to start connection")

func _on_network_connected(mode: String) -> void:
    print("Connected as: ", mode)
    if mode == "client":
        # Client connected successfully
        pass
```

### Session Events

```gdscript
# Server-side: Broadcast game events
func _on_player_scored(player_id: int, points: int) -> void:
    GGF.get_manager(&"NetworkManager").broadcast_session_event("player_scored", {
        "player_id": player_id,
        "points": points,
        "total_score": get_player_score(player_id)
    })

# Client-side: Handle received events
func _ready() -> void:
    GGF.get_manager(&"NetworkManager").session_event_received.connect(_on_session_event)

func _on_session_event(event_name: StringName, data: Dictionary) -> void:
    match event_name:
        "player_scored":
            _update_scoreboard(data["player_id"], data["total_score"])
        "game_ended":
            _show_game_over_screen()
```

## Integration

### With EventManager

NetworkManager automatically mirrors its signals to EventManager:

```gdscript
# Subscribe to network events through EventManager
GGF.events().subscribe("network_connected", _on_network_connected)
GGF.events().subscribe("peer_joined", _on_peer_joined)
```

### With GameManager

NetworkManager integrates with game state management:

```gdscript
func _on_network_connected(mode: String) -> void:
    if mode == "server":
        GGF.get_manager(&"GameManager").change_state("LOBBY")
    else:
        GGF.get_manager(&"GameManager").change_state("CONNECTING")
```

## Best Practices

1. **Handle disconnections gracefully** - Always check connection status
2. **Use session events for game logic** - Keep network-specific code separate
3. **Validate server authority** - Only server should broadcast critical events
4. **Implement reconnection logic** - Handle temporary disconnects
5. **Test with multiple instances** - Use Godot's multiplayer testing features

## See Also

- [EventManager](EventManager.md) - For event-based communication
- [GameManager](GameManager.md) - For game state management