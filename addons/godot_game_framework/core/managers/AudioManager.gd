class_name GGF_AudioManager
extends Node

## AudioManager - Extensible audio management system for the Godot Game Framework
## 
## This manager handles music, sound effects, and volume controls.
## Extend this class to add custom audio functionality.

signal music_changed(track: AudioStream)
signal sound_effect_played(effect: AudioStream)
signal volume_changed(bus_name: String, volume: float)

# Audio buses
@export_group("Audio Buses")
@export var music_bus_name: String = "Music"
@export var sfx_bus_name: String = "SFX"
@export var master_bus_name: String = "Master"

# Volume settings (0.0 to 1.0)
@export_group("Volume Settings")
@export_range(0.0, 1.0) var master_volume: float = 1.0:
	set(value):
		master_volume = clamp(value, 0.0, 1.0)
		_set_bus_volume(master_bus_name, master_volume)
		volume_changed.emit(master_bus_name, master_volume)

@export_range(0.0, 1.0) var music_volume: float = 1.0:
	set(value):
		music_volume = clamp(value, 0.0, 1.0)
		_set_bus_volume(music_bus_name, music_volume)
		volume_changed.emit(music_bus_name, music_volume)

@export_range(0.0, 1.0) var sfx_volume: float = 1.0:
	set(value):
		sfx_volume = clamp(value, 0.0, 1.0)
		_set_bus_volume(sfx_bus_name, sfx_volume)
		volume_changed.emit(sfx_bus_name, sfx_volume)

# Current music player
var _music_player: AudioStreamPlayer
var _current_music: AudioStream

# Sound effect players pool
var _sfx_players: Array[AudioStreamPlayer] = []
var _max_sfx_players: int = 10

func _ready() -> void:
	_initialize_audio_buses()
	_initialize_music_player()
	_initialize_sfx_pool()
	_apply_volume_settings()
	_connect_to_event_manager()

## Initialize audio buses if they don't exist
## Override this method to customize bus setup
func _initialize_audio_buses() -> void:
	if not AudioServer.get_bus_index(music_bus_name) >= 0:
		AudioServer.add_bus(1)
		AudioServer.set_bus_name(1, music_bus_name)
	
	if not AudioServer.get_bus_index(sfx_bus_name) >= 0:
		AudioServer.add_bus(2)
		AudioServer.set_bus_name(2, sfx_bus_name)

## Initialize the music player
## Override this method to customize music player setup
func _initialize_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = music_bus_name
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

## Initialize the sound effect player pool
## Override this method to customize SFX pool setup
func _initialize_sfx_pool() -> void:
	for i in range(_max_sfx_players):
		var player := AudioStreamPlayer.new()
		player.bus = sfx_bus_name
		player.finished.connect(_on_sfx_finished.bind(player))
		_sfx_players.append(player)
		add_child(player)

## Apply volume settings to buses
## Override this method to customize volume application
func _apply_volume_settings() -> void:
	_set_bus_volume(master_bus_name, master_volume)
	_set_bus_volume(music_bus_name, music_volume)
	_set_bus_volume(sfx_bus_name, sfx_volume)

## Set volume for a specific bus
## Override this method to customize volume setting behavior
func _set_bus_volume(bus_name: String, volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(volume))

## Play music track
## Override this method to add custom music playback logic
func play_music(stream: AudioStream, fade_in: bool = false, fade_duration: float = 1.0) -> void:
	if stream == null:
		GGF.log().warn("AudioManager", "Attempted to play null music stream")
		return
	
	if _current_music == stream and _music_player.playing:
		return  # Already playing this track
	
	_current_music = stream
	_music_player.stream = stream
	
	if fade_in:
		_music_player.volume_db = -80.0
		_music_player.play()
		var tween := create_tween()
		tween.tween_method(_set_music_volume_db, -80.0, 0.0, fade_duration)
	else:
		_music_player.play()
	
	music_changed.emit(stream)
	_on_music_started(stream)

## Stop music
## Override this method to add custom stop logic
func stop_music(fade_out: bool = false, fade_duration: float = 1.0) -> void:
	if not _music_player.playing:
		return
	
	if fade_out:
		var tween := create_tween()
		tween.tween_method(_set_music_volume_db, 0.0, -80.0, fade_duration)
		await tween.finished
		_music_player.stop()
	else:
		_music_player.stop()
	
	_current_music = null

## Play sound effect
## Override this method to add custom SFX playback logic
func play_sfx(stream: AudioStream, volume_scale: float = 1.0) -> AudioStreamPlayer:
	if stream == null:
		GGF.log().warn("AudioManager", "Attempted to play null SFX stream")
		return null
	
	var player := _get_available_sfx_player()
	if player == null:
		GGF.log().warn("AudioManager", "No available SFX players, consider increasing pool size")
		return null
	
	player.stream = stream
	player.volume_db = linear_to_db(sfx_volume * volume_scale)
	player.play()
	
	sound_effect_played.emit(stream)
	_on_sfx_played(stream, player)
	
	return player

## Get an available SFX player from the pool
func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	return null

## Set music volume in decibels (internal helper)
func _set_music_volume_db(db: float) -> void:
	_music_player.volume_db = db

## Called when music finishes playing
## Override this method to handle music completion
func _on_music_finished() -> void:
	_on_music_ended(_current_music)

## Called when a sound effect finishes playing
func _on_sfx_finished(_player: AudioStreamPlayer) -> void:
	# Player is automatically available again
	pass

## Virtual methods - Override these in extended classes

## Called when music starts playing
## Override to add custom behavior when music starts
func _on_music_started(_stream: AudioStream) -> void:
	pass

## Called when music ends
## Override to add custom behavior when music ends (e.g., loop, next track)
func _on_music_ended(_stream: AudioStream) -> void:
	pass

## Called when a sound effect is played
## Override to add custom behavior when SFX plays
func _on_sfx_played(_stream: AudioStream, _player: AudioStreamPlayer) -> void:
	pass

## Handle setting changed event from EventManager
func _on_setting_changed_event(data: Dictionary) -> void:
	var category := data.get("category", "") as String
	var key := data.get("key", "") as String
	var value: Variant = data.get("value", 1.0)
	
	if category == "audio" and value is float:
		var volume := value as float
		match key:
			"master_volume":
				set_master_volume(volume)
			"music_volume":
				set_music_volume(volume)
			"sfx_volume":
				set_sfx_volume(volume)

## Get current music stream
func get_current_music() -> AudioStream:
	return _current_music

## Check if music is playing
func is_music_playing() -> bool:
	return _music_player.playing

## Set master volume (0.0 to 1.0)
func set_master_volume(volume: float) -> void:
	master_volume = volume

## Set music volume (0.0 to 1.0)
func set_music_volume(volume: float) -> void:
	music_volume = volume

## Set SFX volume (0.0 to 1.0)
func set_sfx_volume(volume: float) -> void:
	sfx_volume = volume

## Connect to EventManager for cross-manager communication
func _connect_to_event_manager() -> void:
	var event_manager := GGF.events()
	if event_manager and event_manager.has_method("subscribe"):
		# Subscribe to settings changes
		event_manager.subscribe("setting_changed", _on_setting_changed_event)

