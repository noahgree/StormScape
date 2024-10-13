extends Node
class_name HealthComponent


@export var max_health: int = 100
@export var max_shield: int = 100
var health: int: set = _set_health
var shield: int: set = _set_shield
var ready_to_broadcast: bool # makes sure the call deffered's have been called already


func _ready() -> void: 
	health = max_health
	shield = max_shield
	call_deferred("_emit_initial_values")


func take_damage(amount: int) -> void:
	var spillover_damage: int = max(0, amount - shield)
	shield = clampi(shield - amount, 0, max_shield)
	
	if spillover_damage > 0:
		health = clampi(health - spillover_damage, 0, max_health)
		
	# handling death
	if health <= 0:
		if get_parent().has_method("die"):
			get_parent().die()
		else:
			get_parent().queue_free()

func heal(amount: int) -> void:
	var spillover_health: int = max(0, (amount + health) - max_health)
	health = clampi(health + amount, 0, max_health)
	
	if spillover_health > 0:
		shield = clampi(shield + spillover_health, 0, max_shield)


func _emit_initial_values() -> void:
	SignalBus.PlayerHealthChanged.emit(health)
	SignalBus.PlayerShieldChanged.emit(shield)
	ready_to_broadcast = true

func _set_health(new_value: int) -> void:
	health = clampi(new_value, 0, max_health)
	if ready_to_broadcast:
		SignalBus.PlayerHealthChanged.emit(health)

func _set_shield(new_value: int) -> void:
	shield = clampi(new_value, 0, max_shield)
	if ready_to_broadcast:
		SignalBus.PlayerShieldChanged.emit(shield)
