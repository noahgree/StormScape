extends Resource
class_name ProjectileResource

@export_group("General")
@export var speed: int = 500
@export var speed_falloff: Curve = Curve.new()
@export var lifetime: float = 100.0
@export var max_distance: int = 500
@export var max_pierce: int = 0
@export var max_ricochet: int = 0
@export var spin_speed: float = 0.0
@export var homing: bool = false

@export_group("Arc Trajectory")
@export var arc_height: float = 0.0
@export var arc_time: float = 0.15
@export var arc_collision_delay: float = 0.3

@export_group("Splitting Logic")
@export var split_count: int = 0
@export var split_delay: float = 0.0

@export_group("Area of Effect")
@export var splash_radius: int = 0
@export var splash_falloff_exponent: float = 1.0
@export var splash_effect_delay: float = 0.0
@export var splash_vfx: PackedScene = null
@export var splash_sound: String = ""
