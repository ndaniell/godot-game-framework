extends PanelContainer

## Default toast notification scene script.
##
## Contract used by NotificationManager:
## - must be a Control
## - must expose `set_message(message: String) -> void`
## - optional: `set_notification_type(type: int) -> void`
## - optional: `set_notification_data(data: Dictionary) -> void`
##
## Note: All styling should be done in the scene file or via themes.
## Optional methods are not implemented - extend this script to add custom behavior.

var _pending_message: String = ""
var _has_pending_message := false

@onready var _message_label: Label = $Margin/MessageLabel


func _ready() -> void:
	if _message_label != null and _has_pending_message:
		_message_label.text = _pending_message


func set_message(message: String) -> void:
	_pending_message = message
	_has_pending_message = true
	if _message_label != null:
		_message_label.text = _pending_message
