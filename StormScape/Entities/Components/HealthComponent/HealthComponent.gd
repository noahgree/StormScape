@icon("res://Utilities/Debug/EditorIcons/health_component.svg")
extends Node
class_name HealthComponent
## A component for handling health and shield for an entity.
##
## Has functions for handling taking damage and healing.
## This class should always remain agnostic about the entity and the entity's UI it updates.

signal health_changed(new_health: int, old_health: int)
signal max_health_changed(new_max_health: int)
signal shield_changed(new_shield: int, old_shield: int)
signal max_shield_changed(new_max_shield: int)
signal armor_changed(new_armor: int)

@export var _max_health: int = 100 ## The maximum amount of health the entity can have.
@export var _max_shield: int = 100 ## The maximum amount of shield the entity can have.
@export_range(0, 100, 1) var base_armor: int = 0 ## The initial percentage of damage deflected.
@export var infinte_hp: bool = false ## When true, the entity cannot run out of health or shield.

@onready var entity: Entity = get_parent() ## The entity this health component operates on.

var health: int: set = _set_health ## The current health of the entity.
var shield: int: set = _set_shield ## The current shield of the entity.
var armor: int = 0: set = _set_armor ## The current armor of the entity. This is the percent of dmg that is blocked.
var is_dying: bool = false ## Whether the entity is actively dying or not.
var current_popup: EffectPopup ## The current effect popup display that is active and can be updated.
var current_sounds: Dictionary[StringName, Array] = {} ## The current sounds being played by this component.
var just_loaded: bool = false ## When true, we shouldn't emit initial values.
const MAX_ARMOR: int = 100 ## The maximum amount of armor the entity can have.


#region Setup
func _ready() -> void:
	var moddable_stats: Dictionary[StringName, Array] = {
		&"max_health" : [_max_health, on_max_health_changed], &"max_shield" : [_max_shield, on_max_shield_changed]
	}
	entity.stats.add_moddable_stats_with_associated_callables(moddable_stats)
	call_deferred("_emit_initial_values")

## Called from a deferred method caller in order to let any associated ui ready up first.
## Then it emits the initially loaded values.
func _emit_initial_values() -> void:
	if just_loaded:
		_set_health(health)
		_set_shield(shield)
		_set_armor(armor)
	else:
		health = int(entity.stats.get_stat("max_health"))
		shield = int(entity.stats.get_stat("max_shield"))
		armor = base_armor
#endregion

#region Utils: Taking Damage
## Takes damage to both health and shield, starting with available shield then applying any remaining
## amount to health.
func damage_shield_then_health(amount: int, source_type: String, was_crit: bool, multishot_id: int) -> void:
	if amount > 0 and not is_dying:
		if shield > 0:
			var src_type: String = source_type if source_type != "basic_damage" else "shield_damage"
			_create_or_update_popup_for_src_type(src_type, false, was_crit, min(shield, amount))
			_play_sound("shield_hit", multishot_id)
		if amount - shield > 0:
			var src_type: String = source_type if source_type != "basic_damage" else "health_damage"
			_create_or_update_popup_for_src_type(src_type, false, was_crit, (amount - shield))

	if infinte_hp:
		return

	var spillover_damage: int = max(0, amount - shield)
	shield = int(max(0, shield - amount))

	if spillover_damage > 0:
		health = int(max(0, health - spillover_damage))
	_check_for_death()

## Decrements only the health value by the passed in amount.
func damage_health(amount: int, source_type: String, was_crit: bool, _multishot_id: int) -> void:
	if not is_dying:
		var src_type: String = source_type if source_type != "basic_damage" else "health_damage"
		_create_or_update_popup_for_src_type(src_type, false, was_crit, min(health, amount))
		if not infinte_hp:
			health = max(0, health - amount)
		_check_for_death()

## Decrements only the shield value by the passed in amount.
func damage_shield(amount: int, source_type: String, was_crit: bool, multishot_id: int) -> void:
	if not is_dying:
		var src_type: String = source_type if source_type != "basic_damage" else "shield_damage"
		_create_or_update_popup_for_src_type(src_type, false, was_crit, min(shield, amount))
		if not infinte_hp:
			shield = max(0, shield - amount)
		if amount > 0:
			_play_sound("shield_hit", multishot_id)

## Handles what happens when health reaches 0 for the entity.
func _check_for_death() -> void:
	if health <= 0 and not is_dying:
		is_dying = true
		var loot_table: LootTableResource = entity.loot
		if loot_table != null:
			loot_table.handle_death()

		if entity.has_method("die"):
			entity.die()
		else:
			entity.queue_free()
#endregion

#region Changing Armor
## Called externally to update the current armor value.
func update_armor(new_armor: int) -> void:
	armor = new_armor
#endregion

#region Utils: Applying Healing
## Heals to both health and shield, starting with health then applying any remaining amount to shield.
func heal_health_then_shield(amount: int, source_type: String, _multishot_id: int) -> void:
	if not is_dying:
		var max_health: int = int(entity.stats.get_stat("max_health"))
		var max_shield: int = int(entity.stats.get_stat("max_shield"))

		if health < max_health:
			var src_type: String = source_type if source_type != "basic_healing" else "health_healing"
			var current_total: int = health + shield
			var max_total: int = max_health + max_shield
			_create_or_update_popup_for_src_type(src_type, true, false, min((max_total - current_total), amount))
		else:
			var src_type: String = source_type if source_type != "basic_healing" else "shield_healing"
			_create_or_update_popup_for_src_type(src_type, true, false, min(max_shield - shield, amount))

		var spillover_health: int = max(0, (amount + health) - max_health)
		health = clampi(health + amount, 0, max_health)

		if spillover_health > 0:
			shield = clampi(shield + spillover_health, 0, max_shield)

## Heals only health.
func heal_health(amount: int, source_type: String, _multishot_id: int) -> void:
	if not is_dying:
		var max_health: int = int(entity.stats.get_stat("max_health"))
		var src_type: String = source_type if source_type != "basic_healing" else "health_healing"
		_create_or_update_popup_for_src_type(src_type, true, false, min(max_health - health, amount))

		health = min(health + amount, max_health)

## Heals only shield.
func heal_shield(amount: int, source_type: String, _multishot_id: int) -> void:
	if not is_dying:
		var max_shield: int = int(entity.stats.get_stat("max_shield"))
		var src_type: String = source_type if source_type != "basic_healing" else "shield_healing"
		_create_or_update_popup_for_src_type(src_type, true, false, min(max_shield - shield, amount))

		shield = min(shield + amount, max_shield)
#endregion

#region Setters & On-Change Funcs
## Setter for the current health. Clamps the new value to the allowed range and updates any connected UI.
func _set_health(new_value: int) -> void:
	var old_health: int = health
	health = clampi(new_value, 0, int(entity.stats.get_stat("max_health")))
	health_changed.emit(health, old_health)

## Setter for the current shield. Clamps the new value to the allowed range and updates any connected UI.
func _set_shield(new_value: int) -> void:
	var old_shield: int = shield
	shield = clampi(new_value, 0, int(entity.stats.get_stat("max_shield")))
	shield_changed.emit(shield, old_shield)

## Setter for the current armor. Clamps the new value to the allowed range.
func _set_armor(new_value: int) -> void:
	armor = clampi(new_value, 0, MAX_ARMOR)
	armor_changed.emit(armor)

## When max health changes, we need to limit the current health value. Usually called by stat mod caches.
func on_max_health_changed(new_max_health: int) -> void:
	health = min(health, new_max_health)
	max_health_changed.emit(new_max_health)

## When max shield changes, we need to limit the current shield value. Usually called by stat mod caches.
func on_max_shield_changed(new_max_shield: int) -> void:
	shield = min(shield, new_max_shield)
	max_shield_changed.emit(new_max_shield)

## Handles playing sounds for this class and respects the fact that multishots should all share a sound.
func _play_sound(sound_name: String, multishot_id: int) -> void:
	var string_name_sound_name: StringName = StringName(sound_name)

	if multishot_id != -1:
		if (string_name_sound_name in current_sounds.keys()) and (multishot_id in current_sounds[string_name_sound_name]):
			return

		var player: Variant = AudioManager.play_2d(sound_name, entity.global_position, 0, Globals.world_root)
		if not AudioManager.is_player_valid(player):
			return

		if string_name_sound_name in current_sounds.keys():
			current_sounds[string_name_sound_name].append(multishot_id)
		else:
			current_sounds[string_name_sound_name] = [multishot_id]

		var callable: Callable = Callable(func() -> void:
			current_sounds[string_name_sound_name].erase(multishot_id)
			if current_sounds[string_name_sound_name].is_empty():
				current_sounds.erase(string_name_sound_name)
			)
		AudioManager.add_finish_callable_to_player(player, callable)
	else:
		AudioManager.play_2d(sound_name, entity.global_position)
#endregion

#region Popups
func _create_or_update_popup_for_src_type(src_type: String, was_healing: bool, was_crit: bool, amount: int) -> void:
	if amount == 0:
		return

	var source_id_only: String = StringHelpers.get_before_colon(src_type)
	if current_popup:
		current_popup.update_popup(amount, source_id_only, was_crit, was_healing)
	else:
		var new_popup: EffectPopup = EffectPopup.create_popup(source_id_only, was_healing, was_crit, amount, entity)
		new_popup.tree_exiting.connect(func() -> void: new_popup.queue_free())
		current_popup = new_popup
#endregion

#region Debug
## Increases or decreases hp based on the amount.
func change_hp_by_amount(amount: int) -> void:
	if amount >= 0:
		heal_health_then_shield(amount, "basic_healing", 0)
	else:
		damage_shield_then_health(-amount, "basic_damage", false, 0)
#endregion
