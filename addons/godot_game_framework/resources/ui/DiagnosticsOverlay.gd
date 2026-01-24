extends Control

## Diagnostics overlay showing runtime metrics.
##
## - F3 toggles the overlay.
## - Contains a toggle for FPS display and an expandable graph area.

signal fps_display_toggled(enabled: bool)

const _DEFAULT_TOGGLE_KEY := KEY_F3

@export var toggle_key: Key = _DEFAULT_TOGGLE_KEY

var _expanded := false
var _fps_enabled := true
var _syncing_ui := false
var _sample_timer: Timer = null
var _fps_metric_checkbox: CheckBox = null

@onready var _panel: PanelContainer = $Panel
@onready var _fps_toggle: CheckButton = $Panel/Margin/VBox/FpsRow/FpsToggle
@onready var _fps_value: Label = $Panel/Margin/VBox/FpsRow/FpsValue
@onready var _expand_button: Button = $Panel/Margin/VBox/Header/ExpandButton
@onready var _graph_panel: Control = $Panel/Margin/VBox/GraphPanel
@onready var _graph: Control = $Panel/Margin/VBox/GraphPanel/Graph
@onready var _extras: Control = $Panel/Margin/VBox/Extras
@onready var _window_option: OptionButton = $Panel/Margin/VBox/Extras/GraphControls/WindowOption
@onready var _metrics_list: VBoxContainer = $Panel/Margin/VBox/Extras/MetricsList


func _ready() -> void:
	set_process_unhandled_input(true)
	set_process(true)

	if _fps_toggle != null:
		_fps_toggle.toggled.connect(_on_fps_toggle_toggled)
		_set_fps_enabled(_fps_toggle.button_pressed)

	if _expand_button != null:
		_expand_button.pressed.connect(_on_expand_pressed)
		_apply_expanded_state()

	_setup_graph()


func _process(_delta: float) -> void:
	if _fps_value != null and _fps_enabled:
		_fps_value.text = "%d fps" % int(Engine.get_frames_per_second())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == toggle_key:
			visible = not visible
			get_viewport().set_input_as_handled()


func _on_fps_toggle_toggled(enabled: bool) -> void:
	_set_fps_enabled(enabled)


func _on_expand_pressed() -> void:
	_expanded = not _expanded
	_apply_expanded_state()


func _apply_expanded_state() -> void:
	if _extras != null:
		_extras.visible = _expanded
	if _panel != null:
		_panel.custom_minimum_size = Vector2(560, 420) if _expanded else Vector2(420, 220)
	if _expand_button != null:
		_expand_button.text = "Collapse" if _expanded else "Expand"


func _setup_graph() -> void:
	if _graph == null:
		return

	if _graph.has_method("register_series"):
		_graph.call("register_series", "FPS", Color(0.30, 0.90, 0.55))

	if _window_option != null:
		_window_option.clear()
		_window_option.add_item("10s", 10)
		_window_option.add_item("30s", 30)
		_window_option.add_item("60s", 60)
		_window_option.add_item("300s", 300)
		_window_option.select(0)
		_window_option.item_selected.connect(_on_window_option_selected)
		_on_window_option_selected(0)

	_build_metrics_list()
	_start_sampling()


func _build_metrics_list() -> void:
	if _metrics_list == null:
		return

	for child in _metrics_list.get_children():
		if child is Node:
			(child as Node).queue_free()

	_fps_metric_checkbox = CheckBox.new()
	_fps_metric_checkbox.text = "FPS"
	_fps_metric_checkbox.button_pressed = _fps_enabled
	_fps_metric_checkbox.toggled.connect(_on_metrics_fps_toggled)
	_metrics_list.add_child(_fps_metric_checkbox)


func _start_sampling() -> void:
	if _sample_timer != null and is_instance_valid(_sample_timer):
		_sample_timer.queue_free()

	_sample_timer = Timer.new()
	_sample_timer.one_shot = false
	_sample_timer.wait_time = _get_graph_sample_interval()
	_sample_timer.timeout.connect(_on_sample_timer_timeout)
	add_child(_sample_timer)
	_sample_timer.start()


func _on_sample_timer_timeout() -> void:
	if not _fps_enabled:
		return
	if _graph != null and _graph.has_method("push_sample"):
		_graph.call("push_sample", "FPS", float(Engine.get_frames_per_second()))


func _on_window_option_selected(index: int) -> void:
	if _window_option == null:
		return

	var id := _window_option.get_item_id(index)
	var seconds := float(id)
	if _graph != null and _graph.has_method("set_time_window"):
		_graph.call("set_time_window", seconds)


func _on_metrics_fps_toggled(enabled: bool) -> void:
	if _syncing_ui:
		return
	_set_fps_enabled(enabled)


func _set_fps_enabled(enabled: bool) -> void:
	_fps_enabled = enabled

	if _graph_panel != null:
		_graph_panel.visible = enabled
	if _fps_value != null:
		_fps_value.visible = enabled
	if _graph != null and _graph.has_method("set_series_enabled"):
		_graph.call("set_series_enabled", "FPS", enabled)

	_syncing_ui = true
	if _fps_toggle != null:
		_fps_toggle.button_pressed = enabled
	if _fps_metric_checkbox != null:
		_fps_metric_checkbox.button_pressed = enabled
	_syncing_ui = false

	fps_display_toggled.emit(enabled)


func _get_graph_sample_interval() -> float:
	if _graph == null:
		return 0.2
	if _graph.has_method("get"):
		var val: Variant = _graph.get("sample_interval")
		if val is float:
			return max(0.01, val)
	return 0.2
