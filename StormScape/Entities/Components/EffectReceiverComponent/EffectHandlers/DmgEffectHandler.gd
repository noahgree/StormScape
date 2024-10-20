extends Node
## A handler for using the data provided in the effect source to apply damage in different ways.

@onready var health_component: HealthComponent = get_parent().health_component


func _get_dmg_after_crit_then_armor(effect_source: EffectSource) -> int:
	var should_crit: bool = randf() < effect_source.crit_chance
	var dmg_after_crit: int = effect_source.base_damage
	if should_crit: 
		dmg_after_crit = round(dmg_after_crit * effect_source.crit_multiplier)
	
	var armor_block_percent: float = max(0, health_component.armor - effect_source.armor_penetration)
	var new_damage: int = max(0, round(dmg_after_crit * (1 - armor_block_percent)))
	return new_damage

func handle_instant_dmg(effect_source: EffectSource) -> void:
	var dmg_after_crit_then_armor: int = _get_dmg_after_crit_then_armor(effect_source)
	_send_handled_dmg(effect_source.dmg_affected_stats, dmg_after_crit_then_armor)

func handle_over_time_dmg(effect_source: EffectSource) -> void:
	var dmg_after_crit_then_armor: int = _get_dmg_after_crit_then_armor(effect_source)
	
	var dot_timer: Timer = Timer.new()
	dot_timer.set_meta("effect_source", effect_source)
	dot_timer.set_meta("ticks_completed", 0)
	dot_timer.wait_time = max(0.001, (effect_source.dot_total_length / effect_source.dot_number_of_ticks))
	dot_timer.one_shot = false
	
	dot_timer.timeout.connect(func(): _on_dot_timer_timeout(dot_timer))
	add_child(dot_timer)
	if effect_source.dot_delay_time > 0:
		var delay_timer: Timer = Timer.new()
		delay_timer.one_shot = true
		delay_timer.wait_time = effect_source.dot_delay_time
		delay_timer.timeout.connect(dot_timer.start)
		delay_timer.timeout.connect(delay_timer.queue_free)
		add_child(delay_timer)
		delay_timer.start()
	else:
		dot_timer.start()


func _on_dot_timer_timeout(dot_timer: Timer) -> void:
	var effect_source: EffectSource = dot_timer.get_meta("effect_source")
	var ticks_completed: int = dot_timer.get_meta("ticks_completed")
	var max_ticks: int = effect_source.dot_number_of_ticks
	if ticks_completed < max_ticks:
		var damage: int = _get_dmg_after_crit_then_armor(effect_source)
		var dmg_affected_stats: EffectSource.DmgAffectedStats = effect_source.dmg_affected_stats
		_send_handled_dmg(dmg_affected_stats, damage)
		dot_timer.set_meta("ticks_completed", ticks_completed + 1)
		
		if max_ticks == 1:
			dot_timer.stop()
			dot_timer.queue_free()
	else:
		dot_timer.stop()
		dot_timer.queue_free()

func _send_handled_dmg(dmg_affected_stats: EffectSource.DmgAffectedStats, handled_amount: int) -> void:
	match dmg_affected_stats:
		EffectSource.DmgAffectedStats.HEALTH_ONLY:
			health_component.damage_health(handled_amount)
		EffectSource.DmgAffectedStats.SHIELD_ONLY:
			health_component.damage_shield(handled_amount)
		EffectSource.DmgAffectedStats.SHIELD_THEN_HEALTH:
			health_component.damage_shield_then_health(handled_amount)
		EffectSource.DmgAffectedStats.SIMULTANEOUS:
			health_component.damage_shield(handled_amount)
			health_component.damage_health(handled_amount)
