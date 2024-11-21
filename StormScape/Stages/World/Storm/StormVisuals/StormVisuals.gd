extends Resource
class_name StormVisuals

@export_group("General")
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var viusal_change_time: float = 1.0
@export_range(0, 100, 0.1, "suffix:%") var see_thru_amount: float = 30.0 ## The multiplier to apply to how well the player can see through the zone's fx.

@export_group("Gradient")
@export var storm_gradient_colors: Array[Color] = [Color(0.772, 0.384, 0.773, 0.574), Color(0.606, 0.322, 1, 0.542), Color(0.558, 0.396, 1, 0.772), Color(0.345, 0.001, 0.829, 0.877)] ## The colors that make up the storm gradient. Must be an array of size 4.
@export_custom(PROPERTY_HINT_NONE, "suffix:pixels") var final_color_distance: float = 600 ## The distance from the center at which the final color will be fully transitioned. Useful for marking the end of where the player should be able to see if you set the fourth color to be dark.

@export_group("Distortion")
@export var reflection_intensity: float = 0.15
@export var reflection_thickness: float = 30.0
@export var reflection_color: Color = Color(0.287, 0.287, 0.287, 0.293)
@export var turbulence: float = 1.5
@export var ripple_intensity: float = 0.5
@export var ripple_frequency: float = 0.6
@export var ripple_speed: float = 0.5

@export_group("Rain")
@export var rain_amount: int = 0
@export_range(-1.5, 1.5, 0.01) var rain_slant: float = 0.15
@export_range(5.0, 100.0, 1) var rain_speed: float = 25.0
@export var rain_color: Color = Color(0.857, 0.903, 1, 0.417)
@export var rain_size: Vector2 = Vector2(0.008, 0.19)

@export_group("Wind")
@export var wind_brightness: float = 1.25
@export var ground_wind_speed: float = 0.2
@export var top_wind_speed: float = 2.75
@export var wind_reversal_factor: float = 0
@export var wind_spiral_factor: float = 0

@export_group("Ring")
@export var ring_glow_color: Color = Color(0.6, 0.6, 0.6, 1) ## The color the ring around the safe zone should glow.
@export var ring_glow_intensity: float = 3.0 ## The intensity at which the ring around the safe zone should glow.
@export var ring_pulse_speed: float = 4.0 ## The speed at which the glowing ring around the safe zone pulses in and out.
