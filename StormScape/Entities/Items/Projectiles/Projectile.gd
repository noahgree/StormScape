extends HitboxComponent
class_name Projectile
## The viusal representation of the projectile. Defines all needed methods for how to travel and seek, with the flags for what
## to do being set by whatever spawns the projectile.

@export var whiz_sound: String = ""
@export_range(0, 100, 0.1, "suffix:%") var glow_strength: float = 0
@export var glow_color: Color = Color(1, 1, 1)
@export var impact_vfx: PackedScene = null
@export var impact_sound: String = ""

@onready var previous_position: Vector2 = global_position
@onready var sprite: Sprite2D = $Sprite2D

var stats: ProjectileResource
var lifetime_timer: Timer = Timer.new()
var starting_position: Vector2
var starting_rotation: float
var pierce_count: int = 0
var ricochet_count: int = 0
var split_proj_scene: PackedScene
var splits_so_far: int = 0
var split_delay_counter: float = 0
var spin_dir: int = 1


static func spawn(proj_scene: PackedScene, proj_stats: ProjectileResource, effect_src: EffectSource,
				src_entity: PhysicsBody2D, pos: Vector2, rot: float) -> Projectile:
	var proj: Projectile = proj_scene.instantiate()
	proj.split_proj_scene = proj_scene
	proj.global_position = pos
	proj.rotation = rot
	proj.stats = proj_stats
	proj.effect_source = effect_src
	proj.collision_mask = effect_src.scanned_phys_layers
	proj.source_entity = src_entity
	return proj

func _ready() -> void:
	super._ready()
	z_index = -1
	add_child(lifetime_timer)
	lifetime_timer.timeout.connect(queue_free)
	lifetime_timer.start(stats.lifetime)

	if stats.spin_both_ways:
		spin_dir = -1 if randf() < 0.5 else 1
	else:
		if stats.spin_direction == "Left":
			spin_dir = -1
		else:
			spin_dir = 1

	var start_offset: int = int(floor(sprite.region_rect.size.x / 2.0))
	var offset_vector: Vector2 = Vector2(start_offset, 0).rotated(global_rotation)
	global_position += offset_vector if splits_so_far < 1 else Vector2.ZERO

	starting_position = global_position
	starting_rotation = global_rotation

func _physics_process(delta: float) -> void:
	movement_direction = (global_position - previous_position).normalized()
	if (global_position - starting_position).length() >= stats.max_distance:
		queue_free()

	_do_projectile_movement(delta)

	split_delay_counter += delta
	if split_delay_counter >= stats.split_delay:
		_split_self()

func _do_projectile_movement(delta: float) -> void:
	var speed: float = stats.speed_curve.sample_baked(lifetime_timer.time_left / stats.lifetime) * stats.speed
	rotation += stats.spin_speed * delta * spin_dir

	if stats.move_in_rotated_dir:
		position += transform.x * speed * delta
	else:
		position += Vector2(cos(starting_rotation), sin(starting_rotation)).normalized() * speed * delta

func _split_self() -> void:
	if not (splits_so_far < stats.number_of_splits) or (stats.split_into_count < 2):
		return

	splits_so_far += 1
	var step_angle = (deg_to_rad(stats.split_angle) / (stats.split_into_count - 1))
	var start_angle = rotation - (deg_to_rad(stats.split_angle) / 2)

	for i in range(stats.split_into_count):
		var angle = start_angle + (i * step_angle)
		var new_proj: Projectile = Projectile.spawn(split_proj_scene, stats, effect_source, source_entity, position, angle)
		new_proj.splits_so_far = splits_so_far

		get_parent().add_child(new_proj)

	queue_free()

func _process_hit(object) -> void:
	if ricochet_count < stats.max_ricochet:
		var collision_normal = (global_position - object.global_position).normalized()
		var direction = Vector2(cos(starting_rotation), sin(starting_rotation))

		var reflected_direction: Vector2
		if (object is TileMapLayer) or (not stats.ricochet_bounce):
			reflected_direction = -direction
		else:
			reflected_direction = direction.bounce(collision_normal)

		starting_rotation = reflected_direction.angle()
		rotation = reflected_direction.angle()

		ricochet_count += 1
		return

	if pierce_count < stats.max_pierce:
		pierce_count += 1
	else:
		queue_free()
