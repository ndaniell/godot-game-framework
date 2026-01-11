extends Control

@onready var _crosshair: Label = $Crosshair
@onready var _net_status: Label = $TopLeft/NetStatus
@onready var _health: Label = $TopLeft/Health
@onready var _ammo: Label = $TopLeft/Ammo

# Debug (throttled)
var _dbg_last_shot_ms: int = 0

func _ready() -> void:
	_update_net_status()
	if EventManager:
		EventManager.subscribe("network_connected", _on_network_event)
		EventManager.subscribe("network_disconnected", _on_network_event)
		EventManager.subscribe("fps_health_changed", _on_health_changed)
		EventManager.subscribe("fps_ammo_changed", _on_ammo_changed)
		EventManager.subscribe("fps_shot_fired", _on_shot_fired)
		LogManager.debug("HUD", "Subscribed to fps_shot_fired")

func _exit_tree() -> void:
	if EventManager:
		EventManager.unsubscribe("network_connected", _on_network_event)
		EventManager.unsubscribe("network_disconnected", _on_network_event)
		EventManager.unsubscribe("fps_health_changed", _on_health_changed)
		EventManager.unsubscribe("fps_ammo_changed", _on_ammo_changed)
		EventManager.unsubscribe("fps_shot_fired", _on_shot_fired)

func _on_network_event(_data: Dictionary) -> void:
	_update_net_status()

func _update_net_status() -> void:
	if multiplayer.multiplayer_peer == null:
		_net_status.text = "Offline"
		return
	_net_status.text = "Server" if multiplayer.is_server() else "Client"

func _on_health_changed(data: Dictionary) -> void:
	var hp := int(data.get("hp", 100))
	_health.text = "HP: %d" % hp

func _on_ammo_changed(data: Dictionary) -> void:
	var ammo := int(data.get("ammo", 0))
	_ammo.text = "Ammo: %d" % ammo

func _on_shot_fired(_data: Dictionary) -> void:
	# Simple feedback: crosshair briefly enlarges and brightens.
	if _crosshair == null:
		return

	var now_ms := Time.get_ticks_msec()
	if now_ms - _dbg_last_shot_ms > 400:
		_dbg_last_shot_ms = now_ms
		LogManager.debug("HUD", "fps_shot_fired received")

	_crosshair.modulate = Color(1, 0.9, 0.4, 1)
	var t := create_tween()
	t.tween_property(_crosshair, "scale", Vector2(1.6, 1.6), 0.05)
	t.tween_property(_crosshair, "scale", Vector2.ONE, 0.08)
	t.finished.connect(func(): _crosshair.modulate = Color.WHITE)
