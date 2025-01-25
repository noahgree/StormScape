extends Node
class_name FacingComponent
## This component is responsible for determining what directional animation plays based on which direction the entity
## should be facing.
##
## This is completely separate from the FSM.

@onready var entity: PhysicsBody2D = get_parent()

var anim_vector: Vector2 = Vector2.ZERO
var should_rotate: bool = true ## Reflects whether or not we are performing an action that prevents us from changing the current anim vector used by child states to rotate the entity animation.
var rotation_lerping_factor: float = 0.1 ## The current lerping rate for getting the current mouse direction.
const DEFAULT_ROTATION_LERPING_FACTOR: float = 0.1 ## The default lerping rate for getting the current mouse direction.


func _ready() -> void:
	rotation_lerping_factor = DEFAULT_ROTATION_LERPING_FACTOR

func update_anim_vector(new_anim_vector: Vector2) -> void:
	if should_rotate:
		anim_vector = new_anim_vector

func travel_anim_tree(new_anim: String) -> void:
	entity.anim_tree["parameters/playback"].travel(new_anim)

func update_blend_position(anim: String) -> void:
	var path_string: String = "parameters/" + anim + "/blendspace2d/blend_position"
	entity.anim_tree.set(path_string, anim_vector)

func update_time_scale(anim: String, new_time_scale: float) -> void:
	var path_string: String = "parameters/" + anim + "/TimeScale/scale"
	entity.anim_tree.set(path_string, new_time_scale)
