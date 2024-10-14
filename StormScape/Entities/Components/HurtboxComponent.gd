@icon("res://Utilities/Debug/EditorIcons/hurtbox_component.svg")
extends Area2D
class_name HurtboxComponent
## A component for handling an entity taking damage.
##
## Connects to a compatible HealthComponent and applies damage when this hurtbox is hit by something's hitbox.

@export var health_component: HealthComponent

func take_damage(amount: int) -> void:
	if health_component:
		health_component.take_damage(amount)
