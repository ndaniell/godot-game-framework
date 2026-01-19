# ResourceManager

Manages resource loading, caching, preloading, and automatic memory management.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Signals](#signals)
- [Methods](#methods)
- [Usage Examples](#usage-examples)

## Overview

Features:
- **Resource caching** with configurable limits
- **Async loading** support
- **Resource preloading**
- **Reference counting**
- **Auto-unload** of unused resources

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_caching` | bool | true | Enable resource caching |
| `max_cache_size` | int | 100 | Maximum cached resources |
| `auto_unload_unused` | bool | false | Auto-unload unused resources |
| `unload_check_interval` | float | 60.0 | Unload check interval (seconds) |

## Signals

```gdscript
signal resource_loaded(resource_path: String, resource: Resource)
signal resource_unloaded(resource_path: String)
signal resource_preloaded(resource_path: String, resource: Resource)
signal cache_cleared()
```

## Methods

### Resource Loading

#### `load_resource(resource_path: String, use_cache: bool = true) -> Resource`
Load a resource with optional caching.

#### `load_resource_async(resource_path: String, use_cache: bool = true) -> Resource`
Load a resource asynchronously.

#### `unload_resource(resource_path: String, force: bool = false) -> bool`
Unload a resource from cache.

### Resource Preloading

#### `preload_resource(resource_path: String) -> Resource`
Preload a resource.

#### `unpreload_resource(resource_path: String) -> bool`
Remove a preloaded resource.

### Cache Management

#### `get_cached_resource(resource_path: String) -> Resource`
Get a cached resource without loading.

#### `is_resource_cached(resource_path: String) -> bool`
Check if a resource is cached.

#### `is_resource_preloaded(resource_path: String) -> bool`
Check if a resource is preloaded.

#### `get_cache_size() -> int`
Get number of cached resources.

#### `get_cached_paths() -> Array[String]`
Get all cached resource paths.

#### `get_preloaded_paths() -> Array[String]`
Get all preloaded resource paths.

#### `clear_cache() -> void`
Clear the resource cache.

#### `clear_preloaded() -> void`
Clear preloaded resources.

#### `get_ref_count(resource_path: String) -> int`
Get reference count for a resource.

## Usage Examples

### Basic Resource Loading

```gdscript
# Load with caching
var texture = GGF.get_manager(&"ResourceManager").load_resource("res://textures/player.png")
player_sprite.texture = texture

# Load without caching (for one-time use)
var temp_texture = GGF.get_manager(&"ResourceManager").load_resource("res://temp/splash.png", false)
```

### Async Loading

```gdscript
func load_level_async() -> void:
    var ui := GGF.get_manager(&"UIManager")
    var resources := GGF.get_manager(&"ResourceManager")
    ui.show_ui_element("loading_screen")
    
    # Load resources asynchronously
    var level_scene = await resources.load_resource_async("res://scenes/level.tscn")
    var tileset = await resources.load_resource_async("res://tilesets/world.tres")
    
    ui.hide_ui_element("loading_screen")
    get_tree().change_scene_to_packed(level_scene)
```

### Preloading System

```gdscript
class_name AssetPreloader extends Node

var assets_to_preload: Array[String] = [
    "res://textures/enemies/enemy1.png",
    "res://textures/enemies/enemy2.png",
    "res://audio/sfx/explosion.wav",
    "res://scenes/vfx/explosion.tscn"
]

func preload_all_assets() -> void:
    for asset_path in assets_to_preload:
        GGF.get_manager(&"ResourceManager").preload_resource(asset_path)
    print("Assets preloaded: ", assets_to_preload.size())

func _ready() -> void:
    preload_all_assets()
```

### Memory Management

```gdscript
extends GGF_ResourceManager

func _ready() -> void:
    super._ready()
    
    # Enable auto-cleanup
    auto_unload_unused = true
    unload_check_interval = 30.0  # Check every 30 seconds
    
    # Monitor cache size
    resource_loaded.connect(_on_resource_loaded)

func _on_resource_loaded(resource_path: String, resource: Resource) -> void:
    print("Cache size: %d/%d" % [get_cache_size(), max_cache_size])
    
    if get_cache_size() >= max_cache_size * 0.9:
        push_warning("Cache nearly full!")
```

### Level Loading System

```gdscript
class_name LevelLoader extends Node

var current_level: int = 0
var max_levels: int = 5

func _ready() -> void:
    # Preload first level
    _preload_level(current_level)
    # Preload next level
    _preload_level(current_level + 1)

func _preload_level(level_num: int) -> void:
    if level_num >= max_levels:
        return
    
    var level_path = "res://scenes/levels/level%d.tscn" % level_num
    GGF.get_manager(&"ResourceManager").preload_resource(level_path)

func load_next_level() -> void:
    current_level += 1
    
    if current_level >= max_levels:
        return
    
    # Load current (already preloaded)
    var level_scene = GGF.get_manager(&"ResourceManager").load_resource(
        "res://scenes/levels/level%d.tscn" % current_level
    )
    get_tree().change_scene_to_packed(level_scene)
    
    # Unload previous level
    if current_level > 0:
        GGF.get_manager(&"ResourceManager").unload_resource(
            "res://scenes/levels/level%d.tscn" % (current_level - 1)
        )
    
    # Preload next level
    _preload_level(current_level + 1)
```

## Best Practices

1. **Use caching** for frequently accessed resources
2. **Preload** resources before they're needed
3. **Monitor cache size** to avoid memory issues
4. **Unload** unused resources in large games
5. **Async loading** for large resources to avoid freezing

## See Also

- [SceneManager](SceneManager.md) - Scene-specific loading
- [PoolManager](PoolManager.md) - Object instance pooling
