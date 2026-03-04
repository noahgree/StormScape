extends Resource
class_name ESI
## ESI stands for Effect Source Instance, and it acts as a wrapper over instances of effect sources
## that originate from entities and items.

@export var es: EffectSource: set = _set_es ## The effect source that this wraps.
var es_stat_overrides: Dictionary[StringName, float] ## The overrides to use instead when accessing stats from the es.
var conditions: Array[Condition] ## The modifiable list of conditions for the effect source.
var contact_position: Vector2 ## The position of what the effect source is attached to when it makes contact with a receiver.
var movement_direction: Vector2 ## The direction vector of this effect source at contact used for knockback.
var multishot_id: int = -1 ## The id used to relate multishot projectiles with each other. -1 means it did not come from a multishot.


## Sets the new effect source by clearing the old local conditions array and copying all new status
## effects into it.
func _set_es(new_es: EffectSource) -> void:
	es = new_es
	reset_conditions()

## Resets the modifiable conditions array back to the original ones in the es.
func reset_conditions() -> void:
	conditions.clear()
	if es != null:
		conditions.assign(es.conditions)

## Duplicates and returns this ESI with the stat override and condition arrays duplicated.
func copy() -> ESI:
	var new: ESI = self.duplicate()
	new.es_stat_overrides = es_stat_overrides.duplicate()
	new.conditions = conditions.duplicate()
	return new

## Gets a stat, either from the overrides if present or just the base version in the original effect source.
func get_stat(stat_id: StringName) -> float:
	if stat_id in es_stat_overrides:
		return es_stat_overrides[stat_id]
	return es.get(stat_id)

## Gets the original, unmodified stat from the effect source inside this instance.
func get_original_stat(stat_id: StringName) -> float:
	return es.get(stat_id)

## Gets an existing effect index that matches the full effect key (type and source), regardless of level.
## Does not handle duplicates.
func get_existing_effect_index(full_effect_key: StringName) -> int:
	var i: int = 0
	for condition: Condition in conditions:
		if condition.get_full_effect_key() == full_effect_key:
			return i
		i += 1
	return -1

## Replaces or adds all incoming conditions depending on whether they already exist.
func replace_or_add_conditions(new_effects: Array[Condition]) -> void:
	for new_effect: Condition in new_effects:
		var existing_index: int = get_existing_effect_index(new_effect.get_full_effect_key())
		if existing_index > -1:
			if (new_effect.effect_lvl > conditions[existing_index].effect_lvl):
				conditions[existing_index] = new_effect
		else:
			conditions.append(new_effect)
