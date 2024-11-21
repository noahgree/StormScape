extends Node2D
class_name Storm
## The base class for the moving storm's functionalities. Controls the shader parameters and effect application logic.

@export var transform_queue: Array[StormTransform] = [] ## The queue of upcoming transforms to apply to the zone.
@export var default_storm_effect: StatusEffect ## The default effect to apply when a dynamic entity leaves the safe zone.
@export var default_storm_visuals: StormVisuals ## The default storm visuals to apply at start.

@onready var collision_shape: CollisionShape2D = $SafeZone/CollisionShape2D ## The collider that detects when something is in the safe zone.
@onready var storm_circle: ColorRect = $StormCanvas/StormCircle ## The color rect that houses the storm circle shader.

var current_radius: float = 0: ## The current radius of the safe zone.
	set(new_radius):
		current_radius = new_radius
		collision_shape.shape.radius = new_radius
var radius_tween: Tween = null ## The tween controlling a radius change.
var location_tween: Tween = null ## The tween controlling a location change.
var see_thru_tween: Tween = null ## The tween controlling the player's see thru amount change.
var storm_colors_tween: Tween = null ## The tween controlling the storm color changes.
var storm_gradient_end_tween: Tween = null ## The tween controlling the gradient end distance changes.
var glow_ring_tween: Tween = null ## The tween controlling the glow ring changes.
var storm_wind_tween: Tween = null ## The tween controlling the wind brightness changes.
var storm_rain_tween: Tween = null ## The tween controlling the rain changes.
var storm_distortion_tween: Tween = null ## The tween controlling the storm distortion changes.
var storm_change_delay_timer: Timer = Timer.new() ## The timer controlling the delay between a new transform has activated and it actually starting to move/resize.
var current_storm_transform_time_timer: Timer = Timer.new() ## The timer controlling the length of the storm change. Chooses the max time between the resize and relocate time values in the resource.
var see_through_factor: float = 1.0
var current_effect: StatusEffect


func _ready() -> void:
	add_child(storm_change_delay_timer)
	add_child(current_storm_transform_time_timer)
	storm_change_delay_timer.one_shot = true
	current_storm_transform_time_timer.one_shot = true
	storm_change_delay_timer.timeout.connect(_on_storm_change_delay_timer_timeout)
	current_storm_transform_time_timer.timeout.connect(_on_current_storm_transform_time_timer_timeout)

	current_radius = collision_shape.shape.radius

	current_effect = default_storm_effect

	_process_next_transform_in_queue()

func _physics_process(_delta: float) -> void:
	_set_shader_transform_params()

## Updates the shader's transform params with the current values.
func _set_shader_transform_params() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	storm_circle.material.set_shader_parameter("viewport_size", viewport_size)

	var collision_radius = current_radius
	var edge_point_world = global_position + Vector2(collision_radius, 0).rotated(global_rotation)
	var see_through_point_world = global_position + Vector2(20, 0).rotated(global_rotation)

	var screen_center = _get_screen_point_from_world_coord(global_position)
	var screen_edge = _get_screen_point_from_world_coord(edge_point_world)
	var screen_edge_see_through = _get_screen_point_from_world_coord(see_through_point_world)
	var radius_pixels = screen_edge.distance_to(screen_center)
	var radius_pixels_see_through = screen_edge_see_through.distance_to(screen_center)

	var noise_origin = _get_screen_point_from_world_coord(Vector2.ZERO)
	var see_through_point = _get_screen_point_from_world_coord(GlobalData.player_node.global_position)

	storm_circle.material.set_shader_parameter("circle_center_pixels", screen_center)
	storm_circle.material.set_shader_parameter("noise_world_position", noise_origin)
	storm_circle.material.set_shader_parameter("see_through_center_pixels", see_through_point)
	storm_circle.material.set_shader_parameter("see_through_radius", radius_pixels_see_through)
	storm_circle.material.set_shader_parameter("radius_pixels", radius_pixels)

## Converts the world coordinate to a screen position based on camera position, rotation, and zoom.
func _get_screen_point_from_world_coord(world_point: Vector2) -> Vector2:
	var camera: Camera2D = GlobalData.player_camera
	var viewport_size = get_viewport().get_visible_rect().size
	var relative_position = world_point - camera.global_position - camera.offset
	var rotated_position = relative_position.rotated(-camera.rotation)
	var zoomed_position = rotated_position * camera.zoom
	var screen_position = (viewport_size / 2) + zoomed_position

	return screen_position

## When a dynamic entity enters the inner circle, we remove the current storm effect.
func _on_safe_zone_body_entered(body: Node2D) -> void:
	if body is DynamicEntity:
		_remove_current_effect_from_entity(body)
		body.remove_from_group("entities_out_of_safe_area")

## When a dynamic entity exits the inner safe circle, we apply the current storm effect.
func _on_safe_zone_body_exited(body: Node2D) -> void:
	if body is DynamicEntity:
		_add_effect_to_entity(body, current_effect)
		body.add_to_group("entities_out_of_safe_area")

## Adds a new transform resource to the end of the queue, and if it is the only one in the queue, it starts the transform immediately.
func add_storm_transform_to_queue(new_transform: StormTransform) -> void:
	transform_queue.append(new_transform.duplicate())
	if transform_queue.size() == 1:
		_process_next_transform_in_queue()

## Processes the front of the transform queue by setting up the zone time timer and calling for the zone to start updating.
func _process_next_transform_in_queue() -> void:
	if transform_queue.is_empty():
		_apply_visual_overrides(default_storm_visuals)
		return

	var new_transform: StormTransform = transform_queue[0]
	var delay: float = max(new_transform.time_to_resize, new_transform.time_to_move)

	current_storm_transform_time_timer.stop()
	current_storm_transform_time_timer.wait_time = delay

	_halt_current_phase_and_check_for_delay(new_transform)


## When the current transform ends, check for another one.
func _on_current_storm_transform_time_timer_timeout() -> void:
	_handle_effect_switching()

	if not transform_queue.is_empty():
		transform_queue.pop_front()

	_process_next_transform_in_queue()

func _handle_effect_switching() -> void:
	var new_effect: StatusEffect = transform_queue[1].status_effect if transform_queue.size() > 1 and transform_queue[1].status_effect != null else default_storm_effect
	for entity in get_tree().get_nodes_in_group("entities_out_of_safe_area"):
		_remove_current_effect_from_entity(entity)
		_add_effect_to_entity(entity, new_effect)

## Kills the current storm sequence and checks if we need to delay before starting the next one.
func _halt_current_phase_and_check_for_delay(new_transform: StormTransform) -> void:
	if radius_tween: radius_tween.kill()
	if location_tween: location_tween.kill()

	if new_transform.delay > 0:
		storm_change_delay_timer.stop()
		storm_change_delay_timer.set_meta("storm_params", new_transform)
		storm_change_delay_timer.start(new_transform.delay)

		storm_circle.material.set_shader_parameter("pulse_speed", 10)
	else:
		_start_zone(new_transform)

## When the delay before the next transform ends, cue the new zone phase.
func _on_storm_change_delay_timer_timeout() -> void:
	var params: StormTransform = storm_change_delay_timer.get_meta("storm_params")
	_start_zone(params)

## Starts the next zone sequence using a new passed in storm transform resource.
func _start_zone(new_transform: StormTransform) -> void:
	storm_circle.material.set_shader_parameter("pulse_speed", 4)
	_check_for_visual_overrides(new_transform)
	_tween_to_new_zone(new_transform)
	_set_new_effect(new_transform.status_effect)
	current_storm_transform_time_timer.start()

func _check_for_visual_overrides(new_transform: StormTransform) -> void:
	var visuals: StormVisuals = default_storm_visuals if not new_transform.override_visuals else new_transform.storm_visuals
	_apply_visual_overrides(visuals)

func _apply_visual_overrides(new_visuals: StormVisuals) -> void:
	for i in range(4):
		_tween_storm_colors(new_visuals.storm_gradient_colors[i], i + 1, new_visuals.viusal_change_time)
	_tween_storm_gradient_end(new_visuals.final_color_distance, new_visuals.viusal_change_time)
	_tween_glow_ring(new_visuals)
	_tween_wind(new_visuals)
	_tween_rain(new_visuals)
	_tween_distortion(new_visuals)
	_tween_player_see_thru(new_visuals)
	storm_circle.material.set_shader_parameter("pulse_speed", new_visuals.ring_pulse_speed)

func _tween_storm_colors(new_color: Color, index: int, change_time: float) -> void:
	storm_colors_tween = create_tween().set_ease(Tween.EASE_IN)

	storm_colors_tween.tween_method(
		func(new_value): storm_circle.material.set_shader_parameter("color" + str(index), new_value),
		storm_circle.material.get_shader_parameter("color" + str(index)),
		new_color,
		change_time
	)

func _tween_storm_gradient_end(new_end_distance: float, change_time: float) -> void:
	storm_gradient_end_tween = create_tween().set_ease(Tween.EASE_IN)

	storm_gradient_end_tween.tween_method(
		func(new_value): storm_circle.material.set_shader_parameter("gradient_end", new_value),
		storm_circle.material.get_shader_parameter("gradient_end"),
		new_end_distance,
		change_time
	)

func _tween_glow_ring(new_visuals: StormVisuals) -> void:
	glow_ring_tween = create_tween().set_ease(Tween.EASE_IN).set_parallel(true)

	glow_ring_tween.tween_method(
		func(new_value): storm_circle.material.set_shader_parameter("glow_color", new_value),
		storm_circle.material.get_shader_parameter("glow_color"),
		new_visuals.ring_glow_color,
		new_visuals.viusal_change_time
	)
	glow_ring_tween.tween_method(
		func(new_value): storm_circle.material.set_shader_parameter("glow_intensity", new_value),
		storm_circle.material.get_shader_parameter("glow_intensity"),
		new_visuals.ring_glow_intensity,
		new_visuals.viusal_change_time
	)

func _tween_wind(new_visuals: StormVisuals) -> void:
	storm_wind_tween = create_tween().set_ease(Tween.EASE_IN)

	storm_wind_tween.tween_property(
		storm_circle.material,
		"shader_parameter/noise_brightness",
		0.0,
		new_visuals.viusal_change_time / 2.0
		)

	storm_wind_tween.chain().tween_callback(storm_circle.material.set_shader_parameter.bind("bottom_noise_speed", new_visuals.ground_wind_speed))

	storm_wind_tween.chain().tween_callback(storm_circle.material.set_shader_parameter.bind("top_noise_speed", new_visuals.top_wind_speed))

	storm_wind_tween.parallel().tween_callback(storm_circle.material.set_shader_parameter.bind("reverse_intensity", new_visuals.wind_reversal_factor))

	storm_wind_tween.parallel().tween_callback(storm_circle.material.set_shader_parameter.bind("swirl_intensity", new_visuals.wind_spiral_factor))

	storm_wind_tween.chain().tween_property(
		storm_circle.material,
		"shader_parameter/noise_brightness",
		new_visuals.wind_brightness,
		new_visuals.viusal_change_time / 2.0
		)

func _tween_rain(new_visuals: StormVisuals) -> void:
	storm_rain_tween = create_tween().set_ease(Tween.EASE_IN)

	storm_rain_tween.tween_property(
		storm_circle.material,
		"shader_parameter/count",
		0,
		new_visuals.viusal_change_time / 2.0
		)

	storm_rain_tween.chain().tween_callback(storm_circle.material.set_shader_parameter.bind("slant", new_visuals.rain_slant))

	storm_rain_tween.parallel().tween_callback(storm_circle.material.set_shader_parameter.bind("speed", new_visuals.rain_speed))

	storm_rain_tween.parallel().tween_callback(storm_circle.material.set_shader_parameter.bind("rain_color", new_visuals.rain_color))

	storm_rain_tween.parallel().tween_callback(storm_circle.material.set_shader_parameter.bind("size", new_visuals.rain_size))

	storm_rain_tween.chain().tween_property(
		storm_circle.material,
		"shader_parameter/count",
		new_visuals.rain_amount,
		new_visuals.viusal_change_time / 2.0
		)

func _tween_distortion(new_visuals: StormVisuals) -> void:
	storm_distortion_tween = create_tween().set_ease(Tween.EASE_IN)

	storm_distortion_tween.tween_property(
		storm_circle.material,
		"shader_parameter/reflection_thickness",
		0.0,
		new_visuals.viusal_change_time / 2.0
		)

	storm_distortion_tween.chain().tween_callback(storm_circle.material.set_shader_parameter.bind("reflection_intensity", new_visuals.reflection_intensity))
	storm_distortion_tween.parallel().tween_callback(storm_circle.material.set_shader_parameter.bind("turbulence_intensity", new_visuals.turbulence))
	storm_distortion_tween.parallel().tween_callback(storm_circle.material.set_shader_parameter.bind("ripple_intensity", new_visuals.ripple_intensity))
	storm_distortion_tween.parallel().tween_callback(storm_circle.material.set_shader_parameter.bind("ripple_frequency", new_visuals.ripple_frequency))
	storm_distortion_tween.parallel().tween_callback(storm_circle.material.set_shader_parameter.bind("ripple_speed", new_visuals.ripple_speed))

	storm_distortion_tween.chain().tween_property(
		storm_circle.material,
		"shader_parameter/reflection_thickness",
		new_visuals.reflection_thickness,
		new_visuals.viusal_change_time / 2.0
		)

func _tween_player_see_thru(new_visuals: StormVisuals) -> void:
	see_thru_tween = create_tween().set_ease(Tween.EASE_IN)
	see_thru_tween.tween_property(
		storm_circle.material,
		"shader_parameter/see_through_opacity",
		new_visuals.see_thru_amount / 100.0,
		new_visuals.viusal_change_time
		)

## Starts the tweens that will move the zone.
func _tween_to_new_zone(new_transform: StormTransform) -> void:
	radius_tween = create_tween().set_ease(Tween.EASE_IN)

	var new_radius: float = new_transform.new_radius
	if new_transform.offset_radius: new_radius = current_radius + new_transform.new_radius

	radius_tween.tween_property(self, "current_radius", new_radius, new_transform.time_to_resize)

	location_tween = create_tween().set_ease(Tween.EASE_IN)

	var new_location: Vector2 = new_transform.new_location
	if new_transform.offset_location: new_location = global_position + new_transform.new_location

	location_tween.tween_property(self, "global_position", new_location, new_transform.time_to_move)

## Updates the current effect that gets applied to entities leaving the safe zone.
func _set_new_effect(new_effect: StatusEffect) -> void:
	if new_effect != null:
		current_effect = new_effect
	else:
		current_effect = default_storm_effect

func _remove_current_effect_from_entity(body: DynamicEntity) -> void:
	var effects_manager: StatusEffectManager = body.effects
	if effects_manager != null:
		effects_manager.request_effect_removal(current_effect.effect_name)

func _add_effect_to_entity(body: DynamicEntity, effect_to_add: StatusEffect) -> void:
	var receiver: EffectReceiverComponent = body.get_node_or_null("EffectReceiverComponent")
	if receiver != null:
		receiver.handle_status_effect(effect_to_add)
