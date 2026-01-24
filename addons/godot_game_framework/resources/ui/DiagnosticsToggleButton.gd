extends Button

## A small helper button that toggles the diagnostics overlay.
##
## Intended usage: attach to a Button in menus.

const _DEFAULT_ELEMENT_NAME := "DiagnosticsOverlay"

@export var diagnostics_element_name: String = _DEFAULT_ELEMENT_NAME
@export var fade: bool = true


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if diagnostics_element_name.is_empty():
		return

	if GGF == null:
		return

	if not GGF.has_method("get_manager"):
		return

	var ui := GGF.call("get_manager", &"UIManager") as Node
	if ui == null:
		return

	if not ui.has_method("is_ui_element_visible"):
		return

	var is_visible_val: Variant = ui.call("is_ui_element_visible", diagnostics_element_name)
	var visible_now := is_visible_val is bool and (is_visible_val as bool)

	if visible_now:
		if ui.has_method("hide_ui_element"):
			ui.call("hide_ui_element", diagnostics_element_name, fade)
	else:
		if ui.has_method("show_ui_element"):
			ui.call("show_ui_element", diagnostics_element_name, fade)

