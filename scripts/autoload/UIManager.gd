extends CanvasLayer

## UIManager - Extensible UI management system for the Godot Game Framework
##
## This manager handles UI elements, menus, dialogs, and UI layer management.
## Extend this class to add custom UI functionality.

signal ui_element_shown(element_name: String)
signal ui_element_hidden(element_name: String)
signal menu_opened(menu_name: String)
signal menu_closed(menu_name: String)
signal dialog_opened(dialog_name: String)
signal dialog_closed(dialog_name: String)
signal focus_changed(old_element: Control, new_element: Control)

# UI layers
@export_group("UI Layers")
@export var background_layer: int = 0
@export var game_layer: int = 1
@export var ui_layer: int = 2
@export var menu_layer: int = 3
@export var dialog_layer: int = 4
@export var overlay_layer: int = 5

# UI element tracking
var _ui_elements: Dictionary = {}  # name -> Control
var _open_menus: Array[String] = []
var _open_dialogs: Array[String] = []
var _menu_stack: Array[String] = []

# Focus management
var _focus_history: Array[Control] = []
var _current_focus: Control = null

## Initialize the UI manager
## Override this method to add custom initialization
func _ready() -> void:
	_initialize_ui_layers()
	_initialize_ui_manager()
	_on_ui_manager_ready()

## Initialize UI layers
## Override this method to customize layer setup
func _initialize_ui_layers() -> void:
	layer = ui_layer

## Initialize UI manager
## Override this method to customize initialization
func _initialize_ui_manager() -> void:
	# Connect to input events for focus management
	pass

## Register a UI element
## Override this method to add custom registration logic
func register_ui_element(element_name: String, element: Control, z_layer: int = -1) -> void:
	if element_name.is_empty():
		push_error("UIManager: Cannot register UI element with empty name")
		return
	
	if element == null:
		push_error("UIManager: Cannot register null UI element: " + element_name)
		return
	
	# Set layer if specified
	if z_layer >= 0:
		element.z_index = z_layer
	
	# Store element
	_ui_elements[element_name] = element
	
	# Add to scene tree if not already
	if not element.get_parent():
		add_child(element)
	
	_on_ui_element_registered(element_name, element)

## Unregister a UI element
func unregister_ui_element(element_name: String) -> void:
	if not _ui_elements.has(element_name):
		return
	
	var element := _ui_elements[element_name] as Control
	_ui_elements.erase(element_name)
	
	# Remove from focus if it's the current focus
	if _current_focus == element:
		_current_focus = null
	
	_on_ui_element_unregistered(element_name, element)

## Show a UI element
## Override this method to add custom show logic
func show_ui_element(element_name: String, fade_in: bool = false) -> void:
	if not _ui_elements.has(element_name):
		push_warning("UIManager: UI element not registered: " + element_name)
		return
	
	var element := _ui_elements[element_name] as Control
	if element.visible:
		return
	
	element.visible = true
	
	if fade_in:
		element.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(element, "modulate:a", 1.0, 0.3)
	
	ui_element_shown.emit(element_name)
	_on_ui_element_shown(element_name, element)

## Hide a UI element
## Override this method to add custom hide logic
func hide_ui_element(element_name: String, fade_out: bool = false) -> void:
	if not _ui_elements.has(element_name):
		push_warning("UIManager: UI element not registered: " + element_name)
		return
	
	var element := _ui_elements[element_name] as Control
	if not element.visible:
		return
	
	if fade_out:
		var tween := create_tween()
		tween.tween_property(element, "modulate:a", 0.0, 0.3)
		await tween.finished
		element.visible = false
		element.modulate.a = 1.0
	else:
		element.visible = false
	
	ui_element_hidden.emit(element_name)
	_on_ui_element_hidden(element_name, element)

## Toggle UI element visibility
func toggle_ui_element(element_name: String) -> void:
	if not _ui_elements.has(element_name):
		return
	
	var element := _ui_elements[element_name] as Control
	if element.visible:
		hide_ui_element(element_name)
	else:
		show_ui_element(element_name)

## Open a menu
## Override this method to add custom menu opening logic
func open_menu(menu_name: String, close_others: bool = false) -> void:
	if not _ui_elements.has(menu_name):
		push_warning("UIManager: Menu not registered: " + menu_name)
		return
	
	# Close other menus if requested
	if close_others:
		close_all_menus()
	
	# Add to open menus
	if menu_name not in _open_menus:
		_open_menus.append(menu_name)
		_menu_stack.append(menu_name)
	
	show_ui_element(menu_name)
	
	menu_opened.emit(menu_name)
	_on_menu_opened(menu_name)

## Close a menu
## Override this method to add custom menu closing logic
func close_menu(menu_name: String) -> void:
	if menu_name not in _open_menus:
		return
	
	_open_menus.erase(menu_name)
	_menu_stack.erase(menu_name)
	
	hide_ui_element(menu_name)
	
	menu_closed.emit(menu_name)
	_on_menu_closed(menu_name)
	
	# Restore focus to previous menu if available
	if _menu_stack.size() > 0:
		var previous_menu := _menu_stack[_menu_stack.size() - 1]
		_on_menu_focus_restored(previous_menu)

## Close all menus
func close_all_menus() -> void:
	for menu_name in _open_menus.duplicate():
		close_menu(menu_name)

## Open a dialog
## Override this method to add custom dialog opening logic
func open_dialog(dialog_name: String, modal: bool = true) -> void:
	if not _ui_elements.has(dialog_name):
		push_warning("UIManager: Dialog not registered: " + dialog_name)
		return
	
	# Add to open dialogs
	if dialog_name not in _open_dialogs:
		_open_dialogs.append(dialog_name)
	
	show_ui_element(dialog_name)
	
	# Set as modal if requested
	var dialog := _ui_elements[dialog_name] as Control
	if modal and dialog != null:
		# Check if it's actually a Window before casting
		# Use get_class() to avoid static type checking issues
		if dialog.get_class() == "Window":
			# Use call() to avoid static type checking
			if dialog.has_method("popup_centered"):
				dialog.call("popup_centered")
	
	dialog_opened.emit(dialog_name)
	_on_dialog_opened(dialog_name)

## Close a dialog
## Override this method to add custom dialog closing logic
func close_dialog(dialog_name: String) -> void:
	if dialog_name not in _open_dialogs:
		return
	
	_open_dialogs.erase(dialog_name)
	
	hide_ui_element(dialog_name)
	
	dialog_closed.emit(dialog_name)
	_on_dialog_closed(dialog_name)

## Close all dialogs
func close_all_dialogs() -> void:
	for dialog_name in _open_dialogs.duplicate():
		close_dialog(dialog_name)

## Set focus to a UI element
## Override this method to add custom focus logic
func set_focus(element: Control) -> void:
	if element == null:
		return
	
	var old_focus := _current_focus
	_current_focus = element
	
	# Add to focus history
	if old_focus != null:
		_focus_history.append(old_focus)
		# Limit history size
		if _focus_history.size() > 10:
			_focus_history.pop_front()
	
	# Set actual focus
	if element is Control:
		element.grab_focus()
	
	focus_changed.emit(old_focus, element)
	_on_focus_changed(old_focus, element)

## Restore previous focus
func restore_previous_focus() -> void:
	if _focus_history.is_empty():
		return
	
	var previous_focus_val: Variant = _focus_history.pop_back()
	var previous_focus: Control = previous_focus_val if previous_focus_val is Control else null
	if previous_focus != null:
		set_focus(previous_focus)

## Clear focus
func clear_focus() -> void:
	if _current_focus != null:
		var old_focus := _current_focus
		_current_focus = null
		if old_focus is Control:
			old_focus.release_focus()
		focus_changed.emit(old_focus, null)
		_on_focus_changed(old_focus, null)

## Get a registered UI element
func get_ui_element(element_name: String) -> Control:
	if not _ui_elements.has(element_name):
		return null
	return _ui_elements[element_name] as Control

## Check if a UI element is visible
func is_ui_element_visible(element_name: String) -> bool:
	if not _ui_elements.has(element_name):
		return false
	return (_ui_elements[element_name] as Control).visible

## Check if a menu is open
func is_menu_open(menu_name: String) -> bool:
	return menu_name in _open_menus

## Check if a dialog is open
func is_dialog_open(dialog_name: String) -> bool:
	return dialog_name in _open_dialogs

## Get current focus
func get_current_focus() -> Control:
	return _current_focus

## Get open menus
func get_open_menus() -> Array[String]:
	return _open_menus.duplicate()

## Get open dialogs
func get_open_dialogs() -> Array[String]:
	return _open_dialogs.duplicate()

## Virtual methods - Override these in extended classes

## Called when UI manager is ready
## Override to add initialization logic
func _on_ui_manager_ready() -> void:
	pass

## Called when a UI element is registered
## Override to handle element registration
func _on_ui_element_registered(_name: String, _element: Control) -> void:
	pass

## Called when a UI element is unregistered
## Override to handle element unregistration
func _on_ui_element_unregistered(_name: String, _element: Control) -> void:
	pass

## Called when a UI element is shown
## Override to handle element showing
func _on_ui_element_shown(_name: String, _element: Control) -> void:
	pass

## Called when a UI element is hidden
## Override to handle element hiding
func _on_ui_element_hidden(_name: String, _element: Control) -> void:
	pass

## Called when a menu is opened
## Override to handle menu opening
func _on_menu_opened(_menu_name: String) -> void:
	pass

## Called when a menu is closed
## Override to handle menu closing
func _on_menu_closed(_menu_name: String) -> void:
	pass

## Called when menu focus is restored
## Override to handle focus restoration
func _on_menu_focus_restored(_menu_name: String) -> void:
	pass

## Called when a dialog is opened
## Override to handle dialog opening
func _on_dialog_opened(_dialog_name: String) -> void:
	pass

## Called when a dialog is closed
## Override to handle dialog closing
func _on_dialog_closed(_dialog_name: String) -> void:
	pass

## Called when focus changes
## Override to handle focus changes
func _on_focus_changed(_old_element: Control, _new_element: Control) -> void:
	pass
