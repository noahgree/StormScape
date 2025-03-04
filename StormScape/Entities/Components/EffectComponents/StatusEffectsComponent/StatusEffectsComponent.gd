@icon("res://Utilities/Debug/EditorIcons/status_effect_component.svg")
extends Node2D
class_name StatusEffectsComponent
## The component that holds the stats and logic for how the entity should receive effects.
##
## This handles things like fire & poison damage not taking into account armor, etc.

@export var effect_receiver: EffectReceiverComponent ## The effect receiver that sends status effects to this manager to be cached and handled.
@export var stats_ui: Control ## The UI to update upon receiving effects that may update it.
@export_subgroup("Debug")
@export var print_effect_updates: bool = false ## Whether to print when this entity has status effects added and removed.

@onready var affected_entity: PhysicsBody2D = owner ## The entity affected by these status effects.

var current_effects: Dictionary[String, StatusEffect] = {} ## Keys are general status effect titles like "Poison", and values are the effect resources themselves.
var effect_timers: Dictionary[String, Timer] = {} ## Holds references to all timers currently tracking active status effects.


#region Debug
func _draw() -> void:
	if not Engine.is_editor_hint() and DebugFlags.Particles.show_status_effect_particle_emission_area:
		var emission_mgr: ParticleEmissionComponent = owner.emission_mgr
		var extents: Vector2 = emission_mgr.get_extents(ParticleEmissionComponent.Boxes.BELOW)
		var origin: Vector2 = emission_mgr.get_origin(ParticleEmissionComponent.Boxes.BELOW)

		var rect: Rect2 = Rect2(origin - extents, extents * 2)
		draw_rect(rect, Color(1, 0, 0, 0.5), false, 1)
#endregion

#region Save & Load
## We must clear out any existing effect timers and remove all exiting status effects.
func _on_before_load_game() -> void:
	effect_timers = {}
	for status_effect: String in current_effects.keys():
		request_effect_removal(status_effect)
	for child: Variant in get_children():
		if child is Timer:
			child.queue_free()
#endregion

## Assert that this node has a connected effect receiver from which it can receive status effects.
func _ready() -> void:
	assert(effect_receiver != null, owner.name + " has a StatusEffectsComponent without a connected EffectReceiverComponent.")

## Handles an incoming status effect. It starts by adding any stat mods provided by the status effect, and then
## it passes the effect logic to the relevant handler if it exists.
func handle_status_effect(status_effect: StatusEffect) -> void:
	if DebugFlags.PrintFlags.current_effect_changes and print_effect_updates:
		if status_effect is StormSyndromeEffect:
			print_rich("-------[color=green]Adding[/color][b] [color=pink]" + str(status_effect.effect_name) + " " + str(status_effect.effect_lvl) + "[/color][/b]-------")
		else:
			print_rich("-------[color=green]Adding[/color][b] " + str(status_effect.effect_name) + " " + str(status_effect.effect_lvl) + "[/b]-------")

	_handle_status_effect_mods(status_effect)

## Checks if we already have a status effect of the same name and decides what to do depending on the level.
func _handle_status_effect_mods(status_effect: StatusEffect) -> void:
	if status_effect.effect_name in current_effects:
		var existing_lvl: int = current_effects[status_effect.effect_name].effect_lvl

		if existing_lvl > status_effect.effect_lvl: # New effect is lower lvl
			var time_to_add: float = status_effect.mod_time * (float(status_effect.effect_lvl) / float(existing_lvl))
			_extend_effect_duration(status_effect.effect_name, time_to_add)
			return
		elif existing_lvl < status_effect.effect_lvl: # New effect is higher lvl
			_remove_status_effect(current_effects[status_effect.effect_name])
			_add_status_effect(status_effect)
			return
		else: # New effect is same lvl
			_restart_effect_duration(status_effect.effect_name)
			return
	else:
		_add_status_effect(status_effect)

## Adds a status effect to the current effects dict, starts its timer, stores its timer, and applies its mods.
func _add_status_effect(status_effect: StatusEffect) -> void:
	current_effects[status_effect.effect_name] = status_effect

	var mod_timer: Timer = TimerHelpers.create_one_shot_timer(self, max(0.01, status_effect.mod_time))

	if not status_effect.apply_until_removed:
		var removing_callable: Callable = Callable(self, "_remove_status_effect").bind(status_effect)
		mod_timer.timeout.connect(removing_callable)
		mod_timer.set_meta("callable", removing_callable)
	else:
		mod_timer.timeout.connect(func() -> void: mod_timer.start(status_effect.mod_time))

	mod_timer.name = str(status_effect.effect_name) + str(status_effect.effect_lvl) + "_timer"
	if mod_timer.is_inside_tree():
		mod_timer.start()
	else:
		print(affected_entity.name, status_effect)

	effect_timers[status_effect.effect_name] = mod_timer

	_start_effect_fx(status_effect)

	for mod_resource: StatMod in status_effect.stat_mods:
		affected_entity.stats.add_mods([mod_resource] as Array[StatMod], stats_ui)

## Starts the status effects' associated visual FX like particles. Checks if the receiver has the matching handler node first.
func _start_effect_fx(status_effect: StatusEffect) -> void:
	var effect_name: String = status_effect.particle_hander_req if status_effect.particle_hander_req != "" else status_effect.effect_name
	var particle_node: CPUParticles2D = get_node_or_null((effect_name + "Particles").replace(" ", ""))
	if particle_node == null:
		return

	var handler_check: bool = effect_receiver.has_node((effect_name + "Handler").replace(" ", "")) or status_effect.particle_hander_req == ""
	var spawn_particles: bool = status_effect.spawn_particles and handler_check
	if not spawn_particles:
		return

	if status_effect.make_entity_glow and handler_check:
		affected_entity.sprite.update_floor_light(effect_name, false)
		affected_entity.sprite.update_overlay_color(effect_name, false)

	var emission_shape: CPUParticles2D.EmissionShape = particle_node.get_emission_shape()
	var emission_mgr: ParticleEmissionComponent = affected_entity.emission_mgr

	if emission_shape == CPUParticles2D.EmissionShape.EMISSION_SHAPE_SPHERE_SURFACE:
		particle_node.emission_sphere_radius = emission_mgr.get_extents(ParticleEmissionComponent.Boxes.COVER).x
		particle_node.position = emission_mgr.get_origin(ParticleEmissionComponent.Boxes.COVER)
	elif emission_shape == CPUParticles2D.EmissionShape.EMISSION_SHAPE_RECTANGLE and effect_name not in ["Burning", "Frostbite", "Slowness"]:
		particle_node.emission_rect_extents = emission_mgr.get_extents(ParticleEmissionComponent.Boxes.COVER)
		particle_node.position = emission_mgr.get_origin(ParticleEmissionComponent.Boxes.COVER)
	elif effect_name in ["Burning", "Slowness"]: # Because it needs to be at the floor only
		particle_node.emission_rect_extents = emission_mgr.get_extents(ParticleEmissionComponent.Boxes.BELOW)
		particle_node.position = emission_mgr.get_origin(ParticleEmissionComponent.Boxes.BELOW)
	elif effect_name == "Frostbite": # Because it needs to be above it only
		particle_node.emission_rect_extents = emission_mgr.get_extents(ParticleEmissionComponent.Boxes.ABOVE)
		particle_node.position = emission_mgr.get_origin(ParticleEmissionComponent.Boxes.ABOVE)
	else:
		return

	particle_node.emitting = true

	if DebugFlags.Particles.show_status_effect_particle_emission_area:
		queue_redraw()

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
			print_rich("-------[color=red]Removed[/color][b] [color=pink]" + str(status_effect.effect_name) + " " + str(status_effect.effect_lvl) + "[/color][/b]-------")
		else:
			print_rich("-------[color=red]Removed[/color][b] " + str(status_effect.effect_name) + " " + str(status_effect.effect_lvl) + "[/b]-------")

	for mod_resource: StatMod in status_effect.stat_mods:
		affected_entity.stats.remove_mod(mod_resource.stat_id, mod_resource.mod_id, stats_ui)

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

	_stop_effect_fx(status_effect)

## Stops the status effects' associated visual FX like particles.
func _stop_effect_fx(status_effect: StatusEffect) -> void:
	var effect_name: String = status_effect.particle_hander_req if status_effect.particle_hander_req != "" else status_effect.effect_name
	var particle_node: CPUParticles2D = get_node_or_null((effect_name + "Particles").replace(" ", ""))
	if particle_node != null: particle_node.emitting = false

	if status_effect.make_entity_glow:
		affected_entity.sprite.update_floor_light(effect_name, true)
		affected_entity.sprite.update_overlay_color(effect_name, true)

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
