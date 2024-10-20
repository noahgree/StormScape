extends Button

@export var health_component: HealthComponent


func _on_pressed() -> void:
	health_component.damage_shield_then_health(12)
