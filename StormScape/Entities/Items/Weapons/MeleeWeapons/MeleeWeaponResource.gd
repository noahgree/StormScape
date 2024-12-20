extends WeaponResource
class_name MeleeWeaponResource
## The resource that defines all stats for a melee weapon. Passing this around essentially passes the weapon around.

enum MeleeWeaponType { ## The kinds of melee weapons.
	TOOL, PHYSICAL, COMBAT
}

@export_group("General")
@export var melee_weapon_type: MeleeWeaponType = MeleeWeaponType.TOOL ## The kind of melee weapon this is.
@export_group("Normal Use Details")
@export var stamina_cost: float = 3.0 ## The amount of stamina to consume per use.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var cooldown: float = 0.5 ## The minimum time between usages.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var use_speed: float = 0.25 ## How long one swing, punch, or other kind of "usage" of this melee item takes.
@export var swing_angle: int = 125 ## How wide of an angle to swing when triggered.
@export_subgroup("Entity Effects")
@export var use_start_effect: StatusEffect ## The status effect to apply to the source entity at the start of use.
@export var post_use_effect: StatusEffect ## The status effect to apply to the source entity after use.
@export_subgroup("Usage FX")
@export var use_vfx_scene: PackedScene = null ## The scene that spawns and controls usage vfx.
@export var use_sound: String = "" ## The sound to play when using the item.

@export_group("Charge Use Details")
@export var can_do_charge_use: bool = false ## Whether this weapon has a charge use method or not.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var min_charge_time: float = 2 ## How long must the activation be held down before releasing the charge.
@export var auto_do_charge_use: bool = false ## Whether to auto start a charge use when min_charge_time is reached.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var charge_use_cooldown: float = 1.5 ## How long after a charge use must we wait before being able to do it again.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var charge_use_speed: float = 0.75 ## How long one charge use takes to execute.
@export var charge_swing_angle: int = 720 ## How wide of an angle to swing when triggered with charge.
@export var charge_stamina_cost: int = 25 ## How much stamina to consume on charge usages. Overrides standard stamina use.
@export_subgroup("Entity Effects")
@export var chg_use_start_effect: StatusEffect ## The status effect to apply to the source entity at the start of a charge use.
@export var post_chg_use_effect: StatusEffect ## The status effect to apply to the source entity after charge use.
@export_subgroup("Usage FX")
@export var charge_use_vfx_scene: PackedScene = null ## The scene that spawns and controls usage vfx.
@export var charge_use_sound: String = "" ## The sound to play when a charge use happens.
