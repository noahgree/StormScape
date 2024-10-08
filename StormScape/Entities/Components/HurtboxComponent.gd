extends Area2D
class_name HurtboxComponent

@export var health_component: HealthComponent

func take_damage(amount: int) -> void:
	if health_component:
		health_component.take_damage(amount)
