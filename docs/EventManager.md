# EventManager

A global event bus system implementing the publish-subscribe (pub/sub) pattern for decoupled communication between systems.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Signals](#signals)
- [Methods](#methods)
- [Virtual Methods](#virtual-methods)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)

## Overview

The `EventManager` provides a centralized event system that allows different parts of your game to communicate without direct dependencies. It implements the observer pattern, enabling loose coupling between game systems.

**Key Features:**
- **Event subscription** with callable support
- **Event emission** with custom data
- **Event history** for debugging (optional)
- **Automatic cleanup** of invalid listeners
- **Type-safe** event data through dictionaries

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_event_history` | bool | false | Enable event history tracking for debugging |
| `max_history_size` | int | 100 | Maximum number of events to keep in history |

## Signals

```gdscript
signal event_emitted(event_name: String, data: Dictionary)
```
Emitted whenever any event is triggered.

```gdscript
signal listener_added(event_name: String)
```
Emitted when a new listener subscribes to an event.

```gdscript
signal listener_removed(event_name: String)
```
Emitted when a listener unsubscribes from an event.

## Methods

### Event Subscription

#### `subscribe(event_name: String, callable: Callable) -> void`

Subscribe a callable to an event.

**Parameters:**
- `event_name`: Name of the event to listen for
- `callable`: Function to call when the event is emitted

**Example:**
```gdscript
GGF.events().subscribe("player_died", _on_player_died)

func _on_player_died(data: Dictionary) -> void:
    var score = data.get("score", 0)
    print("Player died with score: ", score)
```

#### `subscribe_method(event_name: String, target: Object, method: String) -> void`

Convenience method to subscribe using an object and method name.

**Example:**
```gdscript
GGF.events().subscribe_method("level_complete", self, "_on_level_complete")
```

#### `unsubscribe(event_name: String, callable: Callable) -> void`

Unsubscribe a callable from an event.

#### `unsubscribe_method(event_name: String, target: Object, method: String) -> void`

Convenience method to unsubscribe using an object and method name.

#### `unsubscribe_all(event_name: String) -> void`

Remove all listeners for a specific event.

### Event Emission

#### `emit(event_name: String, data: Dictionary = {}) -> void`

Emit an event with optional data.

**Parameters:**
- `event_name`: Name of the event to emit
- `data`: Dictionary containing event data

**Example:**
```gdscript
GGF.events().emit("player_died", {
    "score": 1000,
    "level": 5,
    "position": player.global_position
})
```

### Event Information

#### `has_listeners(event_name: String) -> bool`

Check if an event has any active listeners.

#### `get_listener_count(event_name: String) -> int`

Get the number of listeners for an event.

#### `get_registered_events() -> Array[String]`

Get all event names that have listeners.

### History Management

#### `get_event_history() -> Array[Dictionary]`

Get the event history (if enabled).

**Returns:** Array of dictionaries containing:
- `event`: Event name
- `data`: Event data
- `time`: Timestamp in milliseconds

#### `clear_event_history() -> void`

Clear the event history.

#### `clear_all_listeners() -> void`

Remove all event listeners from all events.

## Virtual Methods

### `_on_event_manager_ready() -> void`

Called when the event manager is ready. Override for custom initialization.

### `_on_event_emitted(event_name: String, data: Dictionary) -> void`

Called when any event is emitted. Override to log or filter events.

### `_on_listener_added(event_name: String, callable: Callable) -> void`

Called when a listener is added to an event.

### `_on_listener_removed(event_name: String, callable: Callable) -> void`

Called when a listener is removed from an event.

## Usage Examples

### Basic Event Communication

```gdscript
# In your player script
func _on_player_take_damage(amount: int) -> void:
    health -= amount
    if health <= 0:
        GGF.events().emit("player_died", {
            "position": global_position,
            "score": current_score
        })

# In your UI script
func _ready() -> void:
    GGF.events().subscribe("player_died", _on_player_died)

func _on_player_died(data: Dictionary) -> void:
    show_game_over_screen(data.get("score", 0))
```

### Item Collection System

```gdscript
# In item script
func _on_player_collect() -> void:
    GGF.events().emit("item_collected", {
        "item_type": "coin",
        "value": 10,
        "position": global_position
    })
    queue_free()

# In inventory manager
func _ready() -> void:
    GGF.events().subscribe("item_collected", _on_item_collected)

func _on_item_collected(data: Dictionary) -> void:
    var item_type = data.get("item_type", "")
    var value = data.get("value", 0)
    
    match item_type:
        "coin":
            coins += value
        "gem":
            gems += value
```

### Quest System

```gdscript
# Quest manager
class_name QuestManager extends Node

func _ready() -> void:
    GGF.events().subscribe("enemy_defeated", _on_enemy_defeated)
    GGF.events().subscribe("item_collected", _on_item_collected)
    GGF.events().subscribe("area_discovered", _on_area_discovered)

func _on_enemy_defeated(data: Dictionary) -> void:
    var enemy_type = data.get("enemy_type", "")
    update_quest_progress("defeat_enemies", enemy_type)

func _on_item_collected(data: Dictionary) -> void:
    var item_type = data.get("item_type", "")
    update_quest_progress("collect_items", item_type)

func update_quest_progress(quest_type: String, target: String) -> void:
    # Update quest tracking
    if quest_completed(quest_type, target):
        GGF.events().emit("quest_completed", {
            "quest_type": quest_type,
            "target": target
        })
```

### Debugging with Event History

```gdscript
extends GGF_EventManager

func _on_event_manager_ready() -> void:
    enable_event_history = true
    max_history_size = 50

func print_event_history() -> void:
    print("=== Event History ===")
    for event in get_event_history():
        print("[%d] %s: %s" % [event.time, event.event, event.data])

func find_events_by_name(event_name: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for event in get_event_history():
        if event.event == event_name:
            result.append(event)
    return result
```

### Achievement System

```gdscript
# Achievement manager
class_name AchievementManager extends Node

var achievements: Dictionary = {}

func _ready() -> void:
    _setup_achievements()
    _subscribe_to_events()

func _setup_achievements() -> void:
    achievements = {
        "first_blood": {"unlocked": false, "event": "enemy_defeated"},
        "collector": {"unlocked": false, "event": "item_collected", "count": 100},
        "explorer": {"unlocked": false, "event": "area_discovered", "count": 10}
    }

func _subscribe_to_events() -> void:
    GGF.events().subscribe("enemy_defeated", _check_achievements)
    GGF.events().subscribe("item_collected", _check_achievements)
    GGF.events().subscribe("area_discovered", _check_achievements)

func _check_achievements(data: Dictionary) -> void:
    # Check and unlock achievements based on event data
    for achievement_id in achievements:
        var achievement = achievements[achievement_id]
        if not achievement.unlocked:
            if _meets_criteria(achievement, data):
                _unlock_achievement(achievement_id)

func _unlock_achievement(achievement_id: String) -> void:
    achievements[achievement_id].unlocked = true
    GGF.events().emit("achievement_unlocked", {"id": achievement_id})
    GGF.notifications().show_success("Achievement Unlocked: " + achievement_id)
```

## Best Practices

### 1. Use Descriptive Event Names

```gdscript
# Good
GGF.events().emit("player_health_changed", {"health": 50, "max_health": 100})
GGF.events().emit("inventory_item_added", {"item": item_data})

# Bad
GGF.events().emit("update", {"val": 50})
GGF.events().emit("event", {"data": item_data})
```

### 2. Consistent Data Structures

```gdscript
# Define common data structures
const EVENT_PLAYER_DIED = {
    "position": Vector3.ZERO,
    "score": 0,
    "level": 1
}

# Use consistent keys
GGF.events().emit("player_died", {
    "position": player.global_position,
    "score": current_score,
    "level": current_level
})
```

### 3. Cleanup Subscriptions

```gdscript
class_name EnemySpawner extends Node

func _ready() -> void:
    GGF.events().subscribe("wave_started", _on_wave_started)

func _exit_tree() -> void:
    # Clean up subscriptions when node is removed
    GGF.events().unsubscribe("wave_started", _on_wave_started)
```

### 4. Avoid Circular Dependencies

```gdscript
# Bad - Can cause infinite loops
func _on_event_a(data: Dictionary) -> void:
    GGF.events().emit("event_b", data)

func _on_event_b(data: Dictionary) -> void:
    GGF.events().emit("event_a", data)  # Circular!

# Good - Use flags or conditions
func _on_event_a(data: Dictionary) -> void:
    if not data.get("processed", false):
        data.processed = true
        GGF.events().emit("event_b", data)
```

### 5. Event Documentation

```gdscript
# Document your events in a central location
## Common Game Events
##
## player_died: {position: Vector3, score: int, level: int}
## item_collected: {item_type: String, value: int, position: Vector3}
## quest_completed: {quest_id: String, reward: Dictionary}
## achievement_unlocked: {id: String}
## level_changed: {old_level: int, new_level: int}
```

## Common Events

The framework uses several common events for inter-manager communication:

| Event Name | Data | Description |
|------------|------|-------------|
| `game_state_changed` | `{old_state: String, new_state: String}` | Game state transition |
| `game_paused` | `{is_paused: bool}` | Game pause state changed |
| `setting_changed` | `{category: String, key: String, value: Variant}` | Settings updated |
| `save_created` | `{slot: int, metadata: Dictionary}` | Game saved |
| `save_loaded` | `{slot: int, data: Dictionary}` | Game loaded |

## Performance Considerations

- **Event emission is synchronous** - All listeners are called immediately
- **Listener cleanup** - Invalid callables are automatically removed
- **History overhead** - Disable event history in production for better performance
- **Large listener counts** - If an event has many listeners, consider batching or throttling emissions

## See Also

- [GameManager](GameManager.md) - Uses events for state changes
- [SettingsManager](SettingsManager.md) - Emits setting change events
