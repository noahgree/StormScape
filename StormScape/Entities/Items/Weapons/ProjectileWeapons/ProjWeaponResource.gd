@icon("res://Utilities/Debug/EditorIcons/proj_weapon_resource.png")
extends WeaponResource
class_name ProjWeaponResource
## The resource that defines all stats for a projectile weapon. Passing this around essentially passes the weapon around.

enum ProjWeaponType { ## The kinds of projectile weapons.
	PISTOL, SHOTGUN, SMG, SNIPER, RIFLE, EXPLOSIVE, PRIMITIVE, MAGICAL, THROWABLE, SPECIAL
}
enum ProjAmmoType { ## The types of projectile ammo.
	NONE, SELF, LIGHT, MEDIUM, HEAVY, SHELL, ROCKET, MAGIC, ION_CHARGE, STAMINA, CHARGES
}

@export_group("General")
@export var proj_weapon_type: ProjWeaponType = ProjWeaponType.PISTOL ## The kind of projectile weapon this is.
@export_enum("Semi Auto", "Auto", "Charge") var firing_mode: String = "Semi Auto" ## Whether the weapon should fire projectiles once per click or allow holding down for auto firing logic.
@export var projectile_scn: PackedScene ## The projectile scene to spawn on firing.
@export_subgroup("Hitscanning")
@export var use_hitscan: bool = false ## Whether to use hitscan firing and spawn the hitscan scene instead of the main projectile.
@export var allow_hitscan_holding: bool = true ## Whether to keep the hitscan on and continue to consume ammo while the trigger is held.
@export_group("Firing Details")
@export_range(0, 10, 0.01, "hide_slider", "or_greater", "suffix:seconds") var firing_duration: float = 0.1 ## How long it takes to release the projectile after initiating the action. Determines the animation speed as well. Set to 0 by default.
@export_range(0, 30, 0.01, "hide_slider", "or_greater", "suffix:seconds") var fire_cooldown: float = 0.05 ## Time between fully auto projectile emmision. Also the minimum time that must elapse between clicks if set to semi-auto.
@export_range(0.1, 10, 0.01, "hide_slider", "or_greater", "suffix:seconds") var min_charge_time: float = 1 ## How long must the activation be held down before releasing the charge shot. [b]Only used when firing mode is set to "Charge"[/b].
@export_subgroup("Animation")
@export var one_frame_per_fire: bool = false ## When true, the sprite frames will only advance one frame when firing normally.
@export var override_anim_dur: float = 0 ## When greater than 0, the fire animation will run at this override time per loop.
@export var anim_speed_mult: float = 1.0 ## Multiplies the speed scale of the firing animation.
@export var has_post_fire_anim: bool = false ## When true, an animation will play for the specified duration of the cooldown after firing, unless a custom time is given below.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var post_fire_anim_delay: float = 0 ## The delay after the firing duration ends before starting the post-fire animation if one exists.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var post_fire_anim_dur: float = 0 ## The override time for how long the animation should be that plays after firing. Anything greater than 0 activates this override.
@export_subgroup("Entity Effects")
@export var post_firing_effect: StatusEffect = null ## The status effect to apply to the source entity after firing.
@export var charging_stat_effect: StatusEffect = null ## A status effect to apply to the entity while charging. Typically to slow them.
@export_subgroup("Firing FX")
@export_range(0, 30, 0.01) var firing_cam_shake_str: float = 0.0 ## How strong the camera should shake when firing.
@export_range(0, 2, 0.01) var firing_cam_shake_dur: float = 0.0 ## How long the camera shake when firing should take to decay.
@export_range(0, 1, 0.01) var firing_cam_freeze_mult: float = 1.0 ## How strong the camera should freeze when firing.
@export_range(0, 1, 0.01) var firing_cam_freeze_dur: float = 0.0 ## How long the camera freeze when firing should take to decay.
@export var muzzle_flash: Texture2D = null ## The texture to show as the muzzle flash when firing.
@export var firing_sound: String = "" ## The sound to play when firing.
@export var post_fire_sound: String = "" ## The sound to play after firing before the cooldown ends.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var post_fire_sound_delay: float = 0 ## When greater than 0, the post-firing sound waits this delay after the firing duration ends before playing.
@export var charging_sound: String = "" ## The sound to play when charging.

@export_group("Effect & Logic Resources")
@export var projectile_logic: ProjectileResource = ProjectileResource.new() ## The logic passed to the projectile for how to behave.
@export var hitscan_logic: HitscanResource ## The resource containing information on how to fire and operate the hitscan.
@export var effect_source: EffectSource ## The resource that defines what happens to the entity that is hit by this weapon. Includes things like damage and status effects.

@export_group("Ammo & Reloading")
@export var ammo_type: ProjAmmoType = ProjAmmoType.LIGHT ## The kind of ammo to consume on use.
@export var mag_size: int = 30  ## Number of normal attack executions that can happen before a reload is needed.
@export_enum("Magazine", "Single") var reload_type: String = "Magazine" ## Whether to reload over time or all at once at the end.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var mag_reload_time: float = 1.0 ## How long it takes to reload an entire mag.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var single_proj_reload_time: float = 0.25 ## How long it takes to reload a single projectile if the reload type is set to "single".
@export var single_reload_quantity: int = 1 ## How much to add to the mag when the single proj timer elapses each time.
@export var stamina_use_per_proj: float = 0.5 ## How much stamina is needed per projectile when stamina is the ammo type.
@export var dont_consume_ammo: bool = false ## When true, this acts like infinite ammo where the weapon doesn't decrement the ammo in mag upon firing.
@export_subgroup("Recharging")
@export var auto_ammo_interval: float = 0 ## How long it takes to recouperate a single ammo when given automatically. Most useful when using the "Charges" ammo type but can also be used to simply grant ammo over time. Anything above 0 activates this feature. Only works with consumable ammo types, meaning not "Self" or "Stamina".
@export var auto_ammo_count: int = 1 ## How much ammo to grant after the interval is up.
@export_range(0.05, 1000, 0.01, "suffix:seconds", "hide_slider", "or_greater") var auto_ammo_delay: float = 0.5 ## How long after firing must we wait before the grant interval countdown starts.
@export var recharge_uses_inv: bool = false ## When true, the ammo will recharge by consuming ammo from the inventory. When none is left, the recharges will stop.
@export_subgroup("UI")
@export var hide_ammo_ui: bool = false ## When a player uses this, should the ammo UI be hidden.
@export var hide_reload_ui: bool = false ## When a player uses this, should the reloading UI be hidden.
@export_subgroup("Reloading FX")
@export var mag_reload_sound: String = "" ## The sound to play when reloading a whole mag.
@export var proj_reload_sound: String = "" ## The sound to play when reloading a single projectile.
@export var empty_mag_sound: String = "" ## The sound to play when trying to fire with no ammo left.

@export_group("Blooming Logic")
@export_custom(PROPERTY_HINT_NONE, "suffix:degrees") var max_bloom: float = 0 ## The max amount of bloom the weapon can have.
@export var bloom_curve: Curve ## X value is bloom amount (0-1), Y value is multiplier on max_bloom.
@export var bloom_increase_rate: Curve ## How much bloom to add per shot based on current bloom.
@export var bloom_decrease_rate: Curve ## How much bloom to take away per second based on current bloom.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var bloom_decrease_delay: float = 1.0 ## How long after the last bloom increase must we wait before starting to decrease it.

@export_group("Warmup Logic")
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var initial_fire_rate_delay: float = 0 ## At the lowest warmup level, how long must we wait before a shot fires. This only works when the firing mode is set to "Auto".
@export var warmup_delay_curve: Curve ## X value is warmup amount (0-1), Y value is multiplier on initial_fire_rate_delay.
@export var warmup_increase_rate: Curve ## A curve for determining how much warmth to add per shot depending on current warmup.
@export var warmup_decrease_rate: Curve ## How much warmup do we remove per second based on current warmup.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var warmup_decrease_delay: float = 0.75 ## How long after the last warmup increase must we wait before starting to decrease it.

@export_group("Overheating Logic")
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var overheat_penalty: float = 0 ## When we reach max overheating, how long is the penalty before being able to use the weapon again. Anything above 0 activates this feature.
@export var overheat_inc_rate: Curve ## X value is overheat amount (0-1), Y value is how much we add to overheat amount per shot.
@export var overheat_dec_rate: Curve ## X value is overheat amount (0-1), Y value is how much we take away from overheat amount per second.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var overheat_dec_delay: float = 0.75
@export var overheated_sound: String = "" ## The sound to play when the weapon reaches max overheat.

@export_group("Burst Logic")
@export_range(1, 100, 1) var projectiles_per_fire: int = 1 ## How many projectiles are emitted per burst execution.
@export var use_ammo_per_burst_proj: bool = true ## Whether to consume ammo per projectile emmitted or consume 1 per full burst.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var burst_bullet_delay: float = 0.1 ## Time between burst shots after execute.
@export var add_bloom_per_burst_shot: bool = true ## Whether or not each bullet from a burst fire increases bloom individually.
@export var add_overheat_per_burst_shot: bool = true ## Whether or not each bullet from a burst fire increases overheat individually.

@export_group("Barrage Logic")
@export_range(1, 50, 1) var barrage_count: int = 1 ## Number of projectiles fired at 'angular-spread' degrees apart for each execute. Only applies when angular spread is greater than 0.
@export_range(0, 360, 0.1, "suffix:degrees") var angular_spread: float = 25 ## Angular spread of barrage projectiles in degrees.


# Unique Properties #
@export_storage var ammo_in_mag: int = -1: ## The current ammo in the mag.
	set(new_ammo_amount):
		ammo_in_mag = new_ammo_amount
		if DebugFlags.PrintFlags.ammo_updates and self.name != "":
			print_rich("(" + str(self) + ") [b]AMMO[/b]: [color=cyan]" + str(ammo_in_mag) + "[/color]")
