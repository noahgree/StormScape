class_name LerpHelpers
## Functions that help with lerping values in more complex ways than are provided by the engine.


static func lerp_direction(curr_direction: Vector2, target_pos: Vector2,
							origin: Vector2, factor: float) -> Vector2:
	var target_direction: Vector2 = target_pos - origin
	var current_angle: float = curr_direction.angle()
	var target_angle: float = target_direction.angle()
	var angle_diff: float = angle_difference(current_angle, target_angle)
	var new_angle: float = current_angle + (angle_diff * factor)

	return Vector2.RIGHT.rotated(new_angle)
