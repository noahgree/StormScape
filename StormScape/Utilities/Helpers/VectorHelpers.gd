class_name VectorHelpers


static func get_random_direction() -> Vector2:
	var random_angle: float = randf() * TAU
	return Vector2(cos(random_angle), sin(random_angle)).normalized()
