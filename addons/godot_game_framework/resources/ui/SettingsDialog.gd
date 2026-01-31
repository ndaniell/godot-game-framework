extends Control

## Simple settings dialog (framework-provided).
##
## - Opens as a UI element via UIManager using the name `settings_dialog`.
## - Esc closes.

var _syncing := false

@onready var _fullscreen_toggle: CheckBox = %FullscreenToggle
@onready var _vsync_dropdown: OptionButton = %VsyncDropdown
@onready var _msaa_3d_dropdown: OptionButton = %Msaa3dDropdown
@onready var _screen_space_aa_dropdown: OptionButton = %ScreenSpaceAaDropdown
@onready var _taa_toggle: CheckBox = %TaaToggle
@onready var _window_mode_dropdown: OptionButton = %WindowModeDropdown
@onready var _max_fps_dropdown: OptionButton = %MaxFpsDropdown
@onready var _render_scale_slider: HSlider = %RenderScaleSlider
@onready var _master_slider: HSlider = %MasterSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _ui_slider: HSlider = %UiSlider
@onready var _voice_slider: HSlider = %VoiceSlider
@onready var _mute_unfocused_toggle: CheckBox = %MuteUnfocusedToggle
@onready var _reset_button: Button = %ResetButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	set_process_unhandled_input(true)

	_populate_dropdowns()

	_close_button.pressed.connect(_close)
	_reset_button.pressed.connect(_on_reset_pressed)

	_fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	_vsync_dropdown.item_selected.connect(_on_vsync_selected)
	_msaa_3d_dropdown.item_selected.connect(_on_msaa_3d_selected)
	_screen_space_aa_dropdown.item_selected.connect(_on_screen_space_aa_selected)
	_taa_toggle.toggled.connect(_on_taa_toggled)
	_window_mode_dropdown.item_selected.connect(_on_window_mode_selected)
	_max_fps_dropdown.item_selected.connect(_on_max_fps_selected)
	_render_scale_slider.value_changed.connect(_on_render_scale_changed)
	_master_slider.value_changed.connect(_on_master_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_ui_slider.value_changed.connect(_on_ui_changed)
	_voice_slider.value_changed.connect(_on_voice_changed)
	_mute_unfocused_toggle.toggled.connect(_on_mute_unfocused_toggled)

	visibility_changed.connect(_on_visibility_changed)


func _populate_dropdowns() -> void:
	# Populate V-Sync dropdown
	_vsync_dropdown.clear()
	_vsync_dropdown.add_item("Disabled", DisplayServer.VSYNC_DISABLED)
	_vsync_dropdown.set_item_metadata(0, DisplayServer.VSYNC_DISABLED)
	_vsync_dropdown.add_item("Enabled", DisplayServer.VSYNC_ENABLED)
	_vsync_dropdown.set_item_metadata(1, DisplayServer.VSYNC_ENABLED)
	_vsync_dropdown.add_item("Adaptive", DisplayServer.VSYNC_ADAPTIVE)
	_vsync_dropdown.set_item_metadata(2, DisplayServer.VSYNC_ADAPTIVE)
	_vsync_dropdown.add_item("Mailbox", DisplayServer.VSYNC_MAILBOX)
	_vsync_dropdown.set_item_metadata(3, DisplayServer.VSYNC_MAILBOX)

	# Populate MSAA 3D dropdown
	_msaa_3d_dropdown.clear()
	_msaa_3d_dropdown.add_item("Off", Viewport.MSAA_DISABLED)
	_msaa_3d_dropdown.set_item_metadata(0, Viewport.MSAA_DISABLED)
	_msaa_3d_dropdown.add_item("2×", Viewport.MSAA_2X)
	_msaa_3d_dropdown.set_item_metadata(1, Viewport.MSAA_2X)
	_msaa_3d_dropdown.add_item("4×", Viewport.MSAA_4X)
	_msaa_3d_dropdown.set_item_metadata(2, Viewport.MSAA_4X)
	_msaa_3d_dropdown.add_item("8×", Viewport.MSAA_8X)
	_msaa_3d_dropdown.set_item_metadata(3, Viewport.MSAA_8X)

	# Populate Screen-Space AA dropdown
	_screen_space_aa_dropdown.clear()
	_screen_space_aa_dropdown.add_item("Off", Viewport.SCREEN_SPACE_AA_DISABLED)
	_screen_space_aa_dropdown.set_item_metadata(0, Viewport.SCREEN_SPACE_AA_DISABLED)
	_screen_space_aa_dropdown.add_item("FXAA", Viewport.SCREEN_SPACE_AA_FXAA)
	_screen_space_aa_dropdown.set_item_metadata(1, Viewport.SCREEN_SPACE_AA_FXAA)
	_screen_space_aa_dropdown.add_item("SMAA", Viewport.SCREEN_SPACE_AA_SMAA)
	_screen_space_aa_dropdown.set_item_metadata(2, Viewport.SCREEN_SPACE_AA_SMAA)

	# Populate Window Mode dropdown
	_window_mode_dropdown.clear()
	_window_mode_dropdown.add_item("Windowed", DisplayServer.WINDOW_MODE_WINDOWED)
	_window_mode_dropdown.set_item_metadata(0, DisplayServer.WINDOW_MODE_WINDOWED)
	_window_mode_dropdown.add_item("Maximized", DisplayServer.WINDOW_MODE_MAXIMIZED)
	_window_mode_dropdown.set_item_metadata(1, DisplayServer.WINDOW_MODE_MAXIMIZED)
	_window_mode_dropdown.add_item("Fullscreen", DisplayServer.WINDOW_MODE_FULLSCREEN)
	_window_mode_dropdown.set_item_metadata(2, DisplayServer.WINDOW_MODE_FULLSCREEN)
	_window_mode_dropdown.add_item(
		"Exclusive Fullscreen", DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	_window_mode_dropdown.set_item_metadata(3, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	# Populate Max FPS dropdown
	_max_fps_dropdown.clear()
	_max_fps_dropdown.add_item("Uncapped", 0)
	_max_fps_dropdown.set_item_metadata(0, 0)
	_max_fps_dropdown.add_item("30 FPS", 30)
	_max_fps_dropdown.set_item_metadata(1, 30)
	_max_fps_dropdown.add_item("60 FPS", 60)
	_max_fps_dropdown.set_item_metadata(2, 60)
	_max_fps_dropdown.add_item("75 FPS", 75)
	_max_fps_dropdown.set_item_metadata(3, 75)
	_max_fps_dropdown.add_item("90 FPS", 90)
	_max_fps_dropdown.set_item_metadata(4, 90)
	_max_fps_dropdown.add_item("120 FPS", 120)
	_max_fps_dropdown.set_item_metadata(5, 120)
	_max_fps_dropdown.add_item("144 FPS", 144)
	_max_fps_dropdown.set_item_metadata(6, 144)
	_max_fps_dropdown.add_item("165 FPS", 165)
	_max_fps_dropdown.set_item_metadata(7, 165)
	_max_fps_dropdown.add_item("240 FPS", 240)
	_max_fps_dropdown.set_item_metadata(8, 240)


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


func _on_vsync_selected(index: int) -> void:
	if _syncing:
		return
	var settings := _get_settings()
	if settings:
		var vsync_mode: DisplayServer.VSyncMode = _vsync_dropdown.get_item_metadata(index)
		settings.vsync_mode = vsync_mode


func _on_msaa_3d_selected(index: int) -> void:
	if _syncing:
		return
	var settings := _get_settings()
	if settings:
		var msaa_mode: Viewport.MSAA = _msaa_3d_dropdown.get_item_metadata(index)
		settings.msaa_3d = msaa_mode


func _on_screen_space_aa_selected(index: int) -> void:
	if _syncing:
		return
	var settings := _get_settings()
	if settings:
		var ssaa_mode: Viewport.ScreenSpaceAA = _screen_space_aa_dropdown.get_item_metadata(index)
		settings.screen_space_aa = ssaa_mode


func _on_taa_toggled(enabled: bool) -> void:
	if _syncing:
		return
	var settings := _get_settings()
	if settings:
		settings.taa_enabled = enabled


func _on_window_mode_selected(index: int) -> void:
	if _syncing:
		return
	var settings := _get_settings()
	if settings:
		var mode: DisplayServer.WindowMode = _window_mode_dropdown.get_item_metadata(index)
		settings.window_mode = mode


func _on_max_fps_selected(index: int) -> void:
	if _syncing:
		return
	var settings := _get_settings()
	if settings:
		var fps: int = _max_fps_dropdown.get_item_metadata(index)
		settings.max_fps = fps


func _on_render_scale_changed(value: float) -> void:
	if _syncing:
		return
	var settings := _get_settings()
	if settings:
		settings.render_scale = value


func _on_ui_changed(value: float) -> void:
	if _syncing:
		return
	var settings := _get_settings()
	if settings:
		settings.ui_volume = value


func _on_voice_changed(value: float) -> void:
	if _syncing:
		return
	var settings := _get_settings()
	if settings:
		settings.voice_volume = value


func _on_mute_unfocused_toggled(enabled: bool) -> void:
	if _syncing:
		return
	var settings := _get_settings()
	if settings:
		settings.mute_when_unfocused = enabled


func _sync_from_settings() -> void:
	var settings := _get_settings()
	if settings == null:
		return

	_syncing = true
	_fullscreen_toggle.button_pressed = bool(settings.fullscreen)
	_set_dropdown_by_metadata(_vsync_dropdown, settings.vsync_mode)
	_set_dropdown_by_metadata(_msaa_3d_dropdown, settings.msaa_3d)
	_set_dropdown_by_metadata(_screen_space_aa_dropdown, settings.screen_space_aa)
	_taa_toggle.button_pressed = bool(settings.taa_enabled)
	_set_dropdown_by_metadata(_window_mode_dropdown, settings.window_mode)
	_set_dropdown_by_metadata(_max_fps_dropdown, settings.max_fps)
	_render_scale_slider.value = float(settings.render_scale)
	_master_slider.value = float(settings.master_volume)
	_music_slider.value = float(settings.music_volume)
	_sfx_slider.value = float(settings.sfx_volume)
	_ui_slider.value = float(settings.ui_volume)
	_voice_slider.value = float(settings.voice_volume)
	_mute_unfocused_toggle.button_pressed = bool(settings.mute_when_unfocused)
	_syncing = false


func _close() -> void:
	var ui := GGF.get_manager(&"UIManager")
	if ui and ui.has_method("close_dialog"):
		ui.call("close_dialog", "settings_dialog")
	else:
		hide()


func _get_settings() -> Node:
	return GGF.get_manager(&"SettingsManager")


func _set_dropdown_by_metadata(dropdown: OptionButton, value: Variant) -> void:
	for i in range(dropdown.item_count):
		if dropdown.get_item_metadata(i) == value:
			dropdown.selected = i
			return
	# Default to first item if not found
	dropdown.selected = 0


func _is_escape_pressed(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
