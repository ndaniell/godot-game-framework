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

	# Prefer driving the overlay through SettingsManager so the value persists across restarts.
	# This applies to the default overlay element name only; custom element names fall back
	# to plain UI show/hide behavior.
	if diagnostics_element_name == _DEFAULT_ELEMENT_NAME:
		var settings := GGF.settings()
		if settings != null:
			settings.diagnostics_overlay_enabled = not settings.diagnostics_overlay_enabled
			return

	var ui := GGF.ui()
	if ui == null:
		return

	var visible_now := ui.is_ui_element_visible(diagnostics_element_name)

	if visible_now:
		ui.hide_ui_element(diagnostics_element_name, fade)
	else:
		ui.show_ui_element(diagnostics_element_name, fade)
