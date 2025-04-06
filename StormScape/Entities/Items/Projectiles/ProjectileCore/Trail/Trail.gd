extends Line2D
class_name Trail
## A reusable trail component that leaves a simple line behind it.

@export var max_points: int = 25 ## The max length of the trail.
@export var x_offset: float = 0 ## How far behind or ahead of the parent the trail should start.

@onready var curve: Curve2D = Curve2D.new() ## The curve defining the line's shape.

func _ready() -> void:
	hide()

func _process(_delta: float) -> void:
	var offset_vector: Vector2 = Vector2(x_offset, 0).rotated(get_parent().global_rotation)

	curve.add_point(get_parent().global_position + offset_vector)

	if curve.get_baked_points().size() > max_points:
		curve.remove_point(0)

	points = curve.get_baked_points()
	show()
