extends Line2D
class_name Hitscan

@export var effect_source: EffectSource ## The effect to be applied when this ray hits an effect receiver.
@export var source_entity: PhysicsBody2D ## The entity that the effect was produced by.

@onready var start_particles: CPUParticles2D = $StartParticles
@onready var impact_particles: CPUParticles2D = $ImpactParticles
@onready var beam_particles: CPUParticles2D = $BeamParticles

var stats: HitscanResource
var source_item: ProjectileWeapon
var rotation_offset: float
var lifetime_timer: Timer = Timer.new()
var effect_tick_timer: Timer = Timer.new()
var debug_rays: Array[Dictionary] = []
var end_point: Vector2
var is_hitting_something: bool = false:
	set(new_value):
		is_hitting_something = new_value
		impact_particles.emitting = new_value
var impacted_nodes: Dictionary = {}
var holding_allowed: bool = false


## Creates a hitscan scene, assigns its passed in parameters, then returns it.
static func create(hitscan_scene: PackedScene, effect_src: EffectSource, source_wpn: ProjectileWeapon,
					src_entity: PhysicsBody2D, pos: Vector2, rot_offset: float, was_charged: bool = false) -> Hitscan:
	var hitscan: Hitscan = hitscan_scene.instantiate()
	hitscan.global_position = pos
	hitscan.rotation_offset = rot_offset
	hitscan.effect_source = effect_src
	hitscan.source_entity = src_entity
	hitscan.stats = source_wpn.s_stats.hitscan_logic

	if was_charged and source_wpn.s_stats.charged_hitscan_logic != null:
			hitscan.stats = source_wpn.s_stats.charged_hitscan_logic
	if source_wpn.s_stats.allow_hitscan_holding: hitscan.holding_allowed = true

	hitscan.source_item = source_wpn
	return hitscan

func _draw() -> void:
	if not DebugFlags.Projectiles.show_hitscan_rays:
		return

	for ray in debug_rays:
		var from_pos: Vector2 = to_local(ray["from"])
		var to_pos: Vector2 = to_local(ray["to"])
		if ray["hit"]:
			to_pos = to_local(ray["hit_position"])
		var color: Color = Color(0, 1, 0, 0.4) if ray["hit"] else Color(1, 0, 0, 0.25)

		draw_line(from_pos, to_pos, color, 1)

		if ray["hit"]:
			draw_circle(to_pos, 2, color)

func _ready() -> void:
	add_child(lifetime_timer)
	add_child(effect_tick_timer)
	lifetime_timer.one_shot = true
	effect_tick_timer.one_shot = true
	lifetime_timer.timeout.connect(queue_free)
	if not holding_allowed:
		lifetime_timer.start(max(0.05, stats.hitscan_duration))
	start_particles.emitting = true

	_set_up_visual_fx()

func _set_up_visual_fx() -> void:
	if not stats.override_vfx_defaults:
		return
	width = stats.hitscan_max_width
	width_curve = stats.hitscan_width_curve
	start_particles.color_ramp.set_color(0, stats.start_particle_color)
	start_particles.color_ramp.set_color(1, stats.start_particle_color)
	start_particles.color = stats.start_particle_color * (stats.glow_amount + 1.0)
	start_particles.amount = int(start_particles.amount * stats.start_particle_mult)
	impact_particles.color_ramp.set_color(0, stats.impact_particle_color)
	impact_particles.color_ramp.set_color(1, stats.impact_particle_color)
	impact_particles.color = stats.impact_particle_color * (stats.glow_amount + 1.0)
	impact_particles.amount = int(impact_particles.amount * stats.impact_particle_mult)
	beam_particles.color_ramp.set_color(0, stats.beam_particle_color)
	beam_particles.color_ramp.set_color(1, stats.beam_particle_color)
	beam_particles.color = stats.beam_particle_color * (stats.glow_amount + 1.0)
	beam_particles.amount = int(beam_particles.amount * stats.beam_particle_mult)
	default_color = stats.beam_color * (stats.glow_amount + 1.5)

func _physics_process(_delta: float) -> void:
	var equipped_item: EquippableItem = null
	if is_instance_valid(source_entity.hands.equipped_item): equipped_item = source_entity.hands.equipped_item

	if equipped_item != null and equipped_item == source_item:
		global_position = equipped_item.proj_origin_node.global_position.rotated(equipped_item.rotation)
		global_rotation = equipped_item.global_rotation + rotation_offset

		beam_particles.position = points[1] * 0.5
		beam_particles.emission_rect_extents.x = points[1].length() * 0.5
		beam_particles.emitting = true

		_find_target_receivers()

		points[1] = end_point
	else:
		queue_free()

	if DebugFlags.Projectiles.show_hitscan_rays:
		queue_redraw()

## Talks to the physics server to cast collider shapes forward to look for receivers.
func _find_target_receivers() -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var cast_direction: Vector2 = Vector2.RIGHT.rotated(rotation)
	var candidates: Array[Node] = []
	var contact_positions: Array[Vector2] = []

	if DebugFlags.Projectiles.show_hitscan_rays:
		debug_rays.clear()

	var from_pos: Vector2 = global_position
	var to_pos: Vector2 = global_position + (cast_direction * stats.hitscan_max_distance)

	var exclusion_list: Array[RID] = [source_entity.get_rid()]
	for child in source_entity.get_children():
		if child is Area2D:
			exclusion_list.append(child.get_rid())

	var remaining_pierces = stats.hitscan_pierce_count
	var pierce_list: Dictionary ={}

	while remaining_pierces >= 0:
		var query = PhysicsRayQueryParameters2D.new()
		query.from = from_pos
		query.to = to_pos
		query.exclude = exclusion_list
		query.collision_mask = effect_source.scanned_phys_layers
		query.collide_with_bodies = true
		query.collide_with_areas = true
		var result: Dictionary = space_state.intersect_ray(query)

		var debug_ray_info: Dictionary
		if DebugFlags.Projectiles.show_hitscan_rays: debug_ray_info = { "from": from_pos, "to": to_pos, "hit": false, "hit_position": to_pos }

		if result:
			var obj: Node = result.collider
			var collision_point: Vector2 = result.position

			pierce_list[obj] = result

			is_hitting_something = true
			end_point = to_local(collision_point)

			impact_particles.position = to_local(collision_point)
			impact_particles.global_rotation = result.normal.angle()

			if obj and _is_valid_receiver(obj):
				candidates.append(obj)
				contact_positions.append(collision_point)

				from_pos = collision_point

				exclusion_list.append(obj.get_rid())
				for child in obj.get_children():
					if child is Area2D:
						exclusion_list.append(child.get_rid())

				remaining_pierces -= 1

				debug_ray_info["hit"] = true
				debug_ray_info["hit_position"] = result.position
			else:
				remaining_pierces = -1
				debug_ray_info["to"] = collision_point
		else:
			is_hitting_something = false
			remaining_pierces = -1
		debug_rays.append(debug_ray_info)
		end_point = to_local(to_pos)

	if effect_tick_timer.is_stopped():
		for i in range(candidates.size()):
			var receiver_index: int = _select_closest_receiver(candidates)
			var receiver: Node = candidates[receiver_index]
			var effect_receiver: EffectReceiverComponent = receiver.get_node_or_null("EffectReceiverComponent")
			if effect_receiver != null:
				_start_being_handled(effect_receiver, contact_positions[receiver_index])

				candidates.remove_at(receiver_index)
				contact_positions.remove_at(receiver_index)

				effect_tick_timer.stop()
				if stats.hitscan_effect_interval == -1:
					effect_tick_timer.start(1000.0)
				else:
					effect_tick_timer.start(stats.hitscan_effect_interval)

	_update_impact_particles(pierce_list)

## Checks if a receiver of the ray is something we are even allowed to target.
func _is_valid_receiver(obj: Node) -> bool:
	if obj is DynamicEntity or obj is RigidEntity or obj is StaticEntity:
		if obj.team != source_entity.team and obj.team != GlobalData.Teams.PASSIVE:
			return true
	return false

## Give the possible targets, this selects the closest one using a faster 'distance squared' method.
func _select_closest_receiver(targets: Array[Node]) -> int:
	var closest_target: int = 0
	var closest_distance_squared: float = INF
	for i in range(targets.size()):
		var distance_squared: float = global_position.distance_squared_to(targets[i].global_position)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_target = i
	return closest_target

func _update_impact_particles(pierce_list: Dictionary) -> void:
	for node in pierce_list.keys():
		if node in impacted_nodes:
			impacted_nodes[node].position = to_local(pierce_list[node].position)
			impacted_nodes[node].global_rotation = pierce_list[node].normal.angle()
		else:
			var particles: CPUParticles2D = impact_particles.duplicate()
			particles.position = to_local(pierce_list[node].position)
			particles.global_rotation = pierce_list[node].normal.angle()
			impacted_nodes[node] = particles
			add_child(particles)
			particles.emitting = true

	for node in impacted_nodes:
		if not node in pierce_list.keys():
			impacted_nodes[node].queue_free()
			impacted_nodes.erase(node)

## Overrides parent method. When we overlap with an entity who can accept effect sources, pass the effect source to that
## entity's handler. Note that the effect source is duplicated on hit so that we can include unique info like move dir.
func _start_being_handled(handling_area: EffectReceiverComponent, contact_point: Vector2) -> void:
	effect_source = effect_source.duplicate()
	var modified_effect_src: EffectSource = _get_effect_source_adjusted_for_falloff(effect_source, contact_point)
	modified_effect_src.movement_direction = Vector2(cos(rotation), sin(rotation)).normalized()
	effect_source.contact_position = contact_point
	handling_area.handle_effect_source(modified_effect_src, source_entity)

## When we hit a handling area during a hitscan, we apply falloff to the components of the effect source.
func _get_effect_source_adjusted_for_falloff(effect_src: EffectSource, contact_point: Vector2) -> EffectSource:
	var falloff_effect_src: EffectSource = effect_src.duplicate()
	var falloff_mult: float
	var apply_to_bad: bool
	var apply_to_good: bool

	apply_to_bad = stats.bad_effects_falloff
	apply_to_good = stats.good_effects_falloff
	var point_to_sample: float = float(global_position.distance_to(contact_point) / stats.hitscan_max_distance)
	falloff_mult = max(0.05, stats.hitscan_falloff_curve.sample_baked(point_to_sample))

	falloff_effect_src.cam_shake_strength *= falloff_mult
	falloff_effect_src.cam_freeze_multiplier *= falloff_mult

	if apply_to_bad:
		falloff_effect_src.base_damage = int(ceil(falloff_effect_src.base_damage * falloff_mult))
		for i in range(falloff_effect_src.status_effects.size()):
			if falloff_effect_src.status_effects[i] != null and falloff_effect_src.status_effects[i].is_bad_effect:
				var new_stat_effect: StatusEffect = falloff_effect_src.status_effects[i].duplicate()
				new_stat_effect.mod_time *= falloff_mult
				if new_stat_effect is KnockbackEffect:
					new_stat_effect.knockback_force *= falloff_mult

				falloff_effect_src.status_effects[i] = new_stat_effect

	if apply_to_good:
		falloff_effect_src.base_healing = int(ceil(falloff_effect_src.base_healing * falloff_mult))
		for i in range(falloff_effect_src.status_effects.size()):
			if falloff_effect_src.status_effects[i] != null and not falloff_effect_src.status_effects[i].is_bad_effect:
				var new_stat_effect: StatusEffect = falloff_effect_src.status_effects[i].duplicate()
				new_stat_effect.mod_time *= falloff_mult

				falloff_effect_src.status_effects[i] = new_stat_effect

	return falloff_effect_src
