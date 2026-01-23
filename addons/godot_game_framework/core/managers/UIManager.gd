class_name GGF_UIManager
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

const _OVERRIDE_UI_CONFIG_PATH := "res://ggf_ui_config.tres"
const _DEFAULT_UI_CONFIG_PATH := "res://addons/godot_game_framework/resources/ui/ggf_ui_config_default.tres"

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

# UI scene config + layer containers
var _ui_config: Resource = null
var _ui_root: Control = null
var _layer_containers: Dictionary = {}  # int -> Control
var _root_container: Control = null


## Initialize the UI manager
## Override this method to add custom initialization
func _ready() -> void:
	_initialize_ui_layers()
	_ensure_root_container()
	_load_and_apply_ui_config()
	_initialize_ui_manager()
	_on_ui_manager_ready()


## Initialize UI layers
## Override this method to customize layer setup
func _initialize_ui_layers() -> void:
	layer = ui_layer


func _ensure_root_container() -> void:
	if _root_container != null and is_instance_valid(_root_container):
		return

	_root_container = Control.new()
	_root_container.name = "Root"
	_root_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root_container)


## Load and apply optional UI config Resource.
func _load_and_apply_ui_config() -> void:
	_ui_config = _load_ui_config_resource()
	if _ui_config == null:
		return

	var ui_root_scene_val: Variant = _ui_config.get("ui_root_scene")
	if ui_root_scene_val is PackedScene:
		var ui_root_inst := (ui_root_scene_val as PackedScene).instantiate()
		if ui_root_inst is Control:
			_ui_root = ui_root_inst as Control
			if _root_container != null and is_instance_valid(_root_container):
				_root_container.add_child(_ui_root)
			else:
				add_child(_ui_root)
			_cache_layer_containers()
			_apply_container_z_indices()
		else:
			if ui_root_inst != null:
				ui_root_inst.queue_free()
			GGF.log().warn("UIManager", "ui_root_scene must instance a Control; using default behavior")

	var pre_registered_val: Variant = _ui_config.get("pre_registered")
	if pre_registered_val is Array:
		for entry_val in pre_registered_val:
			if not (entry_val is Dictionary):
				continue
			var entry := entry_val as Dictionary
			var name_val: Variant = entry.get("name", "")
			var scene_val: Variant = entry.get("scene", null)
			var layer_val: Variant = entry.get("layer", -1)
			var visible_val: Variant = entry.get("visible", false)

			var element_name: String = name_val if name_val is String else ""
			var scene: PackedScene = scene_val as PackedScene
			var z_layer: int = layer_val if layer_val is int else -1
			var is_visible: bool = visible_val if visible_val is bool else false

			if element_name.is_empty() or scene == null:
				continue

			var ctrl := register_ui_scene(element_name, scene, z_layer)
			if ctrl != null and is_visible:
				show_ui_element(element_name)


func _load_ui_config_resource() -> Resource:
	if ResourceLoader.exists(_OVERRIDE_UI_CONFIG_PATH):
		return load(_OVERRIDE_UI_CONFIG_PATH) as Resource
	if ResourceLoader.exists(_DEFAULT_UI_CONFIG_PATH):
		return load(_DEFAULT_UI_CONFIG_PATH) as Resource
	return null


func _cache_layer_containers() -> void:
	_layer_containers.clear()
	if _ui_root == null:
		return

	var background := _ui_root.get_node_or_null("Background") as Control
	var game := _ui_root.get_node_or_null("Game") as Control
	var ui := _ui_root.get_node_or_null("UI") as Control
	var menu := _ui_root.get_node_or_null("Menu") as Control
	var dialog := _ui_root.get_node_or_null("Dialog") as Control
	var overlay := _ui_root.get_node_or_null("Overlay") as Control

	if background != null:
		_layer_containers[background_layer] = background
	if game != null:
		_layer_containers[game_layer] = game
	if ui != null:
		_layer_containers[ui_layer] = ui
	if menu != null:
		_layer_containers[menu_layer] = menu
	if dialog != null:
		_layer_containers[dialog_layer] = dialog
	if overlay != null:
		_layer_containers[overlay_layer] = overlay


func _apply_container_z_indices() -> void:
	for z in _layer_containers.keys():
		var container := _layer_containers[z] as Control
		if container != null:
			container.z_index = int(z)


## Get the container Control for a layer (z-index).
func get_layer_container(z_layer: int) -> Control:
	var container := _layer_containers.get(z_layer, null) as Control
	if container != null:
		return container
	if _root_container != null and is_instance_valid(_root_container):
		return _root_container
	return _ui_root if _ui_root != null else null


## Register a UI element from a PackedScene.
func register_ui_scene(element_name: String, scene: PackedScene, z_layer: int = -1) -> Control:
	if scene == null:
		GGF.log().error("UIManager", "Cannot register null PackedScene: " + element_name)
		return null

	var inst := scene.instantiate()
	if not (inst is Control):
		if inst != null:
			inst.queue_free()
		GGF.log().error("UIManager", "PackedScene must instance a Control: " + element_name)
		return null

	var ctrl := inst as Control
	register_ui_element(element_name, ctrl, z_layer)
	return ctrl


## Initialize UI manager
## Override this method to customize initialization
func _initialize_ui_manager() -> void:
	# Connect to input events for focus management
	pass


## Register a UI element
## Override this method to add custom registration logic
func register_ui_element(element_name: String, element: Control, z_layer: int = -1) -> void:
	if element_name.is_empty():
		GGF.log().error("UIManager", "Cannot register UI element with empty name")
		return

	if element == null:
		GGF.log().error("UIManager", "Cannot register null UI element: " + element_name)
		return

	# Set layer if specified
	if z_layer >= 0:
		element.z_index = z_layer

	# Store element
	_ui_elements[element_name] = element

	# Add to scene tree if not already
	if not element.get_parent():
		var parent_container := get_layer_container(z_layer)
		parent_container.add_child(element)

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
		GGF.log().warn("UIManager", "UI element not registered: " + element_name)
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
		GGF.log().warn("UIManager", "UI element not registered: " + element_name)
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
func _toggle_ui_element(element_name: String) -> void:
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
		GGF.log().warn("UIManager", "Menu not registered: " + menu_name)
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
		GGF.log().warn("UIManager", "Dialog not registered: " + dialog_name)
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
