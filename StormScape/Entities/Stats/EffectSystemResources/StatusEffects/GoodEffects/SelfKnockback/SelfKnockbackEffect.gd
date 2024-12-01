extends KnockbackEffect
class_name SelfKnockbackEffect
## A special kind of knockback that applies directly to the source entity. Uses either its hands rotation or
## the direction it is facing, as specified.

@export_enum("Direction Faced", "Hands Rotation") var direction_method: String = "Direction Faced" ## What direction vector to apply the knockback in. With "Direction Faced", we apply knockback opposite of anim vector. With "Hands Rotation", we apply it opposite of the direction the hands are facing (useful for gun knockback).
