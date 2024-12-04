@icon("res://Utilities/Debug/EditorIcons/status_effect_manager.svg")
extends Node2D
class_name StatusEffectManager
## The component that holds the stats and logic for how the entity should receive effects.
##
## This handles things like fire & poison damage not taking into account armor, etc.

@export var effect_receiver: EffectReceiverComponent ## The effect receiver that sends status effects to this manager to be cached and handled.
@export var stats_ui: Control ## The UI to update upon receiving effects that may update it.
@export_subgroup("Debug")
@export var print_effect_updates: bool = false ## Whether to print when this entity has status effects added and removed.

var current_effects: Dictionary = {} ## Keys are general status effect titles like "Poison", and values are the effect resources themselves.
var effect_timers: Dictionary = {} ## Holds references to all timers currently tracking active status effects.
var saved_times_left: Dictionary = {} ## Holds time remaining for status effects that were applied during a game save.


#region Save & Load
## We save every effect timer that is in progress into the saved_times_left.
func _on_save_game(_save_data: Array[SaveData]) -> void:
	for effect_name: String in effect_timers.keys():
		saved_times_left[effect_name] = effect_timers.get(effect_name, 0.001).time_left

## We must clear out any existing effect timers and remove all exiting status effects.
func _on_before_load_game() -> void:
	effect_timers = {}
	for status_effect: String in current_effects.keys():
		request_effect_removal(status_effect)
	for child: Variant in get_children():
		if child is Timer:
			child.queue_free()

## For every effect that was saved into current_effects, we duplicate a clean instance, clear out dot/hot resources,
## set the time remaining on the effect from when it got saved, and add the effect back.
func _on_load_game() -> void:
	for status_effect: StatusEffect in current_effects.values():
		var clean_status_effect: StatusEffect = status_effect.duplicate()
		var effect_delay: float = 0

		if "dot_resource" in clean_status_effect:
			clean_status_effect.dot_resource = null
			effect_delay = status_effect.dot_resource.delay_time
		if "hot_resource" in clean_status_effect:
			clean_status_effect.hot_resource = null
			effect_delay = status_effect.hot_resource.delay_time

		clean_status_effect.mod_time = saved_times_left.get(status_effect.effect_name, 0.001) + effect_delay

		if DebugFlags.PrintFlags.current_effect_changes and print_effect_updates:
			print_rich("-------[color=green]Restoring[/color][b] " + str(status_effect.effect_name) + str(status_effect.effect_lvl) + "[/b]-------")
		_add_status_effect(clean_status_effect)
	saved_times_left = {}
#endregion

## Assert that this node has a connected effect receiver from which it can receive status effects.
func _ready() -> void:
	assert(effect_receiver != null, get_parent().name + " has a StatusEffectManager without a connected EffectReceiverComponent.")

## Handles an incoming status effect. It starts by adding any stat mods provided by the status effect, and then
## it passes the effect logic to the relevant handler if it exists.
func handle_status_effect(status_effect: StatusEffect) -> void:
	if DebugFlags.PrintFlags.current_effect_changes and print_effect_updates:
		if status_effect is StormSyndromeEffect:
			print_rich("-------[color=green]Adding[/color][b] [color=pink]" + str(status_effect.effect_name) + str(status_effect.effect_lvl) + "[/color][/b]-------")
		else:
			print_rich("-------[color=green]Adding[/color][b] " + str(status_effect.effect_name) + str(status_effect.effect_lvl) + "[/b]-------")

	if effect_receiver.can_receive_stat_mods:
		_handle_status_effect_mods(status_effect)

## Checks if we already have a status effect of the same name and decides what to do depending on the level.
func _handle_status_effect_mods(status_effect: StatusEffect) -> void:
	if status_effect.effect_name in current_effects:
		var existing_lvl: int = current_effects[status_effect.effect_name].effect_lvl

		if existing_lvl > status_effect.effect_lvl: # new effect is lower lvl
			var time_to_add: float = status_effect.mod_time * (float(status_effect.effect_lvl) / float(existing_lvl))
			_extend_effect_duration(status_effect.effect_name, time_to_add)
			return
		elif existing_lvl < status_effect.effect_lvl: # new effect is higher lvl
			_remove_status_effect(current_effects[status_effect.effect_name])
			_add_status_effect(status_effect)
			return
		else: # new effect is same lvl
			_restart_effect_duration(status_effect.effect_name)
			return
	else:
		_add_status_effect(status_effect)

## Adds a status effect to the current effects dict, starts its timer, stores its timer, and applies its mods.
func _add_status_effect(status_effect: StatusEffect) -> void:
	current_effects[status_effect.effect_name] = status_effect

	var mod_timer: Timer = Timer.new()
	mod_timer.wait_time = max(0.01, status_effect.mod_time)
	mod_timer.one_shot = true

	if not status_effect.apply_until_removed:
		var removing_callable: Callable = Callable(self, "_remove_status_effect").bind(status_effect)
		mod_timer.timeout.connect(removing_callable)
		mod_timer.set_meta("callable", removing_callable)
	else:
		mod_timer.timeout.connect(func() -> void: mod_timer.start(status_effect.mod_time))

	mod_timer.name = str(status_effect.effect_name) + str(status_effect.effect_lvl) + "_timer"
	add_child(mod_timer)
	mod_timer.start()

	effect_timers[status_effect.effect_name] = mod_timer

	if status_effect.spawn_particles: _start_effect_fx(status_effect.effect_name, status_effect.particles_req_handler)

	for mod_resource: StatMod in status_effect.stat_mods:
		get_parent().stats.add_mods([mod_resource] as Array[StatMod], stats_ui)

## Starts the status effects' associated visual FX like particles. Checks if the receiver has the matching handler node first.
func _start_effect_fx(effect_name: String, requires_handler: bool) -> void:
	var particle_node: CPUParticles2D = get_node_or_null((effect_name + "Particles").replace(" ", ""))
	var allowed_to_receive: bool = effect_receiver.has_node((effect_name + "Handler").replace(" ", "")) or not requires_handler

	if not allowed_to_receive:
		return

	get_parent().sprite.update_floor_color(effect_name, false)
	get_parent().sprite.update_glow_color(effect_name, false)

	if particle_node != null:
		var sprite_tex: Texture2D = SpriteHelpers.SpriteDetails.get_frame_texture(get_parent().sprite)
		var scalar: Vector2 = get_parent().sprite.scale
		var emission_shape: CPUParticles2D.EmissionShape = particle_node.get_emission_shape()

		if emission_shape == CPUParticles2D.EmissionShape.EMISSION_SHAPE_SPHERE_SURFACE:
			particle_node.emission_sphere_radius = (sprite_tex.get_width() / 2.0) * scalar.x
			particle_node.position = Vector2(0, -(sprite_tex.get_height() / 2.0) * scalar.y)
		elif emission_shape == CPUParticles2D.EmissionShape.EMISSION_SHAPE_RECTANGLE:
			if effect_name != "Burning" and effect_name != "Frostbite":
				particle_node.emission_rect_extents = Vector2((sprite_tex.get_width() / 4.0) * scalar.x, (sprite_tex.get_height() / 2.0) * scalar.y)
				particle_node.position = Vector2(0, -(sprite_tex.get_height() / 2.0) * scalar.y)

		if effect_name == "Burning":
			particle_node.emission_rect_extents = Vector2((sprite_tex.get_width() / 4.0) * scalar.x, 0.5)
			particle_node.position = Vector2(0, -2)
		elif effect_name == "Frostbite":
			particle_node.emission_rect_extents = Vector2((sprite_tex.get_width() / 3.5) * scalar.x, 3)
			particle_node.position = Vector2(0, -(sprite_tex.get_height() * scalar.y) + 4)

		particle_node.emitting = true

## Extends the duration of the timer associated with some current effect.
func _extend_effect_duration(effect_name: String, time_to_add: float) -> void:
	var timer: Timer = effect_timers.get(effect_name, null)
	if timer != null:
		var new_time: float = timer.get_time_left() + time_to_add
		timer.stop()
		timer.wait_time = new_time
		timer.start()

## Restarts the timer associated with some current effect.
func _restart_effect_duration(effect_name: String) -> void:
	var timer: Timer = effect_timers.get(effect_name, null)
	if timer != null:
		timer.stop()
		timer.start()

## Removes the status effect from the current effects dict and removes all its mods. Additionally removes its
## associated timer from the timer dict.
func _remove_status_effect(status_effect: StatusEffect) -> void:
	if DebugFlags.PrintFlags.current_effect_changes and print_effect_updates:
		if status_effect is StormSyndromeEffect:
			print_rich("-------[color=red]Removed[/color][b] [color=pink]" + str(status_effect.effect_name) + str(status_effect.effect_lvl) + "[/color][/b]-------")
		else:
			print_rich("-------[color=red]Removed[/color][b] " + str(status_effect.effect_name) + str(status_effect.effect_lvl) + "[/b]-------")

	for mod_resource: StatMod in status_effect.stat_mods:
		get_parent().stats.remove_mod(mod_resource.stat_id, mod_resource.mod_id, stats_ui)

	if status_effect.effect_name in current_effects:
		current_effects.erase(status_effect.effect_name)

	var timer: Timer = effect_timers.get(status_effect.effect_name, null)
	if timer != null:
		if timer.has_meta("callable"): # So we can cancel any pending callables before freeing
			var callable: Callable = timer.get_meta("callable")
			timer.timeout.disconnect(callable)
			timer.set_meta("callable", null)
		timer.stop()
		timer.queue_free()
		effect_timers.erase(status_effect.effect_name)

	_stop_effect_fx(status_effect.effect_name)

## Stops the status effects' associated visual FX like particles.
func _stop_effect_fx(effect_name: String) -> void:
	var particle_node: CPUParticles2D = get_node_or_null((effect_name + "Particles").replace(" ", ""))
	if particle_node != null: particle_node.emitting = false
	get_parent().sprite.update_floor_color(effect_name, true)
	get_parent().sprite.update_glow_color(effect_name, true)

## Returns if any effect (no matter the level) of the passed in name is active.
func check_if_has_effect(effect_name: String) -> bool:
	return current_effects.has(effect_name)

## Attempts to remove any effect of the matching name and then tries to cancel any active DOTs and HOTs for it.
func request_effect_removal(effect_name: String) -> void:
	var existing_effect: StatusEffect = current_effects.get(effect_name, null)
	if existing_effect: _remove_status_effect(existing_effect)

	if effect_receiver.has_node("DmgHandler"):
		effect_receiver.get_node("DmgHandler").cancel_over_time_dmg(effect_name)
	if effect_receiver.has_node("HealHandler"):
		effect_receiver.get_node("HealHandler").cancel_over_time_heal(effect_name)

## Removes all bad status effects except for an optional exception effect that may be specified.
func remove_all_bad_status_effects(effect_to_keep: String = "") -> void:
	for status_effect: String in current_effects.keys():
		if effect_to_keep != "" and effect_to_keep == status_effect:
			continue
		elif current_effects[status_effect].is_bad_effect:
			request_effect_removal(status_effect)

## Removes all good status effects except for an optional exception effect that may be specified.
func remove_all_good_status_effects(effect_to_keep: String = "") -> void:
	for status_effect: String in current_effects.keys():
		if effect_to_keep != "" and effect_to_keep == status_effect:
			continue
		elif status_effect in GlobalData.GOOD_STATUS_EFFECTS:
			request_effect_removal(status_effect)
