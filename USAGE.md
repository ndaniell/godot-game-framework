# Usage Guide

Detailed usage examples for all managers in the Godot Game Framework.

## Table of Contents

- [AudioManager](#audiomanager)
- [GameManager](#gamemanager)
- [SaveManager](#savemanager)
- [InputManager](#inputmanager)
- [SceneManager](#scenemanager)
- [UIManager](#uimanager)
- [SettingsManager](#settingsmanager)
- [EventManager](#eventmanager)
- [ResourceManager](#resourcemanager)
- [PoolManager](#poolmanager)
- [TimeManager](#timemanager)
- [NotificationManager](#notificationmanager)
- [Integration Examples](#integration-examples)

---

## AudioManager

Manages music, sound effects, and volume controls.

### Basic Usage

```gdscript
# Play music with fade in
var music_stream = load("res://audio/music/main_theme.ogg")
AudioManager.play_music(music_stream, fade_in=true, fade_duration=1.0)

# Play sound effect
var jump_sfx = load("res://audio/sfx/jump.ogg")
AudioManager.play_sfx(jump_sfx)

# Control volume
AudioManager.set_master_volume(0.8)  # 80% volume
AudioManager.set_music_volume(0.6)
AudioManager.set_sfx_volume(1.0)
```

### Advanced Usage

```gdscript
# Stop music with fade out
AudioManager.stop_music(fade_out=true, fade_duration=0.5)

# Check if music is playing
if AudioManager.is_music_playing():
    print("Music is currently playing")

# Get current music
var current = AudioManager.get_current_music()
```

### Extending AudioManager

```gdscript
extends AudioManager

var music_playlist: Array[AudioStream] = []
var current_track_index: int = 0

func _on_music_ended(stream: AudioStream) -> void:
    # Auto-play next track
    current_track_index = (current_track_index + 1) % music_playlist.size()
    play_music(music_playlist[current_track_index], fade_in=true)
```

---

## GameManager

Manages game state, pause, and scene transitions.

### Basic Usage

```gdscript
# Change game state
GameManager.change_state(GameManager.GameState.PLAYING)
GameManager.change_state(GameManager.GameState.PAUSED)
GameManager.change_state(GameManager.GameState.GAME_OVER)

# Pause/unpause
GameManager.pause_game()
GameManager.unpause_game()
GameManager.toggle_pause()

# Change scene
GameManager.change_scene("res://scenes/level2.tscn")
GameManager.change_scene("res://scenes/menu.tscn", "fade")
```

### State Management

```gdscript
# Check current state
if GameManager.is_in_state(GameManager.GameState.PLAYING):
    # Game is playing
    pass

# Get state name
var state_name = GameManager.get_state_name()  # "PLAYING"

# Quit game
GameManager.quit_game()

# Restart game
GameManager.restart_game()
```

### Extending GameManager

```gdscript
extends GameManager

func _on_game_over() -> void:
    # Show game over screen
    UIManager.open_menu("game_over_menu")
    
    # Save high score
    SaveManager.set_save_data({"high_score": current_score})
```

---

## SaveManager

Handles save/load functionality with multiple slots.

### Basic Usage

```gdscript
# Save game
var metadata = {
    "level": 5,
    "score": 10000,
    "player_name": "Player1"
}
SaveManager.save_game(0, metadata)

# Load game
if SaveManager.load_game(0):
    var data = SaveManager.get_current_save_data()
    print("Loaded level: ", data["game_data"]["level"])

# Quick save/load
SaveManager.quick_save()
SaveManager.quick_load()
```

### Save Slots

```gdscript
# Check if save exists
if SaveManager.save_exists(0):
    var metadata = SaveManager.get_save_metadata(0)
    print("Save date: ", metadata.get("timestamp", 0))

# Get all available saves
var saves = SaveManager.get_available_saves()  # [0, 1, 3]

# Delete save
SaveManager.delete_save(1)
```

### Custom Save Data

```gdscript
extends SaveManager

func _collect_game_data() -> Dictionary:
    var game_data := {
        "level": current_level,
        "score": current_score,
        "inventory": get_inventory_data(),
        "player_position": player.global_position
    }
    return game_data

func _apply_game_data(data: Dictionary) -> void:
    current_level = data.get("level", 1)
    current_score = data.get("score", 0)
    load_inventory(data.get("inventory", {}))
    player.global_position = data.get("player_position", Vector3.ZERO)
```

---

## InputManager

Handles input actions, remapping, and device detection.

### Basic Usage

```gdscript
# Check input
if InputManager.is_action_just_pressed("jump"):
    jump()

if InputManager.is_action_pressed("move_right"):
    move_right()

# Get input strength
var move_strength = InputManager.get_action_strength("move_forward")

# Get 2D movement vector
var movement = InputManager.get_action_vector(
    "move_left", "move_right", 
    "move_up", "move_down"
)
```

### Input Remapping

```gdscript
# Remap action
var new_key = InputEventKey.new()
new_key.keycode = KEY_SPACE
InputManager.remap_action("jump", new_key)

# Reset action to default
InputManager.reset_action("jump")

# Reset all actions
InputManager.reset_all_actions()
```

### Device Detection

```gdscript
# Check input device
if InputManager.is_using_gamepad():
    show_gamepad_hints()
elif InputManager.is_using_keyboard_mouse():
    show_keyboard_hints()

# Get device name
var device = InputManager.get_input_device_name()
print("Using: ", device)
```

---

## SceneManager

Manages scene loading, transitions, and caching.

### Basic Usage

```gdscript
# Load scene
var scene = SceneManager.load_scene("res://scenes/menu.tscn")

# Change scene with transition
SceneManager.change_scene("res://scenes/level1.tscn", "fade")
SceneManager.change_scene("res://scenes/menu.tscn", "slide")

# Preload scene
SceneManager.preload_scene("res://scenes/level2.tscn")
```

### Scene Management

```gdscript
# Check if scene is loaded
if SceneManager.is_scene_loaded("res://scenes/menu.tscn"):
    var menu = SceneManager.get_loaded_scene("res://scenes/menu.tscn")

# Unload scene
SceneManager.unload_scene("res://scenes/menu.tscn")

# Get all loaded scenes
var loaded = SceneManager.get_loaded_scene_paths()
```

### Custom Transitions

```gdscript
extends SceneManager

func _perform_transition(from_scene: String, to_scene: String, transition_type: String) -> void:
    match transition_type:
        "wipe":
            await _wipe_transition(from_scene, to_scene)
        _:
            await super._perform_transition(from_scene, to_scene, transition_type)
```

---

## UIManager

Manages UI elements, menus, dialogs, and focus.

### Basic Usage

```gdscript
# Register UI element
UIManager.register_ui_element("main_menu", main_menu_ui)

# Show/hide UI
UIManager.show_ui_element("main_menu", fade_in=true)
UIManager.hide_ui_element("main_menu", fade_out=true)

# Toggle visibility
UIManager.toggle_ui_element("main_menu")
```

### Menus

```gdscript
# Open menu
UIManager.open_menu("main_menu")
UIManager.open_menu("settings_menu", close_others=true)

# Close menu
UIManager.close_menu("main_menu")
UIManager.close_all_menus()

# Check if menu is open
if UIManager.is_menu_open("main_menu"):
    # Menu is visible
    pass
```

### Dialogs

```gdscript
# Open dialog
UIManager.open_dialog("confirm_dialog", modal=true)
UIManager.close_dialog("confirm_dialog")

# Check if dialog is open
if UIManager.is_dialog_open("confirm_dialog"):
    # Dialog is visible
    pass
```

### Focus Management

```gdscript
# Set focus
UIManager.set_focus(start_button)

# Restore previous focus
UIManager.restore_previous_focus()

# Clear focus
UIManager.clear_focus()
```

---

## SettingsManager

Manages game settings (graphics, audio, gameplay).

### Basic Usage

```gdscript
# Set settings
SettingsManager.set_setting("graphics", "fullscreen", true)
SettingsManager.set_setting("audio", "master_volume", 0.8)
SettingsManager.set_setting("gameplay", "difficulty", "hard")

# Get settings
var fullscreen = SettingsManager.get_setting("graphics", "fullscreen", false)
var volume = SettingsManager.get_setting("audio", "master_volume", 1.0)

# Save/load settings
SettingsManager.save_settings()
SettingsManager.load_settings()
```

### Graphics Settings

```gdscript
# Direct property access
SettingsManager.fullscreen = true
SettingsManager.vsync_mode = DisplayServer.VSYNC_ENABLED
SettingsManager.resolution = Vector2i(1920, 1080)
SettingsManager.window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
```

### Audio Settings

```gdscript
# Audio settings automatically apply to AudioManager
SettingsManager.master_volume = 0.8
SettingsManager.music_volume = 0.6
SettingsManager.sfx_volume = 1.0
```

### Reset Settings

```gdscript
# Reset to defaults
SettingsManager.reset_to_defaults()
```

---

## EventManager

Global event bus for decoupled communication.

### Basic Usage

```gdscript
# Subscribe to event
EventManager.subscribe("player_died", _on_player_died)

# Emit event
EventManager.emit("player_died", {"score": 1000, "level": 5})

# Unsubscribe
EventManager.unsubscribe("player_died", _on_player_died)
```

### Method-based Subscription

```gdscript
# Subscribe using method name
EventManager.subscribe_method("player_died", self, "_on_player_died")

# Unsubscribe
EventManager.unsubscribe_method("player_died", self, "_on_player_died")
```

### Event Handler

```gdscript
func _on_player_died(data: Dictionary) -> void:
    var score = data.get("score", 0)
    var level = data.get("level", 1)
    print("Player died at level ", level, " with score ", score)
    
    # Show game over screen
    GameManager.change_state(GameManager.GameState.GAME_OVER)
```

### Common Events

```gdscript
# Game events
EventManager.emit("game_paused", {"is_paused": true})
EventManager.emit("game_state_changed", {"state": "PLAYING"})

# Player events
EventManager.emit("player_health_changed", {"health": 50, "max_health": 100})
EventManager.emit("player_level_up", {"new_level": 5})

# UI events
EventManager.emit("menu_opened", {"menu": "main_menu"})
```

---

## ResourceManager

Handles resource loading, caching, and memory management.

### Basic Usage

```gdscript
# Load resource (cached)
var texture = ResourceManager.load_resource("res://textures/player.png")

# Load resource asynchronously
var texture = await ResourceManager.load_resource_async("res://textures/player.png")

# Preload resource
ResourceManager.preload_resource("res://scenes/level1.tscn")
```

### Resource Management

```gdscript
# Check if resource is cached
if ResourceManager.is_resource_cached("res://textures/player.png"):
    var texture = ResourceManager.get_cached_resource("res://textures/player.png")

# Unload resource
ResourceManager.unload_resource("res://textures/player.png", force=false)

# Clear cache
ResourceManager.clear_cache()
```

### Cache Statistics

```gdscript
# Get cache size
var size = ResourceManager.get_cache_size()

# Get cached paths
var paths = ResourceManager.get_cached_paths()
```

---

## PoolManager

Object pooling for improved performance.

### Basic Usage

```gdscript
# Create pool
var bullet_prefab = load("res://prefabs/bullet.tscn")
PoolManager.create_pool("bullets", bullet_prefab, initial_size=20)

# Spawn object
var bullet = PoolManager.spawn("bullets", position)

# Despawn object
PoolManager.despawn("bullets", bullet)
```

### Pool Management

```gdscript
# Get pool statistics
var stats = PoolManager.get_pool_stats("bullets")
print("Active: ", stats["active_count"])
print("Inactive: ", stats["inactive_count"])

# Expand pool
PoolManager.expand_pool("bullets", 10)

# Clear pool
PoolManager.clear_pool("bullets")

# Remove pool
PoolManager.remove_pool("bullets")
```

### Custom Object Reset

```gdscript
extends Node

func reset() -> void:
    # Reset object state when spawned from pool
    health = max_health
    position = Vector3.ZERO

func cleanup() -> void:
    # Cleanup when despawned
    pass
```

---

## TimeManager

Time scaling, timers, and time-based mechanics.

### Basic Usage

```gdscript
# Time scaling
TimeManager.set_time_scale(0.5)  # Slow motion (50%)
TimeManager.set_time_scale(2.0)  # Fast forward (200%)
TimeManager.pause_time()  # Pause (0%)
TimeManager.resume_time()  # Normal (100%)

# Slow motion effect
TimeManager.slow_motion(0.5, duration=2.0)  # 50% speed for 2 seconds

# Fast forward
TimeManager.fast_forward(2.0, duration=5.0)  # 2x speed for 5 seconds
```

### Timers

```gdscript
# Create timer
TimeManager.create_timer("powerup", duration=10.0, loop=false)

# Check timer
var progress = TimeManager.get_timer_progress("powerup")  # 0.0 to 1.0
var remaining = TimeManager.get_timer_remaining("powerup")  # seconds

# Pause/resume timer
TimeManager.pause_timer("powerup")
TimeManager.resume_timer("powerup")

# Reset timer
TimeManager.reset_timer("powerup")

# Remove timer
TimeManager.remove_timer("powerup")
```

### Day/Night Cycle

```gdscript
# Enable day/night cycle
TimeManager.enable_day_night_cycle = true
TimeManager.day_duration = 300.0  # 5 minutes
TimeManager.night_duration = 300.0

# Check time
if TimeManager.is_day():
    # Daytime logic
    pass
elif TimeManager.is_night():
    # Nighttime logic
    pass

# Get cycle time (0.0 to 1.0)
var cycle_time = TimeManager.get_cycle_time()
```

### Time Utilities

```gdscript
# Get time values
var game_time = TimeManager.get_game_time()
var real_time = TimeManager.get_real_time()
var delta = TimeManager.get_delta_time()

# Format time
var time_string = TimeManager.format_time(125.5)  # "00:02:05"
var time_with_ms = TimeManager.format_time(125.5, include_milliseconds=true)  # "00:02:05.500"
```

---

## NotificationManager

Toast notifications and system messages.

### Basic Usage

```gdscript
# Show notifications
NotificationManager.show_info("Item collected")
NotificationManager.show_success("Level complete!")
NotificationManager.show_warning("Low health")
NotificationManager.show_error("Connection failed")

# With duration
NotificationManager.show_info("Message", duration=5.0)
```

### Custom Notifications

```gdscript
# Show with custom data
var data = {
    "on_click": Callable(self, "_on_notification_clicked"),
    "hide_on_click": true
}
NotificationManager.show_notification(
    "Click me!",
    NotificationManager.NotificationType.INFO,
    duration=10.0,
    data=data
)
```

### Notification Management

```gdscript
# Hide notification
NotificationManager.hide_notification(notification_id)

# Hide all
NotificationManager.hide_all_notifications()

# Get counts
var active = NotificationManager.get_active_count()
var queued = NotificationManager.get_queued_count()
```

---

## Integration Examples

### Settings → Audio Integration

```gdscript
# Settings automatically apply to AudioManager
SettingsManager.set_setting("audio", "master_volume", 0.8)
# AudioManager volume is automatically updated
```

### Game Pause → Time Integration

```gdscript
# When game is paused, TimeManager automatically pauses timers
GameManager.pause_game()
# All TimeManager timers are paused (if pause_aware_timers is enabled)
```

### Event-Driven Architecture

```gdscript
# Player script
func take_damage(amount: int) -> void:
    health -= amount
    EventManager.emit("player_health_changed", {"health": health, "max_health": max_health})
    
    if health <= 0:
        EventManager.emit("player_died", {"score": score})

# UI script
func _ready() -> void:
    EventManager.subscribe("player_health_changed", _on_health_changed)
    EventManager.subscribe("player_died", _on_player_died)

func _on_health_changed(data: Dictionary) -> void:
    var health = data.get("health", 0)
    health_bar.value = health

func _on_player_died(data: Dictionary) -> void:
    UIManager.open_menu("game_over_menu")
```

### Complete Game Flow Example

```gdscript
extends Node

func _ready() -> void:
    # Setup
    SettingsManager.load_settings()
    EventManager.subscribe("level_complete", _on_level_complete)
    
    # Start game
    GameManager.change_state(GameManager.GameState.PLAYING)
    AudioManager.play_music(level_music, fade_in=true)
    
    # Preload next level
    SceneManager.preload_scene("res://scenes/level2.tscn")

func _on_level_complete(data: Dictionary) -> void:
    var level = data.get("level", 1)
    var score = data.get("score", 0)
    
    # Show notification
    NotificationManager.show_success("Level %d Complete!" % level)
    
    # Save progress
    SaveManager.save_game(0, {
        "level": level + 1,
        "score": score
    })
    
    # Transition to next level
    await get_tree().create_timer(2.0).timeout
    SceneManager.change_scene("res://scenes/level%d.tscn" % (level + 1), "fade")
```

---

For API reference, see [API.md](API.md).
