extends ItemResource
class_name WeaponResource

@export_group("General Weapon Details")
@export var stats: StatModsCacheResource = StatModsCacheResource.new() ## The cache of all up to date stats for this weapon with mods factored in.
@export var effect_source: EffectSource = EffectSource.new() ## The resource that defines what happens to the entity that is hit by this weapon. Includes things like damage and status effects.
