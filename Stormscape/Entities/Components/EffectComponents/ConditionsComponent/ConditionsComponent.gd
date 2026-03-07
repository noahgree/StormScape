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

var actives: Dictionary[Array, int] = {} ## { [id, source] : level }
var actives_by_id: Dictionary[Condition.ID, Dictionary] = {} ## { id : { Condition.SourceType : level } }
var condition_timers: Dictionary[Array, Timer] = {} ## Holds references to all timers currently tracking active conditions. { [id, source] : timer }


#region Core
## Assert that this node has a connected esi receiver from which it can receive conditions.
func _ready() -> void:
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
	if (not _check_filter(condition)) or (entity.invulnerable):
		return

	_debug_print_adding_condition(condition)

	var key: Array = condition.get_key()
	if key in actives:
		var existing_lvl: int = actives[key]
		if existing_lvl > condition.level: # New condition is lower lvl
			_extend_condition_duration(condition, existing_lvl)
		elif existing_lvl < condition.effect_lvl: # New condition is higher lvl
			_remove_condition(condition)
			_add_condition(condition)
		else: # New condition is same lvl
			_restart_condition_duration(condition)
	else:
		_add_condition(condition)

	if (entity is Player) or (not condition.only_cue_on_player_hit):
		AudioManager.play_2d(condition.audio_to_play, entity.global_position)

func _check_filter(condition: Condition) -> bool:
	match filter:
		Filter.NONE:
			return false
		Filter.AUTO:
			return condition.affected_entities & entity.class_type != 0
		Filter.MANUAL:
			var affected: bool = condition.affected_entities & entity.class_type != 0
			return (affected) and (condition.id in manual_filter)
	return false

## Adds a condition to the current effects dict, starts its timer, stores its timer, and applies its mods.
func _add_condition(condition: Condition) -> void:
	if condition.id == Condition.ID.UNTOUCHABLE:
		remove_all_bad_conditions()

	var key: Array = condition.get_key()
	actives[key] = condition.level
	if actives_by_id[condition.id].is_empty():
		actives_by_id[condition.id] = { condition.source_type : condition.level }
	else:
		actives_by_id[condition.id][condition.source_type] = condition.level

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

## Starts the conditions' associated visual FX like particles. Checks if the receiver has the
## matching handler node first.
func _start_condition_fx(condition: Condition) -> void:
	if not condition.spawn_particles:
		return

	if condition.make_entity_glow:
		entity.sprite.update_floor_light(condition.id, false)
		entity.sprite.update_overlay_color(condition.id, false)

	entity.particle_mgr.start_particles(condition.id)

## Removes the condition from the current conditions dict and removes all its mods. Additionally removes its
## associated timer from the timer dict.
func _remove_condition(condition: Condition) -> void:
	_debug_print_removing_condition(condition)

	for mod_resource: StatMod in condition.stat_mods:
		entity.sc.remove_mod(mod_resource.stat_id, mod_resource.mod_id)

	var key: Array = condition.get_key()
	actives.erase(key)
	actives_by_id[condition.id].erase(condition.source_type)
	if actives_by_id[condition.id].is_empty():
		actives_by_id.erase(condition.id)

	var timer: Timer = condition_timers.get(key, null)
	if timer != null:
		if timer.has_meta("on_removal"): # So we can cancel any pending callables before freeing
			var callable: Callable = timer.get_meta("on_removal")
			timer.timeout.disconnect(callable)
			timer.remove_meta("on_removal")
		timer.stop()
		timer.queue_free()
		condition_timers.erase(key)

	_stop_associated_eotis(condition)

	_stop_condition_fx(condition)

## Stops the conditions' associated visual FX like particles.
func _stop_condition_fx(condition: Condition) -> void:
	entity.sprite.update_floor_light(condition.id, true)
	entity.sprite.update_overlay_color(condition.id, true)

	# Only remove all FX if there are no more instances of the same condition ID
	var conditions: Dictionary[Condition.SourceType, int] = actives_by_id.get(condition.id, null)
	if (conditions == null) or (conditions.keys().size() > 1):
		return

	entity.particle_mgr.stop_particles(condition.id)

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

func remove_condition_by_source_type(condition_id: Condition.ID, source_type: Condition.SourceType) -> void:
	var condition_level: int = actives.get([condition_id, source_type], -1)
	if condition_level != -1:
		var condition: Condition = cache.get([condition_id, source_type, condition_level])
		_remove_condition(condition)

## Attempts to remove all conditions of the matching id, regardless of source type.
func remove_condition_for_all_sources(condition_id: Condition.ID) -> void:
	var conditions_of_id: Dictionary[Condition.SourceType, int] = actives_by_id.get(condition_id, null)
	if conditions_of_id == null:
		return

	var to_erase: Array[Condition] = []
	for source_type: Condition.SourceType in conditions_of_id:
		var condition: Condition = cache.get([condition_id, source_type], null)
		if condition == null:
			continue
		to_erase.append(condition)

	for effect: Condition in to_erase:
		_remove_condition(effect)

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
		var key_to_check: Array = [condition_id, source_type, actives[[condition_id, source_type]]]
		var condition_to_check: Condition = cache.get(key_to_check, null)
		if (condition_to_check) and (condition_to_check.goodness == goodness):
			remove_condition_by_source_type(condition_id, source_type)

## Removes all conditions.
func remove_all_conditions() -> void:
	for condition: Condition in actives.values():
		_remove_condition(condition)

## Returns true if there is an "untouchable" condition in the current conditions.
func is_untouchable() -> bool:
	return actives_by_id.has(Condition.ID.UNTOUCHABLE)

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
