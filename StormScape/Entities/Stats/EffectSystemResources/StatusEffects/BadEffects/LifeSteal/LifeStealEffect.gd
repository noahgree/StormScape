extends StatusEffect
class_name LifeStealEffect
## Resource type for all life steal effects.

@export_custom(PROPERTY_HINT_NONE, "suffix:%") var dmg_steal_mult: float = 0.25 ## What percent of the damage inflicted should be transferred back to the source entity.
