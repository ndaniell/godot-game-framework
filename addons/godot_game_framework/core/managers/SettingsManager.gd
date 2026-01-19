class_name GGF_SettingsManager
extends Node

## SettingsManager - Extensible settings management system for the Godot Game Framework
##
## This manager handles game settings including graphics, audio, and gameplay settings.
## Extend this class to add custom settings functionality.

signal setting_changed(category: String, key: String, value: Variant)
signal graphics_settings_changed(settings: Dictionary)
signal audio_settings_changed(settings: Dictionary)
signal gameplay_settings_changed(settings: Dictionary)
signal settings_loaded
signal settings_saved

# Settings file path
@export_group("Settings Configuration")
@export var settings_file_path: String = "user://settings.save"
@export var auto_save: bool = true

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

# Internal settings storage
var _settings: Dictionary = {"graphics": {}, "audio": {}, "gameplay": {}, "custom": {}}


## Initialize the settings manager
## Override this method to add custom initialization
func _ready() -> void:
	# Get LogManager reference

	GGF.log().info("SettingsManager", "SettingsManager initializing...")
	_initialize_settings()
	# Wait for other managers to be ready before loading settings
	await get_tree().process_frame
	load_settings()
	_apply_settings()
	_on_settings_manager_ready()
	GGF.log().info("SettingsManager", "SettingsManager ready")


## Initialize settings
## Override this method to customize initialization
func _initialize_settings() -> void:
	# Initialize default settings
	_settings["graphics"] = {
		"fullscreen": fullscreen,
		"vsync_mode": vsync_mode,
		"resolution": resolution,
		"window_mode": window_mode,
	}

	_settings["audio"] = {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
	}

	_settings["gameplay"] = {
		"difficulty": difficulty,
		"language": language,
	}


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

	# Apply audio settings
	if _settings.has("audio"):
		var audio := _settings["audio"] as Dictionary
		if audio.has("master_volume"):
			master_volume = audio["master_volume"]
		if audio.has("music_volume"):
			music_volume = audio["music_volume"]
		if audio.has("sfx_volume"):
			sfx_volume = audio["sfx_volume"]

	# Apply gameplay settings
	if _settings.has("gameplay"):
		var gameplay := _settings["gameplay"] as Dictionary
		if gameplay.has("difficulty"):
			difficulty = gameplay["difficulty"]
		if gameplay.has("language"):
			language = gameplay["language"]

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
	}

	_settings["audio"] = {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
	}

	_settings["gameplay"] = {
		"difficulty": difficulty,
		"language": language,
	}


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
	match category:
		"graphics":
			_apply_graphics_setting(key, value)
		"audio":
			_apply_audio_setting(key, value)
		"gameplay":
			_apply_gameplay_setting(key, value)

	_setting_changed(category, key, value)

	if auto_save:
		save_settings()


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
	_initialize_settings()
	_apply_settings()
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
