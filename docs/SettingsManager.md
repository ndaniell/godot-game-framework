# SettingsManager

Manages game settings including graphics, audio, and gameplay preferences with persistent storage.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Signals](#signals)
- [Methods](#methods)
- [Usage Examples](#usage-examples)

## Overview

Features:
- **Graphics settings** (resolution, fullscreen, vsync)
- **Audio settings** (volume controls)
- **Gameplay settings** (difficulty, language)
- **Auto-save** on changes
- **Integration** with AudioManager for volume

## Properties

### Configuration

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `settings_file_path` | String | `"user://settings.save"` | Path to settings file |
| `auto_save` | bool | true | Auto-save on setting changes |

### Graphics

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `fullscreen` | bool | false | Fullscreen mode |
| `vsync_mode` | VSyncMode | `ENABLED` | VSync mode |
| `resolution` | Vector2i | (1920, 1080) | Window resolution |
| `window_mode` | WindowMode | `WINDOWED` | Window mode |

### Audio

| Property | Type | Range | Description |
|----------|------|-------|-------------|
| `master_volume` | float | 0.0-1.0 | Master volume |
| `music_volume` | float | 0.0-1.0 | Music volume |
| `sfx_volume` | float | 0.0-1.0 | SFX volume |

### Gameplay

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `difficulty` | String | "normal" | Game difficulty |
| `language` | String | "en" | Game language code |

## Signals

```gdscript
signal setting_changed(category: String, key: String, value: Variant)
signal graphics_settings_changed(settings: Dictionary)
signal audio_settings_changed(settings: Dictionary)
signal gameplay_settings_changed(settings: Dictionary)
signal settings_loaded()
signal settings_saved()
```

## Methods

### Settings Management

#### `set_setting(category: String, key: String, value: Variant) -> void`
Set a setting value.

#### `get_setting(category: String, key: String, default_value: Variant = null) -> Variant`
Get a setting value.

#### `load_settings() -> bool`
Load settings from file.

#### `save_settings() -> bool`
Save settings to file.

#### `reset_to_defaults() -> void`
Reset all settings to defaults.

### Settings Retrieval

#### `get_all_settings() -> Dictionary`
Get all settings as a dictionary.

#### `get_graphics_settings() -> Dictionary`
Get graphics settings only.

#### `get_audio_settings() -> Dictionary`
Get audio settings only.

#### `get_gameplay_settings() -> Dictionary`
Get gameplay settings only.

## Usage Examples

### Settings Menu

```gdscript
class_name SettingsMenu extends Control

@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var vsync_option: OptionButton = %VsyncOption
@onready var master_slider: HSlider = %MasterVolumeSlider
@onready var music_slider: HSlider = %MusicVolumeSlider
@onready var sfx_slider: HSlider = %SfxVolumeSlider

func _ready() -> void:
    # Load current values
    _load_current_settings()
    
    # Connect signals
    fullscreen_check.toggled.connect(_on_fullscreen_toggled)
    master_slider.value_changed.connect(_on_master_volume_changed)
    music_slider.value_changed.connect(_on_music_volume_changed)
    sfx_slider.value_changed.connect(_on_sfx_volume_changed)

func _load_current_settings() -> void:
    fullscreen_check.button_pressed = SettingsManager.fullscreen
    master_slider.value = SettingsManager.master_volume
    music_slider.value = SettingsManager.music_volume
    sfx_slider.value = SettingsManager.sfx_volume

func _on_fullscreen_toggled(enabled: bool) -> void:
    SettingsManager.set_setting("graphics", "fullscreen", enabled)

func _on_master_volume_changed(value: float) -> void:
    SettingsManager.set_setting("audio", "master_volume", value)

func _on_music_volume_changed(value: float) -> void:
    SettingsManager.set_setting("audio", "music_volume", value)

func _on_sfx_volume_changed(value: float) -> void:
    SettingsManager.set_setting("audio", "sfx_volume", value)

func _on_reset_pressed() -> void:
    SettingsManager.reset_to_defaults()
    _load_current_settings()
```

### Resolution Selector

```gdscript
class_name ResolutionSelector extends OptionButton

const RESOLUTIONS = [
    Vector2i(1920, 1080),
    Vector2i(1600, 900),
    Vector2i(1280, 720),
    Vector2i(854, 480)
]

func _ready() -> void:
    # Populate options
    for res in RESOLUTIONS:
        add_item("%d x %d" % [res.x, res.y])
    
    # Select current resolution
    var current = SettingsManager.resolution
    for i in range(RESOLUTIONS.size()):
        if RESOLUTIONS[i] == current:
            selected = i
            break
    
    item_selected.connect(_on_resolution_selected)

func _on_resolution_selected(index: int) -> void:
    SettingsManager.set_setting("graphics", "resolution", RESOLUTIONS[index])
```

### Custom Settings Category

```gdscript
# Add custom settings
func _ready() -> void:
    # Set custom gameplay settings
    SettingsManager.set_setting("gameplay", "camera_shake", true)
    SettingsManager.set_setting("gameplay", "motion_blur", false)
    SettingsManager.set_setting("gameplay", "show_hints", true)

# Use custom settings
func should_show_hints() -> bool:
    return SettingsManager.get_setting("gameplay", "show_hints", true)
```

## Best Practices

1. **Auto-save is enabled by default** - changes persist automatically
2. **Use categories** ("graphics", "audio", "gameplay", "custom")
3. **Provide defaults** with `get_setting()`
4. **Listen to signals** for reactive UI updates
5. **Reset option** for user convenience

## Integration

### With AudioManager

Audio settings automatically update AudioManager:
```gdscript
# This automatically calls AudioManager.set_master_volume()
SettingsManager.set_setting("audio", "master_volume", 0.8)
```

### With EventManager

Setting changes emit events:
```gdscript
EventManager.subscribe("setting_changed", _on_setting_changed)

func _on_setting_changed(data: Dictionary) -> void:
    var category = data.get("category", "")
    var key = data.get("key", "")
    var value = data.get("value")
    print("Setting changed: %s.%s = %s" % [category, key, value])
```

## See Also

- [AudioManager](AudioManager.md) - Audio volume integration
- [EventManager](EventManager.md) - Setting change events
