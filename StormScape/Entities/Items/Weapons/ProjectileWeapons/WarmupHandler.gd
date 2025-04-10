extends Node
class_name WarmupHandler

signal warmup_finished

var weapon: ProjectileWeapon
var warmup_timer: Timer = TimerHelpers.create_one_shot_timer(weapon, 1, _on_warmup_timer_timeout)


func initialize(new_weapon: ProjectileWeapon) -> void:
	weapon = new_weapon

func needs_warmup() -> bool:
	return weapon.stats.s_mods.get_stat("initial_fire_rate_delay") > 0

func start_warmup() -> void:
	var warmup_time: float = weapon.stats.s_mods.get_stat("initial_fire_rate_delay")
	if warmup_time <= 0:
		warmup_finished.emit()
		return

	var anim_player: AnimationPlayer = weapon.anim_player
	if anim_player.has_animation("warmup"):
		anim_player.speed_scale = 1.0 / warmup_time
		anim_player.play("warmup")

	warmup_timer.start(warmup_time)

func _on_warmup_timer_timeout() -> void:
	warmup_finished.emit()
