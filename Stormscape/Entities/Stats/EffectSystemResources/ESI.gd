extends Resource
class_name ESI
## ESI stands for Effect Source Instance, and it acts as a wrapper over instances of effect sources
## that originate from entities and items.

@export var es: EffectSource: set = _set_es ## The effect source that this wraps.
var es_stat_overrides: Dictionary[StringName, float] ## The overrides to use instead when accessing stats from the es.
var conditions: Array[Condition] ## The modifiable list of conditions for the effect source.
var source_entity: Entity: set = _set_source_entity, get = _get_source_entity ## The entity that produced this ESI.
var source_entity_team: Globals.Teams = Globals.Teams.PLAYER ## A local copy of the last known source entity's team. Stored in case the source entity is freed but we still need the team it was on.
var source_ii: II: set = _set_source_ii, get = _get_source_ii ## The item instance that produced this ESI.
var source_ii_lvl: int = 1 ## A local copy of the last known source II's level. Stored in case the source II is freed but we still need the level it was at. Always set to 1 if the source II was not a weapon.
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

## Called externally to set both at the same time.
func set_source_info(src_entity: Entity, src_ii: II) -> void:
	source_entity = src_entity
	source_ii = src_ii

## Sets the last known source entity team when the source entity gets set.
func _set_source_entity(new_source_entity: Entity) -> void:
	source_entity = new_source_entity
	if source_entity:
		source_entity_team = source_entity.team

## Gets and returns the source entity, but only if it is still valid and has not been freed.
func _get_source_entity() -> Entity:
	if source_entity and is_instance_valid(source_entity):
		return source_entity
	return null

## Sets the last known source II level when the source II gets set. If the II is not a weapon, set the
## level to 1.
func _set_source_ii(new_source_ii: II) -> void:
	source_ii = new_source_ii
	if (source_ii) and (source_ii is WeaponII):
		source_ii_lvl = source_ii.level
	else:
		source_ii_lvl = 1

## Gets and returns the source II, but only if it is still valid and has not been freed.
func _get_source_ii() -> II:
	if source_ii and is_instance_valid(source_ii):
		return source_ii
	return null

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
