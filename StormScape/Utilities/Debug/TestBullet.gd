extends Node2D

var previous_position: Vector2
var movement_direction: Vector2


func _physics_process(delta: float) -> void:
	position.x += 20 * delta
	position.y += 1 * delta
	movement_direction = get_movement_direction()
	previous_position = global_position

func get_movement_direction() -> Vector2:
	return (global_position - previous_position).normalized()
