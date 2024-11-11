extends Node2D
class_name HandComponents

@onready var main_hand: Node2D = $MainHand
@onready var hand_sprite: Sprite2D = $HandSprite


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("primary"):
		if main_hand.get_child_count() > 0 and main_hand.get_child(0).has_method("fire"):
			main_hand.get_child(0).fire(get_parent())

func _physics_process(_delta: float) -> void:
	if get_parent().move_fsm.anim_vector.y < 0:
		z_index = -2
	else:
		z_index = 0

	global_rotation = (get_global_mouse_position() - global_position).angle()
	if get_parent().move_fsm.anim_vector.x < 0:
		scale.y = -1
	else:
		scale.y = 1
