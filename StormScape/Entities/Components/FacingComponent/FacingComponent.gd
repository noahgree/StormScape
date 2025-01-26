@icon("res://Utilities/Debug/EditorIcons/facing_component.svg")
extends Node
class_name FacingComponent
## This component is responsible for determining what directional animation plays based on
## which direction the entity should be facing.
##
## This is completely separate from the FSM.

@onready var entity: PhysicsBody2D = get_parent() ## The entity this facing component controls.

var facing_dir: Vector2 = Vector2.ZERO ## The current animation vector determining animation directionality.
var should_rotate: bool = true ## Reflects whether or not we are performing an action that prevents us from changing the current anim vector used by child states to rotate the entity animation.
var rotation_lerping_factor: float = DEFAULT_ROTATION_LERPING_FACTOR ## The current lerping rate for getting the current mouse direction.
const DEFAULT_ROTATION_LERPING_FACTOR: float = 0.1 ## The default lerping rate for getting the current mouse direction.


## Sets the new animation vector as long as we can currently rotate.
func update_facing_dir(new_facing_dir: Vector2) -> void:
	if should_rotate:
		facing_dir = new_facing_dir

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
