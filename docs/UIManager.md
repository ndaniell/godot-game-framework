# UIManager

Manages UI elements, menus, dialogs, focus management, and UI layer organization.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Signals](#signals)
- [Methods](#methods)
- [Usage Examples](#usage-examples)

## Overview

Features:
- **UI element registration and management**
- **Menu/dialog stack management**
- **Focus tracking and restoration**
- **UI layer organization** (z-index management)
- **Show/hide with animations**

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `background_layer` | int | 0 | Z-index for background UI |
| `game_layer` | int | 1 | Z-index for game UI (HUD) |
| `ui_layer` | int | 2 | Z-index for standard UI |
| `menu_layer` | int | 3 | Z-index for menus |
| `dialog_layer` | int | 4 | Z-index for dialogs |
| `overlay_layer` | int | 5 | Z-index for overlays |

## Signals

```gdscript
signal ui_element_shown(element_name: String)
signal ui_element_hidden(element_name: String)
signal menu_opened(menu_name: String)
signal menu_closed(menu_name: String)
signal dialog_opened(dialog_name: String)
signal dialog_closed(dialog_name: String)
signal focus_changed(old_element: Control, new_element: Control)
```

## Methods

### UI Element Management

#### `register_ui_element(name: String, element: Control, layer: int = -1) -> void`
Register a UI element with the manager.

#### `unregister_ui_element(name: String) -> void`
Unregister a UI element.

#### `show_ui_element(name: String, fade_in: bool = false) -> void`
Show a registered UI element.

#### `hide_ui_element(name: String, fade_out: bool = false) -> void`
Hide a registered UI element.

#### `toggle_ui_element(name: String) -> void`
Toggle UI element visibility.

#### `get_ui_element(name: String) -> Control`
Get a registered UI element.

#### `is_ui_element_visible(name: String) -> bool`
Check if a UI element is visible.

### Menu Management

#### `open_menu(menu_name: String, close_others: bool = false) -> void`
Open a menu, optionally closing other menus.

#### `close_menu(menu_name: String) -> void`
Close a menu.

#### `close_all_menus() -> void`
Close all open menus.

#### `is_menu_open(menu_name: String) -> bool`
Check if a menu is open.

#### `get_open_menus() -> Array[String]`
Get all open menu names.

### Dialog Management

#### `open_dialog(dialog_name: String, modal: bool = true) -> void`
Open a dialog.

#### `close_dialog(dialog_name: String) -> void`
Close a dialog.

#### `close_all_dialogs() -> void`
Close all open dialogs.

#### `is_dialog_open(dialog_name: String) -> bool`
Check if a dialog is open.

#### `get_open_dialogs() -> Array[String]`
Get all open dialog names.

### Focus Management

#### `set_focus(element: Control) -> void`
Set focus to a UI element.

#### `restore_previous_focus() -> void`
Restore focus to the previous element.

#### `clear_focus() -> void`
Clear current focus.

#### `get_current_focus() -> Control`
Get the currently focused element.

## Usage Examples

### Setting Up UI

```gdscript
func _ready() -> void:
    # Register UI elements
    UIManager.register_ui_element("main_menu", $MainMenu, UIManager.menu_layer)
    UIManager.register_ui_element("pause_menu", $PauseMenu, UIManager.menu_layer)
    UIManager.register_ui_element("hud", $HUD, UIManager.game_layer)
    UIManager.register_ui_element("settings_dialog", $SettingsDialog, UIManager.dialog_layer)
    
    # Show HUD, hide menus
    UIManager.show_ui_element("hud")
    UIManager.hide_ui_element("main_menu")
    UIManager.hide_ui_element("pause_menu")
```

### Pause Menu

```gdscript
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        if GameManager.is_paused:
            UIManager.close_menu("pause_menu")
            GameManager.unpause_game()
        else:
            UIManager.open_menu("pause_menu")
            GameManager.pause_game()
```

### Menu System

```gdscript
class_name MainMenu extends Control

func _on_play_button_pressed() -> void:
    UIManager.close_menu("main_menu")
    GameManager.change_state("PLAYING")
    GameManager.change_scene("res://scenes/level1.tscn", "fade")

func _on_settings_button_pressed() -> void:
    UIManager.open_dialog("settings_dialog")

func _on_quit_button_pressed() -> void:
    GameManager.quit_game()
```

### Dialog System

```gdscript
class_name ConfirmDialog extends Control

signal confirmed
signal cancelled

func _ready() -> void:
    %ConfirmButton.pressed.connect(_on_confirm)
    %CancelButton.pressed.connect(_on_cancel)

func _on_confirm() -> void:
    confirmed.emit()
    UIManager.close_dialog(name)

func _on_cancel() -> void:
    cancelled.emit()
    UIManager.close_dialog(name)

# Usage
func show_delete_confirmation(save_slot: int) -> void:
    var dialog = UIManager.get_ui_element("confirm_dialog")
    dialog.confirmed.connect(func(): SaveManager.delete_save(save_slot))
    UIManager.open_dialog("confirm_dialog")
```

### Focus Management

```gdscript
func _ready() -> void:
    # Set initial focus
    UIManager.set_focus($MainMenu/PlayButton)
    
    # Listen for focus changes
    UIManager.focus_changed.connect(_on_focus_changed)

func _on_focus_changed(old_element: Control, new_element: Control) -> void:
    if old_element:
        old_element.modulate = Color.WHITE
    if new_element:
        new_element.modulate = Color.YELLOW
```

## Best Practices

1. **Register UI elements at startup** for centralized management
2. **Use layers** for proper Z-ordering
3. **Close menus properly** to maintain the menu stack
4. **Handle focus** for keyboard/gamepad navigation
5. **Use fade animations** for polish

## See Also

- [GameManager](GameManager.md) - For game state coordination
- [InputManager](InputManager.md) - For UI input handling
- [NotificationManager](NotificationManager.md) - For toast messages
