extends Resource
class_name ProjectileResource

@export_group("General")
@export var speed: int = 500 ## The highest speed the projectile can travel in.
@export var speed_curve: Curve = Curve.new() ## How the speed changes based on lifetime left.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var lifetime: float = 3 ## The max time this projectile can be in the air.
@export_custom(PROPERTY_HINT_NONE, "suffix:pixels") var max_distance: int = 500 ## The max distance this projectile can travel from its starting position.
@export_range(0, 100, 1) var max_pierce: int = 0 ## The max amount of collisions this can take before freeing.
@export_range(0, 100, 1) var max_ricochet: int = 0 ## The max amount of ricochets this can do before trying to pierce and then freeing.
@export var ricochet_bounce: bool = true ## Whether the ricochets should bounce at an angle or just reverse the direction they were travelling in. Note that when colliding with TileMaps, it always just reverses direction.
@export var homing: bool = false ## Whether this projectile should home-in on its target.

@export_group("Spin")
@export_range(0, 10000, 1, "suffix:º/sec") var spin_speed: float = 0.0 ## How fast this projectile should spin while in the air.
@export var spin_both_ways: bool = true ## Whether each projectile should choose a direction at random or depend on the spin_direction.
@export_enum("Left", "Right") var spin_direction: String = "Left" ## If spin_both_ways is false, all projectiles will spin this direction.
@export var move_in_rotated_dir: bool = false ## When true, projectiles will travel in the direction of their current rotation, determined by spinning it. If false, they will keep their original trajectory despite the spins. Note that this does nothing if we are arcing.

@export_group("Arc Trajectory")
@export_range(0, 89, 1, "suffix:degrees") var launch_angle: float = 0 ## The initial angle to launch the projectile at.
@export_custom(PROPERTY_HINT_NONE, "suffix:pixels") var arc_travel_distance: int = 125 ## How many pixels the arc shot should travel before landing.
@export var arc_speed: float = 350 ## How fast the arcing motion happens.
@export_custom(PROPERTY_HINT_NONE, "suffix:pixels") var max_collision_height: int = 25 ## How many simulated pixels off the ground this can be before it can no longer collide with things.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var grounding_free_delay: float = 0 ## How much time after we hit the ground do we wait before freeing the projectile. Note that this doesn't apply if we start an AOE after grounding.

@export_group("Splitting Logic")
@export_range(0, 20, 1) var number_of_splits: int = 0 ## How many times the recursive splits should happen.
@export var split_into_counts: Array[int] = [2] ## For each split index, you should assign how many to create.
@export_custom(PROPERTY_HINT_NONE, "suffix:degrees") var angular_spreads: Array[float] = [45] ## For each split index, you should specify how wide of an angle the projectiles will be spread amongst.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var split_delays: Array[float] = [0.2] ## For each split index, you should assign how long after the last projectile spawn to wait before splitting again. The first delay is the delay before the initial split.
@export_subgroup("Splitting FX")
@export var splitting_sounds: Array[String] = [""] ## For each split index, you should assign the sound to be played during the split.
@export_range(0, 30, 0.01) var split_cam_shakes_str: Array[float] = [1.0] ## For each split index, you should determine how strong the camera shake will be at the split.
@export_range(0, 2, 0.01) var split_cam_shakes_dur: Array[float] = [0.2] ## For each split index, you should determine how long the camera shake will last after the split.

@export_group("Area of Effect")
@export_range(0, 200, 1, "suffix:pixels") var splash_radius: int = 0 ## If above 0, this projectile will do AOE damage after hitting something.
@export var do_aoe_on_arc_land: bool = true ## Whether to trigger an AOE when we land after an arc shot.
@export var splash_falloff_curve: Curve = Curve.new() ## Changes damage and mod times for the effect source based on how far away from the origin of the splash damage the receiver was hit.
@export var bad_effects_falloff: bool = true ## Whether to apply the falloff curve to bad effects.
@export var good_effects_falloff: bool = false ## Whether to apply the falloff curve to good effects.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var splash_effect_delay: float = 0.0 ## How long after triggering the AOE does the projectile sit in wait before re-enabling the larger collider.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var splash_effect_dur: float = 0.05 ## How long the larger collider will be enabled for once a splash is triggered.
@export var splash_before_freeing: bool = false ## Whether to trigger the splash once we reach end of lifetime if we haven't hit anything yet.
@export var splash_effect_source: EffectSource = null ## The effect source to apply when something is hit by splash damage. If null, this will just use the default effect source for this projectile.
@export_subgroup("AOE FX")
@export var splash_vfx: PackedScene = null
@export var splash_sound: String = ""
