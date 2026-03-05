extends Resource
class_name EntityStatModifiers
## A resource that holds all starting, unmodded values for the modifiers applied to several kinds of incoming
## ESI effects and conditions.

@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var dmg_weakness: float = 0.0 ## Increases ALL incoming damage.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var dmg_resistance: float = 0.0 ## Decreases ALL incoming damage.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var heal_affinity: float = 0.0 ## Increases ALL incoming healing.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var heal_reduction: float = 0.0 ## Decreases ALL incoming healing.

@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var burning_weakness: float = 0.0 ## A multiplier for burning damage on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var burning_resistance: float = 0.0 ## A multiplier for burning reduction on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var frostbite_weakness: float = 0.0 ## A multiplier for frostbite damage on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var frostbite_resistance: float = 0.0 ## A multiplier for frostbite reduction on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var knockback_weakness: float = 0.0 ## A multiplier for knockback on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var knockback_resistance: float = 0.0 ## A multiplier for redudcing knockback on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var life_steal_weakness: float = 0.0 ## An increase multiplier for life steal applied to an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var life_steal_resistance: float = 0.0 ## A reduction multiplier for life steal applied to an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var poison_weakness: float = 0.0 ## A multiplier for poison damage on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var poison_resistance: float = 0.0 ## A multiplier for poison damage on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var regen_affinity: float = 0.0 ## A multiplier for regen boosting on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var regen_reduction: float = 0.0 ## A multiplier for regen reduction on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var storm_weakness: float = 0.0 ## A multiplier for increasing storm damage on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var storm_resistance: float = 0.0 ## A multiplier for reducing storm damage on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var stun_weakness: float = 0.0 ## A multiplier for increasing stun time applied to an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var stun_resistance: float = 0.0 ## A multiplier for decreasing stun time applied to an entity.
@export_range(0, 1, 1, "hide_slider", "suffix:(1 = on | 0 = off)") var time_snare_immunity: float = 0 ## If aything besides 0, the time snare effect is nullified.
