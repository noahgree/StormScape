class_name VectorHelpers


static func random_direction() -> Vector2:
	var random_angle: float = randf() * TAU
	return Vector2(cos(random_angle), sin(random_angle)).normalized()

static func randi_between_xy(range_vector: Vector2i) -> float:
	return randi_range(range_vector.x, range_vector.y)
