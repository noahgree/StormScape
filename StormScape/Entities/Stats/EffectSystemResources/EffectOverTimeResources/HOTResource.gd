extends Resource
class_name HOTResource
## A resource that manages data relating to applying healing over time.

@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var healing_time: float = 0 ## How long in total the HOT resource should apply over.
@export var heal_ticks_array: Array[int] = [] ## The number of healing ticks and their amounts to apply over the healing time.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var delay_time: float = 0 ## The delay before this effect starts.
@export var heal_affected_stats: Globals.HealAffectedStats = Globals.HealAffectedStats.HEALTH_THEN_SHIELD ## The stats to apply the healing to.

@export_subgroup("Perpetual")
@export var run_until_removed: bool = false ## When true, the healing from the first element in the heal array will continue to be applied until the source effect is removed.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var time_between_ticks: float = 1.0 ## The time between applying the same healing amount when run_until_removed is true.

@export_group("Visuals")
@export var hit_flash_color: Color = Color(0, 1, 0, 0.6) ## The color to update the hitflash with every time healing from this resource is added.
