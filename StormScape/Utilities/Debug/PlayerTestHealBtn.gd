extends Button

@export var health_component: HealthComponent
@export var stamina_component: StaminaComponent


func _on_pressed() -> void:
	health_component.heal(15)
