extends Resource
class_name ProjectileResource

@export_group("General")
@export var speed: int = 500
@export var speed_curve: Curve = Curve.new()
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var lifetime: float = 3
@export_custom(PROPERTY_HINT_NONE, "suffix:pixels") var max_distance: int = 500
@export var max_pierce: int = 0
@export var max_ricochet: int = 0
@export var ricochet_bounce: bool = true
@export var homing: bool = false

@export_group("Spin")
@export var spin_speed: float = 0.0
@export var spin_both_ways: bool = true
@export_enum("Left", "Right") var spin_direction: String = "Left"
@export var move_in_rotated_dir: bool = false

@export_group("Arc Trajectory")
@export_custom(PROPERTY_HINT_NONE, "suffix:pixels") var arc_height: float = 0.0
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var arc_time: float = 0.15
@export var arc_collision_delay: float = 0.3

@export_group("Splitting Logic")
@export var number_of_splits: int = 0
@export var split_into_count: int = 2
@export_custom(PROPERTY_HINT_NONE, "suffix:degrees") var split_angle: float = 15
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var split_delay: float = 0.35
@export_subgroup("Splitting FX")
@export_range(0, 30, 0.01) var split_cam_shake_str: float = 0.0
@export_range(0, 2, 0.01) var split_cam_shake_dur: float = 0.0

@export_group("Area of Effect")
@export_custom(PROPERTY_HINT_NONE, "suffix:pixels") var splash_radius: int = 0
@export var splash_falloff_exponent: float = 1.0
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var splash_effect_delay: float = 0.0
@export_subgroup("AOE FX")
@export var splash_vfx: PackedScene = null
@export var splash_sound: String = ""
