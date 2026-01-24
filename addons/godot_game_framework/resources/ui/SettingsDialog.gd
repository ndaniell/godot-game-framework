extends Control

## Simple settings dialog (framework-provided).
##
## - Opens as a UI element via UIManager using the name `settings_dialog`.
## - Esc closes.

var _syncing := false

@onready var _fullscreen_toggle: CheckBox = %FullscreenToggle
@onready var _master_slider: HSlider = %MasterSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _reset_button: Button = %ResetButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	set_process_unhandled_input(true)

	_close_button.pressed.connect(_close)
	_reset_button.pressed.connect(_on_reset_pressed)

	_fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	_master_slider.value_changed.connect(_on_master_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)

	visibility_changed.connect(_on_visibility_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or _is_escape_pressed(event):
		_close()
		get_viewport().set_input_as_handled()


func _on_visibility_changed() -> void:
	if visible:
		_sync_from_settings()


func _on_reset_pressed() -> void:
	var settings := _get_settings()
	if settings and settings.has_method("reset_to_defaults"):
		settings.reset_to_defaults()
	_sync_from_settings()


func _on_fullscreen_toggled(enabled: bool) -> void:
	if _syncing:
		return
	var settings := _get_settings()
	if settings:
		settings.fullscreen = enabled


func _on_master_changed(value: float) -> void:
	if _syncing:
		return
	var settings := _get_settings()
	if settings:
		settings.master_volume = value


func _on_music_changed(value: float) -> void:
	if _syncing:
		return
	var settings := _get_settings()
	if settings:
		settings.music_volume = value


func _on_sfx_changed(value: float) -> void:
	if _syncing:
		return
	var settings := _get_settings()
	if settings:
		settings.sfx_volume = value


func _sync_from_settings() -> void:
	var settings := _get_settings()
	if settings == null:
		return

	_syncing = true
	_fullscreen_toggle.button_pressed = bool(settings.fullscreen)
	_master_slider.value = float(settings.master_volume)
	_music_slider.value = float(settings.music_volume)
	_sfx_slider.value = float(settings.sfx_volume)
	_syncing = false


func _close() -> void:
	var ui := GGF.get_manager(&"UIManager")
	if ui and ui.has_method("close_dialog"):
		ui.call("close_dialog", "settings_dialog")
	else:
		hide()


func _get_settings() -> Node:
	return GGF.get_manager(&"SettingsManager")


func _is_escape_pressed(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
