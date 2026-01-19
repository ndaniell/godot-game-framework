# SceneManager

Manages scene loading, unloading, preloading, transitions, and scene caching for optimized performance.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Signals](#signals)
- [Methods](#methods)
- [Virtual Methods](#virtual-methods)
- [Usage Examples](#usage-examples)

## Overview

Features:
- **Scene loading/unloading** with caching
- **Scene preloading** for faster transitions
- **Transition effects** (fade, slide, custom)
- **Scene caching** with configurable limits
- **Current scene tracking**

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `default_transition_duration` | float | 0.5 | Default transition duration in seconds |
| `enable_scene_caching` | bool | true | Enable scene caching |
| `max_cached_scenes` | int | 5 | Maximum number of cached scenes |

## Signals

```gdscript
signal scene_loaded(scene_path: String, scene_instance: Node)
signal scene_unloaded(scene_path: String)
signal scene_preloaded(scene_path: String, packed_scene: PackedScene)
signal transition_started(from_scene: String, to_scene: String, transition_type: String)
signal transition_completed(scene_path: String)
```

## Methods

### Scene Loading

#### `load_scene(scene_path: String, parent: Node = null, make_current: bool = false) -> Node`
Load and instance a scene.

#### `unload_scene(scene_path: String, remove_from_cache: bool = true) -> bool`
Unload a scene from memory.

#### `change_scene(scene_path: String, transition_type: String = "") -> void`
Change to a new scene with optional transition.

#### `reload_current_scene() -> void`
Reload the current scene.

### Scene Preloading

#### `preload_scene(scene_path: String) -> PackedScene`
Preload a scene into memory without instancing.

#### `unpreload_scene(scene_path: String) -> bool`
Remove a preloaded scene from memory.

### Scene Information

#### `get_loaded_scene(scene_path: String) -> Node`
Get a loaded scene instance.

#### `is_scene_loaded(scene_path: String) -> bool`
Check if a scene is loaded.

#### `is_scene_preloaded(scene_path: String) -> bool`
Check if a scene is preloaded.

#### `get_current_scene_path() -> String`
Get the current scene path.

#### `get_loaded_scene_paths() -> Array[String]`
Get all loaded scene paths.

#### `get_preloaded_scene_paths() -> Array[String]`
Get all preloaded scene paths.

### Cache Management

#### `clear_loaded_scenes() -> void`
Clear all loaded scenes from cache.

#### `clear_preloaded_scenes() -> void`
Clear all preloaded scenes from cache.

## Virtual Methods

### `_perform_transition(from_scene: String, to_scene: String, transition_type: String) -> void`
Override to create custom transitions.

### `_fade_transition(from_scene: String, to_scene: String) -> void`
Override to customize fade transition.

### `_slide_transition(from_scene: String, to_scene: String) -> void`
Override to customize slide transition.

## Usage Examples

### Basic Scene Changes

```gdscript
# Simple scene change
GGF.get_manager(&"SceneManager").change_scene("res://scenes/level2.tscn")

# Scene change with fade transition
GGF.get_manager(&"SceneManager").change_scene("res://scenes/menu.tscn", "fade")

# Reload current scene
GGF.get_manager(&"SceneManager").reload_current_scene()
```

### Preloading for Faster Loads

```gdscript
# Preload next level during gameplay
func _ready() -> void:
    var scene_manager := GGF.get_manager(&"SceneManager")
    scene_manager.preload_scene("res://scenes/level2.tscn")
    scene_manager.preload_scene("res://scenes/level3.tscn")

# Later, when changing scenes
func advance_to_next_level() -> void:
    GGF.get_manager(&"SceneManager").change_scene("res://scenes/level2.tscn", "fade")
```

### Custom Transitions

```gdscript
extends GGF_SceneManager

func _perform_transition(from_scene: String, to_scene: String, transition_type: String) -> void:
    match transition_type:
        "fade":
            await _custom_fade(from_scene, to_scene)
        "wipe":
            await _wipe_transition(from_scene, to_scene)
        _:
            get_tree().change_scene_to_file(to_scene)

func _custom_fade(from_scene: String, to_scene: String) -> void:
    # Create fade overlay
    var fade = ColorRect.new()
    fade.color = Color.BLACK
    fade.modulate.a = 0.0
    get_tree().root.add_child(fade)
    
    # Fade out
    var tween = create_tween()
    tween.tween_property(fade, "modulate:a", 1.0, 0.5)
    await tween.finished
    
    # Change scene
    get_tree().change_scene_to_file(to_scene)
    
    # Fade in
    tween = create_tween()
    tween.tween_property(fade, "modulate:a", 0.0, 0.5)
    await tween.finished
    
    fade.queue_free()
```

### Level Management System

```gdscript
class_name LevelManager extends Node

var levels: Array[String] = [
    "res://scenes/levels/level1.tscn",
    "res://scenes/levels/level2.tscn",
    "res://scenes/levels/level3.tscn"
]
var current_level_index: int = 0

func _ready() -> void:
    # Preload first two levels
    var scene_manager := GGF.get_manager(&"SceneManager")
    scene_manager.preload_scene(levels[0])
    if levels.size() > 1:
        scene_manager.preload_scene(levels[1])

func load_next_level() -> void:
    if current_level_index >= levels.size() - 1:
        # Game complete
        scene_manager.change_scene("res://scenes/victory.tscn", "fade")
        return
    
    current_level_index += 1
    
    # Preload next level if available
    if current_level_index + 1 < levels.size():
        scene_manager.preload_scene(levels[current_level_index + 1])
    
    # Load current level
    scene_manager.change_scene(levels[current_level_index], "fade")

func restart_level() -> void:
    scene_manager.change_scene(levels[current_level_index], "fade")
```

## Best Practices

1. **Preload next scenes** during gameplay for instant transitions
2. **Limit cache size** to avoid memory issues
3. **Use transitions** for polish
4. **Clear caches** when changing major game sections
5. **Track current scene** for save/load systems

## See Also

- [GameManager](GameManager.md) - Coordinates with scene changes
- [ResourceManager](ResourceManager.md) - For general resource loading
