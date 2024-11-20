extends Resource
class_name StormTransform
## A resource for defining the parameters on how to change the current zone.

@export var new_location: Vector2 = Vector2.ZERO
@export_custom(PROPERTY_HINT_NONE, "suffix:pixels") var new_radius: float = 50
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var delay: float = 0
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var time_to_move: float = 10.0
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var time_to_resize: float = 10.0
@export var status_effect: StatusEffect = null
