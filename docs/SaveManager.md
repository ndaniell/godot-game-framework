# SaveManager

Manages game data persistence with support for multiple save slots, auto-save, and custom save data collection.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Signals](#signals)
- [Methods](#methods)
- [Virtual Methods](#virtual-methods)
- [Usage Examples](#usage-examples)

## Overview

The `SaveManager` provides:

- **Multiple save slots** (configurable limit)
- **Auto-save** functionality with configurable intervals
- **Metadata** support for save file information
- **Extensible data collection** through virtual methods
- **JSON-based** save files for easy debugging

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `save_directory` | String | `"user://saves"` | Directory for save files |
| `max_save_slots` | int | 10 | Maximum number of save slots |
| `save_file_prefix` | String | `"save_"` | Prefix for save file names |
| `save_file_extension` | String | `".save"` | Extension for save files |
| `auto_save_enabled` | bool | false | Enable auto-save |
| `auto_save_interval` | float | 300.0 | Auto-save interval in seconds |
| `current_save_slot` | int | -1 | Current active save slot |

## Signals

```gdscript
signal save_created(slot: int, metadata: Dictionary)
signal save_loaded(slot: int, data: Dictionary)
signal save_deleted(slot: int)
signal save_failed(slot: int, error: String)
```

## Methods

### Save/Load Operations

#### `save_game(slot: int = 0, metadata: Dictionary = {}) -> bool`
Save game data to a slot with optional metadata.

#### `load_game(slot: int = 0) -> bool`
Load game data from a slot.

#### `delete_save(slot: int) -> bool`
Delete a save slot.

#### `quick_save() -> bool`
Save to current slot (or slot 0).

#### `quick_load() -> bool`
Load from current slot (or slot 0).

### Save Information

#### `save_exists(slot: int) -> bool`
Check if a save slot exists.

#### `get_save_metadata(slot: int) -> Dictionary`
Get metadata for a save slot without loading the full save.

#### `get_available_saves() -> Array[int]`
Get all slot numbers that have save data.

#### `get_current_save_data() -> Dictionary`
Get the currently loaded save data.

#### `set_save_data(data: Dictionary) -> void`
Manually set save data (useful for runtime modifications).

## Virtual Methods

Override these to customize what data is saved/loaded:

### `_collect_game_data() -> Dictionary`
Collect all game data to save. Override to add custom game state.

### `_collect_player_data() -> Dictionary`
Collect player-specific data (health, inventory, etc.).

### `_collect_world_data() -> Dictionary`
Collect world-specific data (enemy states, item pickups, etc.).

### `_apply_save_data(data: Dictionary) -> void`
Apply loaded save data. Override to restore custom game state.

### `_apply_player_data(player_data: Dictionary) -> void`
Apply player-specific data when loading.

### `_apply_world_data(world_data: Dictionary) -> void`
Apply world-specific data when loading.

## Usage Examples

### Basic Save/Load

```gdscript
# Save
func save_current_progress() -> void:
    var metadata = {
        "level": current_level,
        "playtime": total_playtime,
        "date": Time.get_datetime_string_from_system()
    }
    if SaveManager.save_game(0, metadata):
        NotificationManager.show_success("Game Saved!")
    else:
        NotificationManager.show_error("Save Failed!")

# Load
func load_saved_game(slot: int) -> void:
    if SaveManager.load_game(slot):
        NotificationManager.show_success("Game Loaded!")
        GameManager.change_scene("res://scenes/gameplay.tscn")
```

### Save Slot UI

```gdscript
class_name SaveSlotUI extends PanelContainer

@export var slot_number: int = 0

@onready var label: Label = %Label
@onready var load_button: Button = %LoadButton
@onready var delete_button: Button = %DeleteButton

func _ready() -> void:
    load_button.pressed.connect(_on_load_pressed)
    delete_button.pressed.connect(_on_delete_pressed)
    _update_display()

func _update_display() -> void:
    if SaveManager.save_exists(slot_number):
        var metadata = SaveManager.get_save_metadata(slot_number)
        label.text = "Level %d - %s" % [
            metadata.get("level", 1),
            metadata.get("date", "Unknown")
        ]
        load_button.disabled = false
        delete_button.disabled = false
    else:
        label.text = "Empty Slot"
        load_button.disabled = true
        delete_button.disabled = true

func _on_load_pressed() -> void:
    SaveManager.load_game(slot_number)

func _on_delete_pressed() -> void:
    SaveManager.delete_save(slot_number)
    _update_display()
```

### Custom Save Data

```gdscript
extends SaveManager

# Override to save custom game data
func _collect_player_data() -> Dictionary:
    var player = get_tree().get_first_node_in_group("player")
    if not player:
        return {}
    
    return {
        "health": player.health,
        "max_health": player.max_health,
        "position": {
            "x": player.global_position.x,
            "y": player.global_position.y,
            "z": player.global_position.z
        },
        "inventory": player.inventory.serialize(),
        "equipped_weapon": player.equipped_weapon.item_id if player.equipped_weapon else ""
    }

func _collect_world_data() -> Dictionary:
    return {
        "enemies_defeated": get_tree().get_nodes_in_group("enemy_defeated"),
        "items_collected": get_tree().get_nodes_in_group("item_collected"),
        "doors_unlocked": get_tree().get_nodes_in_group("door_unlocked")
    }

func _apply_player_data(player_data: Dictionary) -> void:
    var player = get_tree().get_first_node_in_group("player")
    if not player:
        return
    
    player.health = player_data.get("health", 100)
    player.max_health = player_data.get("max_health", 100)
    
    var pos_data = player_data.get("position", {})
    player.global_position = Vector3(
        pos_data.get("x", 0),
        pos_data.get("y", 0),
        pos_data.get("z", 0)
    )
    
    player.inventory.deserialize(player_data.get("inventory", {}))

func _apply_world_data(world_data: Dictionary) -> void:
    # Mark enemies as defeated
    var defeated_enemies = world_data.get("enemies_defeated", [])
    for enemy_id in defeated_enemies:
        var enemy = get_node_or_null(enemy_id)
        if enemy:
            enemy.queue_free()
    
    # Mark items as collected
    var collected_items = world_data.get("items_collected", [])
    for item_id in collected_items:
        var item = get_node_or_null(item_id)
        if item:
            item.queue_free()
```

### Auto-Save System

```gdscript
extends SaveManager

func _ready() -> void:
    super._ready()
    
    # Enable auto-save every 5 minutes
    auto_save_enabled = true
    auto_save_interval = 300.0
    
    # Subscribe to checkpoint events
    EventManager.subscribe("checkpoint_reached", _on_checkpoint_reached)

func _on_checkpoint_reached(data: Dictionary) -> void:
    # Manual save at checkpoints
    quick_save()
    NotificationManager.show_info("Progress Saved")
```

## Best Practices

1. **Use metadata** for save slot previews without loading full data
2. **Validate data** when loading to handle corrupted saves
3. **Provide multiple slots** for player choice
4. **Auto-save carefully** - don't auto-save during critical moments
5. **Show save status** via notifications or UI

## See Also

- [GameManager](GameManager.md) - For saving game state
- [NotificationManager](NotificationManager.md) - For save confirmations
