extends Line2D
class_name FootStreak

static var scene: PackedScene = load("res://Entities/EntityCore/EntityTypes/DynamicEntity/FootStreak.tscn")

@onready var particles: CPUParticles2D = $CPUParticles2D

const MAX_TRAIL_LENGTH: float = 50.0
var lifetime_timer: Timer = TimerHelpers.create_one_shot_timer(self, 0.5, _on_lifetime_timer_timeout)
var is_fading: bool = false


static func create() -> FootStreak:
	var streak: FootStreak = scene.instantiate()
	return streak

func _ready() -> void:
	lifetime_timer.start()

func update_trail_position(pos: Vector2, particle_rot: float) -> void:
	lifetime_timer.stop()
	lifetime_timer.start()

	add_point(pos)
	particles.global_position = pos
	particles.global_rotation = particle_rot
	particles.emitting = true

	if points.size() > MAX_TRAIL_LENGTH:
		remove_point(0)

func _on_lifetime_timer_timeout() -> void:
	is_fading = true

	var tween: Tween = create_tween()
	tween.tween_method(func(new_value: float) -> void:
		modulate.a = new_value
		gradient.set_offset(2, new_value),
		1.0, 0.0, 5.0)
	tween.parallel().tween_method(func(new_value: float) -> void: gradient.set_offset(1, new_value), gradient.get_offset(1), 0.0, 5.0)
	tween.chain().tween_callback(queue_free)
