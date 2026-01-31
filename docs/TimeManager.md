# TimeManager

Manages time scaling, custom timers, and optional day/night cycles for time-based game mechanics.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Signals](#signals)
- [Methods](#methods)
- [Usage Examples](#usage-examples)

## Overview

Features:
- **Time scaling** for slow motion/fast forward
- **Custom timers** with pause awareness
- **Game time tracking** (scaled and real time)
- **Day/night cycles** (optional)
- **Pause coordination** with GameManager

## Properties

### Time Configuration

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `time_scale` | float | 1.0 | Time scale multiplier (0.0-10.0) |
| `pause_aware_timers` | bool | true | Timers respect pause state |

### Time Tracking

| Property | Type | Description |
|----------|------|-------------|
| `game_time` | float | Total scaled game time |
| `real_time` | float | Total real (unscaled) time |
| `delta_time` | float | Scaled delta time |
| `unscaled_delta_time` | float | Unscaled delta time |

### Day/Night Cycle

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_day_night_cycle` | bool | false | Enable day/night cycle |
| `day_duration` | float | 300.0 | Day duration in seconds |
| `night_duration` | float | 300.0 | Night duration in seconds |
| `start_time` | float | 0.0 | Cycle start time (0.0-1.0) |

## Signals

```gdscript
signal time_scale_changed(old_scale: float, new_scale: float)
signal timer_completed(timer_id: String)
signal day_night_changed(is_day: bool)
signal time_cycle_changed(cycle_time: float)
```

## Methods

### Time Control

#### `set_time_scale(scale: float) -> void`
Set time scale (0.0-10.0).

#### `pause_time() -> void`
Set time scale to 0 (pause).

#### `resume_time() -> void`
Set time scale to 1 (normal).

#### `slow_motion(scale: float = 0.5, duration: float = 0.0) -> void`
Apply slow motion effect.

#### `fast_forward(scale: float = 2.0, duration: float = 0.0) -> void`
Apply fast forward effect.

### Timers

#### `create_timer(timer_id: String, duration: float, loop: bool = false) -> bool`
Create a custom timer.

#### `remove_timer(timer_id: String) -> bool`
Remove a timer.

#### `pause_timer(timer_id: String) -> bool`
Pause a timer.

#### `resume_timer(timer_id: String) -> bool`
Resume a paused timer.

#### `reset_timer(timer_id: String) -> bool`
Reset a timer to 0.

#### `get_timer_progress(timer_id: String) -> float`
Get timer progress (0.0-1.0).

#### `get_timer_remaining(timer_id: String) -> float`
Get remaining time in seconds.

#### `timer_exists(timer_id: String) -> bool`
Check if a timer exists.

#### `is_timer_paused(timer_id: String) -> bool`
Check if a timer is paused.

### Day/Night Cycle

#### `get_cycle_time() -> float`
Get cycle time (0.0-1.0).

#### `is_day() -> bool`
Check if it's daytime.

#### `is_night() -> bool`
Check if it's nighttime.

### Time Information

#### `format_time(seconds: float, include_milliseconds: bool = false) -> String`
Format time as HH:MM:SS string.

Note: To access time tracking values, use the public properties directly: `game_time`, `real_time`, `delta_time`, `unscaled_delta_time`.

## Virtual Methods

Override these methods to customize TimeManager behavior:

### `_on_time_manager_ready() -> void`
Called when TimeManager is ready.

### `_on_time_scale_changed(old_scale: float, new_scale: float) -> void`
Called when time scale changes.

### `_on_timer_created(timer_id: String, duration: float, loop: bool) -> void`
Called when a timer is created.

### `_on_timer_completed(timer_id: String) -> void`
Called when a timer completes. Default implementation handles special timers like "slow_motion_reset" and "fast_forward_reset".

### `_on_timer_removed(timer_id: String) -> void`
Called when a timer is removed.

### `_on_timer_paused(timer_id: String) -> void`
Called when a timer is paused.

### `_on_timer_resumed(timer_id: String) -> void`
Called when a timer is resumed.

### `_on_timer_reset(timer_id: String) -> void`
Called when a timer is reset.

### `_on_day_night_changed(is_day_time: bool) -> void`
Called when day/night state changes.

## Usage Examples

### Slow Motion Effect

```gdscript
func trigger_slow_motion() -> void:
    # Slow to 50% for 2 seconds
    var time_manager := GGF.get_manager(&"TimeManager")
    time_manager.slow_motion(0.5, 2.0)
    
    # Slow motion visual effects
    _apply_slow_mo_shader()
    await time_manager.timer_completed
    _remove_slow_mo_shader()
```

### Custom Timer System

```gdscript
class_name PowerupTimer extends Node

func activate_speed_boost(duration: float) -> void:
    player.speed *= 2.0
    
    var time_manager := GGF.get_manager(&"TimeManager")
    time_manager.create_timer("speed_boost", duration)
    time_manager.timer_completed.connect(_on_speed_boost_ended, CONNECT_ONE_SHOT)

func _on_speed_boost_ended(timer_id: String) -> void:
    if timer_id == "speed_boost":
        player.speed /= 2.0
        GGF.notifications().show_info("Speed Boost Ended")
```

### Playtime Tracker

```gdscript
class_name PlaytimeTracker extends Node

@export var save_slot: int = 0

func get_playtime() -> String:
    var time_manager := GGF.get_manager(&"TimeManager")
    return time_manager.format_time(time_manager.game_time)

func get_session_time() -> String:
    var time_manager := GGF.get_manager(&"TimeManager")
    return time_manager.format_time(time_manager.real_time)

func save_playtime() -> void:
    var time_manager := GGF.get_manager(&"TimeManager")
    GGF.get_manager(&"SaveManager").save_game(save_slot, {
        "playtime": time_manager.game_time,
        "formatted": get_playtime()
    })
```

### Day/Night Cycle

```gdscript
extends GGF_TimeManager

func _ready() -> void:
    super._ready()
    
    # Enable day/night cycle
    enable_day_night_cycle = true
    day_duration = 600.0     # 10 minutes
    night_duration = 300.0   # 5 minutes
    start_time = 0.25        # Start at dawn
    
    day_night_changed.connect(_on_day_night_changed)

func _on_day_night_changed(is_day_time: bool) -> void:
    if is_day_time:
        # Switch to day lighting
        _transition_to_day()
        GGF.events().emit("time_of_day", {"time": "day"})
    else:
        # Switch to night lighting
        _transition_to_night()
        GGF.events().emit("time_of_day", {"time": "night"})
        # Spawn night enemies
        GGF.events().emit("spawn_night_enemies", {})

func _transition_to_day() -> void:
    var tween = create_tween()
    tween.tween_property(sun_light, "light_energy", 1.0, 5.0)
    tween.parallel().tween_property(environment, "ambient_light_energy", 0.3, 5.0)

func _transition_to_night() -> void:
    var tween = create_tween()
    tween.tween_property(sun_light, "light_energy", 0.1, 5.0)
    tween.parallel().tween_property(environment, "ambient_light_energy", 0.05, 5.0)
```

### Cooldown System

```gdscript
class_name CooldownManager extends Node

var cooldowns: Dictionary = {}

func start_cooldown(ability_id: String, duration: float) -> void:
    var time_manager := GGF.get_manager(&"TimeManager")
    time_manager.create_timer("cooldown_" + ability_id, duration)
    cooldowns[ability_id] = duration
    time_manager.timer_completed.connect(_on_cooldown_complete)

func _on_cooldown_complete(timer_id: String) -> void:
    if timer_id.begins_with("cooldown_"):
        var ability_id = timer_id.replace("cooldown_", "")
        cooldowns.erase(ability_id)
        GGF.events().emit("cooldown_ready", {"ability": ability_id})

func is_on_cooldown(ability_id: String) -> bool:
    return cooldowns.has(ability_id)

func get_cooldown_remaining(ability_id: String) -> float:
    if not is_on_cooldown(ability_id):
        return 0.0
    return GGF.get_manager(&"TimeManager").get_timer_remaining("cooldown_" + ability_id)

func get_cooldown_progress(ability_id: String) -> float:
    if not is_on_cooldown(ability_id):
        return 1.0
    return GGF.get_manager(&"TimeManager").get_timer_progress("cooldown_" + ability_id)
```

### Time-Based Scoring

```gdscript
class_name SpeedrunTimer extends Control

@onready var time_label: Label = %TimeLabel

var start_time: float = 0.0
var running: bool = false

func start_speedrun() -> void:
    start_time = GGF.get_manager(&"TimeManager").game_time
    running = true

func stop_speedrun() -> float:
    running = false
    return GGF.get_manager(&"TimeManager").game_time - start_time

func _process(_delta: float) -> void:
    if running:
        var time_manager := GGF.get_manager(&"TimeManager")
        var elapsed = time_manager.game_time - start_time
        time_label.text = time_manager.format_time(elapsed, true)
```

## Best Practices

1. **Use custom timers** for game logic instead of Timer nodes
2. **Respect time scale** in game physics
3. **Coordinate with GameManager** for pause functionality
4. **Format time** for display using `format_time()`
5. **Day/night cycles** should transition smoothly

## Integration

### With GameManager

Time automatically pauses when game is paused:
```gdscript
GGF.get_manager(&"GameManager").pause_game()  # TimeManager.time_scale set to 0
GGF.get_manager(&"GameManager").unpause_game()  # TimeManager.time_scale restored
```

### With EventManager

TimeManager subscribes to pause events automatically.

## See Also

- [GameManager](GameManager.md) - Pause coordination
- [EventManager](EventManager.md) - Time events
