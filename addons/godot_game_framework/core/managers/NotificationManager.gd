class_name GGF_NotificationManager
extends CanvasLayer

## NotificationManager - Extensible notification system for the Godot Game Framework
##
## This manager handles notifications, toasts, and system messages.
## Extend this class to add custom notification functionality.

signal notification_shown(notification_id: String, data: Dictionary)
signal notification_hidden(notification_id: String)
signal notification_clicked(notification_id: String)

# Notification types
enum NotificationType {
	INFO,
	SUCCESS,
	WARNING,
	ERROR,
	CUSTOM,
}

# Notification configuration
@export_group("Notification Configuration")
@export var default_duration: float = 3.0
@export var max_notifications: int = 5
@export var notification_spacing: float = 10.0
@export var position: Vector2 = Vector2(20, 20)
@export var alignment: Vector2 = Vector2(0, 0)  # 0 = top/left, 1 = bottom/right

# Active notifications
var _notifications: Dictionary = {}  # id -> { "node": Control, "data": Dictionary, "timer": Timer }
var _notification_queue: Array[Dictionary] = []
var _next_id: int = 0


## Initialize the notification manager
## Override this method to add custom initialization
func _ready() -> void:
	# Get LogManager reference

	GGF.log().info("NotificationManager", "NotificationManager initializing...")
	_initialize_notification_manager()
	_on_notification_manager_ready()
	GGF.log().info("NotificationManager", "NotificationManager ready")

## Initialize notification manager
## Override this method to customize initialization
func _initialize_notification_manager() -> void:
	layer = 100  # High layer to appear on top
	pass

## Show a notification
## Override this method to add custom notification logic
func show_notification(message: String, type: NotificationType = NotificationType.INFO, duration: float = -1.0, data: Dictionary = {}) -> String:
	if message.is_empty():
		GGF.log().warn("NotificationManager", "Cannot show empty notification")
		return ""

	GGF.log().debug("NotificationManager", "Showing notification: '" + message.substr(0, 50) + "...'")

	# Check if we're at max capacity
	if _notifications.size() >= max_notifications:
		GGF.log().debug("NotificationManager", "Notification queued (at capacity)")
		# Queue notification
		_notification_queue.append({
			"message": message,
			"type": type,
			"duration": duration,
			"data": data,
		})
		return ""
	
	var notification_id := _generate_notification_id()
	var actual_duration := duration if duration > 0.0 else default_duration
	
	# Create notification node
	var notification_node := _create_notification_node(message, type, data)
	if notification_node == null:
		GGF.log().error("NotificationManager", "Failed to create notification node")
		return ""
	
	# Add to scene tree
	add_child(notification_node)
	
	# Position notification
	_position_notification(notification_node, _notifications.size())
	
	# Create timer for auto-hide
	var timer := Timer.new()
	timer.wait_time = actual_duration
	timer.one_shot = true
	timer.timeout.connect(_on_notification_timer_timeout.bind(notification_id))
	add_child(timer)
	timer.start()
	
	# Store notification
	_notifications[notification_id] = {
		"node": notification_node,
		"data": data,
		"timer": timer,
		"type": type,
		"message": message,
	}
	
	# Animate in
	_animate_notification_in(notification_node)
	
	notification_shown.emit(notification_id, data)
	_on_notification_shown(notification_id, message, type, data)
	
	return notification_id

## Hide a notification
## Override this method to add custom hide logic
func hide_notification(notification_id: String) -> bool:
	if not _notifications.has(notification_id):
		return false
	
	var notification_data := _notifications[notification_id] as Dictionary
	var node := notification_data["node"] as Control
	var timer := notification_data["timer"] as Timer
	
	# Stop timer
	if is_instance_valid(timer):
		timer.stop()
		timer.queue_free()
	
	# Animate out
	_animate_notification_out(node, notification_id)
	
	return true

## Hide all notifications
func hide_all_notifications() -> void:
	for notification_id in _notifications.keys():
		hide_notification(notification_id)
	_on_all_notifications_hidden()

## Create notification node
## Override this method to customize notification appearance
func _create_notification_node(message: String, type: NotificationType, data: Dictionary) -> Control:
	# Create a simple label-based notification
	# Override this to create custom notification UI
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	var label := Label.new()
	
	# Configure panel
	panel.custom_minimum_size = Vector2(300, 60)
	
	# Configure label
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Ensure the label gets a real width (prevents per-character wrapping / vertical text).
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL

	margin.add_child(label)
	panel.add_child(margin)
	
	# Set style based on type
	_set_notification_style(panel, type)
	
	# Make clickable if data has callback
	if data.has("on_click"):
		var notification_id: String = data.get("id", "")
		panel.gui_input.connect(_handle_notification_clicked.bind(notification_id))
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	return panel

## Set notification style based on type
## Override this method to customize styling
func _set_notification_style(_panel: Control, _type: NotificationType) -> void:
	# Override to set custom styles
	# This is a placeholder - implement actual styling
	pass

## Position notification
func _position_notification(notification_panel: Control, index: int) -> void:
	var offset_y := index * (notification_panel.custom_minimum_size.y + notification_spacing)
	
	if alignment.y == 0:  # Top
		notification_panel.position = position + Vector2(0, offset_y)
	else:  # Bottom
		var screen_size := get_viewport().get_visible_rect().size
		notification_panel.position = Vector2(position.x, screen_size.y - position.y - notification_panel.custom_minimum_size.y - offset_y)
	
	if alignment.x == 1:  # Right
		var screen_size := get_viewport().get_visible_rect().size
		notification_panel.position.x = screen_size.x - position.x - notification_panel.custom_minimum_size.x

## Animate notification in
## Override this method to customize animation
func _animate_notification_in(notification_panel: Control) -> void:
	# Simple fade/slide in
	notification_panel.modulate.a = 0.0
	notification_panel.position.x -= 50.0
	
	var tween := create_tween()
	tween.parallel().tween_property(notification_panel, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(notification_panel, "position:x", notification_panel.position.x + 50.0, 0.3)

## Animate notification out
## Override this method to customize animation
func _animate_notification_out(notification_panel: Control, notification_id: String) -> void:
	var tween := create_tween()
	tween.parallel().tween_property(notification_panel, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(notification_panel, "position:x", notification_panel.position.x - 50.0, 0.3)

	# Avoid `await tween.finished` here: if the game quits while a tween is in-flight,
	# any suspended coroutine can keep the Tween alive and trigger "ObjectDB leaked at exit".
	# Using a one-shot callback keeps teardown deterministic for headless/CI runs.
	tween.finished.connect(func() -> void:
		_remove_notification(notification_id)
		_process_notification_queue()
	, CONNECT_ONE_SHOT)

## Remove notification
func _remove_notification(notification_id: String) -> void:
	if not _notifications.has(notification_id):
		return
	
	var notification_data := _notifications[notification_id] as Dictionary
	var node := notification_data["node"] as Control
	
	if is_instance_valid(node):
		node.queue_free()
	
	_notifications.erase(notification_id)
	
	# Reposition remaining notifications
	_reposition_notifications()
	
	notification_hidden.emit(notification_id)
	_on_notification_hidden(notification_id)

## Reposition all notifications
func _reposition_notifications() -> void:
	var index := 0
	for notification_id in _notifications.keys():
		var notification_data := _notifications[notification_id] as Dictionary
		var node := notification_data["node"] as Control
		_position_notification(node, index)
		index += 1

## Process notification queue
func _process_notification_queue() -> void:
	if _notification_queue.is_empty() or _notifications.size() >= max_notifications:
		return
	
	var queued := _notification_queue.pop_front() as Dictionary
	show_notification(
		queued.get("message", ""),
		queued.get("type", NotificationType.INFO),
		queued.get("duration", -1.0),
		queued.get("data", {})
	)

## Generate unique notification ID
func _generate_notification_id() -> String:
	_next_id += 1
	return "notification_%d" % _next_id

## Called when notification timer times out
func _on_notification_timer_timeout(notification_id: String) -> void:
	hide_notification(notification_id)

## Called when notification is clicked (internal handler)
func _handle_notification_clicked(event: InputEvent, notification_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _notifications.has(notification_id):
			var notification_data := _notifications[notification_id] as Dictionary
			var data := notification_data["data"] as Dictionary
			
			if data.has("on_click"):
				var callback := data["on_click"] as Callable
				if callback.is_valid():
					callback.call()
			
			notification_clicked.emit(notification_id)
			_on_notification_clicked(notification_id, data)
			
			# Hide if auto-hide on click
			if data.get("hide_on_click", false):
				hide_notification(notification_id)

## Convenience methods for different notification types

func show_info(message: String, duration: float = -1.0, data: Dictionary = {}) -> String:
	return show_notification(message, NotificationType.INFO, duration, data)

func show_success(message: String, duration: float = -1.0, data: Dictionary = {}) -> String:
	return show_notification(message, NotificationType.SUCCESS, duration, data)

func show_warning(message: String, duration: float = -1.0, data: Dictionary = {}) -> String:
	return show_notification(message, NotificationType.WARNING, duration, data)

func show_error(message: String, duration: float = -1.0, data: Dictionary = {}) -> String:
	return show_notification(message, NotificationType.ERROR, duration, data)

## Get active notification count
func get_active_count() -> int:
	return _notifications.size()

## Get queued notification count
func get_queued_count() -> int:
	return _notification_queue.size()

## Virtual methods - Override these in extended classes

## Called when notification manager is ready
## Override to add initialization logic
func _on_notification_manager_ready() -> void:
	pass

## Called when a notification is shown
## Override to handle notification showing
func _on_notification_shown(_notification_id: String, _message: String, _type: NotificationType, _data: Dictionary) -> void:
	pass

## Called when a notification is hidden
## Override to handle notification hiding
func _on_notification_hidden(_notification_id: String) -> void:
	pass

## Called when a notification is clicked
## Override to handle notification clicks
func _on_notification_clicked(_notification_id: String, _data: Dictionary) -> void:
	pass

## Called when all notifications are hidden
## Override to handle all notifications hidden
func _on_all_notifications_hidden() -> void:
	pass

