extends Control

## A simple multi-series time graph designed for diagnostics overlays.
##
## Samples are assumed to be equally spaced in time (see `sample_interval`).
## The graph supports multiple named series and per-series enable/disable.

signal series_registered(series_name: String)
signal series_enabled_changed(series_name: String, enabled: bool)
signal time_window_changed(seconds: float)

@export var sample_interval: float = 0.2
@export var history_seconds: float = 10.0
@export var padding: Vector2 = Vector2(8, 8)
@export var grid_lines: int = 4


class Series:
	var color: Color
	var enabled: bool = true
	var samples: PackedFloat32Array = PackedFloat32Array()

	func _init(series_color: Color) -> void:
		color = series_color


var _series: Dictionary = {}  # String -> Series


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_redraw()


func register_series(series_name: String, color: Color) -> void:
	if series_name.is_empty():
		return
	if _series.has(series_name):
		return

	_series[series_name] = Series.new(color)
	_trim_all_to_max_samples()
	series_registered.emit(series_name)
	queue_redraw()


func get_series_names() -> Array[String]:
	var out: Array[String] = []
	for k in _series.keys():
		if k is String:
			out.append(k as String)
	return out


func is_series_enabled(series_name: String) -> bool:
	if not _series.has(series_name):
		return false
	var s := _series[series_name] as Series
	return s != null and s.enabled


func set_series_enabled(series_name: String, enabled: bool) -> void:
	if not _series.has(series_name):
		return
	var s := _series[series_name] as Series
	if s == null:
		return
	s.enabled = enabled
	series_enabled_changed.emit(series_name, enabled)
	queue_redraw()


func clear_series(series_name: String) -> void:
	if not _series.has(series_name):
		return
	var s := _series[series_name] as Series
	if s == null:
		return
	s.samples = PackedFloat32Array()
	queue_redraw()


func push_sample(series_name: String, value: float) -> void:
	if not _series.has(series_name):
		return
	var s := _series[series_name] as Series
	if s == null:
		return
	s.samples.push_back(value)

	_trim_series_to_max_samples(series_name)
	queue_redraw()


func set_time_window(seconds: float) -> void:
	history_seconds = max(1.0, seconds)
	_trim_all_to_max_samples()
	time_window_changed.emit(history_seconds)
	queue_redraw()


func get_max_samples() -> int:
	var interval: float = max(0.01, sample_interval)
	return max(2, int(ceil(history_seconds / interval)) + 1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return

	var pad_x: float = max(0.0, padding.x)
	var pad_y: float = max(0.0, padding.y)
	var graph_rect: Rect2 = Rect2(
		Vector2(pad_x, pad_y),
		Vector2(max(1.0, rect.size.x - pad_x * 2.0), max(1.0, rect.size.y - pad_y * 2.0))
	)

	_draw_grid(graph_rect)

	var enabled_series: Array[Series] = _get_enabled_series()
	if enabled_series.is_empty():
		return

	var min_val: float = 0.0
	var max_val: float = 0.0
	var first := true
	for s in enabled_series:
		for fv in s.samples:
			if first:
				min_val = fv
				max_val = fv
				first = false
			else:
				min_val = min(min_val, fv)
				max_val = max(max_val, fv)

	if first:
		return

	# Prefer a 0 baseline when data is non-negative.
	if min_val >= 0.0:
		min_val = 0.0

	var value_range: float = max(0.0001, max_val - min_val)
	var max_samples: int = get_max_samples()

	for s in enabled_series:
		_draw_series(s, graph_rect, min_val, value_range, max_samples)


func _draw_grid(graph_rect: Rect2) -> void:
	var grid_color := Color(1, 1, 1, 0.08)
	draw_rect(graph_rect, Color(0, 0, 0, 0), false, 1.0)

	var lines: int = int(clamp(grid_lines, 0, 10))
	if lines <= 0:
		return

	for i in range(1, lines + 1):
		var t := float(i) / float(lines + 1)
		var y: float = graph_rect.position.y + graph_rect.size.y * t
		draw_line(
			Vector2(graph_rect.position.x, y),
			Vector2(graph_rect.position.x + graph_rect.size.x, y),
			grid_color,
			1.0
		)


func _draw_series(
	series: Series, graph_rect: Rect2, min_val: float, value_range: float, max_samples: int
) -> void:
	if series == null:
		return
	var color: Color = series.color
	var samples: PackedFloat32Array = series.samples

	if samples.size() < 2:
		return

	var start_x: float = graph_rect.position.x
	var end_x: float = graph_rect.position.x + graph_rect.size.x
	var step_x: float = (end_x - start_x) / float(max(1, max_samples - 1))

	var last_point: Vector2
	var has_last := false
	for i in range(samples.size()):
		var x: float = start_x + step_x * float(i)
		var norm: float = (samples[i] - min_val) / value_range
		var y: float = graph_rect.position.y + graph_rect.size.y * (1.0 - clamp(norm, 0.0, 1.0))
		var p: Vector2 = Vector2(x, y)

		if has_last:
			draw_line(last_point, p, color, 2.0, true)

		last_point = p
		has_last = true


func _get_enabled_series() -> Array[Series]:
	var out: Array[Series] = []
	for k in _series.keys():
		if not (k is String):
			continue
		var s := _series[k] as Series
		if s != null and s.enabled:
			out.append(s)
	return out


func _trim_all_to_max_samples() -> void:
	for k in _series.keys():
		if k is String:
			_trim_series_to_max_samples(k as String)


func _trim_series_to_max_samples(series_name: String) -> void:
	if not _series.has(series_name):
		return

	var max_samples: int = get_max_samples()
	var s := _series[series_name] as Series
	if s == null:
		return
	while s.samples.size() > max_samples:
		s.samples.remove_at(0)
