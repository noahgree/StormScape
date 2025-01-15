extends HitboxComponent
class_name Projectile
## The viusal representation of the projectile. Defines all needed methods for how to travel and seek, with the flags for what
## to do being set by whatever spawns the projectile.

@export var whiz_sound: String = "" ## The sound to play when whizzing by the player.
@export_custom(PROPERTY_HINT_NONE, "suffix:pixels") var whiz_sound_distance: int = 25 ## The max distance from the player that the whiz sound will still play.
@export_range(0, 500, 0.1, "suffix:%") var glow_strength: float = 0 ## How strong the glow should be.
@export var glow_color: Color = Color(1, 1, 1) ## The color of the glow.
@export var impact_vfx: PackedScene = null ## The VFX to spawn at the site of impact. Could be a decal or something.
@export var impact_sound: String = "" ## The sound to play at the site of impact.

@onready var sprite: Node2D = $ProjSprite ## The sprite for this projectile.
@onready var shadow: Sprite2D = $Shadow ## The shadow sprite for this projectile.
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer") ## The anim player for this projectile.

#region Local Vars
const FOV_RAYCAST_COUNT: int = 36
var stats: ProjectileResource ## The logic for how to operate this projectile.
var s_mods: StatModsCacheResource ## The cache containing the current numerical values for firing metrics.
var starting_proj_height: int ## The starting height the projectile is at when calculating the fake z axis.
var lifetime_timer: Timer = Timer.new() ## The timer tracking how long the projectile has left to exist.
var aoe_delay_timer: Timer = Timer.new() ## The timer tracking how long after starting an AOE do we wait before enabling damage again.
var homing_timer: Timer = Timer.new() ## Timer to control homing duration.
var homing_delay_timer: Timer = Timer.new() ## Timer for homing start delay.
var initial_boost_timer: Timer = Timer.new() ## The timer that tracks how long we have left in an initial boost.
var current_sampled_speed: float = 0 ## The current speed pulled from the speed curve.
var true_current_speed: float = 0 ## The real current speed calculated from change in position over time.
var current_initial_boost: float = 1.0 ## If we need to boost at the start, this tracks the current boost.
var cumulative_distance: float = 0 ## The cumulative distance we have travelled since spawning.
var previous_position: Vector2 ## A temp variable for holding previous position. Used in movement direction calculation.
var starting_position: Vector2 ## The starting position of this projectile. Used in calculations.
var starting_rotation: float ## The starting rotation of this projectile. Used in calculations.
var pierce_count: int = 0 ## The number of times we have pierced so far.
var ricochet_count: int = 0 ## The number of times we have ricocheted so far.
var split_proj_scene: PackedScene ## The packed scene containing this projectile's scene for when we split and need to copy.
var splits_so_far: int = 0 ## The number of times this has been split so far.
var split_delay_counter: float = 0 ## The incremented delta counter for how long to wait before splitting.
var spin_dir: int = 1 ## The spin direction. -1 is left, 1 is right.
var is_in_aoe_phase: bool = false ## Whether we are currently executing an AOE sequence.
var is_arcing: bool = false ## Whether we are currently moving in an arcing motion.
var fake_z_axis: float = 0 ## The fake z axis var for simulating height off the ground while arcing.
var updated_arc_angle: float = 0 ## The updated arcing angle for falloff since the last bounce.
var fake_previous_pos: float ## The fake previous position that ignores the change caused by simulating the fake z axis.
var arc_time_counter: float = 0 ## How long we have been arcing so far.
var non_sped_up_time_counter: float = 0 ## How long we have been moving so far, used in determining spin speed when added.
var starting_arc_speed: float = 0 ## The initial speed of an arc, used in kinematic equations.
var resettable_starting_dir: Vector2 ## The initial direction of an arc, used in kinematic equations.
var resettable_starting_pos: Vector2 ## The starting position of the arc, can be updated after a ricochet to start a new arc.
var bounces_so_far: int = 0 ## The number of times so far that we have bounced off the ground after an initial arc.
var is_homing_active: bool = false ## Indicates if homing is currently active.
var homing_target: Node = null ## The current homing target.
var mouse_scan_targets: Array[Node] ## The current list of targets in range of the mouse click for the mouse position homing.
var played_whiz_sound: bool = false ## Whether this has already played the whiz sound once or not.
var debug_homing_rays: Array[Dictionary] = [] ## An array of debug info about the FOV homing method raycasts.
var debug_recent_hit_location: Vector2 ## The location of the most recent point we hit something.
var source_wpn_stats: ProjWeaponResource ## The projectile weapon resource for the weapon that fired this projectile.
var aoe_overlapped_receivers: Dictionary[Area2D, Timer] = {} ## The areas that are currently in an AOE area.
var is_disabling_monitoring: bool = false ## When true, we are waiting on the deferred call to disable collision monitoring.
var multishot_id: int = 0 ## The id passed in on creation that relates the sibling projectiles spawned on the same multishot barrage.
var max_distance_random_offset: float = 0 ## Assigned upon creation to add randomization to how far each shot of a multishot firing can travel.
#endregion


#region On Load
func _on_before_load_game() -> void:
	queue_free()
#endregion

#region Core
## Creates a projectile and assigns its needed variables in a specific order. Then it returns it.
static func create(wpn_stats: ProjWeaponResource, src_entity: PhysicsBody2D, pos: Vector2, rot: float) -> Projectile:
	var proj_scene: PackedScene = wpn_stats.projectile_scn
	var proj: Projectile = proj_scene.instantiate()
	proj.source_wpn_stats = wpn_stats
	proj.split_proj_scene = proj_scene
	proj.global_position = pos
	proj.rotation = rot

	proj.stats = wpn_stats.projectile_logic
	proj.s_mods = wpn_stats.s_mods
	if proj.stats.speed_curve.point_count == 0:
		push_error("\"" + src_entity.name + "\" has a weapon attempting to fire projectiles, but the projectile resource within the weapon has a blank speed curve.")
	proj.max_distance_random_offset = randf_range(0, 15)

	var effect_src: EffectSource = wpn_stats.effect_source
	proj.effect_source = effect_src
	proj.collision_mask = effect_src.scanned_phys_layers
	proj.source_entity = src_entity
	return proj

## Used for debugging the homing system & other collisions. Draws vectors to where we have scanned during the "FOV" method.
func _draw() -> void:
	if DebugFlags.Projectiles.show_movement_dir:
		var local_movement_direction: Vector2 = movement_direction.rotated(-rotation) * 100
		draw_line(Vector2.ZERO, local_movement_direction, Color(1, 1, 1, 0.5), 0.6)

	if debug_recent_hit_location != Vector2.ZERO and DebugFlags.Projectiles.show_collision_points:
		z_index = 100
		draw_circle(to_local(debug_recent_hit_location), 1.5, Color(1, 1, 0, 0.35))

	if DebugFlags.Projectiles.show_homing_targets and homing_target != null:
		z_index = 100
		draw_circle(to_local(homing_target.global_position), 5, Color(1, 0, 1, 0.3))

	if not DebugFlags.Projectiles.show_homing_rays:
		return

	for ray: Dictionary[String, Variant] in debug_homing_rays:
		var from_pos: Vector2 = to_local(ray["from"])
		var to_pos: Vector2 = to_local(ray["hit_position"])
		var color: Color = Color(0, 1, 0, 0.4) if ray["hit"] else Color(1, 0, 0, 0.25)

		draw_line(from_pos, to_pos, color, 1)

		if ray["hit"]:
			draw_circle(to_pos, 2, color)

## Setting up z_index, hiding shadow until rotation is assigned, and initializing timers. Then this sets up spin and arcing
## logic should we need it.
func _ready() -> void:
	super._ready()
	add_to_group("has_save_logic")
	shadow.visible = false
	previous_position = global_position
	sprite.self_modulate = glow_color * (1.0 + (glow_strength / 100.0))

	add_child(lifetime_timer)
	add_child(aoe_delay_timer)
	add_child(homing_timer)
	add_child(homing_delay_timer)
	add_child(initial_boost_timer)
	lifetime_timer.one_shot = true
	aoe_delay_timer.one_shot = true
	homing_delay_timer.one_shot = true
	homing_timer.one_shot = true
	initial_boost_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout_or_reached_max_distance)
	homing_delay_timer.timeout.connect(_start_homing)
	homing_timer.timeout.connect(_on_homing_timer_timeout)
	initial_boost_timer.timeout.connect(func() -> void: current_initial_boost = 1.0)
	lifetime_timer.start(stats.lifetime)

	_set_up_potential_homing_delay()

	if stats.override_gun_height and splits_so_far == 0:
		starting_proj_height = stats.height_override

	_set_up_starting_transform_and_spin_logic()
	if stats.launch_angle > 0 and stats.homing_method == "None":
		is_arcing = true
		hide()
		_reset_arc_logic()

	if stats.initial_boost_time > 0:
		current_initial_boost = stats.initial_boost_mult
		initial_boost_timer.start(stats.initial_boost_time)

## Enables the main projectile collider.
func _enable_collider() -> void:
	collider.disabled = false

## Disables the main projectile collider.
func _disable_collider() -> void:
	collider.disabled = true

func _disable_monitoring() -> void:
	monitoring = false
	is_disabling_monitoring = false
#endregion

#region General
## Assigns a random spin direction if we need one, otherwise picks from the pre-chosen direction.
## Then it determines where to start shooting from based on how big its sprite texture is.
func _set_up_starting_transform_and_spin_logic() -> void:
	if stats.do_y_axis_reflection:
		var angle: float = wrapf(rotation, 0, TAU)
		if (angle > (PI / 2) and angle < (3 * PI / 2)):
			sprite.flip_v = true

	if stats.spin_both_ways:
		spin_dir = -1 if randf() < 0.5 else 1
	else:
		if splits_so_far == 0:
			var hands_rot: float = fmod(source_entity.hands.hands_anchor.rotation + TAU, TAU)
			if stats.spin_direction == "Forward":
				spin_dir = -1 if hands_rot > PI / 2 and hands_rot < 3 * PI / 2 else 1
			else:
				spin_dir = 1 if hands_rot > PI / 2 and hands_rot < 3 * PI / 2 else -1

	var sprite_rect: Vector2 = SpriteHelpers.SpriteDetails.get_frame_rect(sprite)
	var start_offset: int = int(ceil(sprite_rect.x / (4.0 if (stats.launch_angle > 0 and stats.homing_method == "None") else 2.0)) * scale.x)
	var sprite_offset: Vector2 = Vector2(start_offset, 0).rotated(global_rotation)
	global_position += sprite_offset if splits_so_far < 1 else Vector2.ZERO

	starting_position = global_position
	starting_rotation = global_rotation
	resettable_starting_pos = global_position
	resettable_starting_dir = Vector2(cos(global_rotation), sin(global_rotation)).normalized()

## This is updating our movement direction and determining how to travel based on movement logic in the projectile resource.
func _physics_process(delta: float) -> void:
	non_sped_up_time_counter += delta

	previous_position = global_position

	var max_dist: float = s_mods.get_stat("proj_max_distance")
	if (global_position - starting_position).length() >= (max_dist + max_distance_random_offset):
		if not is_in_aoe_phase:
			_on_lifetime_timer_timeout_or_reached_max_distance()

	if stats.homing_method == "None":
		if not is_in_aoe_phase and not is_arcing:
			_do_projectile_movement(delta)
		elif is_arcing:
			_do_arc_movement(delta)
	else:
		if not is_in_aoe_phase:
			_do_projectile_movement(delta)

	split_delay_counter += delta
	var delay_to_use: float = ArrayHelpers.get_or_default(stats.split_delays, splits_so_far, stats.split_delays[0])
	if splits_so_far < stats.number_of_splits and split_delay_counter >= delay_to_use:
		shadow.visible = false
		_split_self()

	movement_direction = (global_position - previous_position).normalized()
	_check_for_whiz_sound()

	if DebugFlags.Projectiles.show_homing_rays or DebugFlags.Projectiles.show_collision_points or DebugFlags.Projectiles.show_homing_targets or DebugFlags.Projectiles.show_movement_dir:
		queue_redraw()

## This moves the projectile based on the current method, accounting for current rotation if we need to.
## It chooses speed from the speed curve based on lifetime remaining.
func _do_projectile_movement(delta: float) -> void:
	var speed: float = s_mods.get_stat("proj_speed")
	var sampled_point: float = stats.speed_curve.sample_baked(1 - (lifetime_timer.time_left / stats.lifetime))
	current_sampled_speed = sampled_point * speed * current_initial_boost

	if is_homing_active:
		_apply_homing_movement(delta)
		if homing_target == null or not homing_target.is_inside_tree():
			is_homing_active = false
	else:
		rotation += deg_to_rad(stats.spin_speed * spin_dir) * delta

		if stats.move_in_rotated_dir:
			position += transform.x * current_sampled_speed * delta
		else:
			position += Vector2(cos(starting_rotation), sin(starting_rotation)).normalized() * current_sampled_speed * delta

	var distance_change: float = previous_position.distance_to(global_position)
	cumulative_distance += distance_change
	true_current_speed = distance_change / delta

	_update_shadow(global_position, movement_direction)

## Updates the shadow in a realistic manner.
func _update_shadow(new_position: Vector2, movement_dir: Vector2) -> void:
	var fake_shadow_dir: Vector2
	if stats.shadow_matches_spin:
		fake_shadow_dir = movement_dir.normalized()
		shadow.rotation = atan2(fake_shadow_dir.y, fake_shadow_dir.x)
		shadow.rotation += non_sped_up_time_counter * deg_to_rad(stats.spin_speed * spin_dir)
	else:
		fake_shadow_dir = resettable_starting_dir.normalized()
		shadow.rotation = atan2(resettable_starting_dir.y, resettable_starting_dir.x)

	if is_arcing:
		var displacement_vector: Vector2 = new_position - resettable_starting_pos
		var projection_length: float = displacement_vector.dot(resettable_starting_dir)
		shadow.global_position = resettable_starting_pos + (resettable_starting_dir * projection_length)
		shadow.global_position.y += starting_proj_height if bounces_so_far == 0 else 0
	else:
		shadow.global_position = new_position
		shadow.global_position.y += starting_proj_height

	shadow.visible = true
#endregion

#region Homing
## Sets up the homing delay if one exists, otherwise begins homing immediately if we have a valid homing method selected.
func _set_up_potential_homing_delay() -> void:
	if stats.homing_method != "None":
		if stats.homing_start_delay > 0:
			homing_delay_timer.start(stats.homing_start_delay)
		else:
			_start_homing()

## Starts the homing sequence by turning it on and starting the homing timer if needed. Then calls for us to find a target.
func _start_homing() -> void:
	is_homing_active = true
	var original_dur: float = s_mods.get_original_stat("proj_homing_duration")
	if original_dur > -1:
		homing_timer.start(s_mods.get_stat("proj_homing_duration"))
	_find_homing_target_based_on_method()

## Choses the proper way to pick a target based on the current homing method.
func _find_homing_target_based_on_method() -> void:
	if stats.homing_method == "FOV":
		_find_target_in_fov()
	elif stats.homing_method == "Closest":
		_find_closest_target()
	elif stats.homing_method == "Mouse Position":
		if splits_so_far == 0:
			_choose_from_mouse_area_targets()
		elif is_instance_valid(homing_target):
			homing_target = null
			is_homing_active = false
	elif stats.homing_method == "Boomerang":
		homing_target = source_entity
	else:
		homing_target = null
		is_homing_active = false

## Talks to the physics server to cast rays and look for targets when using the "FOV" homing method.
func _find_target_in_fov() -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var fov_radians: float = deg_to_rad(stats.homing_fov_angle)
	var half_fov: float = fov_radians / 2.0
	var direction: Vector2 = Vector2.RIGHT.rotated(rotation)
	var candidates: Array[Node] = []

	if DebugFlags.Projectiles.show_homing_rays:
		debug_homing_rays.clear()

	var step: float = fov_radians / FOV_RAYCAST_COUNT

	for i: int in range(FOV_RAYCAST_COUNT + 1):
		var angle_offset: float = -half_fov + step * i
		var cast_direction: Vector2 = direction.rotated(angle_offset)
		var from_pos: Vector2 = global_position
		var to_pos: Vector2 = global_position + cast_direction * stats.homing_max_range

		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
		query.from = from_pos
		query.to = to_pos
		query.collision_mask = effect_source.scanned_phys_layers

		var exclusion_list: Array[RID] = [self.get_rid()]

		if not effect_source.can_hit_self:
			exclusion_list.append(source_entity.get_rid())

		for child: Node in source_entity.get_children():
			if child is Area2D:
				exclusion_list.append(child.get_rid())

		query.exclude = exclusion_list
		query.collide_with_bodies = true
		query.collide_with_areas = true

		var result: Dictionary[Variant, Variant] = space_state.intersect_ray(query)

		var debug_ray_info: Dictionary[String, Variant]
		if DebugFlags.Projectiles.show_homing_rays: debug_ray_info = { "from": from_pos, "to": to_pos, "hit": false, "hit_position": to_pos }

		if result:
			var obj: Node = result.collider
			if obj and _is_valid_homing_target(obj):
				candidates.append(obj)
				if DebugFlags.Projectiles.show_homing_rays:
					debug_ray_info["hit"] = true
					debug_ray_info["hit_position"] = result.position
		if DebugFlags.Projectiles.show_homing_rays:
			debug_homing_rays.append(debug_ray_info)

	if candidates.size() > 0:
		homing_target = _select_closest_homing_target(candidates, global_position)
	else:
		homing_target = null
		is_homing_active = stats.can_change_target

## Checks if the homing target is something we are even allowed to target.
func _is_valid_homing_target(obj: Node) -> bool:
	if obj is DynamicEntity or obj is RigidEntity or obj is StaticEntity:
		if obj.team != source_entity.team and obj.team != GlobalData.Teams.PASSIVE:
			return true
	return false

## Give the possible targets, this selects the closest one using a faster 'distance squared' method.
func _select_closest_homing_target(targets: Array[Node], to_position: Vector2) -> Node:
	var closest_target: Node = null
	var closest_distance_squared: float = INF
	for target: Node in targets:
		var distance_squared: float = to_position.distance_squared_to(target.global_position)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_target = target
	return closest_target

## Gets all the options in the appropriate scene tree group. Used for the "closest" homing method.
func _find_closest_target() -> void:
	var candidates: Array[Node] = []
	var group_name: String = "enemy_entities" if source_entity.team == GlobalData.Teams.PLAYER else "player_entities"
	var max_range_squared: float = stats.homing_max_range * stats.homing_max_range

	for entity: Node in get_tree().get_nodes_in_group(group_name):
		if entity != source_entity and _is_valid_homing_target(entity):
			var distance_squared: float = global_position.distance_squared_to(entity.global_position)
			if distance_squared <= max_range_squared:
				candidates.append(entity)

	if candidates.size() > 0:
		homing_target = _select_closest_homing_target(candidates, global_position)
	else:
		homing_target = null
		is_homing_active = false

func _choose_from_mouse_area_targets() -> void:
	var candidates: Array[Node] = []
	for obj: Node in mouse_scan_targets:
		if obj and _is_valid_homing_target(obj):
			candidates.append(obj)

	if candidates.size() > 0:
		homing_target = _select_closest_homing_target(candidates, CursorManager.get_cursor_mouse_position())
	else:
		homing_target = null
		is_homing_active = false

## When the amount of time we are allowed to spend homing is over, turn off homing entirely.
func _on_homing_timer_timeout() -> void:
	is_homing_active = false
	homing_target = null

## Gradually move and turn towards the target. If the target doesn't exist, attempt to retarget if we can.
func _apply_homing_movement(delta: float) -> void:
	if not homing_target or not homing_target.is_inside_tree():
		homing_target = null
		if stats.can_change_target:
			_find_homing_target_based_on_method()
		else:
			is_homing_active = false
		return

	var target_dir: Vector2 = (homing_target.global_position - global_position).normalized()
	var current_dir: Vector2 = Vector2(cos(rotation), sin(rotation)).normalized()
	var angle_to_target: float = current_dir.angle_to(target_dir)
	var turn_stat: float = s_mods.get_stat("proj_max_turn_rate")
	var max_turn_rate: float = deg_to_rad(turn_stat * stats.turn_rate_curve.sample_baked((stats.lifetime - lifetime_timer.time_left) / stats.lifetime)) * delta

	angle_to_target = clamp(angle_to_target, -max_turn_rate, max_turn_rate)
	rotation += angle_to_target
	sprite.rotation += deg_to_rad(stats.spin_speed * spin_dir) * delta

	var move_dir: Vector2 = Vector2(cos(rotation), sin(rotation)).normalized()
	var displacement: Vector2 = move_dir * (current_sampled_speed * stats.homing_speed_mult) * delta
	position += displacement
	movement_direction = displacement.normalized()

	if stats.homing_method == "Boomerang":
		if lifetime_timer.time_left <= max(0, stats.lifetime - 0.35): # So that the return distance doesn't trigger on throw
			if global_position.distance_squared_to(source_entity.global_position) < pow(stats.boomerang_home_radius, 2):
				queue_free()
#endregion

#region Arcing
## Sets up starting arcing variables like initial speed based on kinematics.
func _reset_arc_logic() -> void:
	var falloff_mult: float = max(0.01, stats.bounce_falloff_curve.sample_baked(1 - (lifetime_timer.time_left / stats.lifetime)))
	var dist_stat: float = s_mods.get_stat("proj_arc_travel_distance")
	var dist: float = dist_stat * falloff_mult
	updated_arc_angle = stats.launch_angle * falloff_mult

	starting_arc_speed = find_initial_arc_speed(dist, updated_arc_angle, starting_proj_height if bounces_so_far == 0 else 0)
	resettable_starting_pos = global_position
	arc_time_counter = 0

## Calculates the distance we will travel in our arcing motion based on speed, angle, and height.
func calculate_arc_distance(speed: float, angle: float, height: int) -> float:
	const G: float = 9.8
	var rad_angle: float = deg_to_rad(angle)
	var sin_angle: float = sin(rad_angle)
	var cos_angle: float = cos(rad_angle)

	var v_sin: float = speed * sin_angle
	var v_cos: float = speed * cos_angle
	var discriminant: float = v_sin * v_sin + 2 * G * height
	if discriminant < 0:
		return 0

	var time: float = (v_sin + sqrt(discriminant)) / G
	return v_cos * time

## Calculates the initial speed of the arcing motion based on the target distance and angle and starting height.
func find_initial_arc_speed(target_distance: float, angle: float, height: int) -> float:
	var low: float = 0
	var high: float = 100.0
	var epsilon: float = 1.0  # Precision

	while high - low > epsilon:
		var mid: float = (low + high) / 2
		var distance: float = calculate_arc_distance(mid, angle, height)

		if distance < target_distance:
			low = mid
		else:
			high = mid

	return (low + high) / 2

## This is called every phys frame to update the arcing position based on kinemtaic equations.
func _do_arc_movement(delta: float) -> void:
	arc_time_counter += delta * (stats.arc_speed / 90.0) * current_initial_boost

	fake_z_axis = starting_arc_speed * sin(deg_to_rad(updated_arc_angle)) * arc_time_counter - 0.5 * 9.8 * pow(arc_time_counter, 2)

	var ground_level: float = -(starting_proj_height) if bounces_so_far == 0 else 0
	var bounce_stat: int = int(s_mods.get_stat("proj_bounce_count"))

	if fake_z_axis > ground_level:
		z_index = 3
		var fake_x_axis: float = starting_arc_speed * cos(deg_to_rad(stats.launch_angle)) * arc_time_counter
		var new_position: Vector2 = resettable_starting_pos + (resettable_starting_dir * fake_x_axis)
		new_position.y -= fake_z_axis
		var fake_move_dir: Vector2 = (new_position - global_position).normalized()

		rotation = atan2(fake_move_dir.y, fake_move_dir.x)
		rotation += non_sped_up_time_counter * deg_to_rad(stats.spin_speed * spin_dir)

		global_position = new_position

		var dist_so_far: float = (starting_arc_speed * cos(deg_to_rad(stats.launch_angle)) * non_sped_up_time_counter * (stats.arc_speed / 90.0) * current_initial_boost)
		cumulative_distance += dist_so_far - fake_previous_pos
		fake_previous_pos = dist_so_far

		_update_shadow(new_position, fake_move_dir)
		show()
	elif bounce_stat > 0 and (bounces_so_far < bounce_stat):
		z_index = 0
		bounces_so_far += 1
		if stats.ping_pong_bounce:
			resettable_starting_dir *= -1
			spin_dir *= -1
		non_sped_up_time_counter = 0
		_reset_arc_logic()
	else:
		z_index = 0
		is_arcing = false
		if stats.do_aoe_on_arc_land and (stats.aoe_radius > 0):
			if not is_in_aoe_phase:
				lifetime_timer.stop()
				_handle_aoe()
		else:
			if stats.grounding_free_delay > 0:
				await get_tree().create_timer(stats.grounding_free_delay, false, true, false).timeout
			queue_free()

	if fake_z_axis > stats.max_collision_height:
		call_deferred("_disable_collider")
	else:
		call_deferred("_enable_collider")
#endregion

#region Splitting, Ricocheting, Piercing
## Splits the projectile into multiple instances across a specified angle.
func _split_self() -> void:
	var split_into_count: int = ArrayHelpers.get_or_default(stats.split_into_counts, splits_so_far, stats.split_into_counts[0])
	if not (splits_so_far < stats.number_of_splits) or (split_into_count < 2):
		return

	splits_so_far += 1
	var angular_spread: float = ArrayHelpers.get_or_default(stats.angular_spreads, splits_so_far - 1, stats.angular_spreads[0])
	var split_into_count_offset_by_one: float = ArrayHelpers.get_or_default(stats.split_into_counts, splits_so_far - 1, stats.split_into_counts[0])
	var close_to_360_adjustment: int = 0 if angular_spread > 310 else 1
	var step_angle: float = (deg_to_rad(angular_spread) / (split_into_count_offset_by_one - close_to_360_adjustment))
	var start_angle: float = starting_rotation - (deg_to_rad(angular_spread) / 2)
	var new_multishot_id: int = UIDHelper.generate_multishot_uid()

	for i: int in range(split_into_count_offset_by_one):
		var angle: float = start_angle + (i * step_angle)
		var new_proj: Projectile = Projectile.create(source_wpn_stats, source_entity, position, angle)
		new_proj.splits_so_far = splits_so_far
		new_proj.spin_dir = spin_dir
		new_proj.multishot_id = new_multishot_id
		if stats.homing_method == "Mouse Position": new_proj.homing_target = homing_target

		get_parent().add_child(new_proj)

	var sound: String = ArrayHelpers.get_or_default(stats.splitting_sounds, splits_so_far - 1, stats.splitting_sounds[0])
	if sound != "":
		AudioManager.play_sound(sound, AudioManager.SoundType.SFX_2D, global_position)

	var split_cam_fx: CamFXResource = ArrayHelpers.get_or_default(stats.split_cam_fx, splits_so_far - 1, stats.split_cam_fx[0])
	split_cam_fx.activate_all()

	queue_free()

## Calculates the new direction of the projectile when it bounces or reflects off a collider.
func _handle_ricochet(object: Variant) -> void:
	var collision_normal: Vector2 = (global_position - object.global_position).normalized()
	var direction: Vector2 = Vector2(cos(rotation), sin(rotation))

	var reflected_direction: Vector2
	if (object is TileMapLayer) or (not stats.ricochet_angle_bounce):
		reflected_direction = -direction

		resettable_starting_dir = reflected_direction.normalized()
	else:
		reflected_direction = direction.bounce(collision_normal)
		resettable_starting_dir = direction.bounce(collision_normal)

	_reset_arc_logic()
	starting_rotation = reflected_direction.angle()
	rotation = reflected_direction.angle()

	multishot_id = UIDHelper.generate_multishot_uid()

	ricochet_count += 1

	if stats.can_change_target and stats.homing_method != "Mouse Position":
		homing_target = null
		_find_homing_target_based_on_method()

## Updates the number of things we have pierced through.
func _handle_pierce() -> void:
	pierce_count += 1
#endregion

#region AOE
## Begins a aoe damage sequence by checking if we have a circle collision shape to work with.
## If so, it plays any needed animations and creates the defined waits for aoe duration and delay.
func _handle_aoe() -> void:
	if collider.shape is not CircleShape2D and collider.shape is not CapsuleShape2D:
		push_error("\"" + name + "\" projectile has AOE logic but its collision shape is not a circle or capsule.")
		return

	is_in_aoe_phase = true
	is_disabling_monitoring = true
	call_deferred("_disable_monitoring")
	area_exited.connect(_on_area_exited)

	if stats.aoe_delay > 0:
		call_deferred("_disable_collider")
		if anim_player != null and anim_player.get_animation_library("ProjectileAnimLibrary").has_animation("aoe"):
			anim_player.speed_scale = 1 / stats.aoe_delay
			anim_player.play("ProjectileAnimLibrary/aoe")

		aoe_delay_timer.start(stats.aoe_delay)
		await aoe_delay_timer.timeout

	var new_shape: Shape2D = collider.shape.duplicate()
	call_deferred("_assign_new_collider_shape_and_aoe_entities", new_shape)

	await get_tree().create_timer(max(0.05, stats.aoe_effect_dur), false, true, false).timeout
	queue_free()

## Assigns the collider to a new shape and re-enables it. Takes into account scaling of the projectile itself
## to preserve aoe radius.
## This also applies the initial hit of the aoe effect source to entities in range. The handling function won't apply status
## effects as a result of this hit.
func _assign_new_collider_shape_and_aoe_entities(new_shape: Shape2D) -> void:
	new_shape.radius = (s_mods.get_stat("proj_aoe_radius") / scale.x)
	collider.shape = new_shape
	_enable_collider()
	set_deferred("monitoring", true)

	# Handling initial hit of the aoe source. This is like how an explosion hits once but the ground burning will be separate.
	await get_tree().physics_frame
	await get_tree().physics_frame
	for area: Area2D in get_overlapping_areas():
		if (area.get_parent() == source_entity) and not stats.aoe_effect_source.can_hit_self:
			return
		elif area is EffectReceiverComponent:
			_start_being_handled(area as EffectReceiverComponent)
	for body: Node2D in get_overlapping_bodies():
		_on_body_entered(body)
#endregion

#region Lifetime & Handling
## When the lifetime ends, either start an AOE or queue free.
func _on_lifetime_timer_timeout_or_reached_max_distance() -> void:
	var original_radius: float = s_mods.get_original_stat("proj_aoe_radius")
	if original_radius > 0 and stats.aoe_before_freeing:
		_handle_aoe()
	else:
		queue_free()

## Overrides parent hitbox. When in AOE, we add new entities to a dictionary with an associated timer that applies the status
## effects on an interval.
func _on_area_entered(area: Area2D) -> void:
	if not is_in_aoe_phase:
		super._on_area_entered(area)
		return

	if (area.get_parent() == source_entity) and not stats.aoe_effect_source.can_hit_self:
		return

	if area is EffectReceiverComponent:
		var timer: Timer = Timer.new()
		timer.set_meta("area", area)
		timer.timeout.connect(_on_aoe_interval_timer_timeout.bind(timer))
		aoe_overlapped_receivers[area] = timer

		if stats.aoe_effects_delay > 0:
			await get_tree().create_timer(stats.aoe_effects_delay, false, true, false).timeout
			if not is_instance_valid(area) or not is_instance_valid(timer):
				return

		if area in aoe_overlapped_receivers:
			for status_effect: StatusEffect in stats.aoe_effect_source.status_effects:
				area.handle_status_effect(status_effect)

			add_child(timer)
			timer.start(stats.aoe_effect_interval)

## When the status effect interval timer ends, check if the area still exists, then apply the effects again.
func _on_aoe_interval_timer_timeout(timer: Timer) -> void:
	var area: Area2D = timer.get_meta("area")
	if area not in aoe_overlapped_receivers:
		timer.queue_free()
		return
	elif not is_instance_valid(area):
		aoe_overlapped_receivers.erase(area)
		timer.queue_free()
		return

	for status_effect: StatusEffect in stats.aoe_effect_source.status_effects:
		area.handle_status_effect(status_effect)

## When in AOE, remove the area from the dictionary and free its associated timer on exiting the AOE zone.
func _on_area_exited(area: Area2D) -> void:
	if not is_in_aoe_phase or is_disabling_monitoring:
		return

	if area is EffectReceiverComponent:
		var timer: Timer = aoe_overlapped_receivers.get(area, null)
		if timer:
			timer.queue_free()
			aoe_overlapped_receivers.erase(area)

## Overrides parent method. When we intersect with any kind of object, this processes what to do next.
func _process_hit(object: Node2D) -> void:
	var sprite_rect: Vector2 = SpriteHelpers.SpriteDetails.get_frame_rect(sprite)
	debug_recent_hit_location = global_position + Vector2(sprite_rect.x / 2, 0).rotated(rotation)
	if not is_in_aoe_phase:
		var ricochet_stat: int = int(s_mods.get_stat("proj_max_ricochet"))
		if stats.ricochet_walls_only and object is TileMapLayer:
			_handle_ricochet(object)
			spin_dir *= -1
			return
		if ricochet_count < ricochet_stat:
			_handle_ricochet(object)
			return

		var pierce_stat: int = int(s_mods.get_stat("proj_max_pierce"))
		if pierce_count < pierce_stat:
			if object is DynamicEntity or object is RigidEntity or object is StaticEntity or object is EffectReceiverComponent:
				_handle_pierce()
				return

		var original_radius: float = s_mods.get_original_stat("proj_aoe_radius")
		if original_radius > 0:
			lifetime_timer.stop()
			_handle_aoe()
			return

		_kill_projectile_on_hit()

## Stops and frees the projectile on hit when it cannot pierce, ricochet, or AOE anymore. Meant to be overridden by child classes.
func _kill_projectile_on_hit() -> void:
	queue_free()

## Overrides parent method. When we overlap with an entity who can accept effect sources, pass the effect source to that
## entity's handler. Note that the effect source is duplicated on hit so that we can include unique info like move dir.
func _start_being_handled(handling_area: EffectReceiverComponent) -> void:
	if not is_in_aoe_phase:
		effect_source = effect_source.duplicate()
		effect_source.multishot_id = multishot_id
		var modified_effect_src: EffectSource = _get_effect_source_adjusted_for_falloff(effect_source, handling_area, false)
		modified_effect_src.movement_direction = movement_direction
		modified_effect_src.contact_position = global_position
		handling_area.handle_effect_source(modified_effect_src, source_entity)
	else:
		if stats.aoe_effect_source == null: stats.aoe_effect_source = effect_source
		var modified_effect_src: EffectSource = _get_effect_source_adjusted_for_falloff(stats.aoe_effect_source, handling_area, true)
		modified_effect_src.contact_position = global_position
		handling_area.handle_effect_source(modified_effect_src, source_entity, false) # Don't reapply status effects.

## When we hit a handling area during an AOE, we need to apply falloff based on distance from the center of the AOE.
func _get_effect_source_adjusted_for_falloff(effect_src: EffectSource, handling_area: EffectReceiverComponent, is_aoe: bool = false) -> EffectSource:
	var dist_to_center: float = handling_area.get_parent().global_position.distance_to(global_position)
	var falloff_effect_src: EffectSource = effect_src.duplicate()
	var falloff_mult: float
	var apply_to_bad: bool
	var apply_to_good: bool

	if is_aoe:
		apply_to_bad = stats.bad_effects_aoe_falloff
		apply_to_good = stats.good_effects_aoe_falloff
		var radius_stat: float = s_mods.get_stat("proj_aoe_radius")
		falloff_mult = max(0.05, stats.aoe_effect_falloff_curve.sample_baked(dist_to_center / radius_stat))
	else:
		apply_to_bad = stats.bad_effects_falloff
		apply_to_good = stats.good_effects_falloff
		var point_to_sample: float = 1.0 - (max(0, float(stats.point_of_max_falloff) - cumulative_distance) / stats.point_of_max_falloff)
		var sampled_point: float = stats.effect_falloff_curve.sample_baked(point_to_sample)
		falloff_mult = max(0.05, sampled_point)

	if apply_to_bad:
		falloff_effect_src.base_damage = int(min(falloff_effect_src.base_damage, ceil(falloff_effect_src.base_damage * falloff_mult)))

	if apply_to_good:
		falloff_effect_src.base_healing = int(min(falloff_effect_src.base_healing, ceil(falloff_effect_src.base_healing * falloff_mult)))

	return falloff_effect_src
#endregion

## Checks to see if the speed is fast enough and we aren't headed straight for our target then plays the whiz sound once.
func _check_for_whiz_sound() -> void:
	if true_current_speed > 150:
		if not played_whiz_sound and GlobalData.player_node != null:
			var player: Player = GlobalData.player_node
			if (player.global_position - global_position).dot(movement_direction) > 20:
				if global_position.distance_squared_to(player.global_position) < pow(whiz_sound_distance, 2):
					if whiz_sound != "":
						AudioManager.play_sound(whiz_sound, AudioManager.SoundType.SFX_2D, global_position)
						played_whiz_sound = true
