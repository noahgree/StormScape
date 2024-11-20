extends Node2D
class_name Storm
## The base class for the moving storm's functionalities. Controls the shader parameters and effect application logic.

@export var transform_queue: Array[StormTransform] = [] ## The queue of upcoming transforms to apply to the zone.
@export var current_effect: StormSyndromeEffect ## The current effect to apply when a dynamic entity leaves the safe zone.

@onready var collision_shape: CollisionShape2D = $SafeZone/CollisionShape2D ## The collider that detects when something is in the safe zone.
@onready var storm_circle: ColorRect = $StormCanvas/StormCircle ## The color rect that houses the storm circle shader.

var current_radius: float = 0: ## The current radius of the safe zone.
	set(new_radius):
		current_radius = new_radius
		collision_shape.shape.radius = new_radius
var radius_tween: Tween = null ## The tween controlling a radius change.
var location_tween: Tween = null ## The tween controlling a location change.
var storm_change_delay_timer: Timer = Timer.new() ## The timer controlling the delay between a new transform has activated and it actually starting to move/resize.
var current_storm_transform_time_timer: Timer = Timer.new() ## The timer controlling the length of the storm change. Chooses the max time between the resize and relocate time values in the resource.


func _ready() -> void:
	add_child(storm_change_delay_timer)
	add_child(current_storm_transform_time_timer)
	storm_change_delay_timer.one_shot = true
	current_storm_transform_time_timer.one_shot = true
	storm_change_delay_timer.timeout.connect(_on_storm_change_delay_timer_timeout)
	current_storm_transform_time_timer.timeout.connect(_on_current_storm_transform_time_timer_timeout)

	current_radius = collision_shape.shape.radius

	_process_next_transform_in_queue()

func _physics_process(_delta: float) -> void:
	_set_shader_transform_params()

## Updates the shader's transform params with the current values.
func _set_shader_transform_params() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	storm_circle.material.set_shader_parameter("viewport_size", viewport_size)

	var collision_radius = current_radius
	var edge_point_world = global_position + Vector2(collision_radius, 0).rotated(global_rotation)

	var screen_center = _get_screen_point_from_world_coord(global_position)
	var screen_edge = _get_screen_point_from_world_coord(edge_point_world)
	var radius_pixels = screen_edge.distance_to(screen_center)

	var noise_origin = _get_screen_point_from_world_coord(Vector2.ZERO)

	storm_circle.material.set_shader_parameter("circle_center_pixels", screen_center)
	storm_circle.material.set_shader_parameter("noise_world_position", noise_origin)
	storm_circle.material.set_shader_parameter("radius_pixels", radius_pixels)

## Converts the world coordinate to a screen position based on camera position, rotation, and zoom.
func _get_screen_point_from_world_coord(world_point: Vector2) -> Vector2:
	var camera: Camera2D = GlobalData.player_camera
	var viewport_size = get_viewport().get_visible_rect().size
	var relative_position = world_point - camera.global_position
	var rotated_position = relative_position.rotated(-camera.rotation)
	var zoomed_position = rotated_position * camera.zoom
	var screen_position = (viewport_size / 2) + zoomed_position

	return screen_position

## When a dynamic entity enters the inner circle, we remove the current storm effect.
func _on_safe_zone_body_entered(body: Node2D) -> void:
	if body is DynamicEntity:
		var effects_manager: StatusEffectManager = body.effects
		if effects_manager != null:
			effects_manager.request_effect_removal(current_effect.effect_name)

## When a dynamic entity exits the inner safe circle, we apply the current storm effect.
func _on_safe_zone_body_exited(body: Node2D) -> void:
	if body is DynamicEntity:
		var receiver: EffectReceiverComponent = body.get_node_or_null("EffectReceiverComponent")
		if receiver != null:
			receiver.handle_status_effect(current_effect)

## Adds a new transform resource to the end of the queue, and if it is the only one in the queue, it starts the transform immediately.
func add_storm_transform_to_queue(new_transform: StormTransform) -> void:
	transform_queue.append(new_transform.duplicate())
	if transform_queue.size() == 1:
		_process_next_transform_in_queue()

## Processes the front of the transform queue by setting up the zone time timer and calling for the zone to start updating.
func _process_next_transform_in_queue() -> void:
	if transform_queue.is_empty():
		return

	var new_transform: StormTransform = transform_queue[0]
	var delay: float = max(new_transform.time_to_resize, new_transform.time_to_move)

	_start_zone_update(new_transform)

	current_storm_transform_time_timer.stop()
	current_storm_transform_time_timer.start(delay)

## When the current transform ends, check for another one.
func _on_current_storm_transform_time_timer_timeout() -> void:
	if not transform_queue.is_empty():
		transform_queue.pop_front()

	_process_next_transform_in_queue()

## Starts updating the zone with a new passed in storm transform resource.
func _start_zone_update(new_transform: StormTransform) -> void:
	if radius_tween:
		radius_tween.stop()
		radius_tween.kill()

	if location_tween:
		location_tween.stop()
		location_tween.kill()

	if new_transform.delay > 0:
		storm_change_delay_timer.stop()
		storm_change_delay_timer.set_meta("storm_params", new_transform)
		storm_change_delay_timer.start(new_transform.delay)
	else:
		_tween_to_new_zone(new_transform)
		_set_new_effect(new_transform.status_effect)

## Starts the tweens that will move the zone.
func _tween_to_new_zone(new_transform: StormTransform) -> void:
	radius_tween = create_tween()
	radius_tween.tween_property(self, "current_radius", new_transform.new_radius, new_transform.time_to_resize)

	location_tween = create_tween()
	location_tween.tween_property(self, "global_position", new_transform.new_location, new_transform.time_to_move)

## Updates the current effect that gets applied to entities leaving the safe zone.
func _set_new_effect(new_effect: StatusEffect) -> void:
	if new_effect != null:
		current_effect = new_effect

## When the delay before the next transform ends, start that transform and set the current effect.
func _on_storm_change_delay_timer_timeout() -> void:
	var params: StormTransform = storm_change_delay_timer.get_meta("storm_params")
	_tween_to_new_zone(params)
	_set_new_effect(params.status_effect)
