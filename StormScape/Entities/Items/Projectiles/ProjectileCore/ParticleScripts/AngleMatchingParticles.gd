extends CPUParticles2D
class_name AngleMatchingParticles
## Attaches to a CPU Particles node to make it match the angle of rotation of the parent.

@export var angle_offset: float = 0 ## The extra consistent amount of rotation to add each time the angle is set.

@onready var parent: Node2D = get_parent() ## The node to match the rotation angle to.


func _process(_delta: float) -> void:
	angle_min = -parent.global_rotation_degrees + angle_offset
	angle_max = -parent.global_rotation_degrees + angle_offset
