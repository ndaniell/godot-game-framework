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

```gdscript
signal arena_ready(peer_id: int)
```
Emitted when a peer reports its level/arena is loaded and ready for gameplay.

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

### Arena Ready Coordination

#### `report_local_arena_ready() -> void`

Mark the local (host) arena as loaded and ready. Should be called after level loading completes.

#### `is_peer_arena_ready(peer_id: int) -> bool`

Check if a specific peer has reported arena ready.

**Parameters:**
- `peer_id`: Peer ID to check

**Returns:** true if peer has reported ready

#### `get_ready_peers() -> Array[int]`

Get all peer IDs that have reported arena ready.

**Returns:** Array of ready peer IDs

## Usage Examples

### Basic Hosting

```gdscript
func _on_host_button_pressed() -> void:
    if NetworkManager.host(8910):
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
    if NetworkManager.join(ip, port):
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
    NetworkManager.broadcast_session_event("player_scored", {
        "player_id": player_id,
        "points": points,
        "total_score": get_player_score(player_id)
    })

# Client-side: Handle received events
func _ready() -> void:
    NetworkManager.session_event_received.connect(_on_session_event)

func _on_session_event(event_name: StringName, data: Dictionary) -> void:
    match event_name:
        "player_scored":
            _update_scoreboard(data["player_id"], data["total_score"])
        "game_ended":
            _show_game_over_screen()
```

### Arena Ready Coordination

```gdscript
# In level/arena loading script (e.g., Arena01.gd)
func _ready() -> void:
    # Load level assets, setup scene
    await load_level_assets()

    # Report arena ready to coordinate with other peers
    if NetworkManager:
        if multiplayer.is_server():
            NetworkManager.report_local_arena_ready()
        else:
            NetworkManager._rpc_report_arena_ready.rpc_id(1)

# Server-side: wait for peers before starting gameplay
func _on_peer_joined(peer_id: int) -> void:
    _pending_peers[peer_id] = true

func _on_arena_ready(peer_id: int) -> void:
    if _pending_peers.has(peer_id):
        _pending_peers.erase(peer_id)
        # Spawn player for this peer
        spawn_player_for_peer(peer_id)

        # Check if all peers are ready to start match
        if _pending_peers.is_empty():
            start_gameplay()
```

## Integration

### With EventManager

NetworkManager automatically mirrors its signals to EventManager:

```gdscript
# Subscribe to network events through EventManager
EventManager.subscribe("network_connected", _on_network_connected)
EventManager.subscribe("peer_joined", _on_peer_joined)
```

### With GameManager

NetworkManager integrates with game state management:

```gdscript
func _on_network_connected(mode: String) -> void:
    if mode == "server":
        GameManager.change_state("LOBBY")
    else:
        GameManager.change_state("CONNECTING")
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
- [ExampleMultiplayerFPS.md](../ExampleMultiplayerFPS.md) - Multiplayer example usage