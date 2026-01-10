# docs/

This directory contains detailed documentation for each manager in the Godot Game Framework.

## Manager Documentation

Each manager has comprehensive documentation covering:

- **Overview** - What the manager does and key features
- **Properties** - Configurable export variables
- **Signals** - Events emitted by the manager
- **Methods** - Public API for interacting with the manager
- **Virtual Methods** - Override points for customization
- **Usage Examples** - Practical code examples
- **Integration** - How it works with other managers
- **Best Practices** - Recommended patterns and tips

## Available Manager Docs

### Core Managers

- **[AudioManager](AudioManager.md)** - Music, sound effects, and volume control
- **[GameManager](GameManager.md)** - Game state management, pause, and lifecycle
- **[SaveManager](SaveManager.md)** - Save/load system with multiple slots
- **[InputManager](InputManager.md)** - Input handling, remapping, and device detection
- **[SceneManager](SceneManager.md)** - Scene loading, transitions, and caching
- **[UIManager](UIManager.md)** - UI elements, menus, dialogs, and focus management

### System Managers

- **[EventManager](EventManager.md)** - Global event bus (pub/sub pattern)
- **[SettingsManager](SettingsManager.md)** - Graphics, audio, and gameplay settings
- **[ResourceManager](ResourceManager.md)** - Resource loading, caching, and pooling
- **[PoolManager](PoolManager.md)** - Object pooling for performance

### Utility Managers

- **[TimeManager](TimeManager.md)** - Time scaling, timers, and day/night cycles
- **[NotificationManager](NotificationManager.md)** - Toast notifications and system messages

## Quick Reference

### Common Patterns

All managers follow consistent patterns for extensibility:

1. **Virtual Methods** - Override `_on_*` methods to customize behavior
2. **Signals** - Subscribe to signals for reactive programming
3. **Export Variables** - Configure managers in the editor
4. **Safe Initialization** - Managers wait for dependencies before initializing

### Manager Communication

Managers communicate through:

- **EventManager** - For decoupled event-based communication
- **Direct References** - For tight integration (e.g., SettingsManager → AudioManager)
- **Signals** - For reactive updates

### Initialization Order

Managers initialize in autoload order. Use `await get_tree().process_frame` if you need to wait for other managers.

## Additional Resources

For additional information, see:

- **[README.md](../README.md)** - Project overview and quick start
- **[TESTING.md](../TESTING.md)** - Testing framework documentation

## Examples by Use Case

### Audio & Sound

- Play background music → [AudioManager](AudioManager.md)
- Adjust volume settings → [SettingsManager](SettingsManager.md)
- React to audio events → [EventManager](EventManager.md)

### Game Flow

- Change game states → [GameManager](GameManager.md)
- Load scenes → [SceneManager](SceneManager.md)
- Pause/unpause → [GameManager](GameManager.md) + [TimeManager](TimeManager.md)

### Data Persistence

- Save game data → [SaveManager](SaveManager.md)
- Store settings → [SettingsManager](SettingsManager.md)
- Load resources → [ResourceManager](ResourceManager.md)

### User Interface

- Show/hide UI elements → [UIManager](UIManager.md)
- Display notifications → [NotificationManager](NotificationManager.md)
- Handle input → [InputManager](InputManager.md)

### Performance Optimization

- Pool game objects → [PoolManager](PoolManager.md)
- Cache resources → [ResourceManager](ResourceManager.md)
- Preload scenes → [SceneManager](SceneManager.md)

### Time & Timing

- Slow motion effects → [TimeManager](TimeManager.md)
- Custom timers → [TimeManager](TimeManager.md)
- Day/night cycles → [TimeManager](TimeManager.md)

## Contributing

When extending or customizing managers:

1. Follow the established patterns
2. Use virtual methods for overrides
3. Document your custom behavior
4. Test with the included testing framework

## See Also

- [Godot Documentation](https://docs.godotengine.org/) - Official Godot docs
- Project repository for latest updates and issues
