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
signal ui_ready
```

Emitted when the UIManager is ready.

## Methods

### UI Element Management

#### `register_ui_element(name: String, element: Control, layer: int = -1) -> void`
Register a UI element with the manager.

#### `register_ui_scene(element_name: String, scene: PackedScene, z_layer: int = -1) -> Control`
Register a UI element from a PackedScene. Returns the instantiated Control or null on error.

#### `unregister_ui_element(name: String) -> void`
Unregister a UI element.

#### `show_ui_element(name: String, fade_in: bool = false) -> void`
Show a registered UI element.

#### `hide_ui_element(name: String, fade_out: bool = false) -> void`
Hide a registered UI element.

#### `get_ui_element(name: String) -> Control`
Get a registered UI element.

#### `is_ui_element_visible(name: String) -> bool`
Check if a UI element is visible.

#### `is_ready() -> bool`
Check if the UIManager is ready.

#### `get_overlay_container() -> Control`
Get the overlay layer container.

#### `get_layer_container(z_layer: int) -> Control`
Get the container Control for a specific layer (z-index).

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

## Virtual Methods

Override these methods to customize UIManager behavior:

### `_on_ui_manager_ready() -> void`
Called when UIManager is ready.

### `_on_ui_element_registered(name: String, element: Control) -> void`
Called when a UI element is registered.

### `_on_ui_element_unregistered(name: String, element: Control) -> void`
Called when a UI element is unregistered.

### `_on_ui_element_shown(name: String, element: Control) -> void`
Called when a UI element is shown.

### `_on_ui_element_hidden(name: String, element: Control) -> void`
Called when a UI element is hidden.

### `_on_menu_opened(menu_name: String) -> void`
Called when a menu is opened.

### `_on_menu_closed(menu_name: String) -> void`
Called when a menu is closed.

### `_on_menu_focus_restored(menu_name: String) -> void`
Called when focus is restored to a previous menu in the stack.

### `_on_dialog_opened(dialog_name: String) -> void`
Called when a dialog is opened.

### `_on_dialog_closed(dialog_name: String) -> void`
Called when a dialog is closed.

### `_on_focus_changed(old_element: Control, new_element: Control) -> void`
Called when focus changes between UI elements.

## Usage Examples

### Setting Up UI

```gdscript
func _ready() -> void:
    var ui := GGF.get_manager(&"UIManager")
    # Register UI elements
    ui.register_ui_element("main_menu", $MainMenu, ui.menu_layer)
    ui.register_ui_element("pause_menu", $PauseMenu, ui.menu_layer)
    ui.register_ui_element("hud", $HUD, ui.game_layer)
    ui.register_ui_element("settings_dialog", $SettingsDialog, ui.dialog_layer)
    
    # Show HUD, hide menus
    ui.show_ui_element("hud")
    ui.hide_ui_element("main_menu")
    ui.hide_ui_element("pause_menu")
```

### Pause Menu

```gdscript
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        var gm := GGF.get_manager(&"GameManager")
        var ui := GGF.get_manager(&"UIManager")
        if gm.is_paused:
            ui.close_menu("pause_menu")
            gm.unpause_game()
        else:
            ui.open_menu("pause_menu")
            gm.pause_game()
```

### Menu System

```gdscript
class_name MainMenu extends Control

func _on_play_button_pressed() -> void:
    var ui := GGF.get_manager(&"UIManager")
    var gm := GGF.get_manager(&"GameManager")
    ui.close_menu("main_menu")
    gm.change_state("PLAYING")
    gm.change_scene("res://scenes/level1.tscn", "fade")

func _on_settings_button_pressed() -> void:
    GGF.get_manager(&"UIManager").open_dialog("settings_dialog")

func _on_quit_button_pressed() -> void:
    GGF.get_manager(&"GameManager").quit_game()
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
    GGF.get_manager(&"UIManager").close_dialog(name)

func _on_cancel() -> void:
    cancelled.emit()
    GGF.get_manager(&"UIManager").close_dialog(name)

# Usage
func show_delete_confirmation(save_slot: int) -> void:
    var ui := GGF.get_manager(&"UIManager")
    var dialog = ui.get_ui_element("confirm_dialog")
    dialog.confirmed.connect(func(): GGF.get_manager(&"SaveManager").delete_save(save_slot))
    ui.open_dialog("confirm_dialog")
```

### Focus Management

```gdscript
func _ready() -> void:
    # Set initial focus
    GGF.get_manager(&"UIManager").set_focus($MainMenu/PlayButton)
    
    # Listen for focus changes
    GGF.get_manager(&"UIManager").focus_changed.connect(_on_focus_changed)

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

## Customization (Scenes + Overrides)

The framework can optionally build its UI structure from scenes, and allows host projects to override those scenes.

### Override config file

- **Project override**: create `res://ggf_ui_config.tres`
- **Fallback**: `res://addons/godot_game_framework/resources/ui/ggf_ui_config_default.tres`

The config resource type is `GGF_UIConfig` (`addons/godot_game_framework/core/types/UIConfig.gd`).

### Shipped default scenes

The addon ships these scenes under `addons/godot_game_framework/resources/ui/`:

- `UIRoot.tscn` (layer containers: `Background`, `Game`, `UI`, `Menu`, `Dialog`, `Overlay`)
- `NotificationToast.tscn` + `NotificationToast.gd`
- Templates: `MenuTemplate.tscn`, `DialogTemplate.tscn`, `ConfirmDialogTemplate.tscn`, `SettingsDialogTemplate.tscn`

### Register UI from scenes

`UIManager` includes `register_ui_scene(name, packed_scene, layer)` which instances a `PackedScene` (must be a `Control`) and registers it like `register_ui_element(...)`.

## See Also

- [GameManager](GameManager.md) - For game state coordination
- [InputManager](InputManager.md) - For UI input handling
- [NotificationManager](NotificationManager.md) - For toast messages
