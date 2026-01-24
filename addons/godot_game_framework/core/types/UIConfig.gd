class_name GGF_UIConfig extends Resource

## GGF_UIConfig - Scene configuration for UIManager and NotificationManager
##
## Host projects can override the framework defaults by creating:
## `res://ggf_ui_config.tres`
##
## If the override file does not exist, managers will fall back to:
## `res://addons/godot_game_framework/resources/ui/ggf_ui_config_default.tres`

@export_group("Core UI Scenes")
@export var ui_root_scene: PackedScene

@export_group("Notification Scenes")
@export var notification_container_scene: PackedScene
@export var notification_toast_scene: PackedScene

@export_group("Optional Pre-Registered UI")
## Each entry is a Dictionary with keys:
## - name: String
## - scene: PackedScene
## - layer: int
## - kind: String ("element" | "menu" | "dialog") (optional)
## - visible: bool (optional, default false)
@export var pre_registered: Array[Dictionary] = []
