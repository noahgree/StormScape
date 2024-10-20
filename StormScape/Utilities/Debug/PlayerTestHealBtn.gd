extends Button

@export var health_component: HealthComponent


func _on_pressed() -> void:
	health_component.heal_health_then_shield(15)
