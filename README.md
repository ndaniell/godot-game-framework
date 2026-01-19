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
3. Enable the addon (or keep `GGF` autoload enabled)

## Quick Start

### Basic Usage

Managers are available via the single autoload bootstrapper `GGF`:

```gdscript
# Play music
GGF.get_manager(&"AudioManager").play_music(my_music_stream)

# Change game state
GGF.get_manager(&"GameManager").change_state("PLAYING")

# Save game
GGF.get_manager(&"SaveManager").save_game(0, {"level": 5, "score": 1000})

# Show notification
GGF.notifications().show_success("Level Complete!")

# Create object pool
var pool_manager := GGF.get_manager(&"PoolManager")
pool_manager.create_pool("bullets", bullet_prefab, 20)
var bullet = pool_manager.spawn("bullets", position)
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

### Core Managers

- **[AudioManager](docs/AudioManager.md)** - Music, sound effects, and volume control
- **[GameManager](docs/GameManager.md)** - Game state management, pause, and lifecycle
- **[SaveManager](docs/SaveManager.md)** - Save/load system with multiple slots
- **[InputManager](docs/InputManager.md)** - Input handling, remapping, and device detection
- **[SceneManager](docs/SceneManager.md)** - Scene loading, transitions, and caching
- **[UIManager](docs/UIManager.md)** - UI elements, menus, dialogs, and focus management

### System Managers

- **[EventManager](docs/EventManager.md)** - Global event bus (pub/sub pattern)
- **[SettingsManager](docs/SettingsManager.md)** - Graphics, audio, and gameplay settings
- **[ResourceManager](docs/ResourceManager.md)** - Resource loading, caching, and pooling
- **[PoolManager](docs/PoolManager.md)** - Object pooling for performance

### Utility Managers

- **[TimeManager](docs/TimeManager.md)** - Time scaling, timers, and day/night cycles
- **[NotificationManager](docs/NotificationManager.md)** - Toast notifications and system messages

### Quick Examples

```gdscript
# Audio
GGF.get_manager(&"AudioManager").play_music(music_stream, fade_in=true)
GGF.get_manager(&"AudioManager").play_sfx(sfx_stream)

# Game State
GGF.get_manager(&"GameManager").change_state("PLAYING")
GGF.get_manager(&"GameManager").pause_game()

# Save/Load
GGF.get_manager(&"SaveManager").save_game(0, {"level": 5})
GGF.get_manager(&"SaveManager").load_game(0)

# Events
GGF.events().subscribe("player_died", _on_player_died)
GGF.events().emit("player_died", {"score": 1000})

# UI
GGF.get_manager(&"UIManager").open_menu("main_menu")
GGF.notifications().show_success("Level Complete!")
```

For detailed documentation on each manager, see the **[docs/](docs/)** folder.

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
├── addons/
│   └── godot_game_framework/
│       ├── GGF.gd
│       ├── core/
│       │   ├── managers/
│       │   └── types/
│       ├── resources/
│       └── tests/
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
1. Open `addons/godot_game_framework/tests/TestScene.tscn` in Godot
2. Run the scene (F5)
3. View test results in the output console

## Documentation

For detailed information on each manager, see the **[docs/](docs/)** folder.

Each manager has comprehensive documentation including:
- Overview and features
- Properties and configuration
- Complete API reference
- Usage examples
- Best practices
- Integration guides

## Examples

This repository is focused on the addon itself; example gameplay projects live outside this repo.
