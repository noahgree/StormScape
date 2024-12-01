extends ItemResource
class_name WeaponResource
## The base resource for all weapons. This will be subclasses to define more traits, but everything here applies to all weapons.

@export_group("General Weapon Details")
@export var s_mods: StatModsCacheResource = StatModsCacheResource.new() ## The cache of all up to date stats for this weapon with mods factored in.
@export var effect_source: EffectSource = EffectSource.new() ## The resource that defines what happens to the entity that is hit by this weapon. Includes things like damage and status effects.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var pullout_delay: float = 0.3 ## How long after equipping must we wait before we can use this weapon.
@export_subgroup("Modding Details")
@export var blocked_mods: Array[String] = [] ## The string names of weapon mod titles that are not allowed to be applied to this weapon.


# Unique Properties #
@export_storage var time_last_equipped: float = 0 ## The time that this weapon was last equipped.
@export_storage var cache_is_setup: bool = false ## Whether the stats cache has been setup for this weapon before. If it has, we don't want to set it up again after re-equipping. This also determines whether the effect sources are unique to this instance.
@export_storage var current_mods: Dictionary = {} ## The current mods applied to this weapon.
@export_storage var original_status_effects: Array[StatusEffect] = [] ## The original status effect list of the effect source before any mods are applied.
@export_storage var original_charge_status_effects: Array[StatusEffect] = [] ## The original status effect list of the charge effect source before any mods are applied.
