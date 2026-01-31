class_name GGF_SettingsConfig extends Resource

## GGF_SettingsConfig - Default settings configuration resource
##
## This resource defines default values for all game settings.
## Host projects can override the framework defaults by creating:
## `res://ggf_settings_config.tres`
##
## If the override file does not exist, SettingsManager will use the defaults
## defined in code or fall back to a framework default resource.

# Graphics settings defaults
@export_group("Graphics Defaults")
@export var fullscreen: bool = false
@export var vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED
@export var resolution: Vector2i = Vector2i(1920, 1080)
@export var window_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
@export var msaa_3d: Viewport.MSAA = Viewport.MSAA_DISABLED
@export var screen_space_aa: Viewport.ScreenSpaceAA = Viewport.SCREEN_SPACE_AA_DISABLED
@export var taa_enabled: bool = false
@export var max_fps: int = 0  # 0 = uncapped
@export_range(0.5, 2.0, 0.05) var render_scale: float = 1.0

# Audio settings defaults
@export_group("Audio Defaults")
@export_range(0.0, 1.0) var master_volume: float = 1.0
@export_range(0.0, 1.0) var music_volume: float = 1.0
@export_range(0.0, 1.0) var sfx_volume: float = 1.0
@export_range(0.0, 1.0) var ui_volume: float = 1.0
@export_range(0.0, 1.0) var voice_volume: float = 1.0
@export var mute_when_unfocused: bool = false

# Gameplay settings defaults
@export_group("Gameplay Defaults")
@export var difficulty: String = "normal"
@export var language: String = "en"


## Get all graphics settings as a dictionary
func get_graphics_defaults() -> Dictionary:
	return {
		"fullscreen": fullscreen,
		"vsync_mode": vsync_mode,
		"resolution": resolution,
		"window_mode": window_mode,
		"msaa_3d": msaa_3d,
		"screen_space_aa": screen_space_aa,
		"taa_enabled": taa_enabled,
		"max_fps": max_fps,
		"render_scale": render_scale,
	}


## Get all audio settings as a dictionary
func get_audio_defaults() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ui_volume": ui_volume,
		"voice_volume": voice_volume,
		"mute_when_unfocused": mute_when_unfocused,
	}


## Get all gameplay settings as a dictionary
func get_gameplay_defaults() -> Dictionary:
	return {
		"difficulty": difficulty,
		"language": language,
	}


## Get all settings as a dictionary
func get_all_defaults() -> Dictionary:
	return {
		"graphics": get_graphics_defaults(),
		"audio": get_audio_defaults(),
		"gameplay": get_gameplay_defaults(),
	}
