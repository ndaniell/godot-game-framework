# Godot Game Framework

A comprehensive, extensible game framework for Godot 4.5+ that provides essential managers and systems for rapid game development.

## Features

### Core Managers

- **AudioManager** - Music, sound effects, and volume control
- **GameManager** - Game state management, pause, and lifecycle
- **SaveManager** - Save/load system with multiple slots
- **InputManager** - Input handling, remapping, and device detection
- **SceneManager** - Scene loading, transitions, and caching
- **UIManager** - UI elements, menus, dialogs, and focus management
- **SettingsManager** - Graphics, audio, and gameplay settings
- **EventManager** - Global event bus (pub/sub pattern)
- **ResourceManager** - Resource loading, caching, and pooling
- **PoolManager** - Object pooling for performance
- **TimeManager** - Time scaling, timers, and day/night cycles
- **NotificationManager** - Toast notifications and system messages

### Key Features

- ✅ **Extensible** - All managers use virtual methods for easy customization
- ✅ **Integrated** - Managers communicate through EventManager
- ✅ **Type-safe** - Full GDScript type hints
- ✅ **Well-documented** - Comprehensive inline documentation
- ✅ **Production-ready** - Error handling and validation throughout

## Installation

1. Clone or download this repository
2. Open the project in Godot 4.5 or later
3. All managers are automatically loaded as autoload singletons

## Quick Start

### Basic Usage

All managers are available globally as autoload singletons:

```gdscript
# Play music
AudioManager.play_music(my_music_stream)

# Change game state
GameManager.change_state(GameManager.GameState.PLAYING)

# Save game
SaveManager.save_game(0, {"level": 5, "score": 1000})

# Show notification
NotificationManager.show_success("Level Complete!")

# Create object pool
PoolManager.create_pool("bullets", bullet_prefab, 20)
var bullet = PoolManager.spawn("bullets", position)
```

### Extending Managers

All managers are designed to be extended. Override virtual methods to add custom behavior:

```gdscript
extends AudioManager

func _on_music_started(stream: AudioStream) -> void:
    print("Now playing: ", stream.resource_path)
    # Add custom logic here
```

## Manager Overview

### AudioManager
Handles all audio playback including music, sound effects, and volume control.

```gdscript
AudioManager.play_music(music_stream, fade_in=true)
AudioManager.play_sfx(sfx_stream)
AudioManager.set_master_volume(0.8)
```

### GameManager
Manages game state, pause functionality, and scene transitions.

```gdscript
GameManager.change_state(GameManager.GameState.PLAYING)
GameManager.pause_game()
GameManager.change_scene("res://scenes/level2.tscn")
```

### SaveManager
Provides save/load functionality with multiple save slots.

```gdscript
SaveManager.save_game(0, {"level": 5})
SaveManager.load_game(0)
SaveManager.delete_save(1)
```

### InputManager
Handles input actions, remapping, and device detection.

```gdscript
if InputManager.is_action_just_pressed("jump"):
    jump()
    
InputManager.remap_action("jump", new_key_event)
```

### SceneManager
Manages scene loading, unloading, and transitions.

```gdscript
SceneManager.load_scene("res://scenes/menu.tscn")
SceneManager.change_scene("res://scenes/level1.tscn", "fade")
SceneManager.preload_scene("res://scenes/level2.tscn")
```

### UIManager
Handles UI elements, menus, dialogs, and focus management.

```gdscript
UIManager.register_ui_element("main_menu", menu_ui)
UIManager.open_menu("main_menu")
UIManager.set_focus(button_node)
```

### SettingsManager
Manages game settings including graphics, audio, and gameplay.

```gdscript
SettingsManager.set_setting("graphics", "fullscreen", true)
SettingsManager.set_setting("audio", "master_volume", 0.8)
SettingsManager.save_settings()
```

### EventManager
Global event bus for decoupled communication between systems.

```gdscript
EventManager.subscribe("player_died", _on_player_died)
EventManager.emit("player_died", {"score": 1000})
```

### ResourceManager
Handles resource loading, caching, and memory management.

```gdscript
var texture = ResourceManager.load_resource("res://textures/player.png")
ResourceManager.preload_resource("res://scenes/level1.tscn")
```

### PoolManager
Object pooling system for improved performance.

```gdscript
PoolManager.create_pool("bullets", bullet_prefab, 20)
var bullet = PoolManager.spawn("bullets", position)
PoolManager.despawn("bullets", bullet)
```

### TimeManager
Time scaling, timers, and time-based mechanics.

```gdscript
TimeManager.slow_motion(0.5, 2.0)  # 50% speed for 2 seconds
TimeManager.create_timer("powerup", 10.0, false)
TimeManager.set_time_scale(2.0)  # Fast forward
```

### NotificationManager
Toast notifications and system messages.

```gdscript
NotificationManager.show_success("Level Complete!")
NotificationManager.show_error("Connection failed", 5.0)
NotificationManager.show_info("New item collected")
```

## Integration

Managers are designed to work together seamlessly:

- **SettingsManager** ↔ **AudioManager** - Settings automatically apply to audio
- **GameManager** ↔ **TimeManager** - Pause state coordinates with time scaling
- **EventManager** - All managers can communicate through events

## Architecture

### Extensibility Pattern

All managers follow a consistent pattern:

1. **Virtual Methods** - Override `_on_*` methods to customize behavior
2. **Signals** - Subscribe to signals for reactive programming
3. **Export Variables** - Configure managers in the editor
4. **Safe Initialization** - Managers wait for dependencies before initializing

### Example: Custom AudioManager

```gdscript
extends AudioManager

func _on_music_started(stream: AudioStream) -> void:
    # Custom behavior when music starts
    print("Playing: ", stream.resource_path)
    
func _on_music_ended(stream: AudioStream) -> void:
    # Auto-play next track in playlist
    play_next_track()
```

## Requirements

- Godot 4.5 or later
- GDScript support

## Project Structure

```
godot-game-framework/
├── scripts/
│   └── autoload/
│       ├── AudioManager.gd
│       ├── GameManager.gd
│       ├── SaveManager.gd
│       ├── InputManager.gd
│       ├── SceneManager.gd
│       ├── UIManager.gd
│       ├── SettingsManager.gd
│       ├── EventManager.gd
│       ├── ResourceManager.gd
│       ├── PoolManager.gd
│       ├── TimeManager.gd
│       └── NotificationManager.gd
├── project.godot
└── README.md
```

## Contributing

This is a framework designed to be extended. Feel free to:

1. Extend managers with your own functionality
2. Add new managers following the same pattern
3. Customize virtual methods for your game's needs

## License

This framework is provided as-is for use in your projects.

## Testing

The framework includes a comprehensive testing system. See [TESTING.md](TESTING.md) for details.

To run tests:
1. Open `scenes/test/TestScene.tscn` in Godot
2. Run the scene (F5)
3. View test results in the output console

## Support

For detailed usage examples, see [USAGE.md](USAGE.md).

For API reference, see [API.md](API.md).

For testing documentation, see [TESTING.md](TESTING.md).
