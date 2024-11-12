extends WeaponResource
class_name ProjWeaponResource
## The resource that defines all stats for a projectile weapon. Passing this around essentially passes the weapon around.

enum ProjWeaponType { ## The kinds of projectile weapons.
	PISTOL, SHOTGUN, SMG, SNIPER, RIFLE, EXPLOSIVE, PRIMITIVE, MAGICAL, SPECIAL
}
enum AmmoType { ## The kinds of ammo to consume on firing.
	LIGHT, MEDIUM, HEAVY, SHELL, ROCKET, MAGIC, CHARGE
}

@export_group("Projectile Weapon Details")
@export var proj_weapon_type: ProjWeaponType = ProjWeaponType.PISTOL ## The kind of projectile weapon this is.
@export var projectile: PackedScene ## The projectile scene to spawn on firing.
@export var projectile_data: ProjectileResource ## The logic passed to the projectile for how to behave.
@export var ammo_type: AmmoType = AmmoType.LIGHT ## The kind of ammo to consume on firing.
@export var mag_size: int = 30  ## Number of attack executions that can happen before a reload is needed.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var reload_time: float = 1.0 ## How long it takes to reload an entire mag.
@export_enum("Magazine", "Single") var reload_type: String = "Magazine" ## Whether to reload over time or all at once at the end.
@export_enum("Semi Auto", "Auto") var firing_mode: String = "Semi Auto" ## Whether the weapon should fire projectiles once per click or allow holding down for auto firing logic.
@export var uses_bloom: bool = false ## Whether to use blooming logic when firing or just aim straight on.
@export var bloom_curve: Curve = Curve.new() ## How to apply blooming logic over time.
@export var recoil_curve: Curve = Curve.new() ## How to apply recoil logic over time.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var auto_fire_delay: float = 0.15 ## Time between fully auto projectile emmision. Also the minimum time that must elapse between clicks if set to semi-auto.

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
@export var cam_shake_strength: float = 0.0 ## How strong the camera should shake when firing.
@export var cam_shake_duration: float = 0.0 ## How long the camera shake when firing should take to decay.
@export var cam_freeze_strength: float = 0.0 ## How strong the camera should freeze when firing.
@export var cam_freeze_duration: float = 0.0 ## How long the camera freeze when firing should take to decay.
@export var firing_vfx_scene: PackedScene = null ## The scene that spawns and controls vfx when firing.
@export var firing_sound: String = "" ## The sound to play when firing.
@export var reload_sound: String = "" ## The sound to play when reloading.
