@icon("res://Utilities/Debug/EditorIcons/status_effect_component.svg")
extends Node2D
class_name ConditionsComponent
## The component that holds the stats and logic for how the entity should receive conditions.
##
## This handles things like fire & poison damage not taking into account armor, etc.

enum Filter { ## The different ways to filter out incoming conditions.
	AUTO, ## Only allow conditions this entity can receive based on entity type.
	MANUAL, ## Follows entity type restrictions like AUTO, but the incoming condition must also be part of the "manual filter" array.
	NONE ## For when this entity cannot receive any conditions.
}

static var cache: Dictionary[Array, Condition] = {} ## A cache of all conditions. { [id, source, level] : condition }

@export var debug_updates: bool = false ## Whether to print when this entity has conditions added and removed.
@export var filter: Filter = Filter.AUTO ## The way we should filter out incoming conditions.
@export var manual_filter: Array[Condition.ID] ## The conditions the owning entity can have.

@onready var entity: Entity = owner ## The entity affected by these conditions.
@onready var esi_receiver: ESIReceiverComponent = entity.esi_receiver ## The ESI receiver that sends conditions to this manager to be cached and handled.

const PROCESS_INTERVAL: float = 0.1 ## How often we should process the CIs. Helps with performance.

var actives: Dictionary[Array, CI] = {} ## { [id, source] : CI }
var actives_by_id: Dictionary[Condition.ID, Dictionary] = {} ## { id : { Condition.SourceType : CI } }
var tick_accumulator: float ## Tracks time since last tick.


## Assert that this node has a connected esi receiver from which it can receive conditions.
func _ready() -> void:
	set_process(false) # Wait until we have an active CI to start processing

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

func _process(delta: float) -> void:
	tick_accumulator += delta

	while tick_accumulator >= PROCESS_INTERVAL:
		tick_accumulator -= PROCESS_INTERVAL
		for ci: CI in actives.values():
			ci.process(PROCESS_INTERVAL)

#region Adding Conditions
func handle_conditions_in_esi(esi: ESI) -> void:
	var bad_effects_to_enemies: bool = ESI.can_hit_enemy_with_bad(entity.team, esi)
	var bad_effects_to_allies: bool = ESI.can_hit_ally_with_bad(entity.team, esi)
	var good_effects_to_enemies: bool = ESI.can_hit_enemy_with_good(entity.team, esi)
	var good_effects_to_allies: bool = ESI.can_hit_ally_with_good(entity.team, esi)

	for condition: Condition in esi.conditions:
		if condition.goodness == Condition.Goodness.BAD:
			if bad_effects_to_allies or bad_effects_to_enemies:
				_process_condition(condition, esi)
		else:
			if good_effects_to_allies or good_effects_to_enemies:
				_process_condition(condition, esi)

## Handles an incoming condition. It starts by adding any stat mods provided by the condition, and then
## it passes the condition logic to the relevant handler if it exists.
func _process_condition(condition: Condition, esi: ESI) -> void:
	if (not _check_filter(condition)) or (entity.invulnerable):
		return
	if (condition.goodness == Condition.Goodness.BAD) and (is_untouchable()):
		return

	for condition_id_to_stop: Condition.ID in condition.conditions_to_stop:
		remove_condition_for_all_sources(condition_id_to_stop)

	_debug_print_adding_condition(condition)

	condition.on_received_regardless_of_level(esi, entity)

	var key: Array = condition.get_key()
	if key in actives:
		var existing_ci: CI = actives[key]
		if existing_ci.condition.level > condition.level: # New condition is lower lvl
			if (condition.eot_stats.perpetual) and (not existing_ci.condition.eot_stats.perpetual):
				_remove_ci(existing_ci)
				_add_ci(condition)
			elif not existing_ci.condition.eot_stats.perpetual:
				existing_ci.extend_time_left(condition)
		elif existing_ci.condition.level < condition.level: # New condition is higher lvl
			if (existing_ci.condition.eot_stats.perpetual) and (not condition.eot_stats.perpetual):
				return
			_remove_ci(existing_ci)
			_add_ci(condition)
		else: # New condition is same lvl (so the exact same condition resource)
			existing_ci.restart_time_left(condition)
	else:
		_add_ci(condition)

	if (entity is Player) or (not condition.only_cue_on_player_hit):
		AudioManager.play_2d(condition.audio_to_play, entity.global_position)

func _check_filter(condition: Condition) -> bool:
	match condition.filter:
		Filter.NONE:
			return false
		Filter.AUTO:
			return condition.affected_entities & entity.class_type != 0
		Filter.MANUAL:
			var affected: bool = condition.affected_entities & entity.class_type != 0
			return (affected) and (condition.id in manual_filter)
	return false

func _add_ci(condition: Condition) -> void:
	if condition.id == Condition.ID.UNTOUCHABLE:
		remove_all_bad_conditions()

	var ci: CI = CI.new(condition)
	actives[condition.get_key()] = ci
	if actives_by_id[condition.id].is_empty():
		actives_by_id[condition.id] = { condition.source_type : condition.level }
	else:
		actives_by_id[condition.id][condition.source_type] = ci

	ci.condition_expired.connect(_remove_ci)

	_start_condition_fx(ci)

	for mod_resource: StatMod in ci.condition.stat_mods:
		entity.sc.add_mods([mod_resource] as Array[StatMod])

## Passes the condition to a handler if one is needed for additional logic handling.
func _handle_dynamic_condition(condition: Condition, esi: ESI) -> void:
	if condition is StunEffect:
		if stun_handler: stun_handler.handle_stun(condition)
		else: return
	if condition is TimeSnareEffect:
		if time_snare_handler: time_snare_handler.handle_time_snare(condition)
		else: return

## Starts the conditions' associated visual FX like particles.
func _start_condition_fx(ci: CI) -> void:
	if not ci.condition.spawn_particles:
		return

	if ci.condition.make_entity_glow:
		entity.sprite.update_floor_light(ci.condition.id, false)
		entity.sprite.update_overlay_color(ci.condition.id, false)

	entity.particle_mgr.start_particles(ci.condition.id)
#endregion


#region Removing Conditions
func _remove_ci(ci: CI) -> void:
	_debug_print_removing_condition(ci.condition)

	for mod_resource: StatMod in ci.condition.stat_mods:
		entity.sc.remove_mod(mod_resource.stat_id, mod_resource.mod_id)

	var key: Array = ci.condition.get_key()
	actives.erase(key)
	actives_by_id[ci.condition.id].erase(ci.condition.source_type)
	if actives_by_id[ci.condition.id].is_empty():
		actives_by_id.erase(ci.condition.id)

	_stop_associated_eotis(ci.condition)
	_stop_condition_fx(ci.condition)

## Stops the conditions' associated visual FX like particles.
func _stop_condition_fx(condition: Condition) -> void:
	entity.sprite.update_floor_light(condition.id, true)
	entity.sprite.update_overlay_color(condition.id, true)

	# Only remove all FX if there are no more instances of the same condition ID
	var conditions: Dictionary[Condition.SourceType, int] = actives_by_id.get(condition.id, null)
	if (conditions == null) or (conditions.keys().size() > 1):
		return
	entity.particle_mgr.stop_particles(condition.id)

func remove_condition_by_source_type(condition_id: Condition.ID, source_type: Condition.SourceType) -> void:
	var existing_ci: CI = actives.get([condition_id, source_type], null)
	if existing_ci != null:
		_remove_ci(existing_ci)

## Attempts to remove all CIs of the matching condition id, regardless of source type.
func remove_condition_for_all_sources(condition_id: Condition.ID) -> void:
	if condition_id not in actives_by_id:
		return

	var to_erase: Array[CI] = []
	for source_type: Condition.SourceType in actives_by_id[condition_id]:
		var ci: CI = actives_by_id[condition_id][source_type]
		to_erase.append(ci)

	for ci: CI in to_erase:
		_remove_ci(ci)

func _stop_associated_eotis(condition: Condition) -> void:
	esi_receiver.dh_handler.stop_eotis_by_source_type(condition.id, condition.source_type)

## Removes all bad conditions except for an optional exception condition that may be specified.
## The optional kept condition should be given only as its id, not including its source type.
func remove_all_bad_conditions(condition_id_to_keep: Condition.ID = Condition.ID.NULL) -> void:
	_remove_all_of_certain_goodness(condition_id_to_keep, Condition.Goodness.BAD)

## Removes all good conditions except for an optional exception condition that may be specified.
## The optional kept condition should be given only as its id, not including its source type.
func remove_all_good_conditions(condition_id_to_keep: Condition.ID = Condition.ID.NULL) -> void:
	_remove_all_of_certain_goodness(condition_id_to_keep, Condition.Goodness.GOOD)

func _remove_all_of_certain_goodness(id_to_keep: Condition.ID, goodness: Condition.Goodness) -> void:
	for condition_id: Condition.ID in actives_by_id:
		if condition_id == id_to_keep:
			continue
		var source_type: Condition.SourceType = actives_by_id[condition_id].keys().front()
		var ci_to_check: CI = actives_by_id[condition_id][source_type]
		if ci_to_check.condition.goodness == goodness:
			remove_condition_by_source_type(condition_id, source_type)

## Removes all conditions.
func remove_all_conditions() -> void:
	for ci: CI in actives.values():
		_remove_ci(ci)
#endregion


#region Utils
## Returns if any condition (no matter the source type or level) of the passed in id is active.
func check_if_has_condition(condition_id: Condition.ID) -> bool:
	if actives_by_id.has(condition_id):
		return true
	return false

## Returns if the condition and associated source type (no matter the level) is active.
func check_if_has_condition_by_source_type(condition_id: Condition.ID, source_type: Condition.SourceType) -> bool:
	if actives.has([condition_id, source_type]):
		return true
	return false

## Returns true if there is an "untouchable" condition in the current conditions.
func is_untouchable() -> bool:
	return actives_by_id.has(Condition.ID.UNTOUCHABLE)
#endregion


#region Debug
func _debug_print_adding_condition(condition: Condition) -> void:
	if DebugFlags.current_condition_changes and debug_updates:
		if condition.id == Condition.ID.STORM_SYNDROME:
			print_rich("-------[color=green]Adding[/color][b] [color=pink]" + str(condition) + "[/color][/b][color=gray] to " + entity.name + "-------")
		else:
			print_rich("-------[color=green]Adding[/color][b] " + str(condition) + "[/b][color=gray] to " + entity.name + "-------")

func _debug_print_removing_condition(condition: Condition) -> void:
	if DebugFlags.current_condition_changes and debug_updates:
		if condition.id == Condition.ID.STORM_SYNDROME:
			print_rich("-------[color=red]Removed[/color][b] [color=pink]" + str(condition) + "[/color][/b][color=gray] from " + entity.name + "-------")
		else:
			print_rich("-------[color=red]Removed[/color][b] " + str(condition) + "[/b][color=gray] from " + entity.name + "-------")
#endregion
