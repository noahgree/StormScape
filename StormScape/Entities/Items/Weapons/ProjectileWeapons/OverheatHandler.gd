extends Node
class_name OverheatHandler

signal max_overheat_reached
signal cooled_down

var weapon: ProjectileWeapon
var anim_player: AnimationPlayer
var source_entity: PhysicsBody2D
var auto_decrementer: AutoDecrementer
var is_tweening_overheat_overlays: bool = false ## Whether the post-overheat penalty tween is lowering the opacity of the overlays.


func initialize(new_weapon: ProjectileWeapon) -> void:
	weapon = new_weapon
	anim_player = weapon.anim_player
	source_entity = weapon.source_entity
	auto_decrementer = source_entity.inv.auto_decrementer

## Increases current overheat level via sampling the increase curve using the current overheat.
func add_overheat() -> void:
	if weapon.stats.s_mods.get_stat("overheat_penalty") <= 0:
		return

	var current_overheat: float = _get_overheat()
	var sampled_point: float = weapon.stats.overheat_inc_rate.sample_baked(current_overheat)
	var increase_rate_multiplier: float = weapon.stats.s_mods.get_stat("overheat_increase_rate_multiplier")
	var increase_amount: float = max(0.005, sampled_point * increase_rate_multiplier)
	auto_decrementer.add_overheat(
		str(weapon.stats.session_uid),
		min(1.0, increase_amount),
		weapon.stats.overheat_dec_rate,
		weapon.stats.overheat_dec_delay,
		_on_overheat_emptied
	)

	weapon.overhead_ui.overheat_bar.show()

	# If this recent addition of overheat puts us at max, trigger max overheat
	if _get_overheat() >= 1.0:
		max_overheat_reached.emit()
		_start_max_overheat_visuals(false)

func _get_overheat() -> float:
	return auto_decrementer.get_overheat(str(weapon.stats.session_uid))

func _on_overheat_emptied() -> void:
	if auto_decrementer.get_cooldown_source_title(weapon.stats.get_cooldown_id()) != "overheat_penalty":
		weapon.overhead_ui.overheat_bar.hide()

	if source_entity is Player:
		CursorManager.change_cursor_tint(Color.WHITE)

func _start_max_overheat_visuals(just_equipped: bool) -> void:
	weapon.add_cooldown(weapon.stats.s_mods.get_stat("overheat_penalty"), "overheat_penalty")
	AudioManager.play_2d(weapon.stats.overheated_sound, weapon.global_position)
	weapon.overheat_ui.update_visuals_for_max_overheat()

	# Activate overlays and tint the mouse cursor
	for overlay: TextureRect in weapon.overheat_overlays:
		overlay.self_modulate.a = 1.0
	if source_entity is Player:
		CursorManager.change_cursor_tint(Color.ORANGE_RED)

	# Set up and start smoke particles
	var smoke_particles: CPUParticles2D = source_entity.hands.smoke_particles
	smoke_particles.visible = true
	smoke_particles.emission_rect_extents = weapon.particle_emission_extents
	smoke_particles.position = weapon.particle_emission_origin + source_entity.hands.main_hand.position
	smoke_particles.emitting = true

	if anim_player.has_animation("overheat"):
		# Only want to resume looping animations if we just re-equipped. "0" is the enum val for no-looping.
		if just_equipped and anim_player.get_animation("overheat").loop_mode == 0:
			return
		anim_player.speed_scale = 1.0 / weapon.stats.overheat_anim_dur
		anim_player.play("overheat")

func update_overhead_ui_overheat_visuals() -> void:
	if not weapon.overhead_ui:
		return

	var current_overheat: float = auto_decrementer.get_overheat(str(weapon.stats.session_uid))
	if current_overheat <= 0:
		return

	if auto_decrementer.get_cooldown_source_title(weapon.stats.get_cooldown_id()) == "overheat_penalty":
		weapon.overhead_ui.update_overheat_progress(100)
	else:
		weapon.overhead_ui.update_overheat_progress(int(current_overheat * 100.0))
		if not is_tweening_overheat_overlays:
			for overlay: TextureRect in weapon.overheat_overlays:
				overlay.self_modulate.a = current_overheat * 0.5

func end_max_overheat_visuals() -> void:
	weapon.overhead_ui.update_visuals_for_max_overheat(true)
	source_entity.hands.smoke_particles.emitting = false

	var current_overheat: float = _get_overheat()
	if current_overheat == 0:
		weapon.overhead_ui.overheat_bar.hide()

	if not weapon.overheat_overlays.is_empty():
		is_tweening_overheat_overlays = true
		var tween: Tween = create_tween().parallel()

		for overlay: TextureRect in weapon.overheat_overlays:
			tween.tween_property(overlay, "self_modulate:a", current_overheat, 0.15)
		tween.tween_method(func(new_value: Color) -> void: CursorManager.change_cursor_tint(new_value), CursorManager.get_cursor_tint(), Color.WHITE, 0.15)
		tween.chain().tween_callback(func() -> void: is_tweening_overheat_overlays = false)

	if anim_player.current_animation == "overheat":
		weapon.reset_animation_state()
