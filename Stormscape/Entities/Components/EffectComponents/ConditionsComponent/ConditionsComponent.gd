@icon("res://Utilities/Debug/EditorIcons/status_effect_component.svg")
extends Node2D
class_name ConditionsComponent
## The component that holds the stats and logic for how the entity should receive conditions.
##
## This handles things like fire & poison damage not taking into account armor, etc.

static var cache: Dictionary[Array, Condition] = {} ## A cache of all conditions. { [id, source, level] : condition }

@export_subgroup("Debug")
@export var print_condition_updates: bool = false ## Whether to print when this entity has conditions added and removed.

@onready var entity: Entity = owner ## The entity affected by these conditions.
@onready var esi_receiver: ESIReceiverComponent = entity.esi_receiver ## The ESI receiver that sends conditions to this manager to be cached and handled.

var active: Dictionary[Array, int] = {} ## { [id, source] : level }
var active_by_id: Dictionary[Condition.ID, Dictionary] = {} ## { id : { Condition.SourceType : level } }
var condition_timers: Dictionary[Array, Timer] = {} ## Holds references to all timers currently tracking active conditions. { [id, source] : timer }
var particle_fade_tweens: Dictionary[Condition.ID, Tween] = {} ## Holds references to all particle fade out tweens so if that condition is started again while fading out, we can cancel it. { id : tween }


#region Core
## Assert that this node has a connected esi receiver from which it can receive conditions.
func _ready() -> void:
	assert(esi_receiver != null, owner.name + " has a ConditionsComponent without a connected ESIReceiverComponent.")

	if ConditionsComponent.cache.is_empty():
		_cache_conditions(Globals.conditions_dir)

## Searches through the given top level folder and recursively finds all condition resources for caching.
func _cache_conditions(folder: String) -> void:
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		push_error("ConditionsComponent couldn't open the folder: " + folder)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if dir.current_is_dir():
			if (file_name != ".") and (file_name != ".."):
				_cache_conditions(folder + "/" + file_name)
		elif file_name.ends_with(".tres"):
			var file_path: String = folder + "/" + file_name
			var condition: Condition = load(file_path)
			ConditionsComponent.cache[[condition.id, condition.source_type, condition.level]] = condition
		file_name = dir.get_next()
	dir.list_dir_end()
#endregion

## Handles an incoming condition. It starts by adding any stat mods provided by the condition, and then
## it passes the condition logic to the relevant handler if it exists.
func handle_condition(condition: Condition) -> void:
	_debug_print_adding_condition(condition)

	var key: Array = condition.get_key()
	if key in active:
		var existing_lvl: int = active[key]
		if existing_lvl > condition.level: # New condition is lower lvl
			_extend_condition_duration(condition, existing_lvl)
		elif existing_lvl < condition.effect_lvl: # New condition is higher lvl
			_remove_condition(condition)
			_add_condition(condition)
		else: # New condition is same lvl
			_restart_condition_duration(condition)
	else:
		_add_condition(condition)

## Adds a condition to the current effects dict, starts its timer, stores its timer, and applies its mods.
func _add_condition(condition: Condition) -> void:
	if condition.id == Condition.ID.UNTOUCHABLE:
		remove_all_bad_conditions()

	var key: Array = condition.get_key()
	active[key] = condition.level
	if active_by_id[condition.id].is_empty():
		active_by_id[condition.id] = { condition.source_type : condition.level }
	else:
		active_by_id[condition.id][condition.source_type] = condition.level

	var mod_timer: Timer = TimerHelpers.create_one_shot_timer(
			self, max(0.01, condition.mod_time), Callable(), str(condition) + "_timer"
		)
	if not condition.apply_until_removed:
		var timeout_func: Callable = Callable(self, "_remove_condition").bind(condition)
		mod_timer.timeout.connect(timeout_func)
		mod_timer.set_meta("on_removal", timeout_func)
	else:
		mod_timer.timeout.connect(func() -> void: mod_timer.start(condition.mod_time))

	condition_timers[key] = mod_timer
	mod_timer.start()

	_start_condition_fx(condition)

	for mod_resource: StatMod in condition.stat_mods:
		entity.sc.add_mods([mod_resource] as Array[StatMod])

## Starts the conditions' associated visual FX like particles. Checks if the receiver has the
## matching handler node first.
func _start_condition_fx(condition: Condition) -> void:
	var effect_name: String = condition.particle_hander_req if condition.particle_hander_req != "" else condition.id.to_pascal_case()
	var particle_node: CPUParticles2D = get_node_or_null(effect_name + "Particles")
	if particle_node == null:
		return

	var handler_check: bool = condition.particle_hander_req == "" or esi_receiver.get(effect_name.to_snake_case() + "_handler") != null
	if not (condition.spawn_particles and handler_check):
		return

	if condition.make_entity_glow and handler_check:
		entity.sprite.update_floor_light(condition.id, false)
		entity.sprite.update_overlay_color(condition.id, false)

	var emission_shape: CPUParticles2D.EmissionShape = particle_node.get_emission_shape()
	var emission_mgr: ParticleEmissionComponent = entity.emission_mgr

	if emission_shape == CPUParticles2D.EmissionShape.EMISSION_SHAPE_SPHERE_SURFACE:
		particle_node.emission_sphere_radius = emission_mgr.get_extents(ParticleEmissionComponent.Boxes.COVER).x
		particle_node.position = emission_mgr.get_origin(ParticleEmissionComponent.Boxes.COVER)
	elif emission_shape == CPUParticles2D.EmissionShape.EMISSION_SHAPE_RECTANGLE and condition.id not in ["burning", "frostbite", "slowness"]:
		particle_node.emission_rect_extents = emission_mgr.get_extents(ParticleEmissionComponent.Boxes.COVER)
		particle_node.position = emission_mgr.get_origin(ParticleEmissionComponent.Boxes.COVER)
	elif condition.id in ["burning", "slowness"]: # Because it needs to be at the floor only
		particle_node.emission_rect_extents = emission_mgr.get_extents(ParticleEmissionComponent.Boxes.BELOW)
		particle_node.position = emission_mgr.get_origin(ParticleEmissionComponent.Boxes.BELOW)
	elif condition.id == "frostbite": # Because it needs to be above it only
		particle_node.emission_rect_extents = emission_mgr.get_extents(ParticleEmissionComponent.Boxes.ABOVE)
		particle_node.position = emission_mgr.get_origin(ParticleEmissionComponent.Boxes.ABOVE)
	else:
		return

	var particle_fade_tween: Tween = particle_fade_tweens.get(condition.id, null)
	if particle_fade_tween != null:
		particle_fade_tween.kill()
		particle_fade_tweens.erase(condition.id)

	particle_node.modulate.a = 1.0
	particle_node.emitting = true

	if DebugFlags.show_condition_particle_emission_area:
		queue_redraw()

## Extends the duration of the timer associated with some current condition.
func _extend_condition_duration(new_condition: Condition, existing_lvl: float) -> void:
	var time_to_add: float = new_condition.mod_time * (float(new_condition.level) / float(existing_lvl))
	var timer: Timer = condition_timers.get(new_condition.get_key(), null)
	if timer != null:
		var new_time: float = timer.get_time_left() + time_to_add
		timer.stop()
		timer.start(new_time)

## Restarts the timer associated with some current condition.
func _restart_condition_duration(condition: Condition) -> void:
	var timer: Timer = condition_timers.get(condition.get_key(), null)
	if timer != null:
		timer.stop()
		timer.start()

## Removes the condition from the current conditions dict and removes all its mods. Additionally removes its
## associated timer from the timer dict.
func _remove_condition(condition: Condition) -> void:
	_debug_print_removing_condition(condition)

	for mod_resource: StatMod in condition.stat_mods:
		entity.sc.remove_mod(mod_resource.stat_id, mod_resource.mod_id)

	var key: Array = condition.get_key()
	active.erase(key)
	active_by_id[condition.id].erase(condition.source_type)
	if active_by_id[condition.id].is_empty():
		active_by_id.erase(condition.id)

	var timer: Timer = condition_timers.get(key, null)
	if timer != null:
		if timer.has_meta("on_removal"): # So we can cancel any pending callables before freeing
			var callable: Callable = timer.get_meta("on_removal")
			timer.timeout.disconnect(callable)
			timer.remove_meta("on_removal")
		timer.stop()
		timer.queue_free()
		condition_timers.erase(key)

	_stop_condition_fx(condition.id, false)

## Stops the conditions' associated visual FX like particles. Pass in only the effect id, not its source type.
func _stop_effect_fx(effect_id: String, force: bool = false) -> void:
	entity.sprite.update_floor_light(effect_id, true)
	entity.sprite.update_overlay_color(effect_id, true)

	if not force:
		var count: int = 0
		for effect_key: String in active:
			if effect_key.begins_with(effect_id + ":"):
				count += 1
		if count >= 1:
			return

	var particle_node: CPUParticles2D = get_node_or_null(effect_id.to_pascal_case() + "Particles")
	if particle_node != null:
		particle_node.emitting = false

		var tween: Tween = create_tween()
		particle_fade_tweens[effect_id] = tween
		tween.tween_property(particle_node, "modulate:a", 0.0, 0.35)
		tween.tween_callback(func() -> void: particle_fade_tweens.erase(effect_id))

## Returns if any condition (no matter the level) of the passed in name is active. Can optionally check
## only for a single source type.
func check_if_has_condition(id: String, source_type: Condition.SourceType = -1) -> bool:
	if source_type != -1:
		return active.has(id + ":" + str(Condition.SourceType.keys()[source_type]).to_lower())
	else:
		for effect_key: StringName in active:
			if effect_key.begins_with(id + ":"):
				return true
		return false

## Attempts to remove any effect of the matching id and source type (which is given as an Enum value).
## It also cancels any active DOTs and HOTs for it.
func request_condition_removal_by_source(id: StringName, source_type: Condition.SourceType) -> void:
	var source_string: StringName = StringName((Condition.SourceType.keys()[source_type]).to_lower())
	request_condition_removal_by_source_string(id, source_string)

## Attempts to remove any effect of the matching id and source type (which is given as a StringName).
## It also cancels any active DOTs and HOTs for it.
func request_condition_removal_by_source_string(id: StringName, source_string: StringName) -> void:
	var key_to_remove: String = id + ":" + source_string
	var existing_effect: Condition = active.get(key_to_remove, null)
	if existing_effect:
		_remove_condition(existing_effect)
	_cancel_over_time_effects(key_to_remove)

## Attempts to remove all effects of the matching id, regardless of source type.
## It also cancels all active DOTs and HOTs for each of them.
func request_condition_removal_for_all_sources(id: Condition.ID) -> void:
	var to_erase: Array[Condition] = []
	for effect_key: StringName in active:
		if effect_key.begins_with(id + ":"):
			to_erase.append(active[effect_key])
			_cancel_over_time_effects(effect_key)

	for effect: Condition in to_erase:
		_remove_condition(effect)

## Sends the cancellation requests for a composite effect key to the damage and heal handlers if they exist.
func _cancel_over_time_effects(key_to_cancel: String) -> void:
	if esi_receiver.dh_handler != null:
		esi_receiver.dh_handler.cancel_over_time_dmg(key_to_cancel)
	if esi_receiver.heal_handler != null:
		esi_receiver.heal_handler.cancel_over_time_heal(key_to_cancel)

## Removes all bad conditions except for an optional exception effect that may be specified.
## The optional kept effect should be given only as its effect id, not including its source type.
func remove_all_bad_conditions(effect_to_keep_id: String = "") -> void:
	for condition_key: StringName in active:
		if effect_to_keep_id == StringHelpers.get_before_colon(condition_key):
			continue
		elif active[condition_key].is_bad_effect:
			request_condition_removal_for_all_sources(StringHelpers.get_before_colon(condition_key))

## Removes all good conditions except for an optional exception effect that may be specified.
## The optional kept effect should be given only as its effect id, not including its source type.
func remove_all_good_conditions(effect_to_keep_id: String = "") -> void:
	for condition_key: StringName in active:
		if effect_to_keep_id == StringHelpers.get_before_colon(condition_key):
			continue
		elif not active[condition_key].is_bad_effect:
			request_condition_removal_for_all_sources(StringHelpers.get_before_colon(condition_key))

## Removes all conditions.
func remove_all_conditions() -> void:
	for condition: Condition in active.values():
		_remove_condition(condition)

## Returns true if there is an "untouchable" effect in the current effects.
func is_untouchable() -> bool:
	for condition: Condition in active.values():
		if condition.id == Condition.ID.UNTOUCHABLE:
			return true
	return false

## Returns a dictionary of arrays, grouped by the effect id. This abstracts out the source types.
func get_current_effects_grouped_by_id() -> Dictionary[StringName, Array]:
	var results: Dictionary[StringName, Array]
	for condition: StringName in active:
		var effect_id: StringName = condition.split(":")[0]
		if effect_id in results:
			results[effect_id].append(active[effect])
		else:
			results[effect_id] = [active[effect]]
	return results

#region Debug
func _draw() -> void:
	if not Engine.is_editor_hint() and DebugFlags.show_condition_particle_emission_area:
		var emission_mgr: ParticleEmissionComponent = owner.emission_mgr
		var extents: Vector2 = emission_mgr.get_extents(ParticleEmissionComponent.Boxes.BELOW)
		var origin: Vector2 = emission_mgr.get_origin(ParticleEmissionComponent.Boxes.BELOW)

		var rect: Rect2 = Rect2(origin - extents, extents * 2)
		draw_rect(rect, Color(1, 0, 0, 0.5), false, 1)

func _debug_print_adding_condition(condition: Condition) -> void:
	if DebugFlags.current_condition_changes and print_condition_updates:
		if condition is StormSyndromeEffect:
			print_rich("-------[color=green]Adding[/color][b] [color=pink]" + str(condition) + "[/color][/b][color=gray] to " + entity.name + "-------")
		else:
			print_rich("-------[color=green]Adding[/color][b] " + str(condition) + "[/b][color=gray] to " + entity.name + "-------")

func _debug_print_removing_condition(condition: Condition) -> void:
	if DebugFlags.current_condition_changes and print_condition_updates:
		if condition.id == Condition.ID.STORM_SYNDROME:
			print_rich("-------[color=red]Removed[/color][b] [color=pink]" + str(condition) + "[/color][/b][color=gray] from " + entity.name + "-------")
		else:
			print_rich("-------[color=red]Removed[/color][b] " + str(condition) + "[/b][color=gray] from " + entity.name + "-------")
#endregion
