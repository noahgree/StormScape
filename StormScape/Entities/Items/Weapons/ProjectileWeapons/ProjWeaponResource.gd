extends WeaponResource
class_name ProjWeaponResource
## The resource that defines all stats for a projectile weapon. Passing this around essentially passes the weapon around.

enum ProjWeaponType { ## The kinds of projectile weapons.
	PISTOL, SHOTGUN, SMG, SNIPER, RIFLE, EXPLOSIVE, PRIMITIVE, MAGICAL, SPECIAL
}
enum AmmoType { ## The kinds of ammo to consume on firing.
	NONE, LIGHT, MEDIUM, HEAVY, SHELL, ROCKET, MAGIC, ION_CHARGE
}

@export_group("Projectile Weapon Details")
@export var proj_weapon_type: ProjWeaponType = ProjWeaponType.PISTOL ## The kind of projectile weapon this is.
@export var projectile: PackedScene ## The projectile scene to spawn on firing.
@export var projectile_data: ProjectileResource = ProjectileResource.new() ## The logic passed to the projectile for how to behave.
@export var ammo_type: AmmoType = AmmoType.LIGHT ## The kind of ammo to consume on firing.
@export var mag_size: int = 30  ## Number of normal attack executions that can happen before a reload is needed.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var reload_time: float = 1.0 ## How long it takes to reload an entire mag.
@export_enum("Magazine", "Single") var reload_type: String = "Magazine" ## Whether to reload over time or all at once at the end.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var pullout_delay: float = 0 ## How long after equipping must we wait before we can use this weapon.
@export_enum("Semi Auto", "Auto", "Charge") var firing_mode: String = "Semi Auto" ## Whether the weapon should fire projectiles once per click or allow holding down for auto firing logic.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var initial_shot_delay: float = 0 ## How long after we initiate a firing should we wait before the shot releases.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var auto_fire_delay: float = 0.065 ## Time between fully auto projectile emmision. Also the minimum time that must elapse between clicks if set to semi-auto.

@export_subgroup("Blooming Logic")
@export_custom(PROPERTY_HINT_NONE, "suffix:degrees") var max_bloom: float = 0 ## The max amount of bloom the weapon can have.
@export var bloom_curve: Curve = Curve.new() ## How to apply blooming logic over time.
@export var bloom_increase_rate: Curve = Curve.new() ## How much bloom to add per shot based on current bloom.
@export var bloom_decrease_rate: Curve = Curve.new() ## How much bloom to take away per second based on current bloom.

@export_subgroup("Auto Fire Warmup Logic")
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var fully_cool_delay_time: float = 0 ## At the lowest warmth level, how long must we wait before a shot fires.
@export var warmth_delay_curve: Curve = Curve.new() ## A curve for how long the time between shots should be based on how much we have been firing recently.
@export var warmth_increase_rate: Curve = Curve.new() ## A curve for determining how much warmth to add depending on current warmth.
@export var warmth_decrease_rate: Curve = Curve.new() ## A curve for determining how much warmth to remove depending on current warmth.

@export_subgroup("Hold Charging Logic")
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var min_charge_time: float = 0 ## How long must the activation be held down before releasing the charge shot.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var charge_fire_cooldown: float = 0.5 ## How long after a charge shot must we wait before being able to fire again.
@export var ammo_use_per_charge: int = 3 ## How much ammo to consume on charge shots.
@export var charge_bloom_mult: float = 5.0 ## How much more should one charge shot count towards current bloom.
@export var charge_projectile: PackedScene = null ## Overrides the normal projectile scene for charge shots.
@export var charge_projectile_data: ProjectileResource = null ## Overrides the normal projectile data for charge shots.
@export var charge_effect_source: EffectSource = null ## Overrides the normal effect source for charge shots.
@export var has_charge_fire_anim: bool = false ## If false, we can duplicate the regular fire anim and keep the speed scale.
@export var charging_entity_speed_mult: float = 1.0 ## A multiplier for entity speed for when this is actively charging.

@export_subgroup("Burst Logic")
@export var projectiles_per_fire: int = 1 ## How many projectiles are emitted per burst execution.
@export var use_ammo_per_proj: bool = true ## Whether to consume ammo per projectile emmitted or consume 1 per full burst.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var burst_bullet_delay: float = 0.1 ## Time between burst shots after execute.
@export var add_bloom_per_burst_shot: bool = true ## Whether or not each bullet from a burst fire increases bloom individually.

@export_subgroup("Barrage Logic")
@export var barrage_count: int = 1 ## Number of projectiles fired at 'angular-spread' degrees apart for each execute. Only applies when angular spread is greater than 0.
@export_range(0, 360, 0.1, "suffix:degrees") var angluar_spread = 10 ## Angular spread of barrage projectiles in degrees.

@export_subgroup("FX")
@export var firing_cam_shake_str: float = 0.0 ## How strong the camera should shake when firing.
@export var firing_cam_shake_dur: float = 0.0 ## How long the camera shake when firing should take to decay.
@export var firing_cam_freeze_str: float = 0.0 ## How strong the camera should freeze when firing.
@export var firing_cam_freeze_dur: float = 0.0 ## How long the camera freeze when firing should take to decay.
@export var charge_cam_fx_mult: float = 1.0 ## How much to multiply the cam fx by when doing a charge shot.
@export var firing_vfx_scene: PackedScene = null ## The scene that spawns and controls vfx when firing.
@export var firing_sound: String = "" ## The sound to play when firing.
@export var charge_firing_sound: String = "" ## The sound to play when charge firing.
@export var reload_sound: String = "" ## The sound to play when reloading.

var auto_fire_delay_left: float = 0
var charge_fire_cooldown_left: float = 0
var current_warmth_level: float = 0
var current_bloom_level: float = 0
