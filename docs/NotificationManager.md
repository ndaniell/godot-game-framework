# NotificationManager

Manages toast notifications and system messages with customizable appearance and behavior.

## Table of Contents

- [Overview](#overview)
- [Enums](#enums)
- [Properties](#properties)
- [Signals](#signals)
- [Methods](#methods)
- [Virtual Methods](#virtual-methods)
- [Usage Examples](#usage-examples)

## Overview

Features:
- **Toast notifications** with auto-dismiss
- **Multiple notification types** (info, success, warning, error, custom)
- **Notification queue** when at max capacity
- **Customizable styling** through virtual methods
- **Click callbacks** for interactive notifications

## Enums

```gdscript
enum NotificationType {
    INFO,
    SUCCESS,
    WARNING,
    ERROR,
    CUSTOM
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `default_duration` | float | 3.0 | Default notification duration (seconds) |
| `max_notifications` | int | 5 | Maximum visible notifications |
| `notification_spacing` | float | 10.0 | Spacing between notifications |
| `position` | Vector2 | (20, 20) | Notification position on screen |
| `alignment` | Vector2 | (0, 0) | Alignment (0=top/left, 1=bottom/right) |

## Signals

```gdscript
signal notification_shown(notification_id: String, data: Dictionary)
signal notification_hidden(notification_id: String)
signal notification_clicked(notification_id: String)
```

## Methods

### Notification Display

#### `show_notification(message: String, type: NotificationType = INFO, duration: float = -1.0, data: Dictionary = {}) -> String`
Show a notification and return its ID.

#### `show_info(message: String, duration: float = -1.0, data: Dictionary = {}) -> String`
Show an info notification.

#### `show_success(message: String, duration: float = -1.0, data: Dictionary = {}) -> String`
Show a success notification.

#### `show_warning(message: String, duration: float = -1.0, data: Dictionary = {}) -> String`
Show a warning notification.

#### `show_error(message: String, duration: float = -1.0, data: Dictionary = {}) -> String`
Show an error notification.

### Notification Management

#### `hide_notification(notification_id: String) -> bool`
Manually hide a notification.

#### `hide_all_notifications() -> void`
Hide all active notifications.

#### `get_active_count() -> int`
Get number of active notifications.

#### `get_queued_count() -> int`
Get number of queued notifications.

## Virtual Methods

### `_create_notification_node(message: String, type: NotificationType, data: Dictionary) -> Control`
Override to create custom notification UI.

### `_set_notification_style(panel: Panel, type: NotificationType) -> void`
Override to customize notification styling per type.

### `_animate_notification_in(notification: Control) -> void`
Override to customize show animation.

### `_animate_notification_out(notification: Control, notification_id: String) -> void`
Override to customize hide animation.

## Usage Examples

### Basic Notifications

```gdscript
# Show different notification types
GGF.notifications().show_info("Game saved successfully")
GGF.notifications().show_success("Achievement unlocked!")
GGF.notifications().show_warning("Low health!")
GGF.notifications().show_error("Connection lost", 5.0)  # Show for 5 seconds
```

### Game Event Notifications

```gdscript
# Player events
func _on_player_level_up(new_level: int) -> void:
    GGF.notifications().show_success(
        "Level Up! You are now level %d" % new_level,
        3.0
    )

# Item pickup
func _on_item_collected(item_name: String) -> void:
    GGF.notifications().show_info(
        "Collected: %s" % item_name,
        2.0
    )

# Quest completion
func _on_quest_completed(quest_name: String, reward: int) -> void:
    GGF.notifications().show_success(
        "Quest Complete: %s (+%d XP)" % [quest_name, reward],
        4.0
    )
```

### Interactive Notifications

```gdscript
# Clickable notification with callback
func show_friend_request(friend_name: String) -> void:
    GGF.notifications().show_notification(
        "%s wants to be friends" % friend_name,
        GGF_NotificationManager.NotificationType.INFO,
        10.0,  # Show for 10 seconds
        {
            "on_click": func(): _accept_friend_request(friend_name),
            "hide_on_click": true
        }
    )

func _accept_friend_request(friend_name: String) -> void:
    # Accept friend request
    GGF.notifications().show_success("You are now friends with %s!" % friend_name)
```

### Custom Notification Manager

```gdscript
extends GGF_NotificationManager

# Custom notification styles
var notification_styles = {
    GGF_NotificationManager.NotificationType.INFO: {
        "color": Color(0.2, 0.6, 0.8),
        "icon": preload("res://ui/icons/info.png")
    },
    GGF_NotificationManager.NotificationType.SUCCESS: {
        "color": Color(0.2, 0.8, 0.3),
        "icon": preload("res://ui/icons/success.png")
    },
    GGF_NotificationManager.NotificationType.WARNING: {
        "color": Color(0.9, 0.7, 0.2),
        "icon": preload("res://ui/icons/warning.png")
    },
    GGF_NotificationManager.NotificationType.ERROR: {
        "color": Color(0.9, 0.2, 0.2),
        "icon": preload("res://ui/icons/error.png")
    }
}

func _create_notification_node(message: String, type: NotificationType, data: Dictionary) -> Control:
    var container = HBoxContainer.new()
    container.custom_minimum_size = Vector2(350, 70)
    
    # Background panel
    var panel = Panel.new()
    var style_box = StyleBoxFlat.new()
    style_box.bg_color = notification_styles[type].color
    style_box.corner_radius_top_left = 8
    style_box.corner_radius_top_right = 8
    style_box.corner_radius_bottom_left = 8
    style_box.corner_radius_bottom_right = 8
    panel.add_theme_stylebox_override("panel", style_box)
    container.add_child(panel)
    
    # Icon
    var icon = TextureRect.new()
    icon.texture = notification_styles[type].icon
    icon.custom_minimum_size = Vector2(32, 32)
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    container.add_child(icon)
    
    # Message label
    var label = Label.new()
    label.text = message
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    container.add_child(label)
    
    return container

func _animate_notification_in(notification: Control) -> void:
    # Slide in from right with bounce
    notification.modulate.a = 0.0
    notification.position.x += 100
    
    var tween = create_tween()
    tween.set_ease(Tween.EASE_OUT)
    tween.set_trans(Tween.TRANS_BACK)
    tween.parallel().tween_property(notification, "modulate:a", 1.0, 0.4)
    tween.parallel().tween_property(notification, "position:x", notification.position.x - 100, 0.4)

func _animate_notification_out(notification: Control, notification_id: String) -> void:
    # Slide out to right
    var tween = create_tween()
    tween.set_ease(Tween.EASE_IN)
    tween.set_trans(Tween.TRANS_CUBIC)
    tween.parallel().tween_property(notification, "modulate:a", 0.0, 0.3)
    tween.parallel().tween_property(notification, "position:x", notification.position.x + 100, 0.3)
    
    await tween.finished
    # Continue with cleanup...
```

### Achievement Notifications

```gdscript
class_name AchievementNotifier extends Node

func show_achievement(achievement_name: String, description: String, icon: Texture2D) -> void:
    GGF.notifications().show_notification(
        "%s\n%s" % [achievement_name, description],
        GGF_NotificationManager.NotificationType.SUCCESS,
        5.0,
        {
            "icon": icon,
            "sound": "achievement_unlock"
        }
    )
```

### Error Handling with Notifications

```gdscript
class_name GameErrorHandler extends Node

func _ready() -> void:
    # Subscribe to error events
    GGF.events().subscribe("network_error", _on_network_error)
    GGF.events().subscribe("save_error", _on_save_error)
    GGF.events().subscribe("load_error", _on_load_error)

func _on_network_error(data: Dictionary) -> void:
    var error = data.get("error", "Unknown error")
    GGF.notifications().show_error(
        "Network Error: %s" % error,
        5.0
    )

func _on_save_error(data: Dictionary) -> void:
    GGF.notifications().show_error(
        "Failed to save game. Please try again.",
        4.0
    )

func _on_load_error(data: Dictionary) -> void:
    GGF.notifications().show_error(
        "Failed to load save file.",
        4.0
    )
```

### Progress Notifications

```gdscript
class_name ProgressNotifier extends Node

var current_notification_id: String = ""

func show_progress(message: String) -> void:
    # Hide previous progress notification
    if not current_notification_id.is_empty():
        GGF.notifications().hide_notification(current_notification_id)
    
    # Show new one that doesn't auto-dismiss
    current_notification_id = GGF.notifications().show_info(
        message,
        999.0  # Very long duration
    )

func complete_progress(final_message: String) -> void:
    # Hide progress notification
    if not current_notification_id.is_empty():
        GGF.notifications().hide_notification(current_notification_id)
        current_notification_id = ""
    
    # Show completion
    GGF.notifications().show_success(final_message, 3.0)

# Usage
func download_assets() -> void:
    progress_notifier.show_progress("Downloading assets...")
    await asset_downloader.download_complete
    progress_notifier.complete_progress("Assets downloaded!")
```

### Notification Sound System

```gdscript
extends GGF_NotificationManager

var notification_sounds = {
    NotificationType.INFO: preload("res://audio/ui/notification_info.wav"),
    NotificationType.SUCCESS: preload("res://audio/ui/notification_success.wav"),
    NotificationType.WARNING: preload("res://audio/ui/notification_warning.wav"),
    NotificationType.ERROR: preload("res://audio/ui/notification_error.wav")
}

func _on_notification_shown(notification_id: String, message: String, type: NotificationType, data: Dictionary) -> void:
    # Play sound for notification type
    if notification_sounds.has(type):
        GGF.get_manager(&"AudioManager").play_sfx(notification_sounds[type], 0.7)
```

## Best Practices

1. **Use appropriate types** - Match notification type to message severity
2. **Keep messages concise** - Short, readable notifications
3. **Set reasonable durations** - 2-5 seconds for most notifications
4. **Limit max notifications** - Avoid cluttering the screen
5. **Use sounds sparingly** - Don't overwhelm with audio feedback
6. **Test positioning** - Ensure notifications don't cover important UI

## Integration

### With EventManager

Listen for game events and show notifications:
```gdscript
GGF.events().subscribe("achievement_unlocked", _on_achievement)
GGF.events().subscribe("player_died", _on_player_died)

func _on_achievement(data: Dictionary) -> void:
    GGF.notifications().show_success(
        "Achievement: %s" % data.get("name", "")
    )
```

### With SaveManager

Show save/load feedback:
```gdscript
GGF.get_manager(&"SaveManager").save_created.connect(
    func(slot, metadata):
        GGF.notifications().show_success("Game Saved!")
)

GGF.get_manager(&"SaveManager").save_failed.connect(
    func(slot, error):
        GGF.notifications().show_error("Save Failed: %s" % error)
)
```

## See Also

- [UIManager](UIManager.md) - For UI management
- [EventManager](EventManager.md) - For event-based notifications
- [AudioManager](AudioManager.md) - For notification sounds
