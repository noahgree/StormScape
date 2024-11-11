extends WeaponResource
class_name ProjWeaponResource

enum ProjWeaponType {
	PISTOL, SHOTGUN, SMG, SNIPER, RIFLE, EXPLOSIVE, PRIMITIVE, MAGICAL, SPECIAL
}
enum AmmoType {
	LIGHT, MEDIUM, HEAVY, SHELL, ROCKET, MAGIC, CHARGE
}

@export_group("Projectile Weapon Details")
@export var proj_weapon_type: ProjWeaponType = ProjWeaponType.PISTOL
@export var projectile: PackedScene
@export var projectile_data: ProjectileResource
@export var ammo_type: AmmoType = AmmoType.LIGHT
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
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var burst_bullet_delay: float = 0.1 ## Time between burst shots after execute.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var auto_burst_delay: float = 0.3 ## Time between fully auto burst projectile emmisions.

@export_subgroup("Barrage Logic")
@export_range(0, 45, 0.1, "suffix:degrees") var angluar_spread = 0 ## Angular spread of barrage projectiles in degrees.
@export var barrage_count: int = 3 ## Number of projectiles fired at 'angular-spread' degrees apart for each execute. Only applies when angular spread is greater than 0.

@export_subgroup("FX")
@export var firing_fx: PackedScene = null
@export var firing_sound: String = ""
@export var reload_sound: String = ""
