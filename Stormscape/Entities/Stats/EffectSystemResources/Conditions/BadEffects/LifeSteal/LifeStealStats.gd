@icon("res://Utilities/Debug/EditorIcons/life_steal_effect.png")
extends Condition
class_name LifeStealStats
## Resource type for all life steal conditions.

@export_range(0, 100, 0.1, "suffix:%", "or_greater") var dmg_steal_pct: float = 25.0 ## What percent of the damage inflicted should be transferred back to the source entity.
