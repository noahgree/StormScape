extends Area2D
class_name HurtboxComponent
## A component for handling an entity taking damage.
##
## Connects to a compatible HealthComponent and sends a damage source when this hurtbox is hit by something's hitbox.

@onready var parent: PhysicsBody2D = get_parent()
