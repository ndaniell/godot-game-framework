extends Control

## Diagnostics overlay showing runtime metrics.
##
## - F3 toggles the overlay.
## - Shows a single row of metric values and a multi-series graph.

const _DEFAULT_TOGGLE_KEY := KEY_F3

const _SERIES_DEFS := {
	"FPS": {"color": Color(0.30, 0.90, 0.55), "unit": "fps"},
	"MemoryMB": {"color": Color(0.90, 0.55, 0.30), "unit": "MB"},
	"Nodes": {"color": Color(0.35, 0.75, 0.95), "unit": ""},
	"DrawCalls": {"color": Color(0.55, 0.30, 0.90), "unit": ""},
	"PhysicsTPS": {"color": Color(0.95, 0.90, 0.35), "unit": "tps"},
	"Peers": {"color": Color(0.35, 0.55, 0.95), "unit": ""},
}

@export var toggle_key: Key = _DEFAULT_TOGGLE_KEY

var _expanded := false
var _sample_timer: Timer = null

var _stat_value_labels: Dictionary = {}  # series_name -> Label

@onready var _panel: PanelContainer = $Panel
@onready var _expand_button: Button = $Panel/Margin/VBox/Header/ExpandButton
@onready var _stats_row: Control = $Panel/Margin/VBox/StatsRow
@onready var _graph_panel: Control = $Panel/Margin/VBox/GraphPanel
@onready var _graph: Control = $Panel/Margin/VBox/GraphPanel/Graph
@onready var _extras: Control = $Panel/Margin/VBox/Extras
@onready var _window_option: OptionButton = $Panel/Margin/VBox/Extras/GraphControls/WindowOption


func _ready() -> void:
	set_process_unhandled_input(true)
	set_process(true)

	if _expand_button != null:
		_expand_button.pressed.connect(_on_expand_pressed)
		_apply_expanded_state()

	_build_stats_row()
	_setup_graph()


func _process(_delta: float) -> void:
	_update_stats_row()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode != toggle_key:
			return

		# Persist the toggle via SettingsManager so the state survives restarts.
		var settings := GGF.get_manager(&"SettingsManager")
		if settings != null:
			var current_enabled := bool(settings.get("diagnostics_overlay_enabled"))
			settings.set("diagnostics_overlay_enabled", not current_enabled)
		else:
			visible = not visible

		get_viewport().set_input_as_handled()


func _on_expand_pressed() -> void:
	_expanded = not _expanded
	_apply_expanded_state()


func _apply_expanded_state() -> void:
	if _extras != null:
		_extras.visible = _expanded
	if _graph_panel != null:
		# Keep the overlay unobtrusive by default; graph only when expanded.
		_graph_panel.visible = _expanded
	if _panel != null:
		_panel.custom_minimum_size = Vector2(980, 600) if _expanded else Vector2(560, 130)
	if _expand_button != null:
		_expand_button.text = "Collapse" if _expanded else "Expand"


func _setup_graph() -> void:
	if _graph == null:
		return

	if _graph.has_method("register_series"):
		for series_name in _SERIES_DEFS.keys():
			if not (series_name is String):
				continue
			var def := _SERIES_DEFS[series_name] as Dictionary
			var color: Color = def.get("color", Color.WHITE)
			_graph.call("register_series", series_name as String, color)

	if _window_option != null:
		_window_option.clear()
		_window_option.add_item("10s", 10)
		_window_option.add_item("30s", 30)
		_window_option.add_item("60s", 60)
		_window_option.add_item("300s", 300)
		_window_option.select(0)
		_window_option.item_selected.connect(_on_window_option_selected)
		_on_window_option_selected(0)

	_start_sampling()


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
	if not visible:
		return
	if _graph == null or not _graph.has_method("push_sample"):
		return

	var metrics := _get_current_metrics()
	for series_name in metrics.keys():
		if series_name is String:
			_graph.call("push_sample", series_name as String, float(metrics[series_name]))


func _on_window_option_selected(index: int) -> void:
	if _window_option == null:
		return

	var id := _window_option.get_item_id(index)
	var seconds := float(id)
	if _graph != null and _graph.has_method("set_time_window"):
		_graph.call("set_time_window", seconds)


func _get_graph_sample_interval() -> float:
	if _graph == null:
		return 0.2
	if _graph.has_method("get"):
		var val: Variant = _graph.get("sample_interval")
		if val is float:
			return max(0.01, val)
	return 0.2


func _build_stats_row() -> void:
	if _stats_row == null:
		return

	for child in _stats_row.get_children():
		if child is Node:
			(child as Node).queue_free()

	_stat_value_labels.clear()

	# Stable order for the row (Dictionary iteration order is not guaranteed).
	var order: Array[String] = ["FPS", "MemoryMB", "Nodes", "DrawCalls", "PhysicsTPS", "Peers"]
	for series_name in order:
		if not _SERIES_DEFS.has(series_name):
			continue

		var def := _SERIES_DEFS[series_name] as Dictionary
		var color: Color = def.get("color", Color.WHITE)

		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)

		var name_label := Label.new()
		name_label.text = _pretty_metric_name(series_name) + ":"
		name_label.modulate = Color(1, 1, 1, 0.75)

		var value_label := Label.new()
		value_label.text = "-"
		value_label.modulate = color

		item.add_child(name_label)
		item.add_child(value_label)
		_stats_row.add_child(item)

		_stat_value_labels[series_name] = value_label


func _update_stats_row() -> void:
	if _stat_value_labels.is_empty():
		return

	var metrics := _get_current_metrics()
	for series_name in _stat_value_labels.keys():
		if not (series_name is String):
			continue
		var label := _stat_value_labels[series_name] as Label
		if label == null:
			continue
		if not metrics.has(series_name):
			label.text = "-"
			continue

		var unit := ""
		if _SERIES_DEFS.has(series_name):
			var def := _SERIES_DEFS[series_name] as Dictionary
			unit = str(def.get("unit", ""))

		label.text = _format_metric_value(series_name as String, float(metrics[series_name]), unit)


func _get_current_metrics() -> Dictionary:
	var fps := float(Engine.get_frames_per_second())
	var mem_mb := float(OS.get_static_memory_usage()) / 1024.0 / 1024.0
	var nodes := float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var draw_calls := float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var physics_tps := float(Engine.physics_ticks_per_second)

	var peers := 0.0
	var network := GGF.network()
	if (
		network != null
		and network.has_method("is_network_connected")
		and network.call("is_network_connected")
	):
		var mp := network.get("multiplayer")
		if mp != null and mp.has_method("get_peers"):
			var peer_list: Variant = mp.call("get_peers")
			if peer_list is Array:
				peers = float((peer_list as Array).size())

	return {
		"FPS": fps,
		"MemoryMB": mem_mb,
		"Nodes": nodes,
		"DrawCalls": draw_calls,
		"PhysicsTPS": physics_tps,
		"Peers": peers,
	}


func _pretty_metric_name(series_name: String) -> String:
	match series_name:
		"MemoryMB":
			return "Mem"
		"DrawCalls":
			return "Draw"
		"PhysicsTPS":
			return "Physics"
		_:
			return series_name


func _format_metric_value(series_name: String, value: float, unit: String) -> String:
	match series_name:
		"FPS", "Nodes", "DrawCalls", "PhysicsTPS", "Peers":
			return "%d%s" % [int(round(value)), (" " + unit) if not unit.is_empty() else ""]
		"MemoryMB":
			return "%.1f %s" % [value, unit]
		_:
			return "%.2f%s" % [value, (" " + unit) if not unit.is_empty() else ""]
