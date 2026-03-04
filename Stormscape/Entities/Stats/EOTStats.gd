extends Resource
class_name EOTStats
## A resource that manages data relating to applying an effect amount (damage or healing) over time.

@export_group("Timing")
@export var tick_count: int = 4 ## How many times the ESI should be applied.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var interval: float = 2.0 ## How long between each tick.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var start_delay: float = 2.0 ## The delay before this effect starts.
@export var perpetual: bool = false ## When true, the esi from the first element in the esi array will continue to be applied until the source condition is removed.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var perpetual_interval: float = 1.0 ## The time between applying the same effect amount when perpetual is true.

@export_group("Ticks")
@export var esi_array: Array[ESI]: set = _set_esi_array ## The effect source instance to apply at each tick. Using only one is recommended, but if more than one are used, the amount used should match the tick count.
@export var affected_stats: Globals.DHTypes = Globals.DHTypes.HEALTH_ONLY ## The stats to apply the amounts to.

@export_group("Stat Mods")
@export var stat_mods: Array[StatMod] ## The mods applied by this effect. Do not have duplicates in this array.
@export var respect_delay: bool = false ## When true, these stat mods won't get applied until after the start delay.

@export_group("Visuals")
@export var hit_flash_color: Color = Color(1, 1, 1, 0.6) ## The color to update the hitflash with every time the effect amount from this resource hits.


## Setter for the esi array to make sure each ESI uses the right source type.
func _set_esi_array(new_esi_array: Array[ESI]) -> void:
	esi_array = new_esi_array
	for esi: ESI in esi_array:
		if esi.es.source_type != Globals.ESISourceType.FROM_EOTI:
			push_error(resource_name + " has EOTIs that don't identify their source as FROM_EOTI. This will cause issues.")
