@tool
extends DynamicEntity
class_name Player
## The main class for the player character.

@onready var hotbar_ui: HotbarUI = %HotbarUI ## The UI script that manages the player hotbar.
@onready var overhead_ui: PlayerOverheadUI = %OverheadUI ## The UI script that manages the player overhead UI for things like reload bars.


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	super._ready()
	SignalBus.player_ready.emit(self)

## Takes in a current direction of rotation and a target position to face, lerping it every frame.
func get_lerped_mouse_direction_to_pos(current_direction: Vector2, target_position: Vector2) -> Vector2:
	var target_direction: Vector2 = (CursorManager.get_cursor_mouse_position() - target_position)

	var current_angle: float = current_direction.angle()
	var target_angle: float = target_direction.angle()

	var angle_diff: float = angle_difference(current_angle, target_angle)
	var new_angle: float = current_angle + angle_diff * facing_component.rotation_lerping_factor

	return Vector2.RIGHT.rotated(new_angle)

## Returns a normalized direction to the mouse position from this entity.
func get_mouse_direction_from_self() -> Vector2:
	var entity_pos_with_sprite_offset: Vector2 = (sprite.position / 2.0) + global_position
	return (CursorManager.get_cursor_mouse_position() - entity_pos_with_sprite_offset).normalized()
