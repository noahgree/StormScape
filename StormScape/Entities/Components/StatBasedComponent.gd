extends Node
class_name StatBasedComponent
## A base class for components that handle moddable stats. 
##
## Used for things like health components with moddable values like max health. 

@export var stats_ui: Control ## The optional UI that will reflect this component's values.
@export var stat_mods: Dictionary = {} ## The catalog of EntityStatMods per stat. Does not store current calculated values. [b]DO NOT EDIT[/b] this in the export panel. This is only 'exported' for easy debugging in remote branch.
var cached_stats: Dictionary = {} ## The up-to-date and calculated stats to be used by anything that depend on them.
var base_values: Dictionary = {} ## The unchanging base values of each moddable stat, usually set by copying the exported values from the component into a dictionary that is passed into the setup function below. 


## Sets up the base values dict and calculates initial values based on any already present mods. 
func add_moddable_stats(base_valued_stats: Dictionary) -> void:
	for stat_id in base_valued_stats.keys():
		var base_value = base_valued_stats[stat_id]
		stat_mods[stat_id] = {}
		base_values[stat_id] = base_value
		_recalculate_stat(stat_id, base_value)

## Recalculates a cached stat. Usually called once something has changed like from an update or removal.
func _recalculate_stat(stat_id: String, base_value: float) -> void:
	var mods: Array = stat_mods[stat_id].values()
	mods.sort_custom(_compare_by_priority)
	
	var result: float = base_value
	for mod in mods:
		if mod.override_all:
			result = mod.apply(base_value, base_value)
			break
		result = mod.apply(base_value, result)
	
	cached_stats[stat_id] = max(0, result)
	print_rich("[color=cyan]" + stat_id + ":[/color] [b]" + str(cached_stats[stat_id]) + "[/b]")
	_update_ui_for_stat(stat_id, result)

## Updates an optionally connected UI when a watched stat changes.
func _update_ui_for_stat(stat_id: String, new_value: float):
	var method_name = "on_" + stat_id + "_changed"
	if stats_ui:
		if stats_ui.has_method(method_name):
			stats_ui.call_deferred("call", method_name, new_value)
	if self.has_method(method_name):
		self.call_deferred("call", method_name, new_value)

## Compares stats to be applied in a certain order based on priority. Useful for if you want a stat
## to multiply the base value before another stat tries to add a constant to it.
func _compare_by_priority(a: EntityStatMod, b: EntityStatMod) -> int:
	return a.priority - b.priority

## Updates a mod's value by a given mod_id that must exist on a given stat_id. 
## This will automatically update any stacking as well.
func update_mod_by_id(stat_id: String, mod_id: String, new_value: float) -> void:
	var existing_mod: EntityStatMod = _get_mod(stat_id, mod_id)
	if existing_mod:
		existing_mod.before_stack_value = new_value
		if existing_mod.can_stack:
			_recalculate_mod_value_with_new_stack_count(existing_mod)
		else:
			existing_mod.value = existing_mod.before_stack_value
		
		_recalculate_stat(stat_id, base_values[stat_id])

## Adds mods to a stat. Handles logic for stacking if the mod can stack.
func add_mods(mod_array: Array[EntityStatMod]) -> void:
	for mod in mod_array:
		if mod.stat_id in stat_mods:
			var existing_mod: EntityStatMod = stat_mods[mod.stat_id].get(mod.mod_id, null)
			if existing_mod and existing_mod.can_stack:
				if existing_mod.stack_count < existing_mod.max_stack_count:
					existing_mod.stack_count += 1
					_recalculate_mod_value_with_new_stack_count(existing_mod)
				else:
					continue
			else:
				mod.before_stack_value = mod.value
				stat_mods[mod.stat_id][mod.mod_id] = mod
			
			_recalculate_stat(mod.stat_id, base_values[mod.stat_id])
		else:
			_push_mod_not_found_error(mod.stat_id, mod.mod_id)

## Removes a mod from a stat. If it has been stacked, it removes the number of instances specified by the count.
func remove_mod(stat_id: String, mod_id: String, count: int = 0) -> void:
	var existing_mod: EntityStatMod = _get_mod(stat_id, mod_id)
	if existing_mod:
		if count == 0:
			stat_mods[stat_id].erase(mod_id)
		elif existing_mod.can_stack:
			existing_mod.stack_count = max(0, existing_mod.stack_count - count)
			_recalculate_mod_value_with_new_stack_count(existing_mod)
			
			if existing_mod.stack_count <= 0:
				stat_mods[stat_id].erase(mod_id)
		
		_recalculate_stat(stat_id, base_values[stat_id])


func _recalculate_mod_value_with_new_stack_count(mod: EntityStatMod) -> void:
	if mod.operation == "*" or mod.operation == "/":
		mod.value = pow(mod.before_stack_value, mod.stack_count)
	else:
		mod.value = mod.before_stack_value * mod.stack_count
		print(mod.before_stack_value)

## Undoes any stacking applied to a mod, setting it back to as if there was only one instance active.
func undo_mod_stacking(stat_id: String, mod_id: String) -> void:
	var existing_mod: EntityStatMod = _get_mod(stat_id, mod_id)
	if existing_mod:
		existing_mod.stack_count = 1
		existing_mod.value = existing_mod.before_stack_value
		
		_recalculate_stat(stat_id, base_values[stat_id])

## Gets the current cached value of a stat.
func get_stat(stat_id: String) -> float:
	var value = cached_stats.get(stat_id, null)
	assert(value != null, stat_id + " was null when trying to be accessed from a StatBasedComponent")
	return value

## Gets the EntityStatMod for the stat_id based on the mod_id. Pushes an error if it can't be found.
func _get_mod(stat_id: String, mod_id: String) -> EntityStatMod:
	if stat_id in stat_mods and mod_id in stat_mods[stat_id]:
		return stat_mods[stat_id].get(mod_id, null)
	else:
		_push_mod_not_found_error(stat_id, mod_id)
		return null

## Pushes an error to the console with the stat id and the mod id for the mod that could not be found.
func _push_mod_not_found_error(stat_id: String, mod_id: String) -> void:
	push_error("The mod for stat \"" + stat_id + "\"" + " with mod_id of: \"" + mod_id + "\" was not in the cache. Check the stat id and the mod id.")
