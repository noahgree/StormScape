extends Line2D
class_name FootStreak

static var scene: PackedScene = load("res://Entities/EntityCore/EntityTypes/DynamicEntity/FootStreak.tscn")

@onready var particles: CPUParticles2D = $CPUParticles2D

const MAX_TRAIL_LENGTH = 50
var lifetime_timer: Timer = Timer.new()
var is_fading: bool = false


static func create() -> FootStreak:
	var streak: FootStreak = scene.instantiate()
	return streak

func _ready() -> void:
	add_child(lifetime_timer)
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)
	lifetime_timer.wait_time = 0.5
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
	tween.tween_method(func(new_value):
		modulate.a = new_value
		gradient.set_offset(2, new_value),
		1.0, 0.0, 5.0)
	tween.parallel().tween_method(func(new_value): gradient.set_offset(1, new_value), gradient.get_offset(1), 0.0, 5.0)
	tween.chain().tween_callback(queue_free)
