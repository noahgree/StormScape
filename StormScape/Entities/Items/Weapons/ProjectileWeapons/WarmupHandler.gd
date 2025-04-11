extends Node
class_name WarmupHandler

signal warmup_finished

var weapon: ProjectileWeapon
var anim_player: AnimationPlayer
var auto_decrementer: AutoDecrementer
var warmup_timer: Timer


func initialize(parent_weapon: ProjectileWeapon) -> void:
	weapon = parent_weapon
	anim_player = weapon.anim_player
	auto_decrementer = weapon.source_entity.inv.auto_decrementer
	warmup_timer = TimerHelpers.create_one_shot_timer(weapon, 1, _on_warmup_timer_timeout)

func needs_warmup() -> bool:
	return weapon.stats.s_mods.get_stat("initial_fire_rate_delay") > 0

func start_warmup() -> void:
	var warmup_time: float = _get_warmup_delay()
	if warmup_time <= 0:
		warmup_finished.emit()
		return

	if anim_player.has_animation("warmup"):
		anim_player.speed_scale = 1.0 / warmup_time
		anim_player.play("warmup")

	warmup_timer.start(warmup_time)

## Increases current warmup level via sampling the increase curve using the current warmup.
func add_warmup() -> void:
	if weapon.stats.s_mods.get_stat("initial_fire_rate_delay") <= 0:
		return
	if weapon.stats.firing_mode != ProjWeaponResource.FiringType.AUTO:
		return

	var current_warmup: float = auto_decrementer.get_warmup(str(weapon.stats.session_uid))
	var sampled_point: float = weapon.stats.warmup_increase_rate.sample_baked(current_warmup)
	var increase_rate_multiplier: float = weapon.stats.s_mods.get_stat("warmup_increase_rate_multiplier")
	var increase_amount: float = max(0.01, sampled_point * increase_rate_multiplier)
	auto_decrementer.add_warmup(
		str(weapon.stats.session_uid),
		min(1, increase_amount),
		weapon.stats.warmup_decrease_rate,
		weapon.stats.warmup_decrease_delay
		)

## Grabs a point from the warmup curve based on current warmup level given by the auto decrementer.
func _get_warmup_delay() -> float:
	var current_warmup: float = auto_decrementer.get_warmup(str(weapon.stats.session_uid))
	if current_warmup > 0:
		var sampled_delay_multiplier: float = weapon.stats.warmup_delay_curve.sample_baked(current_warmup)
		var max_delay: float = weapon.stats.s_mods.get_stat("initial_fire_rate_delay")
		return sampled_delay_multiplier * max_delay
	else:
		return 0

func _on_warmup_timer_timeout() -> void:
	if anim_player.is_playing() and anim_player.current_animation == "warmup":
		await anim_player.animation_finished

	warmup_finished.emit()
