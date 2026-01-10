# AudioManager

Handles all audio playback including music, sound effects, and volume controls for the Godot Game Framework.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Signals](#signals)
- [Methods](#methods)
- [Virtual Methods](#virtual-methods)
- [Usage Examples](#usage-examples)
- [Integration](#integration)

## Overview

The `AudioManager` is an extensible audio management system that provides:

- **Music playback** with fade in/out transitions
- **Sound effects** with pooled audio players
- **Volume control** for master, music, and SFX buses
- **Audio bus management** with automatic setup
- **Event integration** with SettingsManager for volume changes

## Properties

### Audio Buses

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `music_bus_name` | String | "Music" | Name of the music audio bus |
| `sfx_bus_name` | String | "SFX" | Name of the SFX audio bus |
| `master_bus_name` | String | "Master" | Name of the master audio bus |

### Volume Settings

| Property | Type | Range | Description |
|----------|------|-------|-------------|
| `master_volume` | float | 0.0-1.0 | Master volume level |
| `music_volume` | float | 0.0-1.0 | Music volume level |
| `sfx_volume` | float | 0.0-1.0 | Sound effects volume level |

## Signals

```gdscript
signal music_changed(track: AudioStream)
```
Emitted when the current music track changes.

```gdscript
signal sound_effect_played(effect: AudioStream)
```
Emitted when a sound effect is played.

```gdscript
signal volume_changed(bus_name: String, volume: float)
```
Emitted when any volume setting changes.

## Methods

### Music Control

#### `play_music(stream: AudioStream, fade_in: bool = false, fade_duration: float = 1.0) -> void`

Plays a music track with optional fade-in effect.

**Parameters:**
- `stream`: The AudioStream to play
- `fade_in`: Whether to fade in from silence
- `fade_duration`: Duration of the fade effect in seconds

**Example:**
```gdscript
AudioManager.play_music(my_music_stream, true, 2.0)
```

#### `stop_music(fade_out: bool = false, fade_duration: float = 1.0) -> void`

Stops the current music with optional fade-out effect.

**Parameters:**
- `fade_out`: Whether to fade out before stopping
- `fade_duration`: Duration of the fade effect in seconds

**Example:**
```gdscript
AudioManager.stop_music(true, 1.5)
```

#### `get_current_music() -> AudioStream`

Returns the currently playing music stream, or null if no music is playing.

#### `is_music_playing() -> bool`

Returns true if music is currently playing.

### Sound Effects

#### `play_sfx(stream: AudioStream, volume_scale: float = 1.0) -> AudioStreamPlayer`

Plays a sound effect at the specified volume scale.

**Parameters:**
- `stream`: The AudioStream to play
- `volume_scale`: Volume multiplier (0.0-1.0)

**Returns:** The AudioStreamPlayer instance playing the sound, or null if no players are available

**Example:**
```gdscript
AudioManager.play_sfx(explosion_sound, 0.8)
```

### Volume Control

#### `set_master_volume(volume: float) -> void`

Sets the master volume (0.0-1.0).

#### `set_music_volume(volume: float) -> void`

Sets the music volume (0.0-1.0).

#### `set_sfx_volume(volume: float) -> void`

Sets the sound effects volume (0.0-1.0).

## Virtual Methods

Override these methods in extended classes to add custom behavior:

### `_on_music_started(stream: AudioStream) -> void`

Called when music starts playing. Override to add custom logic when music begins.

**Example:**
```gdscript
extends AudioManager

func _on_music_started(stream: AudioStream) -> void:
    print("Now playing: ", stream.resource_path)
    # Show "Now Playing" UI
```

### `_on_music_ended(stream: AudioStream) -> void`

Called when music finishes playing. Override to implement playlist behavior, looping, etc.

**Example:**
```gdscript
func _on_music_ended(stream: AudioStream) -> void:
    # Auto-play next track in playlist
    play_next_track()
```

### `_on_sfx_played(stream: AudioStream, player: AudioStreamPlayer) -> void`

Called when a sound effect is played. Override to track or modify sound effects.

## Usage Examples

### Basic Music Playback

```gdscript
# Load and play music
var music = preload("res://audio/music/main_theme.ogg")
AudioManager.play_music(music, true, 2.0)

# Stop music with fade out
AudioManager.stop_music(true, 1.5)
```

### Playing Sound Effects

```gdscript
# Play a sound effect
var jump_sound = preload("res://audio/sfx/jump.wav")
AudioManager.play_sfx(jump_sound)

# Play quieter footstep sound
var footstep = preload("res://audio/sfx/footstep.wav")
AudioManager.play_sfx(footstep, 0.5)
```

### Volume Control

```gdscript
# Set volumes
AudioManager.set_master_volume(0.8)
AudioManager.set_music_volume(0.7)
AudioManager.set_sfx_volume(0.9)

# Get current music
var current = AudioManager.get_current_music()
if current:
    print("Playing: ", current.resource_path)
```

### Extending AudioManager

```gdscript
extends AudioManager

# Custom playlist implementation
var playlist: Array[AudioStream] = []
var current_track_index: int = 0

func _ready() -> void:
    super._ready()
    _load_playlist()

func _load_playlist() -> void:
    playlist = [
        preload("res://audio/music/track1.ogg"),
        preload("res://audio/music/track2.ogg"),
        preload("res://audio/music/track3.ogg")
    ]

func _on_music_ended(stream: AudioStream) -> void:
    # Auto-play next track
    current_track_index = (current_track_index + 1) % playlist.size()
    play_music(playlist[current_track_index], true)

func play_random_track() -> void:
    current_track_index = randi() % playlist.size()
    play_music(playlist[current_track_index], true)
```

## Integration

### With SettingsManager

AudioManager automatically listens to `setting_changed` events from SettingsManager and updates volumes accordingly:

```gdscript
# SettingsManager will automatically update AudioManager
SettingsManager.set_setting("audio", "master_volume", 0.8)
SettingsManager.set_setting("audio", "music_volume", 0.6)
```

### With EventManager

AudioManager subscribes to events and can be controlled through the event system:

```gdscript
# Manual event emission (handled automatically by SettingsManager)
EventManager.emit("setting_changed", {
    "category": "audio",
    "key": "master_volume",
    "value": 0.8
})
```

## Configuration

The AudioManager automatically creates and manages three audio buses:

1. **Master** - Controls overall volume
2. **Music** - Dedicated bus for music tracks
3. **SFX** - Dedicated bus for sound effects

These buses are created automatically if they don't exist in your project.

### SFX Player Pool

The manager maintains a pool of 10 AudioStreamPlayer nodes for sound effects. This prevents audio from being cut off when many sounds play simultaneously. If you need more concurrent sounds, extend the class and modify `_max_sfx_players`.

## Best Practices

1. **Preload audio files** - Use `preload()` for frequently used sounds to avoid loading delays
2. **Use appropriate formats** - OGG for music, WAV for short sound effects
3. **Normalize volumes** - Keep your source audio files at consistent volumes
4. **Fade transitions** - Use fade effects for smoother audio transitions
5. **Pool management** - Monitor the SFX player pool if you have many rapid sounds

## See Also

- [SettingsManager](SettingsManager.md) - For persistent volume settings
- [EventManager](EventManager.md) - For event-based communication
