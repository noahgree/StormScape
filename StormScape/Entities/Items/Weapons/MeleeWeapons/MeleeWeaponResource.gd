extends WeaponResource
class_name MeleeWeaponResource
## The resource that defines all stats for a melee weapon. Passing this around essentially passes the weapon around.

enum MeleeWeaponType { ## The kinds of melee weapons.
	TOOL, PHYSICAL, COMBAT
}
enum AmmoType { ## The kinds of ammo to consume on attack.
	NONE, STAMINA, MAGIC, ION_CHARGE
}

@export_group("Melee Weapon Details")
@export var melee_weapon_type: MeleeWeaponType = MeleeWeaponType.TOOL ## The kind of melee weapon this is.
@export var ammo_type: AmmoType = AmmoType.NONE ## The kind of ammo to consume on attack.
@export var ammo_cost: float = 3.0 ## The amount of whatever ammo type is selected to consume per attack.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var cooldown: float = 1.0 ## The minimum time between usages.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var use_speed: float = 1.0 ## How long one swing, punch, or other kind of "usage" of this melee item takes.
@export var swing_angle: int = 125 ## How wide of an angle to swing when triggered.

@export_subgroup("Usage FX")
@export var usage_vfx_scene: PackedScene = null ## The scene that spawns and controls usage vfx.
@export var usage_sound: String = "" ## The sound to play when using the item.
@export var cooldown_sound: String = "" ## The sound to play when on cooldown.
