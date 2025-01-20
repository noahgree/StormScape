extends Node2D
## Simulates casings being ejected from weapons.

@onready var sprite: Sprite2D = $Sprite2D ## The casing sprite

const EJECTION_DIST: int = 15 ## How far out to shoot the casing.
const UPWARD_ANGLE: float = 0.12 ## Angle in radians for upward ejection.
const DOWNWARD_DIST: int = 10 ## How far down to travel to the 'ground'.
const BOUNCE_HEIGHT: int = 2 ## How high to bounce off the 'ground'.
const BOUNCE_FORWARD_OFFSET: int = 4 ## How much forward movement to retain in the bounce.

func _ready() -> void:
	_do_casing_ejection()

## Simulates the casing ejection movement then frees itself after.
func _do_casing_ejection() -> void:
	var tween: Tween = create_tween()

	# Calculate ejection direction with an upward angle
	var ejection_angle: float = global_rotation + PI / 2 + UPWARD_ANGLE + randf_range(-0.1, 0.1)
	var ejection_dir: Vector2 = Vector2(cos(ejection_angle), sin(ejection_angle))

	var random_offset: Vector2 = Vector2(randi_range(-2, 2), randi_range(-2, 2))
	var ejection_target_pos: Vector2 = sprite.global_position + ejection_dir * EJECTION_DIST
	var final_target_pos: Vector2 = ejection_target_pos + Vector2(0, DOWNWARD_DIST) + random_offset

	var bounce_pos: Vector2 = final_target_pos - Vector2(0, BOUNCE_HEIGHT) + ejection_dir * BOUNCE_FORWARD_OFFSET
	var post_bounce_pos: Vector2 = final_target_pos + ejection_dir * (BOUNCE_FORWARD_OFFSET * 1.5)

	# Tween for initial ejection with upward angle
	tween.tween_property(sprite, "global_position", ejection_target_pos, 0.2).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)

	# Tween for downward movement
	tween.parallel().tween_property(sprite, "global_position", final_target_pos, 0.2).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN).set_delay(0.1)

	# Add the bounce effect
	tween.tween_property(sprite, "global_position", bounce_pos, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "global_position", post_bounce_pos, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Fade out and free the casing
	tween.parallel().tween_property(sprite, "self_modulate:a", 0.0, 0.5).set_delay(0.4)
	tween.tween_callback(queue_free).set_delay(0.05)
