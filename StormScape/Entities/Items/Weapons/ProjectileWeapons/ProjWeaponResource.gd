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
@export var projectile_data: ProjectileResource ## The logic passed to the projectile for how to behave.
@export var ammo_type: AmmoType = AmmoType.LIGHT ## The kind of ammo to consume on firing.
@export var mag_size: int = 30  ## Number of normal attack executions that can happen before a reload is needed.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var reload_time: float = 1.0 ## How long it takes to reload an entire mag.
@export_enum("Magazine", "Single") var reload_type: String = "Magazine" ## Whether to reload over time or all at once at the end.
@export_enum("Semi Auto", "Auto", "Charge") var firing_mode: String = "Semi Auto" ## Whether the weapon should fire projectiles once per click or allow holding down for auto firing logic.
@export var uses_bloom: bool = false ## Whether to use blooming logic when firing or just aim straight on.
@export var bloom_curve: Curve = Curve.new() ## How to apply blooming logic over time.
@export var recoil_curve: Curve = Curve.new() ## How to apply recoil logic over time.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var auto_fire_delay: float = 0.15 ## Time between fully auto projectile emmision. Also the minimum time that must elapse between clicks if set to semi-auto.

@export_subgroup("Charging Logic")
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var min_charge_time: float = 0.0 ## How long the charge needs to be held before firing.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var charge_fire_cooldown: float = 3 ## How long after a charge shot must we wait before being able to fire again.
@export var has_charge_fire_anim: bool = false ## If false, we can duplicate the regular fire anim and keep the speed scale.
@export var ammo_use_per_charge: int = 3 ## How much ammo to consume on charge shots.
@export var charge_projectile: PackedScene = null ## Overrides the normal projectile scene for charge shots.
@export var charge_projectile_data: ProjectileResource = null ## Overrides the normal projectile data for charge shots.
@export var charge_effect_source: EffectSource = null ## Overrides the normal effect source for charge shots.
@export var charging_entity_speed_mult: float = 1.0 ## A multiplier for entity speed for when this is actively charging.

@export_subgroup("Burst Logic")
@export var num_of_bursts: int = 0 ## How many bursts of fire emit from one execute.
@export var projectiles_per_burst: int = 3 ## How many projectiles are emitted per burst execution.
@export var use_ammo_per_proj: bool = true ## Whether to consume ammo per projectile emmitted or consume 1 per full burst.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var burst_bullet_delay: float = 0.1 ## Time between burst shots after execute.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var auto_burst_delay: float = 0.3 ## Time between fully auto burst projectile emmisions.

@export_subgroup("Barrage Logic")
@export_range(0, 45, 0.1, "suffix:degrees") var angluar_spread = 0 ## Angular spread of barrage projectiles in degrees.
@export var barrage_count: int = 3 ## Number of projectiles fired at 'angular-spread' degrees apart for each execute. Only applies when angular spread is greater than 0.

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


func _init() -> void:
	if charge_effect_source == null:
		charge_effect_source = effect_source
	if charge_projectile_data == null:
		charge_projectile_data = projectile_data
	if charge_projectile == null:
		charge_projectile = projectile
