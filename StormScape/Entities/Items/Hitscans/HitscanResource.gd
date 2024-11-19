extends Resource
class_name HitscanResource

@export_group("General")
@export var hitscan: PackedScene ## The hitscan scene to spawn when using hitscan firing.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var hitscan_duration: float = 0 ## The time the hitscan ray is scanning.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var hitscan_effect_interval: float = -1 ## How long after we last did damage should we do it again. '-1' means only once.
@export var hitscan_pierce_count: int = 0 ## How many objects the hitscan can pierce through.
@export_custom(PROPERTY_HINT_NONE, "suffix:pixels") var hitscan_max_distance: int = 350 ## The max distance the hitscan ray can travel.
@export_subgroup("Hitscan Falloff")
@export var hitscan_falloff_curve: Curve = Curve.new() ## The falloff for the effects applied to the receiver of the hitscan.
@export var bad_effects_falloff: bool = true ## Whether the bad effects of the effect source falloff.
@export var good_effects_falloff: bool = false ## Whether the good effects of the effect source falloff.
@export_group("Visual Override Options")
@export var override_vfx_defaults: bool = false ## Whether to use these properties below or leave the defaults.
@export_custom(PROPERTY_HINT_NONE, "suffix:pixels") var hitscan_max_width: float = 0.5 ## The max width the hitscan ray will be when affected by the width curve.
@export var hitscan_width_curve: Curve = Curve.new() ## The change in width of the hitscan ray over its distance.
@export var beam_color: Color = Color.DEEP_PINK ## The main color of the beam.
@export_range(0, 6, 0.1) var glow_amount: float = 1.0 ## The multiplier for the colors to make them glow stronger.
@export_subgroup("Particles")
@export var start_particle_color: Color = Color.PINK ## The color of the particles at the start of the beam.
@export var start_particle_mult: float = 1.0 ## Multiplies the amount of emitted particles for the start of the hitscan.
@export var impact_particle_color: Color = Color.PINK ## The color of the particles at the impact site.
@export var impact_particle_mult: float = 1.0 ## Multiplies the amount of emitted particles for the impact site of the hitscan.
@export var beam_particle_color: Color = Color.RED ## The color of the particles along the beam.
@export var beam_particle_mult: float = 1.0 ## Multiplies the amount of emitted particles for the beam of the hitscan.
