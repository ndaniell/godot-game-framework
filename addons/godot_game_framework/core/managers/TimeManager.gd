class_name GGF_TimeManager
extends "res://addons/godot_game_framework/core/managers/BaseManager.gd"

## TimeManager - Extensible time management system for the Godot Game Framework
##
## This manager handles time scaling, timers, and time-based mechanics.
## Extend this class to add custom time functionality.

signal time_scale_changed(old_scale: float, new_scale: float)
signal timer_completed(timer_id: String)
signal day_night_changed(is_day: bool)
signal time_cycle_changed(cycle_time: float)

# Time scaling
@export_group("Time Configuration")
@export_range(0.0, 10.0) var time_scale: float = 1.0:
	set(value):
		var old_scale := time_scale
		time_scale = clamp(value, 0.0, 10.0)
		Engine.time_scale = time_scale
		time_scale_changed.emit(old_scale, time_scale)
		_on_time_scale_changed(old_scale, time_scale)

@export var pause_aware_timers: bool = true

# Day/night cycle
@export_group("Day/Night Cycle")
@export var enable_day_night_cycle: bool = false
@export var day_duration: float = 300.0  # seconds
@export var night_duration: float = 300.0  # seconds
@export var start_time: float = 0.0  # 0.0 = midnight, 0.5 = noon

# Game time tracking
var game_time: float = 0.0
var real_time: float = 0.0
var delta_time: float = 0.0
var unscaled_delta_time: float = 0.0

# Timers
# timer_id -> {"duration": float, "elapsed": float, "loop": bool, "paused": bool}
var _timers: Dictionary = {}

var _cycle_time: float = 0.0
var _is_day: bool = true


## Initialize the time manager
## Override this method to add custom initialization
func _ready() -> void:
	_initialize_time_manager()
	_on_time_manager_ready()
	_set_manager_ready()  # Mark manager as ready


## Initialize time manager
## Override this method to customize initialization
func _initialize_time_manager() -> void:
	Engine.time_scale = time_scale
	_cycle_time = start_time
	_update_day_night_state()

	# Subscribe to game pause events if EventManager is available
	var event_manager := GGF.events()
	if event_manager and event_manager.has_method("subscribe"):
		event_manager.subscribe("game_paused", _on_game_paused_event)


## Process time updates
func _process(delta: float) -> void:
	unscaled_delta_time = delta
	delta_time = delta * time_scale

	real_time += delta
	game_time += delta_time

	_update_timers(delta)
	_update_day_night_cycle(delta)


## Update all active timers
func _update_timers(delta: float) -> void:
	var effective_delta := delta_time if pause_aware_timers else delta

	for timer_id in _timers.keys():
		var timer := _timers[timer_id] as Dictionary

		if timer.get("paused", false) as bool:
			continue

		var elapsed_val: Variant = timer.get("elapsed", 0.0)
		var elapsed: float = elapsed_val if elapsed_val is float else 0.0
		elapsed += effective_delta

		var duration_val: Variant = timer.get("duration", 0.0)
		var duration: float = duration_val if duration_val is float else 0.0

		if elapsed >= duration:
			# Timer completed
			var loop_val: Variant = timer.get("loop", false)
			var loop: bool = loop_val if loop_val is bool else false

			if loop:
				elapsed = 0.0
				timer["elapsed"] = elapsed
			else:
				_timers.erase(timer_id)

			timer_completed.emit(timer_id)
			_on_timer_completed(timer_id)
		else:
			timer["elapsed"] = elapsed


## Update day/night cycle
func _update_day_night_cycle(_delta: float) -> void:
	if not enable_day_night_cycle:
		return

	_cycle_time += delta_time / (day_duration + night_duration)

	# Wrap cycle time
	if _cycle_time >= 1.0:
		_cycle_time -= 1.0

	_update_day_night_state()


## Update day/night state
func _update_day_night_state() -> void:
	if not enable_day_night_cycle:
		return

	var day_threshold := day_duration / (day_duration + night_duration)
	var was_day := _is_day
	_is_day = _cycle_time < day_threshold

	if was_day != _is_day:
		day_night_changed.emit(_is_day)
		time_cycle_changed.emit(_cycle_time)
		_on_day_night_changed(_is_day)


## Create a timer
## Override this method to add custom timer creation logic
func create_timer(timer_id: String, duration: float, loop: bool = false) -> bool:
	if timer_id.is_empty():
		GGF.log().error("TimeManager", "Cannot create timer with empty ID")
		return false

	if duration <= 0.0:
		GGF.log().error("TimeManager", "Timer duration must be positive")
		return false

	if timer_id in _timers:
		GGF.log().warn("TimeManager", "Timer already exists: " + timer_id)
		return false

	_timers[timer_id] = {
		"duration": duration,
		"elapsed": 0.0,
		"loop": loop,
		"paused": false,
	}

	_on_timer_created(timer_id, duration, loop)
	return true


## Remove a timer
func remove_timer(timer_id: String) -> bool:
	if not (timer_id in _timers):
		return false

	_timers.erase(timer_id)
	_on_timer_removed(timer_id)
	return true


## Pause a timer
func pause_timer(timer_id: String) -> bool:
	if not (timer_id in _timers):
		return false

	var timer := _timers[timer_id] as Dictionary
	timer["paused"] = true
	_on_timer_paused(timer_id)
	return true


## Resume a timer
func resume_timer(timer_id: String) -> bool:
	if not (timer_id in _timers):
		return false

	var timer := _timers[timer_id] as Dictionary
	timer["paused"] = false
	_on_timer_resumed(timer_id)
	return true


## Reset a timer
func reset_timer(timer_id: String) -> bool:
	if not (timer_id in _timers):
		return false

	var timer := _timers[timer_id] as Dictionary
	timer["elapsed"] = 0.0
	_on_timer_reset(timer_id)
	return true


## Get timer progress (0.0 to 1.0)
func get_timer_progress(timer_id: String) -> float:
	if not (timer_id in _timers):
		return 0.0

	var timer := _timers[timer_id] as Dictionary
	var elapsed := timer.get("elapsed", 0.0) as float
	var duration := timer.get("duration", 0.0) as float
	return elapsed / duration if duration > 0.0 else 0.0


## Get timer remaining time
func get_timer_remaining(timer_id: String) -> float:
	if not (timer_id in _timers):
		return 0.0

	var timer := _timers[timer_id] as Dictionary
	var elapsed := timer.get("elapsed", 0.0) as float
	var duration := timer.get("duration", 0.0) as float
	return max(0.0, duration - elapsed)


## Check if timer exists
func timer_exists(timer_id: String) -> bool:
	return timer_id in _timers


## Check if timer is paused
func is_timer_paused(timer_id: String) -> bool:
	if not (timer_id in _timers):
		return false

	var timer := _timers[timer_id] as Dictionary
	return timer.get("paused", false)


## Set time scale
func set_time_scale(scale: float) -> void:
	time_scale = scale


## Pause time (set scale to 0)
func pause_time() -> void:
	time_scale = 0.0


## Resume time (set scale to 1)
func resume_time() -> void:
	time_scale = 1.0


## Slow motion effect
func slow_motion(scale: float = 0.5, duration: float = 0.0) -> void:
	time_scale = scale
	if duration > 0.0:
		create_timer("slow_motion_reset", duration)
		# Note: Timer completion should restore normal time
		# Override _on_timer_completed to handle this


## Fast forward effect
func fast_forward(scale: float = 2.0, duration: float = 0.0) -> void:
	time_scale = scale
	if duration > 0.0:
		create_timer("fast_forward_reset", duration)


## Get day/night cycle time (0.0 to 1.0)
func get_cycle_time() -> float:
	return _cycle_time


## Check if it's day
func is_day() -> bool:
	return _is_day


## Check if it's night
func is_night() -> bool:
	return not _is_day


## Get current game time
func _get_game_time() -> float:
	return game_time


## Get current real time
func _get_real_time() -> float:
	return real_time


## Get delta time (scaled)
func _get_delta_time() -> float:
	return delta_time


## Get unscaled delta time
func _get_unscaled_delta_time() -> float:
	return unscaled_delta_time


## Format time as string
func format_time(seconds: float, include_milliseconds: bool = false) -> String:
	var hours := int(seconds / 3600.0)
	var minutes := int((seconds - hours * 3600.0) / 60.0)
	var secs := int(seconds - hours * 3600.0 - minutes * 60.0)
	var msecs := int((seconds - int(seconds)) * 1000.0)

	if include_milliseconds:
		return "%02d:%02d:%02d.%03d" % [hours, minutes, secs, msecs]
	return "%02d:%02d:%02d" % [hours, minutes, secs]


## Virtual methods - Override these in extended classes


## Called when time manager is ready
## Override to add initialization logic
func _on_time_manager_ready() -> void:
	pass


## Called when time scale changes
## Override to handle time scale changes
func _on_time_scale_changed(_old_scale: float, _new_scale: float) -> void:
	pass


## Called when a timer is created
## Override to handle timer creation
func _on_timer_created(_timer_id: String, _duration: float, _loop: bool) -> void:
	pass


## Called when a timer completes
## Override to handle timer completion
func _on_timer_completed(timer_id: String) -> void:
	# Handle special timers
	if timer_id == "slow_motion_reset":
		resume_time()
	elif timer_id == "fast_forward_reset":
		resume_time()


## Called when a timer is removed
## Override to handle timer removal
func _on_timer_removed(_timer_id: String) -> void:
	pass


## Called when a timer is paused
## Override to handle timer pause
func _on_timer_paused(_timer_id: String) -> void:
	pass


## Called when a timer is resumed
## Override to handle timer resume
func _on_timer_resumed(_timer_id: String) -> void:
	pass


## Called when a timer is reset
## Override to handle timer reset
func _on_timer_reset(_timer_id: String) -> void:
	pass


## Called when day/night changes
## Override to handle day/night changes
func _on_day_night_changed(_is_day_time: bool) -> void:
	pass


## Handle game pause event from EventManager
func _on_game_paused_event(data: Dictionary) -> void:
	var paused := data.get("is_paused", false) as bool
	if paused and pause_aware_timers:
		# Pause all timers when game is paused
		for timer_id in _timers.keys():
			var timer := _timers[timer_id] as Dictionary
			if not timer.get("paused", false):
				timer["paused"] = true
	else:
		# Resume all timers when game is unpaused
		for timer_id in _timers.keys():
			var timer := _timers[timer_id] as Dictionary
			if timer.get("paused", false):
				timer["paused"] = false
