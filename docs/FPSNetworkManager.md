# FPSNetworkManager

Specialized network manager for FPS multiplayer games that extends the base NetworkManager with game-specific functionality.

## Overview

FPSNetworkManager extends the base NetworkManager with features specifically designed for FPS multiplayer games:

- **Inherits Core Networking**: All basic networking functionality from NetworkManager (host/join/disconnect, session events, peer management)
- **Arena Ready Coordination**: Level loading synchronization to prevent RPC errors during scene transitions
- **Late-Join Support**: Automatic handling of players joining during match transitions
- **FPS-Specific Events**: Session events tailored for FPS gameplay flow

## Table of Contents

- [Overview](#overview)
- [Signals](#signals)
- [Methods](#methods)
- [Usage Examples](#usage-examples)

## Signals

```gdscript
signal arena_ready(peer_id: int)
```
Emitted when a peer reports its arena/level is loaded and ready for gameplay.

## Methods

### Arena Ready Coordination

#### `report_local_arena_ready() -> void`

Mark the local (host) arena as loaded and ready. Should be called after level loading completes on the server.

#### `is_peer_arena_ready(peer_id: int) -> bool`

Check if a specific peer has reported arena ready.

**Parameters:**
- `peer_id`: Peer ID to check

**Returns:** true if peer has reported ready

#### `get_ready_peers() -> Array[int]`

Get all peer IDs that have reported arena ready.

**Returns:** Array of ready peer IDs

## Usage Examples

### Level Loading Coordination

```gdscript
# In arena/level script (Arena01.gd)
func _ready() -> void:
    # Load level assets and setup
    await load_level_assets()

    # Report arena ready to coordinate with other peers
    if FPSNetworkManager:
        if multiplayer.is_server():
            FPSNetworkManager.report_local_arena_ready()
        else:
            FPSNetworkManager._rpc_report_arena_ready.rpc_id(1)
```

### Late-Join Handling

```gdscript
# In game manager (FpsGameManager.gd)
func _on_peer_joined(data: Dictionary) -> void:
    var peer_id = data.peer_id

    if current_state == "PLAYING":
        if _arena_loading_in_progress:
            # Queue for later when arena is ready
            _queued_late_joiners.append(peer_id)
        else:
            # Send match start immediately
            FPSNetworkManager.send_session_event_to_peer(peer_id, "fps_match_start", {})

func _on_scene_changed(scene_path: String) -> void:
    if scene_path == SCENE_ARENA and _arena_loading_in_progress:
        _arena_loading_in_progress = false
        # Process queued late joiners
        for peer_id in _queued_late_joiners:
            FPSNetworkManager.send_session_event_to_peer(peer_id, "fps_match_start", {})
        _queued_late_joiners.clear()
```

### Match Start Broadcasting

```gdscript
# In lobby UI
func _on_start_match_pressed() -> void:
    if FPSNetworkManager and FPSNetworkManager.is_host():
        FPSNetworkManager.broadcast_session_event("fps_match_start", {})
```

## Architecture

FPSNetworkManager follows these design principles:

1. **Extends Base Functionality**: Inherits all generic networking from NetworkManager
2. **Game-Specific Logic**: Adds FPS-specific coordination without cluttering the base manager
3. **Event-Driven**: Uses signals for loose coupling with game systems
4. **Late-Join Friendly**: Handles players joining at any point in the game flow

## Integration

### With FpsGameManager

FPSNetworkManager integrates tightly with FpsGameManager for scene transitions and matchmaking:

```gdscript
# FpsGameManager subscribes to FPSNetworkManager events
func _on_game_ready() -> void:
    FPSNetworkManager.session_event_received.connect(_on_match_start)
    FPSNetworkManager.arena_ready.connect(_on_peer_arena_ready)
```

### With Player Spawning

Arena ready signals coordinate player spawning in multiplayer levels:

```gdscript
# In arena script
func _on_peer_arena_ready(peer_id: int) -> void:
    if _pending_players.has(peer_id):
        _pending_players.erase(peer_id)
        spawn_player_for_peer(peer_id)
```

## Best Practices

1. **Call report_local_arena_ready()** after level assets are fully loaded
2. **Handle arena_ready signals** to coordinate multiplayer gameplay start
3. **Use session events** for FPS-specific game state synchronization
4. **Queue late joiners** during scene transitions to prevent RPC errors

## See Also

- [NetworkManager](NetworkManager.md) - Base networking functionality
- [ExampleMultiplayerFPS.md](ExampleMultiplayerFPS.md) - FPS example implementation
- [FpsGameManager](FpsGameManager.md) - FPS game state management</contents>
</xai:function_call">New file created at: /home/paradox/git/godot-game-framework/docs/FPSNetworkManager.md