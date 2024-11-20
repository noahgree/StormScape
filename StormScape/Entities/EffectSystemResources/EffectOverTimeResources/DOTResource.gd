extends Resource
class_name DOTResource
## A resource that manages data relating to applying damage over time.

@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var damaging_time: float = 0 ## How long in total the DOT resource should apply over.
@export var dmg_ticks_array: Array[int] = [] ## The number of damage ticks and their amounts to apply over the damaging time.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var delay_time: float = 0 ## The delay before this effect starts.
@export var dmg_affected_stats: GlobalData.DmgAffectedStats = GlobalData.DmgAffectedStats.SHIELD_THEN_HEALTH ## The stats to apply the damage to.

@export_subgroup("Perpetual")
@export var run_until_removed: bool = false ## When true, the damage from the first element in the dmg array will continue to be applied until the source effect is removed.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var time_between_ticks: float = 1.0 ## The time between applying the same damage amount when run_until_removed is true.
