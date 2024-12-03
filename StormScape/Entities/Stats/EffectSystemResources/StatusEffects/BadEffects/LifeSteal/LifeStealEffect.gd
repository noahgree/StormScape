extends StatusEffect
class_name LifeStealEffect
## Resource type for all life steal effects.

@export_range(0, 100, 0.1, "suffix:%", "or_greater") var dmg_steal: float = 25.0 ## What percent of the damage inflicted should be transferred back to the source entity.
