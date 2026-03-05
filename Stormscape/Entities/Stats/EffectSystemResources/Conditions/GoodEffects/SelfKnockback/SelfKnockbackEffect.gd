@icon("res://Utilities/Debug/EditorIcons/self_knockback_effect.png")
extends KnockbackEffect
class_name SelfKnockbackEffect
## A special kind of knockback that applies directly to the source entity. Uses either its hands rotation or
## the direction it is facing, as specified.

enum DIRECTION_METHOD { FACING, HANDS_ROTATION }

@export var direction_method: DIRECTION_METHOD = DIRECTION_METHOD.FACING ## What direction vector to apply the knockback in. With "FACING", we apply knockback opposite of anim vector. With "HANDS_ROTATION", we apply it opposite of the direction the hands are facing (useful for gun knockback).
