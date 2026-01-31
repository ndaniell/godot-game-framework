class_name GGF_SettingsManager
extends "res://addons/godot_game_framework/core/managers/BaseManager.gd"

## SettingsManager - Extensible settings management system for the Godot Game Framework
##
## This manager handles game settings including graphics, audio, and gameplay settings.
## Extend this class to add custom settings functionality.
##
## ## Using SettingsConfig for Default Settings
##
## You can define default settings using a SettingsConfig resource:
##
## 1. Create a new SettingsConfig resource in your project root:
##    - Right-click in FileSystem → Create New → Resource
##    - Search for "GGF_SettingsConfig"
##    - Save it as `res://ggf_settings_config.tres`
##
## 2. Configure your desired defaults in the Inspector
##
## 3. The SettingsManager will automatically load it on startup
##
## Alternatively, assign a config to the `default_settings_config` export property.
##
## **Load Priority:**
## 1. Project override: `res://ggf_settings_config.tres`
## 2. Assigned `default_settings_config` export
## 3. Framework defaults (hardcoded)

signal setting_changed(category: String, key: String, value: Variant)
signal graphics_settings_changed(settings: Dictionary)
signal audio_settings_changed(settings: Dictionary)
signal gameplay_settings_changed(settings: Dictionary)
signal settings_loaded
signal settings_saved

# Type constant for SettingsConfig (avoids reliance on global class_name scanning).
const SETTINGS_CONFIG_TYPE := preload(
	"res://addons/godot_game_framework/core/types/SettingsConfig.gd"
)

# Settings file path
@export_group("Settings Configuration")
@export var settings_file_path: String = "user://settings.save"
@export var auto_save: bool = true
@export var default_settings_config: SETTINGS_CONFIG_TYPE

# Graphics settings
@export_group("Graphics Settings")
@export var fullscreen: bool = false:
	set(value):
		fullscreen = value
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED
		)
		_setting_changed("graphics", "fullscreen", value)

@export var vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED:
	set(value):
		vsync_mode = value
		DisplayServer.window_set_vsync_mode(value)
		_setting_changed("graphics", "vsync_mode", value)

@export var resolution: Vector2i = Vector2i(1920, 1080):
	set(value):
		resolution = value
		DisplayServer.window_set_size(value)
		_setting_changed("graphics", "resolution", value)

@export var window_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED:
	set(value):
		window_mode = value
		DisplayServer.window_set_mode(value)
		_setting_changed("graphics", "window_mode", value)

@export var msaa_3d: Viewport.MSAA = Viewport.MSAA_DISABLED:
	set(value):
		msaa_3d = value
		if is_inside_tree():
			var viewport := get_viewport()
			if viewport:
				viewport.msaa_3d = value
		_setting_changed("graphics", "msaa_3d", value)

@export var screen_space_aa: Viewport.ScreenSpaceAA = Viewport.SCREEN_SPACE_AA_DISABLED:
	set(value):
		screen_space_aa = value
		if is_inside_tree():
			var viewport := get_viewport()
			if viewport:
				viewport.screen_space_aa = value
		_setting_changed("graphics", "screen_space_aa", value)

@export var taa_enabled: bool = false:
	set(value):
		taa_enabled = value
		if is_inside_tree():
			var viewport := get_viewport()
			if viewport:
				viewport.use_taa = value
		_setting_changed("graphics", "taa_enabled", value)

@export var max_fps: int = 0:
	set(value):
		max_fps = value
		Engine.max_fps = value
		_setting_changed("graphics", "max_fps", value)

@export_range(0.5, 2.0, 0.05) var render_scale: float = 1.0:
	set(value):
		render_scale = clamp(value, 0.5, 2.0)
		if is_inside_tree():
			var viewport := get_viewport()
			if viewport:
				viewport.scaling_3d_scale = render_scale
		_setting_changed("graphics", "render_scale", value)

# Audio settings (references AudioManager)
@export_group("Audio Settings")
@export_range(0.0, 1.0) var master_volume: float = 1.0:
	set(value):
		master_volume = value
		_apply_audio_volume_to_manager("master_volume", value)
		_setting_changed("audio", "master_volume", value)

@export_range(0.0, 1.0) var music_volume: float = 1.0:
	set(value):
		music_volume = value
		_apply_audio_volume_to_manager("music_volume", value)
		_setting_changed("audio", "music_volume", value)

@export_range(0.0, 1.0) var sfx_volume: float = 1.0:
	set(value):
		sfx_volume = value
		_apply_audio_volume_to_manager("sfx_volume", value)
		_setting_changed("audio", "sfx_volume", value)

@export_range(0.0, 1.0) var ui_volume: float = 1.0:
	set(value):
		ui_volume = value
		_apply_audio_volume_to_manager("ui_volume", value)
		_setting_changed("audio", "ui_volume", value)

@export_range(0.0, 1.0) var voice_volume: float = 1.0:
	set(value):
		voice_volume = value
		_apply_audio_volume_to_manager("voice_volume", value)
		_setting_changed("audio", "voice_volume", value)

@export var mute_when_unfocused: bool = false:
	set(value):
		mute_when_unfocused = value
		_setting_changed("audio", "mute_when_unfocused", value)

# Gameplay settings
@export_group("Gameplay Settings")
@export var difficulty: String = "normal":
	set(value):
		difficulty = value
		_setting_changed("gameplay", "difficulty", value)

@export var language: String = "en":
	set(value):
		language = value
		_setting_changed("gameplay", "language", value)

# Diagnostics settings
@export_group("Diagnostics Settings")
@export var diagnostics_overlay_enabled: bool = false:
	set(value):
		diagnostics_overlay_enabled = value
		_apply_diagnostics_overlay_enabled(value)
		_setting_changed("custom", "diagnostics_overlay_enabled", value)

# Internal settings storage
var _settings: Dictionary = {"graphics": {}, "audio": {}, "gameplay": {}, "custom": {}}
var _autosave_suspend_count: int = 0


func _begin_batch_update() -> void:
	_autosave_suspend_count += 1


func _end_batch_update() -> void:
	_autosave_suspend_count = max(_autosave_suspend_count - 1, 0)


func _is_autosave_suspended() -> bool:
	return _autosave_suspend_count > 0


## Initialize the settings manager
## Override this method to add custom initialization
func _ready() -> void:
	# Get LogManager reference

	GGF.log().info("SettingsManager", "SettingsManager initializing...")
	_begin_batch_update()
	_initialize_settings()
	# Wait for other managers to be ready before loading settings
	await get_tree().process_frame
	var loaded := load_settings()
	# `load_settings()` applies settings on success; only apply defaults if nothing loaded.
	if not loaded:
		_apply_settings()
	_end_batch_update()
	# Ensure we persist defaults once on first run (without spamming saves during init).
	if auto_save and not FileAccess.file_exists(settings_file_path):
		save_settings()
	_on_settings_manager_ready()
	GGF.log().info("SettingsManager", "SettingsManager ready")
	_set_manager_ready()  # Mark manager as ready


## Handle window notifications for focus changes
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_on_window_focus_changed(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_on_window_focus_changed(true)


## Handle window focus changes for mute_when_unfocused
func _on_window_focus_changed(focused: bool) -> void:
	if not mute_when_unfocused:
		return

	var audio_manager := GGF.get_manager(&"AudioManager")
	if not audio_manager or not audio_manager.is_inside_tree():
		return

	# Mute/unmute master bus when focus changes
	var master_bus_idx := AudioServer.get_bus_index("Master")
	if master_bus_idx >= 0:
		AudioServer.set_bus_mute(master_bus_idx, not focused)


## Initialize settings
## Override this method to customize initialization
func _initialize_settings() -> void:
	# Load defaults from config if available
	_load_defaults_from_config()

	# Initialize default settings
	_settings["graphics"] = {
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

	_settings["audio"] = {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ui_volume": ui_volume,
		"voice_volume": voice_volume,
		"mute_when_unfocused": mute_when_unfocused,
	}

	_settings["gameplay"] = {
		"difficulty": difficulty,
		"language": language,
	}

	_settings["custom"] = {
		"diagnostics_overlay_enabled": diagnostics_overlay_enabled,
	}


## Load defaults from SettingsConfig resource
## Checks for project override first, then uses assigned config, then falls back to code defaults
func _load_defaults_from_config() -> void:
	var config: SETTINGS_CONFIG_TYPE = null

	# Try to load project override config
	const PROJECT_CONFIG_PATH := "res://ggf_settings_config.tres"
	if ResourceLoader.exists(PROJECT_CONFIG_PATH):
		config = load(PROJECT_CONFIG_PATH) as SETTINGS_CONFIG_TYPE
		if config:
			GGF.log().info(
				"SettingsManager", "Loaded project settings config from: " + PROJECT_CONFIG_PATH
			)

	# Fall back to assigned config
	if not config and default_settings_config:
		config = default_settings_config
		GGF.log().debug("SettingsManager", "Using assigned default settings config")

	# Apply config defaults if we have one
	if config:
		_apply_config_defaults(config)


## Apply defaults from a SettingsConfig resource
func _apply_config_defaults(config: SETTINGS_CONFIG_TYPE) -> void:
	if not config:
		return

	# Graphics defaults
	fullscreen = config.fullscreen
	vsync_mode = config.vsync_mode
	resolution = config.resolution
	window_mode = config.window_mode
	msaa_3d = config.msaa_3d
	screen_space_aa = config.screen_space_aa
	taa_enabled = config.taa_enabled
	max_fps = config.max_fps
	render_scale = config.render_scale

	# Audio defaults
	master_volume = config.master_volume
	music_volume = config.music_volume
	sfx_volume = config.sfx_volume
	ui_volume = config.ui_volume
	voice_volume = config.voice_volume
	mute_when_unfocused = config.mute_when_unfocused

	# Gameplay defaults
	difficulty = config.difficulty
	language = config.language

	# Diagnostics defaults
	diagnostics_overlay_enabled = config.diagnostics_overlay_enabled


## Load settings from file
## Override this method to customize loading
func load_settings() -> bool:
	GGF.log().debug("SettingsManager", "Loading settings from: " + settings_file_path)

	if not FileAccess.file_exists(settings_file_path):
		GGF.log().warn("SettingsManager", "Settings file does not exist, using defaults")
		return false

	var file := FileAccess.open(settings_file_path, FileAccess.READ)
	if file == null:
		GGF.log().error("SettingsManager", "Failed to open settings file")
		return false

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		GGF.log().error("SettingsManager", "Failed to parse settings JSON")
		return false

	var loaded_settings := json.data as Dictionary
	_settings = loaded_settings

	GGF.log().info("SettingsManager", "Settings loaded successfully")

	# Apply loaded settings
	_apply_settings()

	settings_loaded.emit()
	_on_settings_loaded()

	return true


## Save settings to file
## Override this method to customize saving
func save_settings() -> bool:
	GGF.log().debug("SettingsManager", "Saving settings to: " + settings_file_path)

	# Update settings dictionary before saving
	_update_settings_dict()

	var file := FileAccess.open(settings_file_path, FileAccess.WRITE)
	if file == null:
		GGF.log().error("SettingsManager", "Failed to open settings file for writing")
		return false

	file.store_string(JSON.stringify(_settings))
	file.close()

	GGF.log().info("SettingsManager", "Settings saved successfully")
	settings_saved.emit()
	_on_settings_saved()

	return true


## Apply settings to the game
## Override this method to customize application
func _apply_settings() -> void:
	# Apply graphics settings
	if _settings.has("graphics"):
		var graphics := _settings["graphics"] as Dictionary
		if graphics.has("fullscreen"):
			fullscreen = graphics["fullscreen"]
		if graphics.has("vsync_mode"):
			vsync_mode = graphics["vsync_mode"]
		if graphics.has("resolution"):
			var res_value = graphics["resolution"]
			# Convert from JSON array [x, y] to Vector2i
			if res_value is Array:
				var res_array = res_value as Array
				if res_array.size() >= 2:
					resolution = Vector2i(res_array[0], res_array[1])
			elif res_value is Vector2i:
				resolution = res_value
		if graphics.has("window_mode"):
			window_mode = graphics["window_mode"]
		if graphics.has("msaa_3d"):
			var msaa_val = graphics["msaa_3d"]
			# Cast int from JSON to enum
			msaa_3d = msaa_val as Viewport.MSAA if msaa_val is int else msaa_val
		if graphics.has("screen_space_aa"):
			var ssaa_val = graphics["screen_space_aa"]
			# Cast int from JSON to enum
			screen_space_aa = ssaa_val as Viewport.ScreenSpaceAA if ssaa_val is int else ssaa_val
		if graphics.has("taa_enabled"):
			taa_enabled = graphics["taa_enabled"]
		if graphics.has("max_fps"):
			max_fps = graphics["max_fps"]
		if graphics.has("render_scale"):
			render_scale = graphics["render_scale"]

	# Apply audio settings
	if _settings.has("audio"):
		var audio := _settings["audio"] as Dictionary
		if audio.has("master_volume"):
			master_volume = audio["master_volume"]
		if audio.has("music_volume"):
			music_volume = audio["music_volume"]
		if audio.has("sfx_volume"):
			sfx_volume = audio["sfx_volume"]
		if audio.has("ui_volume"):
			ui_volume = audio["ui_volume"]
		if audio.has("voice_volume"):
			voice_volume = audio["voice_volume"]
		if audio.has("mute_when_unfocused"):
			mute_when_unfocused = audio["mute_when_unfocused"]

	# Apply gameplay settings
	if _settings.has("gameplay"):
		var gameplay := _settings["gameplay"] as Dictionary
		if gameplay.has("difficulty"):
			difficulty = gameplay["difficulty"]
		if gameplay.has("language"):
			language = gameplay["language"]

	# Apply custom settings
	if _settings.has("custom"):
		var custom := _settings["custom"] as Dictionary
		if custom.has("diagnostics_overlay_enabled"):
			diagnostics_overlay_enabled = bool(custom["diagnostics_overlay_enabled"])

	graphics_settings_changed.emit(_settings.get("graphics", {}))
	audio_settings_changed.emit(_settings.get("audio", {}))
	gameplay_settings_changed.emit(_settings.get("gameplay", {}))


## Update settings dictionary from current values
func _update_settings_dict() -> void:
	_settings["graphics"] = {
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

	_settings["audio"] = {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ui_volume": ui_volume,
		"voice_volume": voice_volume,
		"mute_when_unfocused": mute_when_unfocused,
	}

	_settings["gameplay"] = {
		"difficulty": difficulty,
		"language": language,
	}

	_settings["custom"] = {
		"diagnostics_overlay_enabled": diagnostics_overlay_enabled,
	}


func _apply_diagnostics_overlay_enabled(enabled: bool) -> void:
	# Hide/show the overlay immediately. If UIManager isn't ready yet, try again next frame.
	var ui := GGF.ui()
	if ui == null or not ui.is_inside_tree():
		call_deferred("_apply_diagnostics_overlay_enabled", enabled)
		return

	if enabled:
		ui.show_ui_element("DiagnosticsOverlay")
	else:
		ui.hide_ui_element("DiagnosticsOverlay")


## Set a setting value
## Override this method to add custom setting logic
func set_setting(category: String, key: String, value: Variant) -> void:
	if not _settings.has(category):
		_settings[category] = {}

	_settings[category][key] = value

	GGF.log().debug(
		"SettingsManager", "Setting changed: " + category + "." + key + " = " + str(value)
	)

	# Apply setting if it's a known category
	# Note: _apply_*_setting() methods will trigger property setters,
	# which call _setting_changed() and auto-save.
	var setting_applied := false
	match category:
		"graphics":
			_apply_graphics_setting(key, value)
			setting_applied = true
		"audio":
			_apply_audio_setting(key, value)
			setting_applied = true
		"gameplay":
			_apply_gameplay_setting(key, value)
			setting_applied = true

	# For custom categories or unknown settings, manually trigger change notification
	if not setting_applied:
		_setting_changed(category, key, value)


## Get a setting value
func get_setting(category: String, key: String, default_value: Variant = null) -> Variant:
	if not _settings.has(category):
		return default_value

	var category_settings := _settings[category] as Dictionary
	if not category_settings.has(key):
		return default_value

	return category_settings[key]


## Apply a graphics setting
## Override this method to customize graphics setting application
func _apply_graphics_setting(key: String, value: Variant) -> void:
	match key:
		"fullscreen":
			fullscreen = value
		"vsync_mode":
			vsync_mode = value
		"resolution":
			resolution = value
		"window_mode":
			window_mode = value
		"msaa_3d":
			msaa_3d = value
		"screen_space_aa":
			screen_space_aa = value
		"taa_enabled":
			taa_enabled = value
		"max_fps":
			max_fps = value
		"render_scale":
			render_scale = value


## Apply an audio setting
## Override this method to customize audio setting application
func _apply_audio_setting(key: String, value: Variant) -> void:
	match key:
		"master_volume":
			master_volume = value
		"music_volume":
			music_volume = value
		"sfx_volume":
			sfx_volume = value
		"ui_volume":
			ui_volume = value
		"voice_volume":
			voice_volume = value
		"mute_when_unfocused":
			mute_when_unfocused = value


## Apply audio volume to AudioManager (with safety check)
func _apply_audio_volume_to_manager(setting_key: String, value: float) -> void:
	# Check if AudioManager exists and is ready
	var audio_manager := GGF.get_manager(&"AudioManager")
	if not audio_manager or not audio_manager.is_inside_tree():
		return

	match setting_key:
		"master_volume":
			audio_manager.set_master_volume(value)
		"music_volume":
			audio_manager.set_music_volume(value)
		"sfx_volume":
			audio_manager.set_sfx_volume(value)
		"ui_volume":
			audio_manager.set_ui_volume(value)
		"voice_volume":
			audio_manager.set_voice_volume(value)


## Apply a gameplay setting
## Override this method to customize gameplay setting application
func _apply_gameplay_setting(key: String, value: Variant) -> void:
	match key:
		"difficulty":
			difficulty = value
		"language":
			language = value


## Reset settings to defaults
func reset_to_defaults() -> void:
	_begin_batch_update()
	_initialize_settings()
	_apply_settings()
	_end_batch_update()
	save_settings()
	_on_settings_reset()


## Get all settings
func get_all_settings() -> Dictionary:
	_update_settings_dict()
	return _settings.duplicate(true)


## Get graphics settings
func get_graphics_settings() -> Dictionary:
	return _settings.get("graphics", {}).duplicate()


## Get audio settings
func get_audio_settings() -> Dictionary:
	return _settings.get("audio", {}).duplicate()


## Get gameplay settings
func get_gameplay_settings() -> Dictionary:
	return _settings.get("gameplay", {}).duplicate()


## Internal method to emit setting changed signal
func _setting_changed(category: String, key: String, value: Variant) -> void:
	setting_changed.emit(category, key, value)
	# Emit event for EventManager
	var event_manager := GGF.events()
	if event_manager and event_manager.has_method("emit"):
		(
			event_manager
			. emit(
				"setting_changed",
				{
					"category": category,
					"key": key,
					"value": value,
				}
			)
		)
	_on_setting_changed(category, key, value)

	# Auto-save if enabled
	if auto_save and not _is_autosave_suspended():
		save_settings()


## Virtual methods - Override these in extended classes


## Called when settings manager is ready
## Override to add initialization logic
func _on_settings_manager_ready() -> void:
	pass


## Called when settings are loaded
## Override to handle settings load
func _on_settings_loaded() -> void:
	pass


## Called when settings are saved
## Override to handle settings save
func _on_settings_saved() -> void:
	pass


## Called when a setting changes
## Override to handle setting changes
func _on_setting_changed(_category: String, _key: String, _value: Variant) -> void:
	pass


## Called when settings are reset
## Override to handle settings reset
func _on_settings_reset() -> void:
	pass
