# InputManager

Manages input handling, action remapping, device detection, and input mode tracking.

## Table of Contents

- [Overview](#overview)
- [Enums](#enums)
- [Properties](#properties)
- [Signals](#signals)
- [Methods](#methods)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)

## Overview

The `InputManager` provides comprehensive input management including:

- **Input action checking** with convenience methods
- **Action remapping** at runtime
- **Device detection** (keyboard/mouse, gamepad, touch)
- **Input mode tracking** with automatic detection
- **Persistent remaps** saved to disk

## Enums

```gdscript
enum InputMode {
    KEYBOARD_MOUSE,
    GAMEPAD,
    TOUCH,
    AUTO
}
```

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `current_input_mode` | InputMode | `AUTO` | Current input device mode |

## Signals

```gdscript
signal input_action_pressed(action: String)
signal input_action_released(action: String)
signal input_remapped(action: String, old_event: InputEvent, new_event: InputEvent)
signal input_mode_changed(mode: String)
```

## Methods

### Input Checking

#### `is_action_pressed(action: String) -> bool`
Check if an action is currently pressed.

#### `is_action_just_pressed(action: String) -> bool`
Check if an action was just pressed this frame.

#### `is_action_just_released(action: String) -> bool`
Check if an action was just released this frame.

#### `get_action_strength(action: String) -> float`
Get action strength (0.0-1.0) for analog inputs.

#### `get_action_vector(negative_x, positive_x, negative_y, positive_y, exact=false) -> Vector2`
Get a 2D vector from four actions (useful for movement).

### Input Remapping

#### `remap_action(action: String, event: InputEvent, remove_old: bool = true) -> bool`
Remap an action to a new input event.

**Example:**
```gdscript
var new_key = InputEventKey.new()
new_key.keycode = KEY_SPACE
GGF.get_manager(&"InputManager").remap_action("jump", new_key)
```

#### `reset_action(action: String) -> bool`
Reset an action to its default mapping.

#### `reset_all_actions() -> void`
Reset all actions to defaults.

#### `get_action_remaps(action: String) -> Array`
Get all remapped events for an action.

### Device Information

#### `get_input_device_name() -> String`
Get the current input device name.

#### `is_using_gamepad() -> bool`
Check if using a gamepad.

#### `is_using_keyboard_mouse() -> bool`
Check if using keyboard/mouse.

#### `is_using_touch() -> bool`
Check if using touch controls.

## Usage Examples

### Basic Input Checking

```gdscript
func _process(_delta: float) -> void:
    var input := GGF.get_manager(&"InputManager")
    if input.is_action_just_pressed("jump"):
        player.jump()
    
    if input.is_action_pressed("shoot"):
        player.shoot()
    
    # Get movement vector
    var input_vector = input.get_action_vector(
        "move_left", "move_right",
        "move_up", "move_down"
    )
    player.move(input_vector)
```

### Action Remapping UI

```gdscript
class_name InputRemapButton extends Button

@export var action_name: String = ""
var awaiting_input: bool = false

func _ready() -> void:
    pressed.connect(_on_button_pressed)
    _update_button_text()

func _on_button_pressed() -> void:
    awaiting_input = true
    text = "Press any key..."

func _input(event: InputEvent) -> void:
    if not awaiting_input:
        return
    
    if event is InputEventKey and event.pressed:
        GGF.get_manager(&"InputManager").remap_action(action_name, event)
        awaiting_input = false
        _update_button_text()
        accept_event()

func _update_button_text() -> void:
    var remaps = GGF.get_manager(&"InputManager").get_action_remaps(action_name)
    if remaps.is_empty():
        text = "Unbound"
    else:
        var event = remaps[0] as InputEventKey
        text = OS.get_keycode_string(event.keycode)
```

### Device-Specific UI

```gdscript
extends Control

func _ready() -> void:
    GGF.get_manager(&"InputManager").input_mode_changed.connect(_on_input_mode_changed)
    _update_button_prompts()

func _on_input_mode_changed(mode: String) -> void:
    _update_button_prompts()

func _update_button_prompts() -> void:
    if GGF.get_manager(&"InputManager").is_using_gamepad():
        %JumpButton.text = "[A] Jump"
        %ShootButton.text = "[X] Shoot"
    else:
        %JumpButton.text = "[Space] Jump"
        %ShootButton.text = "[LMB] Shoot"
```

## Best Practices

1. **Use InputManager methods** instead of direct Input calls for consistent signal emission
2. **Save remaps** - InputManager automatically saves remaps to disk
3. **Provide reset options** - Allow players to reset controls to defaults
4. **Show current bindings** - Display mapped keys in your settings UI
5. **Handle conflicts** - InputManager automatically removes conflicting bindings

## See Also

- [UIManager](UIManager.md) - For creating input settings UI
- [EventManager](EventManager.md) - Input events can be propagated
