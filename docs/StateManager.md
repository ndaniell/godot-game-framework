# StateManager

Manages game state, pause functionality, and game lifecycle using a configurable state machine.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Signals](#signals)
- [Methods](#methods)
- [Virtual Methods](#virtual-methods)
- [State Machine Configuration](#state-machine-configuration)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)

## Overview

The `StateManager` is a flexible game state management system that:

- **Manages game states** through a configurable state machine
- **Handles pause/unpause** with automatic scene tree coordination
- **Coordinates scene transitions** with SceneManager
- **Integrates with other managers** through EventManager
- **Provides lifecycle hooks** for state-specific behavior

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `states_config_path` | String | `"res://addons/godot_game_framework/resources/data/game_states.tres"` | Path to state machine configuration |
| `current_state` | String | "" | Current game state name |
| `is_paused` | bool | false | Whether the game is paused |
| `current_scene_path` | String | "" | Path to the current scene |

## Signals

```gdscript
signal game_state_changed(old_state: String, new_state: String)
```
Emitted when the game state changes.

```gdscript
signal scene_changed(scene_path: String)
```
Emitted when the scene changes.

```gdscript
signal game_paused(is_paused: bool)
```
Emitted when the pause state changes.

```gdscript
signal game_quit()
```
Emitted when the game is quitting.

## Methods

### State Management

#### `change_state(new_state: String) -> void`

Change to a new game state.

**Parameters:**
- `new_state`: Name of the state (must be defined in state machine config)

**Example:**
```gdscript
GGF.state().change_state("PLAYING")
GGF.state().change_state("PAUSED")
GGF.state().change_state("GAME_OVER")
```

#### `get_state_name() -> String`

Returns the current state name.

#### `is_in_state(state: String) -> bool`

Check if the game is in a specific state.

**Example:**
```gdscript
if GGF.state().is_in_state("PLAYING"):
    # Game is running
```

#### `get_state_definition(state_name: String) -> GameStateDefinition`

Get the state definition resource for a given state.

#### `get_all_states() -> Array`

Get all available state names.

#### `can_transition_to(target_state: String) -> bool`

Check if transitioning to a target state is allowed from the current state.

### Pause Control

#### `pause_game() -> void`

Pause the game and change to PAUSED state.

#### `unpause_game() -> void`

Unpause the game and return to PLAYING state.

#### `toggle_pause() -> void`

Toggle between paused and unpaused states.

### Scene Management

#### `change_scene(scene_path: String, transition_type: String = "") -> void`

Change to a new scene with optional transition effect.

**Parameters:**
- `scene_path`: Path to the scene file
- `transition_type`: Optional transition effect ("fade", "slide", etc.)

**Example:**
```gdscript
GGF.scene().change_scene("res://scenes/level2.tscn", "fade")
```

#### `reload_current_scene() -> void`

Reload the current scene.

### Lifecycle

#### `quit_game() -> void`

Quit the game application.

#### `restart_game() -> void`

Restart the game by loading the main scene.

#### `reload_state_definitions() -> void`

Reload state definitions from file (useful for hot-reloading during development).

## Virtual Methods

Override these methods to add custom behavior:

### `_on_game_ready() -> void`

Called when StateManager is ready.

### `_on_state_changed(old_state: String, new_state: String) -> void`

Called when game state changes.

**Example:**
```gdscript
extends GGF_StateManager

func _on_state_changed(old_state: String, new_state: String) -> void:
    print("State changed: %s -> %s" % [old_state, new_state])
    match new_state:
        "PLAYING":
            # Resume gameplay
            pass
        "PAUSED":
            # Show pause menu
            pass
```

### `_on_pause_changed(is_paused: bool) -> void`

Called when pause state changes.

### `_on_scene_change_started(scene_path: String, transition_type: String) -> void`

Called when scene change begins.

### `_on_scene_changed(scene_path: String) -> void`

Called after scene has changed.

### `_on_node_added(node: Node) -> void`

Called when a node is added to the scene tree.

### `_on_node_removed(node: Node) -> void`

Called when a node is removed from the scene tree.

### `_on_game_over() -> void`

Called when entering GAME_OVER state.

### `_on_victory() -> void`

Called when entering VICTORY state.

### `_on_menu_entered() -> void`

Called when entering MENU state.

### `_on_loading_started() -> void`

Called when entering LOADING state.

### `_on_paused_entered() -> void`

Called when entering PAUSED state.

### `_on_paused_exited() -> void`

Called when exiting PAUSED state.

### `_on_game_quit() -> void`

Called before the game quits.

### `_on_game_restart() -> void`

Called before the game restarts.

## State Machine Configuration

The StateManager uses a resource-based state machine configuration. States are defined in `GameStateMachineConfig` resources.

### State Definition Structure

Each state is defined with:

```gdscript
# GameStateDefinition.gd
@export var name: String = ""
@export var entry_callback: String = ""
@export var exit_callback: String = ""
```

### Example Configuration

```gdscript
# game_states.tres
[resource]
script = ExtResource("GameStateMachineConfig")
default_state = "MENU"

[sub_resource type="GameStateDefinition" id="state_menu"]
name = "MENU"
entry_callback = "_on_menu_entered"

[sub_resource type="GameStateDefinition" id="state_playing"]
name = "PLAYING"

[sub_resource type="GameStateDefinition" id="state_paused"]
name = "PAUSED"
entry_callback = "_on_paused_entered"
exit_callback = "_on_paused_exited"
```

### Common States

| State | Purpose |
|-------|---------|
| `MENU` | Main menu or title screen |
| `PLAYING` | Active gameplay |
| `PAUSED` | Game is paused |
| `LOADING` | Loading resources or scenes |
| `GAME_OVER` | Player has failed |
| `VICTORY` | Player has won |

## Usage Examples

### Basic State Management

```gdscript
func _ready() -> void:
    # Start in menu state
    GGF.state().change_state("MENU")

func start_game() -> void:
    GGF.get_manager(&"GameManager").change_state("PLAYING")
    GGF.get_manager(&"GameManager").change_scene("res://scenes/level1.tscn", "fade")

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        GGF.state().toggle_pause()
```

### Custom Game Manager

```gdscript
extends GGF_StateManager

var lives: int = 3
var score: int = 0

func _on_game_ready() -> void:
    # Connect to events
    GGF.events().subscribe("player_died", _on_player_died)
    GGF.events().subscribe("level_complete", _on_level_complete)

func _on_player_died(data: Dictionary) -> void:
    lives -= 1
    if lives <= 0:
        change_state("GAME_OVER")
    else:
        reload_current_scene()

func _on_level_complete(data: Dictionary) -> void:
    score += data.get("score", 0)
    change_state("VICTORY")

func _on_game_over() -> void:
    # Save high score
    GGF.get_manager(&"SaveManager").save_game(0, {"score": score, "final_score": true})
    # Show game over screen
    GGF.get_manager(&"UIManager").open_menu("game_over_menu")

func _on_victory() -> void:
    # Show victory screen
    GGF.get_manager(&"UIManager").open_menu("victory_menu")
```

### State-Based Behavior

```gdscript
extends GGF_StateManager

func _on_state_changed(old_state: String, new_state: String) -> void:
    # Update UI based on state
    match new_state:
        "MENU":
            GGF.get_manager(&"UIManager").show_ui_element("main_menu")
            GGF.get_manager(&"UIManager").hide_ui_element("hud")
        "PLAYING":
            GGF.get_manager(&"UIManager").hide_ui_element("main_menu")
            GGF.get_manager(&"UIManager").show_ui_element("hud")
        "PAUSED":
            GGF.get_manager(&"UIManager").show_ui_element("pause_menu")
        "LOADING":
            GGF.get_manager(&"UIManager").show_ui_element("loading_screen")

func _on_pause_changed(is_paused: bool) -> void:
    if is_paused:
        # Dim background
        get_tree().call_group("gameplay", "set_process", false)
    else:
        # Resume
        get_tree().call_group("gameplay", "set_process", true)
```

### Level Progression System

```gdscript
extends GGF_StateManager

var current_level: int = 1
var max_level: int = 10

func advance_to_next_level() -> void:
    if current_level >= max_level:
        change_state("VICTORY")
        return
    
    current_level += 1
    change_state("LOADING")
    change_scene("res://scenes/level%d.tscn" % current_level, "fade")

func _on_scene_changed(scene_path: String) -> void:
    # Scene loaded, start playing
    if current_state == "LOADING":
        change_state("PLAYING")
```

### Save/Load Integration

```gdscript
extends GGF_StateManager

func save_current_game() -> void:
    var save_data = {
        "state": current_state,
        "scene": current_scene_path,
        "timestamp": Time.get_unix_time_from_system()
    }
    GGF.get_manager(&"SaveManager").save_game(0, save_data)

func load_saved_game() -> void:
    var save_manager := GGF.get_manager(&"SaveManager")
    if save_manager.load_game(0):
        var data = save_manager.get_current_save_data()
        var game_data = data.get("game_data", {})
        
        # Restore scene
        var scene_path = game_data.get("scene", "")
        if not scene_path.is_empty():
            change_scene(scene_path)
        
        # Restore state
        var saved_state = game_data.get("state", "PLAYING")
        change_state(saved_state)
```

## Best Practices

### 1. Define Clear State Transitions

```gdscript
# In state configuration, define allowed transitions
# This prevents invalid state changes
MENU -> [PLAYING, LOADING]
PLAYING -> [PAUSED, GAME_OVER, VICTORY]
PAUSED -> [PLAYING, MENU]
GAME_OVER -> [MENU, LOADING]
```

### 2. Use Callbacks for State-Specific Logic

```gdscript
# Define entry/exit callbacks for complex state logic
func _on_paused_entered() -> void:
    is_paused = true
    # Open pause menu
    GGF.get_manager(&"UIManager").open_menu("pause_menu")

func _on_paused_exited() -> void:
    is_paused = false
    # Close pause menu
    GGF.get_manager(&"UIManager").close_menu("pause_menu")
```

### 3. Coordinate with Other Managers

```gdscript
# GameManager automatically coordinates with:
# - TimeManager (for pause state)
# - EventManager (for state change events)
# - SceneManager (for scene transitions)

func _on_pause_changed(is_paused: bool) -> void:
    # TimeManager is automatically notified
    # EventManager emits "game_paused" event
    pass
```

### 4. Handle State Persistence

```gdscript
func _collect_game_data() -> Dictionary:
    return {
        "state": current_state,
        "scene": current_scene_path,
        "level": current_level
    }

func _apply_save_data(data: Dictionary) -> void:
    var game_data = data.get("game_data", {})
    if game_data.has("state"):
        change_state(game_data.state)
```

## Integration

### With TimeManager

Pause state automatically affects time scale:
```gdscript
# When paused, TimeManager.time_scale is set to 0
# When unpaused, time scale is restored
```

### With EventManager

StateManager emits events that other systems can listen to:
```gdscript
GGF.events().subscribe("game_state_changed", _on_state_change)
GGF.events().subscribe("game_paused", _on_pause)
```

## See Also

- [SceneManager](SceneManager.md) - Scene loading and transitions
- [TimeManager](TimeManager.md) - Time scaling and pause coordination
- [SaveManager](SaveManager.md) - Saving game state
- [EventManager](EventManager.md) - Event-based communication
