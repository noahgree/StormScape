extends Resource
class_name EOTStats
## A resource that manages data relating to applying an effect amount (damage or healing) over time.

@export_group("Timing")
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var duration: float = 8.0 ## How long all ticks should take, in total.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var start_delay: float = 1.0 ## The delay before this effect starts.
@export var perpetual: bool = false ## When true, the esi from the first element in the esi array will continue to be applied until the source condition is removed.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var perpetual_interval: float = 2.0 ## The time between applying the same effect amount when perpetual is true.

@export_group("Ticks")
@export var tick_count: int = 4 ## How many times the ESI should be applied. Should match the number of effect sources in the ticks array if the size of that array is greater than 1.
@export var ticks_array: Array[EffectSource] ## The effect sources to apply at each tick. Using only one is recommended, but if more than one are used, the amount used should match the tick count.
@export var affected_stats: Globals.DHTypes = Globals.DHTypes.HEALTH_ONLY ## The stats to apply the amounts to.
@export var popup_type: HPComponent.POPUP_TYPE = HPComponent.POPUP_TYPE.BURNING ## What the amount popup and colorations should look like they came from at each tick.
@export var hit_flash_color: Color = Color(1, 1, 1, 0.6) ## The color to update the hitflash with every time the effect amount from this resource hits.

@export_group("Stat Mods")
@export var stat_mods: Array[StatMod] ## The mods applied by this effect. Do not have duplicates in this array.
@export var delay_stats_too: bool = false ## When true, these stat mods won't get applied until after the start delay.
