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
@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var shadow: Sprite2D = $Shadow

var stats: ProjectileResource
var lifetime_timer: Timer = Timer.new()
var splash_effect_delay_timer: Timer = Timer.new()
var starting_position: Vector2
var starting_rotation: float
var pierce_count: int = 0
var ricochet_count: int = 0
var split_proj_scene: PackedScene
var splits_so_far: int = 0
var split_delay_counter: float = 0
var spin_dir: int = 1
var is_in_aoe_phase: bool = false
var fake_z_axis: float = 0
var arc_time_counter: float = 0
var arc_spin_time_counter: float = 0
var starting_arc_speed: float = 0
var starting_arc_direction: Vector2
var starting_arc_position: Vector2


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
	shadow.visible = false
	add_child(lifetime_timer)
	add_child(splash_effect_delay_timer)
	lifetime_timer.one_shot = true
	splash_effect_delay_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)
	lifetime_timer.start(stats.lifetime)

	_set_up_starting_transform_and_spin_logic()
	_set_up_arc_logic()

func _enable_collider() -> void:
	collider.disabled = false

func _disable_collider() -> void:
	collider.disabled = true

func _set_up_starting_transform_and_spin_logic() -> void:
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
	starting_arc_position = global_position

func _physics_process(delta: float) -> void:
	movement_direction = (global_position - previous_position).normalized()
	if (global_position - starting_position).length() >= stats.max_distance:
		queue_free()

	if not is_in_aoe_phase and not stats.launch_angle > 0:
		_do_projectile_movement(delta)
	elif stats.launch_angle > 0:
		_handle_arc(delta)
		shadow.visible = true

	split_delay_counter += delta
	if splits_so_far < stats.number_of_splits and split_delay_counter >= stats.split_delays[splits_so_far]:
		shadow.visible = false
		_split_self()

func _do_projectile_movement(delta: float) -> void:
	var speed: float = stats.speed_curve.sample_baked(lifetime_timer.time_left / stats.lifetime) * stats.speed
	rotation += deg_to_rad(stats.spin_speed * spin_dir) * delta

	if stats.move_in_rotated_dir:
		position += transform.x * speed * delta
	else:
		position += Vector2(cos(starting_rotation), sin(starting_rotation)).normalized() * speed * delta

	shadow.visible = true

func _set_up_arc_logic() -> void:
	starting_arc_direction = Vector2(cos(rotation), sin(rotation)).normalized()
	starting_arc_speed = pow(stats.arc_travel_distance * 9.8 / sin(2 * deg_to_rad(stats.launch_angle)), 0.5)
	shadow.global_position = global_position + Vector2(0, -6)

func _handle_arc(delta: float) -> void:
	arc_time_counter += delta * (stats.arc_speed / 90.0)
	arc_spin_time_counter += delta

	fake_z_axis = starting_arc_speed * sin(deg_to_rad(stats.launch_angle)) * arc_time_counter - 0.5 * 9.8 * pow(arc_time_counter, 2)

	if fake_z_axis > 0:
		z_index = 3
		var fake_x_axis: float = starting_arc_speed * cos(deg_to_rad(stats.launch_angle)) * arc_time_counter
		var new_position = starting_arc_position + (starting_arc_direction * fake_x_axis)
		new_position.y -= fake_z_axis
		var fake_move_dir = (new_position - global_position).normalized()
		rotation = atan2(fake_move_dir.y, fake_move_dir.x)
		rotation += arc_spin_time_counter * deg_to_rad(stats.spin_speed * spin_dir)
		global_position = new_position

		var fake_shadow_dir = starting_arc_direction.normalized()
		shadow.rotation = atan2(fake_shadow_dir.y, fake_shadow_dir.x)
		shadow.rotation += arc_spin_time_counter * deg_to_rad(stats.spin_speed * spin_dir)
		shadow.global_position = starting_arc_position + (starting_arc_direction * fake_x_axis)
		shadow.visible = true
	else:
		z_index = -1
		if stats.do_aoe_on_arc_land and (stats.splash_radius > 0) and not is_in_aoe_phase:
			_handle_aoe()
		else:
			if stats.grounding_free_delay > 0:
				await get_tree().create_timer(stats.grounding_free_delay, false, true, false).timeout
			queue_free()

	if fake_z_axis > stats.max_collision_height:
		call_deferred("_disable_collider")
	else:
		call_deferred("_enable_collider")

func _split_self() -> void:
	if not (splits_so_far < stats.number_of_splits) or (stats.split_into_counts[splits_so_far] < 2):
		return

	var initial_rot: float = starting_rotation if stats.launch_angle > 0 else rotation

	splits_so_far += 1
	var close_to_360_adjustment: int = 0 if stats.angular_spreads[splits_so_far - 1] > 310 else 1
	var step_angle = (deg_to_rad(stats.angular_spreads[splits_so_far - 1]) / (stats.split_into_counts[splits_so_far - 1] - close_to_360_adjustment))
	var start_angle = initial_rot - (deg_to_rad(stats.angular_spreads[splits_so_far - 1]) / 2)

	for i in range(stats.split_into_counts[splits_so_far - 1]):
		var angle: float = start_angle + (i * step_angle)
		var new_proj: Projectile = Projectile.spawn(split_proj_scene, stats, effect_source, source_entity, position, angle)
		new_proj.splits_so_far = splits_so_far

		get_parent().add_child(new_proj)

	if stats.splitting_sounds[splits_so_far - 1] != "":
		AudioManager.play_sound(stats.splitting_sounds[splits_so_far - 1], AudioManager.SoundType.SFX_2D, global_position)
	if stats.split_cam_shakes_dur[splits_so_far - 1] > 0:
		GlobalData.player_camera.start_shake(stats.split_cam_shakes_str[splits_so_far - 1], stats.split_cam_shakes_dur[splits_so_far - 1])

	queue_free()

func _handle_ricochet(object: Variant) -> void:
	var collision_normal: Vector2 = (global_position - object.global_position).normalized()
	var direction = Vector2(cos(starting_rotation), sin(starting_rotation))

	var reflected_direction: Vector2
	if (object is TileMapLayer) or (not stats.ricochet_bounce) or (stats.launch_angle > 0):
		reflected_direction = -direction

		starting_arc_direction = reflected_direction.normalized()
		starting_arc_position = global_position
		arc_time_counter = 0
	else:
		reflected_direction = direction.bounce(collision_normal)

	starting_rotation = reflected_direction.angle()
	rotation = reflected_direction.angle()

	ricochet_count += 1

func _handle_pierce() -> void:
		pierce_count += 1

func _handle_aoe() -> void:
	if collider.shape is not CircleShape2D:
		push_error("\"" + name + "\" projectile has AOE logic but its collision shape is not a circle.")
		return

	if stats.splash_effect_source == null: stats.splash_effect_source = effect_source
	is_in_aoe_phase = true
	if stats.splash_effect_delay > 0:
		call_deferred("_disable_collider")

		if anim_player != null and anim_player.get_animation_library("ProjectileAnimLibrary").has_animation("aoe"):
			anim_player.speed_scale = 1 / stats.splash_effect_delay
			anim_player.play("ProjectileAnimLibrary/aoe")

		splash_effect_delay_timer.start(stats.splash_effect_delay)
		await splash_effect_delay_timer.timeout

	var new_shape: CircleShape2D = collider.shape.duplicate()
	call_deferred("_assign_new_collider_shape", new_shape)

	await get_tree().create_timer(max(0.05, stats.splash_effect_dur), false, true, false).timeout

	queue_free()

func _assign_new_collider_shape(new_shape: CircleShape2D) -> void:
	new_shape.radius = stats.splash_radius
	collider.shape = new_shape
	_enable_collider()

func _process_hit(object: Variant) -> void:
	if not is_in_aoe_phase:
		if ricochet_count < stats.max_ricochet:
			_handle_ricochet(object)
			return

		if pierce_count < stats.max_pierce:
			_handle_pierce()
			return

		if stats.splash_radius > 0:
			lifetime_timer.stop()
			_handle_aoe()
			return

		queue_free()

func _start_being_handled(handling_area: EffectReceiverComponent) -> void:
	if stats.splash_radius == 0:
		effect_source = effect_source.duplicate()
		effect_source.movement_direction = movement_direction
		effect_source.contact_position = get_parent().global_position
		handling_area.handle_effect_source(effect_source, source_entity)
	else:
		var modified_effect_source: EffectSource = _get_effect_source_adjusted_for_aoe_falloff(handling_area)
		modified_effect_source.is_projectile = false
		modified_effect_source.contact_position = global_position
		handling_area.handle_effect_source(modified_effect_source, source_entity)

func _get_effect_source_adjusted_for_aoe_falloff(handling_area: EffectReceiverComponent) -> EffectSource:
	var dist_to_center: float = handling_area.get_parent().global_position.distance_to(global_position)
	var falloff_effect_src: EffectSource = stats.splash_effect_source.duplicate()
	var falloff_mult: float = max(0.05, stats.splash_falloff_curve.sample_baked(dist_to_center / float(stats.splash_radius)))

	falloff_effect_src.cam_shake_strength *= falloff_mult
	falloff_effect_src.cam_freeze_multiplier *= falloff_mult

	if stats.bad_effects_falloff:
		falloff_effect_src.base_damage = int(ceil(falloff_effect_src.base_damage * falloff_mult))
		for i in range(falloff_effect_src.status_effects.size()):
			if falloff_effect_src.status_effects[i] != null and falloff_effect_src.status_effects[i].is_bad_effect:
				var new_stat_effect: StatusEffect = falloff_effect_src.status_effects[i].duplicate()
				new_stat_effect.mod_time *= falloff_mult
				if new_stat_effect is KnockbackEffect:
					new_stat_effect.knockback_force *= falloff_mult

				falloff_effect_src.status_effects[i] = new_stat_effect

	if stats.good_effects_falloff:
		falloff_effect_src.base_healing = int(ceil(falloff_effect_src.base_healing * falloff_mult))
		for i in range(falloff_effect_src.status_effects.size()):
			if falloff_effect_src.status_effects[i] != null and not falloff_effect_src.status_effects[i].is_bad_effect:
				var new_stat_effect: StatusEffect = falloff_effect_src.status_effects[i].duplicate()
				new_stat_effect.mod_time *= falloff_mult

				falloff_effect_src.status_effects[i] = new_stat_effect

	return falloff_effect_src

func _on_lifetime_timer_timeout() -> void:
	if stats.splash_radius > 0 and stats.splash_before_freeing:
		_handle_aoe()
	else:
		queue_free()
