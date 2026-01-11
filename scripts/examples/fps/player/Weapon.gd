extends Node

@export var damage: int = 25
@export var max_range: float = 200.0

var magazine_size: int = 12
var ammo: int = 12

func setup(p_magazine_size: int) -> void:
	magazine_size = max(1, p_magazine_size)
	ammo = magazine_size

func reload() -> void:
	ammo = magazine_size

func try_consume_shot() -> bool:
	if ammo <= 0:
		return false
	ammo -= 1
	return true
