extends Node

## SaveManager - Extensible save/load system for the Godot Game Framework
##
## This manager handles game data persistence with support for multiple save slots.
## Extend this class to add custom save/load functionality.

signal save_created(slot: int, metadata: Dictionary)
signal save_loaded(slot: int, data: Dictionary)
signal save_deleted(slot: int)
signal save_failed(slot: int, error: String)

# Save system configuration
@export_group("Save Configuration")
@export var save_directory: String = "user://saves"
@export var max_save_slots: int = 10
@export var save_file_prefix: String = "save_"
@export var save_file_extension: String = ".save"
@export var auto_save_enabled: bool = false
@export var auto_save_interval: float = 300.0  # 5 minutes

# Current save data
var current_save_slot: int = -1
var save_data: Dictionary = {}

# Auto-save timer
var _auto_save_timer: Timer


## Initialize the save manager
## Override this method to add custom initialization
func _ready() -> void:
	# Get LogManager reference

	LogManager.info("SaveManager", "SaveManager initializing...")
	_initialize_save_directory()
	_initialize_auto_save()
	_on_save_manager_ready()
	LogManager.info("SaveManager", "SaveManager ready")

## Initialize save directory
## Override this method to customize directory setup
func _initialize_save_directory() -> void:
	var dir := DirAccess.open("user://")
	if not dir.dir_exists(save_directory):
		dir.make_dir_recursive(save_directory)

## Initialize auto-save system
## Override this method to customize auto-save setup
func _initialize_auto_save() -> void:
	if auto_save_enabled:
		_auto_save_timer = Timer.new()
		_auto_save_timer.wait_time = auto_save_interval
		_auto_save_timer.timeout.connect(_on_auto_save_timeout)
		_auto_save_timer.autostart = true
		add_child(_auto_save_timer)

## Save game data to a slot
## Override this method to add custom save logic
func save_game(slot: int = 0, metadata: Dictionary = {}) -> bool:
	if slot < 0 or slot >= max_save_slots:
		LogManager.error("SaveManager", "Invalid save slot: " + str(slot))
		save_failed.emit(slot, "Invalid save slot")
		return false

	LogManager.info("SaveManager", "Saving game to slot " + str(slot))

	# Prepare save data
	var save_dict := _prepare_save_data(slot, metadata)

	# Get file path
	var file_path := _get_save_file_path(slot)

	# Save to file
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		var error := FileAccess.get_open_error()
		LogManager.error("SaveManager", "Failed to open save file: " + file_path + " (Error: " + str(error) + ")")
		save_failed.emit(slot, "Failed to open file: " + str(error))
		return false

	# Write save data
	file.store_string(JSON.stringify(save_dict))
	file.close()

	LogManager.info("SaveManager", "Successfully saved game to slot " + str(slot))

	# Update current slot
	current_save_slot = slot
	save_data = save_dict

	save_created.emit(slot, save_dict.get("metadata", {}))
	_on_game_saved(slot, save_dict)

	return true

## Load game data from a slot
## Override this method to add custom load logic
func load_game(slot: int = 0) -> bool:
	if slot < 0 or slot >= max_save_slots:
		LogManager.error("SaveManager", "Invalid save slot: " + str(slot))
		save_failed.emit(slot, "Invalid save slot")
		return false

	LogManager.info("SaveManager", "Loading game from slot " + str(slot))

	# Get file path
	var file_path := _get_save_file_path(slot)

	# Check if file exists
	if not FileAccess.file_exists(file_path):
		LogManager.warn("SaveManager", "Save file does not exist: " + file_path)
		save_failed.emit(slot, "Save file does not exist")
		return false

	# Load from file
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		LogManager.error("SaveManager", "Failed to open save file: " + file_path + " (Error: " + str(error) + ")")
		save_failed.emit(slot, "Failed to open file: " + str(error))
		return false

	# Read and parse JSON
	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_error := json.parse(json_string)
	if parse_error != OK:
		LogManager.error("SaveManager", "Failed to parse save file JSON: " + file_path)
		save_failed.emit(slot, "Failed to parse JSON")
		return false

	var loaded_data := json.data as Dictionary
	if loaded_data.is_empty():
		LogManager.error("SaveManager", "Save file is empty or invalid: " + file_path)
		save_failed.emit(slot, "Save file is empty")
		return false

	LogManager.info("SaveManager", "Successfully loaded game from slot " + str(slot))

	# Update current slot and data
	current_save_slot = slot
	save_data = loaded_data

	# Apply loaded data
	_apply_save_data(loaded_data)

	save_loaded.emit(slot, loaded_data)
	_on_game_loaded(slot, loaded_data)

	return true

## Delete a save slot
## Override this method to add custom delete logic
func delete_save(slot: int) -> bool:
	if slot < 0 or slot >= max_save_slots:
		LogManager.error("SaveManager", "Invalid save slot: " + str(slot))
		return false
	
	var file_path := _get_save_file_path(slot)
	
	if not FileAccess.file_exists(file_path):
		LogManager.warn("SaveManager", "Save file does not exist: " + file_path)
		return false
	
	var dir := DirAccess.open("user://")
	if dir.remove(file_path) != OK:
		LogManager.error("SaveManager", "Failed to delete save file: " + file_path)
		return false
	
	# Clear current slot if it was deleted
	if current_save_slot == slot:
		current_save_slot = -1
		save_data = {}
	
	save_deleted.emit(slot)
	_on_save_deleted(slot)
	
	return true

## Check if a save slot exists
func save_exists(slot: int) -> bool:
	if slot < 0 or slot >= max_save_slots:
		return false
	return FileAccess.file_exists(_get_save_file_path(slot))

## Get save metadata for a slot
func get_save_metadata(slot: int) -> Dictionary:
	if not save_exists(slot):
		return {}
	
	var file_path := _get_save_file_path(slot)
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return {}
	
	var data := json.data as Dictionary
	return data.get("metadata", {})

## Get all available save slots
func get_available_saves() -> Array[int]:
	var saves: Array[int] = []
	for i in range(max_save_slots):
		if save_exists(i):
			saves.append(i)
	return saves

## Quick save (saves to current slot or slot 0)
func quick_save() -> bool:
	var slot := current_save_slot if current_save_slot >= 0 else 0
	return save_game(slot)

## Quick load (loads from current slot or slot 0)
func quick_load() -> bool:
	var slot := current_save_slot if current_save_slot >= 0 else 0
	return load_game(slot)

## Get file path for a save slot
func _get_save_file_path(slot: int) -> String:
	return save_directory + "/" + save_file_prefix + str(slot) + save_file_extension

## Prepare save data dictionary
## Override this method to customize what data is saved
func _prepare_save_data(slot: int, metadata: Dictionary) -> Dictionary:
	var save_dict := {
		"version": "1.0",
		"timestamp": Time.get_unix_time_from_system(),
		"slot": slot,
		"metadata": metadata,
		"game_data": _collect_game_data()
	}
	return save_dict

## Collect game data to save
## Override this method to collect custom game data
func _collect_game_data() -> Dictionary:
	var game_data := {
		"scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "",
		"player_data": _collect_player_data(),
		"world_data": _collect_world_data()
	}
	return game_data

## Collect player data
## Override this method to collect player-specific data
func _collect_player_data() -> Dictionary:
	return {}

## Collect world data
## Override this method to collect world-specific data
func _collect_world_data() -> Dictionary:
	return {}

## Apply loaded save data
## Override this method to customize how data is applied
func _apply_save_data(data: Dictionary) -> void:
	var game_data_val: Variant = data.get("game_data", {})
	var game_data: Dictionary = game_data_val if game_data_val is Dictionary else {}
	_apply_player_data(game_data.get("player_data", {}) as Dictionary)
	_apply_world_data(game_data.get("world_data", {}) as Dictionary)

## Apply player data
## Override this method to apply player-specific data
func _apply_player_data(_player_data: Dictionary) -> void:
	pass

## Apply world data
## Override this method to apply world-specific data
func _apply_world_data(_world_data: Dictionary) -> void:
	pass

## Called when auto-save timer times out
func _on_auto_save_timeout() -> void:
	if current_save_slot >= 0:
		quick_save()

## Virtual methods - Override these in extended classes

## Called when save manager is ready
## Override to add initialization logic
func _on_save_manager_ready() -> void:
	pass

## Called when game is saved
## Override to add post-save logic
func _on_game_saved(_slot: int, _data: Dictionary) -> void:
	pass

## Called when game is loaded
## Override to add post-load logic
func _on_game_loaded(_slot: int, _data: Dictionary) -> void:
	pass

## Called when save is deleted
## Override to add post-delete logic
func _on_save_deleted(_slot: int) -> void:
	pass

## Get current save data
func get_current_save_data() -> Dictionary:
	return save_data.duplicate(true)

## Set save data (for manual data manipulation)
func set_save_data(data: Dictionary) -> void:
	save_data = data
