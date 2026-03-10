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
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var storm_syndrome_weakness: float = 0.0 ## A multiplier for increasing storm damage on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var storm_syndrome_resistance: float = 0.0 ## A multiplier for reducing storm damage on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var stun_weakness: float = 0.0 ## A multiplier for increasing stun time applied to an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var stun_resistance: float = 0.0 ## A multiplier for decreasing stun time applied to an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var time_snare_weakness: float = 0.0 ## A multiplier for increasing time snare time applied to an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var time_snare_resistance: float = 0.0 ## A multiplier for decreasing time snare time applied to an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var confusion_weakness: float = 0.0 ## A multiplier for increasing confusion time applied to an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var confusion_resistance: float = 0.0 ## A multiplier for decreasing confusion time applied to an entity.


func initialize_stat_cache(entity: Entity) -> void:
	var moddable_stats: Dictionary[StringName, float] = {
		&"dmg_weakness": dmg_weakness, &"dmg_resistance": dmg_resistance,
		&"heal_affinity": heal_affinity, &"heal_reduction": heal_reduction,

		&"burning_weakness": burning_weakness, &"burning_resistance": burning_resistance,
		&"frostbite_weakness": frostbite_weakness, &"frostbite_resistance": frostbite_resistance,
		&"knockback_weakness": knockback_weakness, &"knockback_resistance": knockback_resistance,
		&"life_steal_weakness": life_steal_weakness, &"life_steal_resistance": life_steal_resistance,
		&"poison_weakness": poison_weakness, &"poison_resistance": poison_resistance,
		&"regen_affinity": regen_affinity, &"regen_reduction": regen_reduction,
		&"storm_syndrome_weakness": storm_syndrome_weakness,
		&"storm_syndrome_resistance": storm_syndrome_resistance,
		&"stun_weakness": stun_weakness, &"stun_resistance": stun_resistance,
		&"time_snare_weakness": time_snare_weakness, &"time_snare_resistance": time_snare_resistance,
		&"confusion_weakness": confusion_weakness, &"confusion_resistance": confusion_resistance
	}

	entity.sc.add_moddable_stats(moddable_stats)
