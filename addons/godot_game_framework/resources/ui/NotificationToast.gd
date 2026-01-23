extends PanelContainer

## Default toast notification scene script.
##
## Contract used by NotificationManager:
## - must be a Control
## - must expose `set_message(message: String) -> void`
## - optional: `set_notification_type(type: int) -> void`
## - optional: `set_notification_data(data: Dictionary) -> void`

@onready var _message_label: Label = $Margin/MessageLabel
@onready var _margin: MarginContainer = $Margin


func _ready() -> void:
	if _margin != null:
		_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_margin.add_theme_constant_override("margin_left", 10)
		_margin.add_theme_constant_override("margin_right", 10)
		_margin.add_theme_constant_override("margin_top", 10)
		_margin.add_theme_constant_override("margin_bottom", 10)

	if _message_label != null:
		_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL


func set_message(message: String) -> void:
	if _message_label != null:
		_message_label.text = message


func set_notification_type(_type: int) -> void:
	pass


func set_notification_data(_data: Dictionary) -> void:
	pass

