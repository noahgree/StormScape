@icon("res://Utilities/Debug/EditorIcons/facing_component.svg")
extends Node2D
class_name FacingComponent
## This component is responsible for determining what directional animation plays based on
## which direction the entity should be facing.
##
## This is completely separate from the FSM.

@onready var entity: Entity = get_parent() ## The entity this facing component controls.

enum Method { MOVEMENT_DIR, TARGET_POS, MOUSE_POS, ITEM_ROT, NONE } ## The ways the facing component can choose direction.

var facing_dir: Vector2 ## The current animation vector determining animation directionality.
var last_movement_dir: Vector2 ## The last movement dir if it is currently 0 so we know what direction to continue facing while standing still.
var rotation_lerping_factor: float = DEFAULT_ROTATION_LERPING_FACTOR ## The current lerping rate for getting the current mouse direction.
const DEFAULT_ROTATION_LERPING_FACTOR: float = 0.1 ## The default lerping rate for getting the current mouse direction.


#region Debug
func _draw() -> void:
	if not DebugFlags.show_facing_dir:
		return

	var entity_pos_with_sprite_offset: Vector2 = to_local(entity.global_position + (entity.sprite.position / 2.0))
	var end_point: Vector2 = entity_pos_with_sprite_offset + facing_dir.normalized() * 20.0
	draw_line(entity_pos_with_sprite_offset, end_point, Color.DARK_ORANGE, 0.5)

	var font: Font = preload("res://Assets/Theming/Fonts/GameFontResources/ui_dynamic_font.tres")
	var angle_str: String = str(snappedf(facing_dir.angle() * 180.0 / PI, 1.1))
	draw_string(font, entity_pos_with_sprite_offset + Vector2(5, 5), angle_str + "°", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color.ORANGE)
#endregion

## Sets the new animation vector as long as we can currently rotate. Called manually so it syncs with time snares.
func update_facing_dir(method: Method) -> void:
	if DebugFlags.show_facing_dir:
		queue_redraw()
	if Globals.focused_ui_is_open:
		return

	var entity_pos_with_sprite_offset: Vector2 = (entity.sprite.position / 2.0) + entity.global_position
	match method:
		Method.MOVEMENT_DIR:
			var target_dir: Vector2 = entity.fsm.controller.get_movement_vector().normalized()
			if target_dir.length() == 0:
				target_dir = last_movement_dir
			else:
				last_movement_dir = target_dir
			facing_dir = LerpHelpers.lerp_direction_vectors(facing_dir, target_dir, rotation_lerping_factor)
		Method.TARGET_POS:
			var target: Entity = entity.fsm.controller.target
			if target:
				facing_dir = LerpHelpers.lerp_direction(facing_dir, target.global_position, entity_pos_with_sprite_offset, rotation_lerping_factor)
		Method.MOUSE_POS:
			var target_pos: Vector2 = CursorManager.get_cursor_mouse_position()
			facing_dir = LerpHelpers.lerp_direction(facing_dir, target_pos, entity_pos_with_sprite_offset, rotation_lerping_factor)
		Method.ITEM_ROT:
			var item: EquippableItem = entity.hands.equipped_item
			if item == null:
				return
			var direction: Vector2 = (item.global_position - entity_pos_with_sprite_offset).normalized()
			var item_rotation: float = item.sprite.rotation
			facing_dir = direction.rotated(-item_rotation if entity.hands.current_x_direction == -1 else item_rotation)

## Travels to a new animation in the animation tree.
func travel_anim_tree(new_anim: String) -> void:
	entity.anim_tree["parameters/playback"].travel(new_anim)

## Updates the blend position of the animation tree to change the direction of the animation.
func update_blend_position(anim: String) -> void:
	var path_string: String = "parameters/" + anim + "/blendspace2d/blend_position"
	entity.anim_tree.set(path_string, facing_dir)

## Updates the time scale of an animation.
func update_time_scale(anim: String, new_time_scale: float) -> void:
	var path_string: String = "parameters/" + anim + "/TimeScale/scale"
	entity.anim_tree.set(path_string, new_time_scale)
