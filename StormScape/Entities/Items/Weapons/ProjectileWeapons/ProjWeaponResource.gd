extends WeaponResource
class_name ProjWeaponResource
## The resource that defines all stats for a projectile weapon. Passing this around essentially passes the weapon around.

enum ProjWeaponType { ## The kinds of projectile weapons.
	PISTOL, SHOTGUN, SMG, SNIPER, RIFLE, EXPLOSIVE, PRIMITIVE, MAGICAL, THROWABLE, SPECIAL
}

@export_group("General")
@export var proj_weapon_type: ProjWeaponType = ProjWeaponType.PISTOL ## The kind of projectile weapon this is.
@export_enum("Semi Auto", "Auto", "Charge") var firing_mode: String = "Semi Auto" ## Whether the weapon should fire projectiles once per click or allow holding down for auto firing logic.
@export_subgroup("Hitscanning")
@export var use_hitscan: bool = false ## Whether to use hitscan firing and spawn the hitscan scene instead of the main projectile.
@export var allow_hitscan_holding: bool = true ## Whether to keep the hitscan on and continue to consume ammo while the trigger is held.
@export_group("Normal Firing Details")
@export_range(0, 30, 0.01, "hide_slider", "or_greater", "suffix:seconds") var fire_cooldown: float = 0.05 ## Time between fully auto projectile emmision. Also the minimum time that must elapse between clicks if set to semi-auto.
@export_range(0.03, 10, 0.01, "hide_slider", "or_greater", "suffix:seconds") var firing_duration: float = 0.1 ## How long it takes to release the projectile after initiating the action. Determines the animation speed as well. Set to 0 by default.
@export_subgroup("Entity Effects")
@export var post_firing_effect: StatusEffect = null ## The status effect to apply to the source entity after firing.
@export_subgroup("Firing FX")
@export_range(0, 30, 0.01) var firing_cam_shake_str: float = 0.0 ## How strong the camera should shake when firing.
@export_range(0, 2, 0.01) var firing_cam_shake_dur: float = 0.0 ## How long the camera shake when firing should take to decay.
@export_range(0, 1, 0.01) var firing_cam_freeze_mult: float = 1.0 ## How strong the camera should freeze when firing.
@export_range(0, 1, 0.01) var firing_cam_freeze_dur: float = 0.0 ## How long the camera freeze when firing should take to decay.
@export var firing_vfx_scene: PackedScene = null ## The scene that spawns and controls vfx when firing.
@export var firing_sound: String = "" ## The sound to play when firing.

@export_group("Charge Firing Details")
@export_range(0.2, 10, 0.01, "hide_slider", "or_greater", "suffix:seconds") var min_charge_time: float = 1 ## How long must the activation be held down before releasing the charge shot.
@export_range(0, 100, 0.01, "hide_slider", "or_greater", "suffix:seconds") var charge_fire_cooldown: float = 0.5 ## How long after a charge shot must we wait before being able to fire again.
@export_range(0.03, 10, 0.01, "hide_slider", "or_greater", "suffix:seconds") var charge_firing_duration: float = 0.1 ## How long it takes to release the projectile after initiating the charge firing action. Determines the animation speed as well. Set to 0 by default.
@export var ammo_use_per_charge: int = 3 ## How much ammo to consume on charge shots. Overrides all burst and barrage consumption to consume this amount no matter what.
@export var charge_bloom_mult: float = 5.0 ## How much more should one charge shot count towards current bloom.
@export_subgroup("Entity Effects")
@export var charging_stat_effect: StatusEffect = null ## A status effect to apply to the entity while charging. Typically to slow them.
@export var post_chg_shot_effect: StatusEffect = null ## The status effect to apply to the source entity after a charge shot.
@export_subgroup("Firing FX")
@export var charge_cam_fx_mult: float = 1.0 ## How much to multiply the cam fx by when doing a charge shot.
@export var charge_firing_sound: String = "" ## The sound to play when charge firing.
@export var charging_sound: String = "" ## The sound to play when charging.

@export_group("Effect & Logic Resources")
@export_subgroup("Normal Firing")
@export var projectile_scn: PackedScene ## The projectile scene to spawn on firing.
@export var projectile_logic: ProjectileResource = ProjectileResource.new() ## The logic passed to the projectile for how to behave.
@export var hitscan_logic: HitscanResource ## The resource containing information on how to fire and operate the hitscan.
@export_subgroup("Charge Firing")
@export var charge_projectile_scn: PackedScene = null ## Overrides the normal projectile scene for charge shots.
@export var charge_projectile_logic: ProjectileResource = null ## Overrides the normal projectile data for charge shots.
@export var charge_hitscan_logic: HitscanResource ## The resource containing information on how to fire and operate the hitscan when charged.

@export_group("Ammo & Reloading")
@export var ammo_type: GlobalData.ProjAmmoType = GlobalData.ProjAmmoType.LIGHT ## The kind of ammo to consume on use.
@export var mag_size: int = 30  ## Number of normal attack executions that can happen before a reload is needed.
@export_enum("Magazine", "Single") var reload_type: String = "Magazine" ## Whether to reload over time or all at once at the end.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var mag_reload_time: float = 1.0 ## How long it takes to reload an entire mag.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var single_proj_reload_time: float = 0.25 ## How long it takes to reload a single projectile if the reload type is set to "single".
@export var stamina_use_per_proj: float = 0.5 ## How much stamina is needed per projectile when stamina is the ammo type.
@export_subgroup("Reloading FX")
@export var mag_reload_sound: String = "" ## The sound to play when reloading a whole mag.
@export var proj_reload_sound: String = "" ## The sound to play when reloading a single projectile.
@export var empty_mag_sound: String = "" ## The sound to play when trying to fire with no ammo left.

@export_group("Blooming Logic")
@export_custom(PROPERTY_HINT_NONE, "suffix:degrees") var max_bloom: float = 0 ## The max amount of bloom the weapon can have.
@export var bloom_curve: Curve = Curve.new() ## How to apply blooming logic over time.
@export var bloom_increase_rate: Curve = Curve.new() ## How much bloom to add per shot based on current bloom.
@export var bloom_decrease_rate: Curve = Curve.new() ## How much bloom to take away per second based on current bloom.

@export_group("Auto Fire Warmup Logic")
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var fully_cool_delay_time: float = 0 ## At the lowest warmth level, how long must we wait before a shot fires.
@export var warmth_delay_curve: Curve = Curve.new() ## A curve for how long the time between shots should be based on how much we have been firing recently.
@export var warmth_increase_rate: Curve = Curve.new() ## A curve for determining how much warmth to add depending on current warmth.
@export var warmth_decrease_rate: Curve = Curve.new() ## A curve for determining how much warmth to remove depending on current warmth.

@export_group("Burst Logic")
@export_range(1, 100, 1) var projectiles_per_fire: int = 1 ## How many projectiles are emitted per burst execution.
@export var use_ammo_per_burst_proj: bool = true ## Whether to consume ammo per projectile emmitted or consume 1 per full burst.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var burst_bullet_delay: float = 0.1 ## Time between burst shots after execute.
@export var add_bloom_per_burst_shot: bool = true ## Whether or not each bullet from a burst fire increases bloom individually.

@export_group("Barrage Logic")
@export var barrage_count: int = 1 ## Number of projectiles fired at 'angular-spread' degrees apart for each execute. Only applies when angular spread is greater than 0.
@export_range(0, 360, 0.1, "suffix:degrees") var angular_spread: float = 25 ## Angular spread of barrage projectiles in degrees.


# Unique Properties #
@export_storage var current_warmth_level: float = 0 ## The current warm-up level for this weapon.
@export_storage var current_bloom_level: float = 0 ## The current bloom level for this weapon.
@export_storage var ammo_in_mag: int = -1: ## The current ammo in the mag.
	set(new_ammo_amount):
		ammo_in_mag = new_ammo_amount
		if DebugFlags.PrintFlags.ammo_updates and self.name != "":
			print_rich("(" + str(self) + ") [b]AMMO[/b]: [color=cyan]" + str(ammo_in_mag) + "[/color]")
