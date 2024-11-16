extends ItemResource
class_name WeaponResource

@export_group("General Weapon Details")
@export var stats: StatModsCacheResource = StatModsCacheResource.new() ## The cache of all up to date stats for this weapon with mods factored in.
@export var effect_source: EffectSource = EffectSource.new() ## The resource that defines what happens to the entity that is hit by this weapon. Includes things like damage and status effects.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var pullout_delay: float = 0 ## How long after equipping must we wait before we can use this weapon.

# Unique Properties #
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NO_EDITOR) var time_last_equipped: float = 0 ## The time that this weapon was last equipped.
