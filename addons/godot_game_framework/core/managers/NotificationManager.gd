class_name GGF_NotificationManager
extends Node

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

const _OVERRIDE_UI_CONFIG_PATH := "res://ggf_ui_config.tres"
const _DEFAULT_UI_RESOURCES_PATH := "res://addons/godot_game_framework/resources/ui/"
const _DEFAULT_UI_CONFIG_PATH := _DEFAULT_UI_RESOURCES_PATH + "ggf_ui_config_default.tres"
const _DEFAULT_NOTIFICATION_TOAST_SCENE_PATH := (
	_DEFAULT_UI_RESOURCES_PATH + "NotificationToast.tscn"
)
const _DEFAULT_NOTIFICATION_CONTAINER_SCENE_PATH := (
	_DEFAULT_UI_RESOURCES_PATH + "NotificationContainer.tscn"
)

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

var _ui_config: Resource = null
var _notification_toast_scene: PackedScene = null
var _notification_container_scene: PackedScene = null
var _notification_container: Control = null
var _is_hosted_under_ui := false


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
	_load_and_apply_ui_config()
	_bind_to_ui_manager()


func _load_and_apply_ui_config() -> void:
	_ui_config = _load_ui_config_resource()
	if _ui_config == null:
		return

	var toast_scene_val: Variant = _ui_config.get("notification_toast_scene")
	if toast_scene_val is PackedScene:
		_notification_toast_scene = toast_scene_val as PackedScene

	var container_scene_val: Variant = _ui_config.get("notification_container_scene")
	if container_scene_val is PackedScene:
		_notification_container_scene = container_scene_val as PackedScene
		var inst := _notification_container_scene.instantiate()
		if inst is Control:
			_notification_container = inst as Control
			# Hosted under UIManager once UI is ready.
		else:
			if inst != null:
				inst.queue_free()
			GGF.log().warn(
				"NotificationManager",
				"notification_container_scene must instance a Control; ignoring"
			)


func _load_ui_config_resource() -> Resource:
	if ResourceLoader.exists(_OVERRIDE_UI_CONFIG_PATH):
		return load(_OVERRIDE_UI_CONFIG_PATH) as Resource
	if ResourceLoader.exists(_DEFAULT_UI_CONFIG_PATH):
		return load(_DEFAULT_UI_CONFIG_PATH) as Resource
	return null


## Show a notification
## Override this method to add custom notification logic
func show_notification(
	message: String,
	type: NotificationType = NotificationType.INFO,
	duration: float = -1.0,
	data: Dictionary = {}
) -> String:
	if message.is_empty():
		GGF.log().warn("NotificationManager", "Cannot show empty notification")
		return ""

	GGF.log().debug(
		"NotificationManager", "Showing notification: '" + message.substr(0, 50) + "...'"
	)

	# Check if we're at max capacity
	if _notifications.size() >= max_notifications:
		GGF.log().debug("NotificationManager", "Notification queued (at capacity)")
		# Queue notification
		(
			_notification_queue
			. append(
				{
					"message": message,
					"type": type,
					"duration": duration,
					"data": data,
				}
			)
		)
		return ""

	var notification_id := _generate_notification_id()
	var actual_duration := duration if duration > 0.0 else default_duration

	# Create notification node
	var notification_node := _create_notification_node(message, type, data)
	if notification_node == null:
		GGF.log().error("NotificationManager", "Failed to create notification node")
		return ""

	# Add to scene tree
	_ensure_container_hosted()
	if _notification_container != null:
		_notification_container.add_child(notification_node)
	else:
		add_child(notification_node)

	# Make clickable if data has callback
	if data.has("on_click"):
		notification_node.gui_input.connect(_handle_notification_clicked.bind(notification_id))
		notification_node.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		notification_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
func _create_notification_node(
	message: String, type: NotificationType, data: Dictionary
) -> Control:
	var toast_scene := _get_notification_toast_scene()
	if toast_scene == null:
		(
			GGF
			. log()
			. error(
				"NotificationManager",
				"Cannot create notification toast: no toast scene configured and default missing",
			)
		)
		return null

	var inst := toast_scene.instantiate()
	if not (inst is Control):
		if inst != null:
			inst.queue_free()
		(
			GGF
			. log()
			. error(
				"NotificationManager",
				"Notification toast scene must instance a Control",
			)
		)
		return null

	var toast := inst as Control
	if toast.has_method("set_message"):
		toast.call("set_message", message)
	elif toast.has_node("MessageLabel"):
		var label := toast.get_node("MessageLabel") as Label
		if label != null:
			label.text = message
	if toast.has_method("set_notification_type"):
		toast.call("set_notification_type", int(type))
	if toast.has_method("set_notification_data"):
		toast.call("set_notification_data", data)

	_set_notification_style(toast, type)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return toast


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
		notification_panel.position = Vector2(
			position.x,
			screen_size.y - position.y - notification_panel.custom_minimum_size.y - offset_y
		)

	if alignment.x == 1:  # Right
		var screen_size := get_viewport().get_visible_rect().size
		notification_panel.position.x = (
			screen_size.x - position.x - notification_panel.custom_minimum_size.x
		)


## Animate notification in
## Override this method to customize animation
func _animate_notification_in(notification_panel: Control) -> void:
	# Simple fade/slide in
	notification_panel.modulate.a = 0.0
	notification_panel.position.x -= 50.0

	var tween := create_tween()
	tween.parallel().tween_property(notification_panel, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(
		notification_panel, "position:x", notification_panel.position.x + 50.0, 0.3
	)


## Animate notification out
## Override this method to customize animation
func _animate_notification_out(notification_panel: Control, notification_id: String) -> void:
	var tween := create_tween()
	tween.parallel().tween_property(notification_panel, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(
		notification_panel, "position:x", notification_panel.position.x - 50.0, 0.3
	)

	# Avoid `await tween.finished` here: if the game quits while a tween is in-flight,
	# any suspended coroutine can keep the Tween alive and trigger "ObjectDB leaked at exit".
	# Using a one-shot callback keeps teardown deterministic for headless/CI runs.
	tween.finished.connect(
		func() -> void:
			_remove_notification(notification_id)
			_process_notification_queue(),
		CONNECT_ONE_SHOT
	)


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
func _on_notification_shown(
	_notification_id: String, _message: String, _type: NotificationType, _data: Dictionary
) -> void:
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


func _bind_to_ui_manager() -> void:
	var ui := _get_ui_manager()
	if ui == null:
		return

	if ui.has_signal("ui_ready"):
		if not ui.is_connected("ui_ready", Callable(self, "_on_ui_manager_ui_ready")):
			ui.connect("ui_ready", Callable(self, "_on_ui_manager_ui_ready"), CONNECT_ONE_SHOT)

	# Also attempt a deferred attach in case UI is already ready.
	call_deferred("_attach_container_to_ui")


func _on_ui_manager_ui_ready() -> void:
	_attach_container_to_ui()


func _ensure_container_hosted() -> void:
	if _notification_container == null or not is_instance_valid(_notification_container):
		_notification_container = _create_default_container()

	if _notification_container == null or not is_instance_valid(_notification_container):
		return

	_configure_notification_container(_notification_container)

	if _is_hosted_under_ui:
		return

	_attach_container_to_ui()


func _attach_container_to_ui() -> void:
	if _notification_container == null or not is_instance_valid(_notification_container):
		_notification_container = _create_default_container()
		if _notification_container == null or not is_instance_valid(_notification_container):
			return

	var ui := _get_ui_manager()
	if ui == null:
		return

	if ui.has_method("is_ready"):
		var ready_val: Variant = ui.call("is_ready")
		if ready_val is bool and not (ready_val as bool):
			return

	if not ui.has_method("get_overlay_container"):
		return

	var overlay_val: Variant = ui.call("get_overlay_container")
	var overlay := overlay_val as Control
	if overlay == null:
		return

	var current_parent := _notification_container.get_parent()
	_configure_notification_container(_notification_container)
	if current_parent != overlay:
		if current_parent != null:
			current_parent.remove_child(_notification_container)
		overlay.add_child(_notification_container)
	_is_hosted_under_ui = true


func _configure_notification_container(container: Control) -> void:
	container.name = "NotificationContainer"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	container.position = Vector2.ZERO
	container.z_index = 1000


func _create_default_container() -> Control:
	var container_scene := _get_notification_container_scene()
	if container_scene == null:
		(
			GGF
			. log()
			. error(
				"NotificationManager",
				"Cannot create notification container: no container scene configured and default missing",
			)
		)
		return null

	var inst := container_scene.instantiate()
	if not (inst is Control):
		if inst != null:
			inst.queue_free()
		(
			GGF
			. log()
			. error(
				"NotificationManager",
				"Notification container scene must instance a Control",
			)
		)
		return null

	var c := inst as Control
	_configure_notification_container(c)
	return c


func _get_notification_toast_scene() -> PackedScene:
	if _notification_toast_scene != null:
		return _notification_toast_scene

	if not ResourceLoader.exists(_DEFAULT_NOTIFICATION_TOAST_SCENE_PATH):
		return null

	var loaded := load(_DEFAULT_NOTIFICATION_TOAST_SCENE_PATH)
	var scene := loaded as PackedScene
	if scene == null:
		return null

	_notification_toast_scene = scene
	return _notification_toast_scene


func _get_notification_container_scene() -> PackedScene:
	if _notification_container_scene != null:
		return _notification_container_scene

	if not ResourceLoader.exists(_DEFAULT_NOTIFICATION_CONTAINER_SCENE_PATH):
		return null

	var loaded := load(_DEFAULT_NOTIFICATION_CONTAINER_SCENE_PATH)
	var scene := loaded as PackedScene
	if scene == null:
		return null

	_notification_container_scene = scene
	return _notification_container_scene


func _get_ui_manager() -> Node:
	if GGF == null:
		return null
	if not GGF.has_method("get_manager"):
		return null
	return GGF.call("get_manager", &"UIManager") as Node
