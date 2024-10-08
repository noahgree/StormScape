extends Node
class_name StaminaComponent

@export var max_stamina: float = 100.0

var stamina: float
var can_use_stamina: bool = true


func _ready() -> void:
	stamina = max_stamina

func use_stamina(amount: float) -> bool:
	if !can_use_stamina:
		return false
	
	if stamina < amount:
		return false
	else:
		print(stamina)
		stamina -= amount
		return true

func get_can_use_stamina() -> bool:
	return can_use_stamina

func set_can_use_stamina(flag: bool) -> void:
	can_use_stamina = flag
