@tool
extends Node2D
class_name Storm

@export var current_effect: StormSyndromeEffect

@onready var collision_shape: CollisionShape2D = $SafeZone/CollisionShape2D
@onready var storm_circle: ColorRect = $CanvasLayer/StormCircle


func _process(delta: float) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	storm_circle.material.set_shader_parameter("viewport_size", viewport_size)
	storm_circle.size = viewport_size

	if not Engine.is_editor_hint():
		global_position.x += (1 * delta)
		collision_shape.shape.radius -= 2 * delta

		# Calculate the circle's center in screen space
		var screen_center = world_to_screen_point(global_position)

		# Calculate a point at the edge of the circle in world space
		var collision_radius = collision_shape.shape.radius
		var edge_point_world = global_position + Vector2(collision_radius, 0).rotated(global_rotation)

		# Map the edge point to screen space
		var screen_edge = world_to_screen_point(edge_point_world)

		# Calculate the radius in screen pixels
		var radius_pixels = screen_edge.distance_to(screen_center)

		# Set shader parameters
		storm_circle.material.set_shader_parameter("circle_center_pixels", screen_center)
		storm_circle.material.set_shader_parameter("radius_pixels", radius_pixels)


func world_to_screen_point(world_point: Vector2) -> Vector2:
	var camera = GlobalData.player_camera
	var viewport_size = get_viewport().get_visible_rect().size
	var relative_position = world_point - camera.global_position
	var rotated_position = relative_position.rotated(-camera.rotation)
	var zoomed_position = rotated_position * camera.zoom
	var screen_position = (viewport_size / 2) + zoomed_position
	return screen_position

func _on_safe_zone_body_entered(body: Node2D) -> void:
	if body is DynamicEntity:
		var effects_manager: StatusEffectManager = body.effects
		if effects_manager != null:
			effects_manager.request_effect_removal(current_effect.effect_name)

func _on_safe_zone_body_exited(body: Node2D) -> void:
	if body is DynamicEntity:
		var receiver: EffectReceiverComponent = body.get_node_or_null("EffectReceiverComponent")
		if receiver != null:
			receiver.handle_status_effect(current_effect)

func set_safe_zone_radius(new_radius: int) -> void:
	collision_shape.shape.radius = new_radius
