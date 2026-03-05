@icon("res://Utilities/Debug/EditorIcons/status_effect_component.svg")
extends Node2D
class_name ConditionsComponent
## The component that holds the stats and logic for how the entity should receive conditions.
##
## This handles things like fire & poison damage not taking into account armor, etc.

static var cache: Dictionary[Array, Condition] = {} ## A cache of all conditions. { [id, source, level] : condition }

@export var allowed_conditions: Dictionary[Condition.ID, bool] ## The conditions the owning entity can have.
@export var debug_updates: bool = false ## Whether to print when this entity has conditions added and removed.

@onready var entity: Entity = owner ## The entity affected by these conditions.
@onready var esi_receiver: ESIReceiverComponent = entity.esi_receiver ## The ESI receiver that sends conditions to this manager to be cached and handled.

var active: Dictionary[Array, int] = {} ## { [id, source] : level }
var active_by_id: Dictionary[Condition.ID, Dictionary] = {} ## { id : { Condition.SourceType : level } }
var condition_timers: Dictionary[Array, Timer] = {} ## Holds references to all timers currently tracking active conditions. { [id, source] : timer }


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

	_stop_condition_fx(condition)

## Stops the conditions' associated visual FX like particles.
func _stop_condition_fx(condition: Condition) -> void:
	entity.sprite.update_floor_light(condition.id, true)
	entity.sprite.update_overlay_color(condition.id, true)

	var actives: Dictionary[Condition.SourceType, int] = active_by_id.get(condition.id, null)
	if (actives == null) or (actives.keys().size() > 1):
		return

	entity.particle_mgr.stop_particles(condition.id)

## Returns if any condition (no matter the source type or level) of the passed in id is active.
func check_if_has_condition(condition_id: Condition.ID) -> bool:
	if active_by_id.has(condition_id):
		return true
	return false

## Returns if the condition and associated source type (no matter the level) is active.
func check_if_has_condition_by_source_type(condition_id: Condition.ID, source_type: Condition.SourceType) -> bool:
	if active.has([condition_id, source_type]):
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

## Attempts to remove all conditions of the matching id, regardless of source type.
func request_condition_removal_for_all_sources(condition_id: Condition.ID) -> void:
	var conditions_of_id: Dictionary[Condition.SourceType, int] = active_by_id.get(condition_id, null)
	if conditions_of_id == null:
		return

	var to_erase: Array[Condition] = []
	for source_type: Condition.SourceType in conditions_of_id:
		var condition: Condition = cache.get([condition_id, source_type], null)
		if condition == null:
			continue
		to_erase.append(condition)
		_cancel_over_time_effects([condition_id, source_type])

	for effect: Condition in to_erase:
		_remove_condition(effect)

## Sends the cancellation requests for a composite condition key.
func _cancel_over_time_effects(condition_key: Array) -> void:
	if esi_receiver.dh_handler != null:
		esi_receiver.dh_handler.cancel_over_time_dmg(key_to_cancel)
	if esi_receiver.heal_handler != null:
		esi_receiver.heal_handler.cancel_over_time_heal(key_to_cancel)

## Removes all bad conditions except for an optional exception condition that may be specified.
## The optional kept condition should be given only as its id, not including its source type.
func remove_all_bad_conditions(effect_to_keep_id: Condition.ID = Condition.ID.NULL) -> void:
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

## Returns true if there is an "untouchable" condition in the current conditions.
func is_untouchable() -> bool:
	return active_by_id.has(Condition.ID.UNTOUCHABLE)

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
