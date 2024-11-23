extends Resource
class_name StormVisuals

@export_group("General")
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var viusal_change_time: float = 1.0 ## How long the viusal overrides take to change to new values. [b] Must be shorter than the move & resize times or the blending will interfere with the next phase. [/b]

@export_group("Player See Thru")
@export_range(0, 100, 0.1, "suffix:%") var see_thru_amount: float = 25.0 ## The multiplier to apply to how well the player can see through the zone's fx.
@export var see_through_pulse_mult: float = 1.0 ## How much to pulse the player's see through circle during this phase.
@export var see_thru_dist_mult: float = 1.0 ## How much to multiply the current see thru distance by during this phase.

@export_group("Gradient")
@export var storm_gradient_colors: Array[Color] = [Color(0.772, 0.384, 0.773, 0.574), Color(0.606, 0.322, 1, 0.542), Color(0.558, 0.396, 1, 0.772), Color(0.345, 0.001, 0.829, 0.877)] ## The colors that make up the storm gradient. Must be an array of size 4.
@export_custom(PROPERTY_HINT_NONE, "suffix:pixels") var final_color_distance: float = 600 ## The distance from the center at which the final color will be fully transitioned. Useful for marking the end of where the player should be able to see if you set the fourth color to be dark.

@export_group("Distortion")
@export var reflection_intensity: float = 0.15 ## Controls the intensity of the wave suface lines that simulate reflecting bright lights.
@export var reflection_thickness: float = 30.0 ## Controls the thickness of the wave suface lines that simulate reflecting bright lights. Extending this value too high basically makes the storm opaque.
@export var reflection_color: Color = Color(0.287, 0.287, 0.287, 0.293) ## Controls the color of the wave suface lines that simulate reflecting bright lights.
@export var turbulence: float = 1.5 ## Controls the inward quad-warping motion of the entire zone shader. High values make the storm look like it is folding in on itself.
@export var ripple_intensity: float = 0.5 ## Controls the intensity of the ripple effect that sends circular waves outwards.
@export var ripple_frequency: float = 0.6 ## Controls the frequency of the ripple effect that sends circular waves outwards.
@export var ripple_speed: float = 0.5 ## Controls the speed of how fast the ripples move away from the center.

@export_group("Rain")
@export var rain_amount: int = 0 ## WARNING: These are bad for performance. Avoid values over 35. Controls the amount of rain particles.
@export_range(-1.5, 1.5, 0.01) var rain_slant: float = 0.15 ## Controls the angle at which the rain moves across the screen.
@export_range(5.0, 100.0, 1) var rain_speed: float = 25.0 ## Controls how fast the rain moves across the screen.
@export var rain_color: Color = Color(0.857, 0.903, 1, 0.417) ## Controls the color of the rain particles.
@export var rain_size: Vector2 = Vector2(0.008, 0.19) ## Controls the sizing in the x and y direction of the rain particles.

@export_group("Wind")
@export var wind_brightness: float = 1.25 ## Controls how dense and bright the windy cloud patterns are.
@export var ground_wind_speed: float = 0.2 ## Controls how fast the ground layer of windy clouds moves.
@export var top_wind_speed: float = 2.75 ## Controls how fast the upper layer of windy clouds moves. Set this higher than the ground layer to simulate fast, stormy top winds.
@export var wind_reversal_factor: float = 0 ## Anything greater than 0 will start to reverse the direction of the wind.
@export var wind_spiral_factor: float = 0 ## Anything greater than 0 will start to make the storm move in a circular pattern around the center point.

@export_group("Ring")
@export var ring_glow_color: Color = Color(0.722, 0.681, 1, 0.743) ## The color the ring around the safe zone should glow.
@export var ring_glow_intensity: float = 2.3 ## The intensity at which the ring around the safe zone should glow.
@export var ring_pulse_speed: float = 4.0 ## The speed at which the glowing ring around the safe zone pulses in and out.
