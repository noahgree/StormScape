extends Node
class_name HealthComponent

@export var max_health: int = 100
@export var max_shield: int = 100
var health: int
var shield: int


func _ready() -> void: 
	health = max_health
	shield = max_shield

func take_damage(amount: int) -> void:
	var spillover_shield: int = shield - amount
	amount -= shield
	
	shield = clampi(spillover_shield, 0, max_shield)
	
	if amount > 0:
		health = clampi(health - amount, 0, max_health)
	
	# handling death
	if health <= 0:
		if get_parent().has_method("die"):
			get_parent().die()
		else:
			get_parent().queue_free()
