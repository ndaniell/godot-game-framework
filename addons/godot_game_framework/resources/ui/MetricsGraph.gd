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
@export var padding: Vector2 = Vector2(10, 10)
@export var grid_lines: int = 4
@export var axis_left_width: float = 180.0
@export var axis_bottom_height: float = 28.0
@export var show_time_axis_labels: bool = true
@export var show_series_ranges: bool = true


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

	var plot_rect := _get_plot_rect(graph_rect)
	_draw_grid(plot_rect)

	var enabled_series: Array[Series] = _get_enabled_series()
	if enabled_series.is_empty():
		return

	var max_samples: int = get_max_samples()

	for s in enabled_series:
		_draw_series_scaled(s, plot_rect, max_samples)

	if show_time_axis_labels:
		_draw_time_axis_labels(plot_rect, graph_rect)
	if show_series_ranges:
		_draw_series_ranges(enabled_series, plot_rect, graph_rect)


func _get_plot_rect(graph_rect: Rect2) -> Rect2:
	var left := clamp(axis_left_width, 0.0, graph_rect.size.x - 1.0)
	var bottom := clamp(axis_bottom_height, 0.0, graph_rect.size.y - 1.0)
	return Rect2(
		Vector2(graph_rect.position.x + left, graph_rect.position.y),
		Vector2(max(1.0, graph_rect.size.x - left), max(1.0, graph_rect.size.y - bottom))
	)


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


func _draw_series_scaled(series: Series, plot_rect: Rect2, max_samples: int) -> void:
	if series == null:
		return

	var color: Color = series.color
	var samples: PackedFloat32Array = series.samples
	if samples.size() < 2:
		return

	var min_val := samples[0]
	var max_val := samples[0]
	for fv in samples:
		min_val = min(min_val, fv)
		max_val = max(max_val, fv)

	# Prefer a 0 baseline when the series is non-negative.
	if min_val >= 0.0:
		min_val = 0.0

	var value_range: float = max(0.0001, max_val - min_val)

	var start_x: float = plot_rect.position.x
	var end_x: float = plot_rect.position.x + plot_rect.size.x
	var step_x: float = (end_x - start_x) / float(max(1, max_samples - 1))

	var last_point: Vector2
	var has_last := false
	for i in range(samples.size()):
		var x: float = start_x + step_x * float(i)
		var norm: float = (samples[i] - min_val) / value_range
		var y: float = plot_rect.position.y + plot_rect.size.y * (1.0 - clamp(norm, 0.0, 1.0))
		var p: Vector2 = Vector2(x, y)

		if has_last:
			draw_line(last_point, p, color, 2.0, true)

		last_point = p
		has_last = true


func _draw_time_axis_labels(plot_rect: Rect2, _graph_rect: Rect2) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var font_size := get_theme_default_font_size()

	var bottom_y := plot_rect.position.y + plot_rect.size.y + 2.0 + float(font_size)
	var left_x := plot_rect.position.x
	var right_x := plot_rect.position.x + plot_rect.size.x

	var label_color := Color(1, 1, 1, 0.70)
	var seconds := history_seconds

	# Left = -window, Right = 0s, Middle = -window/2
	var left_label := "-%ss" % _format_number(seconds)
	var mid_label := "-%ss" % _format_number(seconds * 0.5)
	var right_label := "0s"

	draw_string(
		font,
		Vector2(left_x, bottom_y),
		left_label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		label_color
	)
	draw_string(
		font,
		Vector2((left_x + right_x) * 0.5, bottom_y),
		mid_label,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		font_size,
		label_color
	)
	draw_string(
		font,
		Vector2(right_x, bottom_y),
		right_label,
		HORIZONTAL_ALIGNMENT_RIGHT,
		-1,
		font_size,
		label_color
	)


func _draw_series_ranges(
	enabled_series: Array[Series], plot_rect: Rect2, graph_rect: Rect2
) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var font_size := get_theme_default_font_size()

	var left_area := Rect2(
		Vector2(graph_rect.position.x, graph_rect.position.y),
		Vector2(max(1.0, plot_rect.position.x - graph_rect.position.x - 6.0), plot_rect.size.y)
	)

	var y := left_area.position.y + float(font_size)
	var line_h := float(font_size) + 4.0

	# Draw "min–max" per series in series color, stacked vertically.
	for s in enabled_series:
		if s == null:
			continue
		if y > left_area.position.y + left_area.size.y - 2.0:
			break
		if s.samples.is_empty():
			continue

		var min_val := s.samples[0]
		var max_val := s.samples[0]
		for fv in s.samples:
			min_val = min(min_val, fv)
			max_val = max(max_val, fv)

		var text := (
			"%s  %s–%s" % [_find_series_name(s), _format_number(min_val), _format_number(max_val)]
		)
		draw_string(
			font,
			Vector2(left_area.position.x + 2.0, y),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color(s.color.r, s.color.g, s.color.b, 0.95)
		)
		y += line_h


func _find_series_name(series: Series) -> String:
	for k in _series.keys():
		if k is String and _series[k] == series:
			return k as String
	return ""


func _format_number(value: float) -> String:
	var av := abs(value)
	if av >= 1000.0:
		return "%d" % int(round(value))
	if av >= 100.0:
		return "%.0f" % value
	if av >= 10.0:
		return "%.1f" % value
	return "%.2f" % value


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
