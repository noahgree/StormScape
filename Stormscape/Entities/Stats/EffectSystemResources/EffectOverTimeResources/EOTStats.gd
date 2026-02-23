extends Resource
class_name EOTStats
## A resource that manages data relating to applying an effect amount (damage or healing) over time.

@export_group("Timing")
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var duration: float = 8.0 ## How long in total the EOT should apply over.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var start_delay: float = 2.0 ## The delay before this effect starts.
@export var perpetual: bool = false ## When true, the effect from the first element in the ticks array will continue to be applied until the source effect is removed.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var perpetual_interval: float = 1.0 ## The time between applying the same effect amount when perpetual is true.

@export_group("Ticks")
@export var ticks_array: Array[int] = [-2, -2, -2, -2] ## The number of ticks and their amounts to apply over the time. Negatives for damage, positives for healing.
@export var affected_stats: Globals.EOTTypes = Globals.EOTTypes.HEALTH_ONLY ## The stats to apply the effect to.

@export_group("Stat Mods")
@export var stat_mods: Array[StatMod] ## The mods applied by this effect. Do not have duplicates in this array.
@export var respect_delay: bool = false ## When true, these stat mods won't get applied until after the start delay.

@export_group("Visuals")
@export var hit_flash_color: Color = Color(1, 1, 1, 0.6) ## The color to update the hitflash with every time the effect amount from this resource hits.
