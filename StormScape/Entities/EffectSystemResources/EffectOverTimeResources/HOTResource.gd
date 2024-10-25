extends Resource
class_name HOTResource
## A resource that manages data relating to applying healing over time.

@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var healing_time: float
@export var heal_ticks_array: Array[int]
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var delay_time: float
@export var heal_affected_stats: GlobalData.HealAffectedStats
