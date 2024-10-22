extends Resource
class_name DOTResource
## A resource that manages data relating to applying damage over time.

@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var damaging_time: float
@export var dmg_ticks_array: Array[int]
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var delay_time: float
@export var dmg_affected_stats: EnumUtils.DmgAffectedStats
