extends Weapon
class_name ProjectileWeapon
## Base class for all weapons that spawn any sort of projectile.

@onready var anim_player: AnimationPlayer = $AnimationPlayer ## The animation controller for this projectile weapon.
@onready var proj_origin: Marker2D = $ProjectileOrigin ## The point at which projectiles should spawn from.


## Overrides the parent method to specify what to do on use while equipped.
func activate() -> void:
	_fire()

func _fire() -> void:
	stats.effect_source.source_entity = source_entity

	var proj: Projectile = Projectile.spawn(stats, proj_origin.global_position, global_rotation)
	GlobalData.world_root.add_child(proj)

	GlobalData.player_camera.start_shake(stats.firing_cam_shake_str, stats.firing_cam_shake_dur)
	GlobalData.player_camera.start_freeze(stats.firing_cam_freeze_str, stats.firing_cam_freeze_dur)
	if stats.firing_sound != "": AudioManager.play_sound(stats.firing_sound, AudioManager.SoundType.SFX_2D, global_position)

	anim_player.speed_scale = 1.0 / stats.auto_fire_delay
	anim_player.play("fire")
