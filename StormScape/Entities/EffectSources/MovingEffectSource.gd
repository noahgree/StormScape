extends EffectSource
class_name MovingEffectSource
## Extends the base DamageSource to provide attributes and methods specific to damage types that move. 
##
## This means things like flying projectiles and magic spell balls, not a moving entity that does damage on touch.

@export var piercing_count: int = 0 ## The number of entities this damage source can travel through 

var previous_position: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	previous_position = global_position
	position.x += 50 * delta
	position.y += 1 * delta

func get_movement_direction() -> Vector2:
	var movement_direction = global_position - previous_position
	return movement_direction.normalized()
