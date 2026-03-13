@icon("res://Utilities/Debug/EditorIcons/status_effect_component.svg")
extends Node2D
class_name ConditionsComponent
## The component that holds the stats and logic for how the entity should receive conditions.
##
## This handles things like fire & poison damage not taking into account armor, etc.

enum Filter { ## The different ways to filter out incoming conditions.
	AUTO, ## Only allow conditions this entity can receive based on entity type.
	MANUAL_ALLOW, ## Follows entity type restrictions like AUTO, but the incoming condition must also be part of the "manual filter" array.
	MANUAL_BLOCK, ## Follows entity type restrictions like AUTO, but the incoming condition must also not be part of the "manual filter" array.
	NONE ## For when this entity cannot receive any conditions.
}

static var cache: Dictionary[Array, Condition] = {} ## A cache of all conditions. { [id, source, level] : condition }
static var path: String = "res://Entities/Components/ConditionsComponent/Conditions/" ## Path to conditions root folder for caching.

@export var debug_updates: bool = false ## Whether to print when this entity has conditions added and removed.
@export var filter: Filter = Filter.AUTO ## The way we should filter out incoming conditions.
@export var manual_filter: Array[Condition.ID] ## The conditions the owning entity can have.

@onready var entity: Entity = owner ## The entity affected by these conditions.
@onready var esi_receiver: ESIReceiverComponent = entity.esi_receiver ## The ESI receiver that sends conditions to this manager to be cached and handled.

const PROCESS_INTERVAL: float = 0.1 ## How often we should process the CIs. Helps with performance.

var actives: Dictionary[Array, Array] = {} ## { [id, source] : [CI] } Higher indices are higher levels.
var actives_by_id: Dictionary[Condition.ID, Dictionary] = {} ## { id : { Condition.SourceType : [CI] } } CIs not ordered.
var actives_by_esi_uid: Dictionary[int, Array] = {} ## { esi_source_uid: [CI } CIs not ordered.
var tick_accumulator: float ## Tracks time since last tick.


## Assert that this node has a connected esi receiver from which it can receive conditions.
func _ready() -> void:
	set_process(false) # Wait until we have an active CI to start processing

	if ConditionsComponent.cache.is_empty():
		_cache_conditions(path)

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
		for ci_array: Array in actives.values():
			for ci: CI in ci_array:
				ci.process(PROCESS_INTERVAL)

#region Adding Conditions
func handle_conditions_in_esi(esi: ESI) -> void:
	var bad_effects_to_enemies: bool = ESI.can_hit_enemy_with_bad(entity.team, esi)
	var bad_effects_to_allies: bool = ESI.can_hit_ally_with_bad(entity.team, esi)
	var good_effects_to_enemies: bool = ESI.can_hit_enemy_with_good(entity.team, esi)
	var good_effects_to_allies: bool = ESI.can_hit_ally_with_good(entity.team, esi)

	for condition: Condition in esi.conditions:
		if condition.id not in Condition.GOOD_CONDITIONS:
			if bad_effects_to_allies or bad_effects_to_enemies:
				_process_condition(condition, esi)
		else:
			if good_effects_to_allies or good_effects_to_enemies:
				_process_condition(condition, esi)

## Handles an incoming condition. It starts by adding any stat mods provided by the condition, and then
## it passes the condition logic to the relevant handler if it exists.
func _process_condition(condition: Condition, esi: ESI) -> void:
	# --- Checking Filter & Entity Invulnerability & Untouchability ---
	if (not _check_filter(condition)) or (entity.invulnerable):
		return
	if (condition.id not in Condition.GOOD_CONDITIONS) and (is_untouchable()):
		return

	# --- Stopping Conditions The New Condition Stops ---
	for condition_id_to_stop: Condition.ID in condition.conditions_to_stop:
		remove_condition_for_all_sources(condition_id_to_stop)

	# --- Debug Print the Addition ---
	_debug_print_adding_condition(condition)

	# --- Calling the On Received Regardless Function ---
	condition.on_received_regardless_of_level(esi, entity)

	# --- Adding the CI ---
	_add_ci(condition, esi)

	# --- Playing Hit Sound ---
	if (entity is Player) or (not condition.only_cue_on_player_hit):
		AudioManager.play_2d(condition.audio_to_play, entity.global_position)

func _check_filter(condition: Condition) -> bool:
	match filter:
		Filter.NONE:
			return false
		Filter.AUTO:
			return condition.affected_entities & entity.class_type != 0
		Filter.MANUAL_ALLOW:
			var affected: bool = condition.affected_entities & entity.class_type != 0
			return (affected) and (condition.id in manual_filter)
		Filter.MANUAL_BLOCK:
			var affected: bool = condition.affected_entities & entity.class_type != 0
			return (affected) and (condition.id not in manual_filter)
	return false

func _add_ci(condition: Condition, esi: ESI) -> void:
	var ci: CI = CI.new(condition, esi.source_entity, esi.source_ii, esi.uid)
	ci.affected_entity = entity
	ci.condition_expired.connect(_remove_ci)

	var condition_key: Array = condition.get_key()
	if actives.has(condition_key):
		_remove_mods_added_by_condition(actives[condition_key].back())

		actives[condition_key].push_back(ci)
		actives[condition_key].sort_custom(func(a: CI, b: CI) -> bool: return a.condition.level < b.condition.level)
	else:
		actives[condition_key] = [ci]

	_add_mods_added_by_condition(actives[condition_key].back())
	_start_condition_fx(actives[condition_key].back())

	if actives_by_id.has(condition.id):
		if actives_by_id[condition.id].has(condition.source_type):
			actives_by_id[condition.id][condition.source_type].append(ci)
		else:
			actives_by_id[condition.id][condition.source_type] = [ci]
	else:
		actives_by_id[condition.id] = { condition.source_type : [ci] }

	if actives_by_esi_uid.has(esi.uid):
		actives_by_esi_uid[esi.uid].append(ci)
	else:
		actives_by_esi_uid[esi.uid] = [ci]

	set_process(true)

func _add_mods_added_by_condition(ci: CI) -> void:
	if ci == null:
		return
	for mod_resource: StatMod in ci.condition.eot_stats.stat_mods:
		entity.sc.add_mods([mod_resource] as Array[StatMod])

## Starts the condition's associated visual FX like particles.
func _start_condition_fx(ci: CI) -> void:
	if ci.condition.make_entity_glow:
		entity.sprite.update_floor_light(ci.condition.id, false)
		entity.sprite.update_overlay_color(ci.condition.id, false)
	if ci.condition.spawn_particles:
		entity.particle_mgr.start_particles(ci.condition.id)
#endregion


#region Removing Conditions
func _remove_ci(ci: CI) -> void:
	_debug_print_removing_condition(ci.condition)

	var condition_key: Array = ci.condition.get_key()
	_remove_mods_added_by_condition(actives[condition_key].back())
	actives[condition_key].erase(ci)
	_add_mods_added_by_condition(actives[condition_key].back() if not actives[condition_key].is_empty() else null)
	if actives[condition_key].is_empty():
		actives.erase(condition_key)

	actives_by_id[ci.condition.id][ci.condition.source_type].erase(ci)
	if actives_by_id[ci.condition.id][ci.condition.source_type].is_empty():
		actives_by_id[ci.condition.id].erase(ci.condition.source_type)
		if actives_by_id[ci.condition.id].is_empty():
			actives_by_id.erase(ci.condition.id)
			_stop_particle_fx(ci)

	actives_by_esi_uid[ci.source_esi_uid].erase(ci)
	if actives_by_esi_uid[ci.source_esi_uid].is_empty():
		actives_by_esi_uid.erase(ci.source_esi_uid)

	_stop_floor_light_fx(ci)

	if actives.is_empty():
		set_process(false)

func _remove_mods_added_by_condition(ci: CI) -> void:
	if ci == null:
		return
	for mod_resource: StatMod in ci.condition.eot_stats.stat_mods:
		entity.sc.remove_mod(mod_resource.stat_id, mod_resource.mod_id)

func _stop_floor_light_fx(ci: CI) -> void:
	if ci == null:
		return
	entity.sprite.update_floor_light(ci.condition.id, true)
	entity.sprite.update_overlay_color(ci.condition.id, true)

func _stop_particle_fx(ci: CI) -> void:
	if ci == null:
		return
	entity.particle_mgr.stop_particles(ci.condition.id)

func remove_condition_by_source_type(condition_id: Condition.ID, source_type: Condition.SourceType) -> void:
	var existing_cis: Array = actives.get([condition_id, source_type], [])
	for existing_ci: CI in existing_cis:
		_remove_ci(existing_ci)

## Attempts to remove all CIs of the matching condition id, regardless of source type.
func remove_condition_for_all_sources(condition_id: Condition.ID) -> void:
	if condition_id not in actives_by_id:
		return

	var to_erase: Array[CI] = []
	for source_type: Condition.SourceType in actives_by_id[condition_id]:
		var ci_array: Array = actives_by_id[condition_id][source_type]
		for ci: CI in ci_array:
			to_erase.append(ci)

	for ci: CI in to_erase:
		_remove_ci(ci)

func remove_conditions_by_esi_uid(esi_uid: int) -> void:
	var to_erase: Array[CI] = []
	for ci: CI in actives_by_esi_uid.get(esi_uid, []):
		to_erase.append(ci)

	for ci: CI in to_erase:
		_remove_ci(ci)

## Removes all conditions of a certain goodness except for an optional exception id that may be specified.
## The optional kept condition should be given only as its id, not including its source type.
func remove_all_of_certain_goodness(id_to_keep: Condition.ID, goodness: Condition.Goodness) -> void:
	for condition_id: Condition.ID in actives_by_id:
		if condition_id == id_to_keep:
			continue
		var source_type: Condition.SourceType = actives_by_id[condition_id].keys().front()
		var ci_to_check: CI = actives_by_id[condition_id][source_type].back()
		if goodness == Condition.Goodness.GOOD:
			if ci_to_check.condition.id in Condition.GOOD_CONDITIONS:
				remove_condition_by_source_type(condition_id, source_type)
		else:
			if ci_to_check.condition.id not in Condition.GOOD_CONDITIONS:
				remove_condition_by_source_type(condition_id, source_type)

## Removes all conditions.
func remove_all_conditions() -> void:
	for ci_array: Array[CI] in actives.values():
		for ci: CI in ci_array:
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
			print_rich("------- [color=green]Adding[/color][b] [color=pink]" + str(condition) + "[/color][/b][color=gray] to " + entity.name + " -------")
		else:
			print_rich("------- [color=green]Adding[/color][b] " + str(condition) + "[/b][color=gray] to " + entity.name + " -------")

func _debug_print_removing_condition(condition: Condition) -> void:
	if DebugFlags.current_condition_changes and debug_updates:
		if condition.id == Condition.ID.STORM_SYNDROME:
			print_rich("------- [color=red]Removed[/color][b] [color=pink]" + str(condition) + "[/color][/b][color=gray] from " + entity.name + " -------")
		else:
			print_rich("------- [color=red]Removed[/color][b] " + str(condition) + "[/b][color=gray] from " + entity.name + " -------")
#endregion
