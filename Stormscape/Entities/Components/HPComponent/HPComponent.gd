@icon("res://Utilities/Debug/EditorIcons/health_component.svg")
extends Node
class_name HPComponent
## A component for handling health and shield for an entity.
##
## Has functions for handling taking damage and healing.
## This class should always remain agnostic about the entity and the entity's UI it updates.

signal health_changed(new_health: int, old_health: int)
signal max_health_changed(new_max_health: int)
signal shield_changed(new_shield: int, old_shield: int)
signal max_shield_changed(new_max_shield: int)
signal armor_changed(new_armor: int)

enum POPUP_CATEGORY { HEALTH, SHIELD } ## The two kinds of popups that this node hosts.

enum POPUP_TYPE { ## The kinds of ways that health and shield values can color and style the popups.
	SHIELD_DAMAGE,
	HEALTH_DAMAGE,
	SHIELD_HEALING,
	HEALTH_HEALING,
	CRIT_DAMAGE,
	BURNING,
	FROSTBITE,
	LIFE_STEAL,
	POISON,
	REGEN,
	STORM_SYNDROME,
	AUTO ## For basic changes that get determined by the sign of the amount.
}

const HEAL_CHANGE_TYPES: Array[POPUP_TYPE] = [POPUP_TYPE.SHIELD_HEALING, POPUP_TYPE.HEALTH_HEALING, POPUP_TYPE.REGEN, POPUP_TYPE.LIFE_STEAL] ## Types in this array indicate that the change was positive.

@export var _max_health: int = 100 ## The maximum amount of health the entity can have.
@export var _max_shield: int = 100 ## The maximum amount of shield the entity can have.
@export_range(0, 100, 1) var base_armor: int = 0 ## The initial percentage of damage deflected.
@export var infinte_hp: bool = false ## When true, the entity cannot run out of health or shield.

@onready var entity: Entity = get_parent() ## The entity this hp component operates on.

const MAX_ARMOR: int = 100 ## The maximum amount of armor the entity can have.
var health: int: set = _set_health ## The current health of the entity.
var shield: int: set = _set_shield ## The current shield of the entity.
var armor: int = 0: set = _set_armor ## The current armor of the entity. This is the percent of dmg that is blocked.
var is_dying: bool = false ## Whether the entity is actively dying or not.
var health_popup: EffectPopup ## The current health popup display that is active and can be updated.
var shield_popup: EffectPopup ## The current shield popup display that is active and can be updated.
var current_sounds: Dictionary[StringName, Array] = {} ## The current sounds being played by this component.

var max_health: int: ## Getter for max_health.
	get: return int(entity.sc.get_stat(&"max_health"))
var max_shield: int: ## Getter for max_shield.
	get: return int(entity.sc.get_stat(&"max_shield"))


#region Setup
func _ready() -> void:
	var moddable_stats: Dictionary[StringName, Array] = {
		&"max_health" : [_max_health, on_max_health_changed], &"max_shield" : [_max_shield, on_max_shield_changed]
	}
	entity.sc.add_moddable_stats_with_associated_callables(moddable_stats)
	call_deferred("_emit_initial_values")

## Called from a deferred method caller in order to let any associated ui ready up first.
## Then it emits the initially loaded values.
func _emit_initial_values() -> void:
	health = max_health
	shield = max_shield
	armor = base_armor
#endregion

#region Taking Damage
## Helper class for returning the resulting new values and how much change was actually used.
class ChangeResult:
	var new_val: int
	var applied: int

	func _init(new_value: int, applied_value: int) -> void:
		new_val = new_value
		applied = applied_value

## Main entry for changing health and shield via damage and healing. Multishot as -1 means it wasn't a multishot.
func change_by_dh_type(amount: int, popup_type: POPUP_TYPE, dh_type: Globals.DHTypes,
							multishot_id: int = -1) -> void:
	if is_dying or amount == 0:
		return

	var remaining: int = amount
	match dh_type:
		Globals.DHTypes.HEALTH_ONLY:
			remaining = _change_health(remaining, popup_type, multishot_id)
		Globals.DHTypes.SHIELD_ONLY:
			remaining = _change_shield(remaining, popup_type, multishot_id)
		Globals.DHTypes.HEALTH_THEN_SHIELD:
			remaining = _change_health(remaining, popup_type, multishot_id)
			remaining = _change_shield(remaining, popup_type, multishot_id)
		Globals.DHTypes.SHIELD_THEN_HEALTH:
			remaining = _change_shield(remaining, popup_type, multishot_id)
			remaining = _change_health(remaining, popup_type, multishot_id)
		Globals.DHTypes.SIMULTANEOUS:
			_change_health(amount, popup_type, multishot_id)
			_change_shield(amount, popup_type, multishot_id)

	if amount < 0:
		_check_for_death()

## Changes the health and spawns the popup, returning how much leftover change there is.
func _change_health(amount: int, popup_type: POPUP_TYPE, _multishot_id: int) -> int:
	var health_result: ChangeResult = _get_result_of_change(health, max_health, amount)
	health = health_result.new_val
	if popup_type == POPUP_TYPE.AUTO:
		popup_type = POPUP_TYPE.HEALTH_DAMAGE if (amount < 0) else POPUP_TYPE.HEALTH_HEALING
	_create_or_update_popup(popup_type, POPUP_CATEGORY.HEALTH, health_result.applied)
	return amount - health_result.applied

## Changes the shield and spawns the popup, returning how much leftover change there is.
func _change_shield(amount: int, popup_type: POPUP_TYPE, multishot_id: int) -> int:
	var shield_result: ChangeResult = _get_result_of_change(shield, max_shield, amount)
	shield = shield_result.new_val
	if popup_type == POPUP_TYPE.AUTO:
		popup_type = POPUP_TYPE.SHIELD_DAMAGE if (amount < 0) else POPUP_TYPE.SHIELD_HEALING
	_create_or_update_popup(popup_type, POPUP_CATEGORY.SHIELD, shield_result.applied)

	if amount < 0:
		_play_sound("shield_hit", multishot_id)

	return amount - shield_result.applied

## Gets the result of applying a numerical change to a current value, returning the same value if
## infinite_hp is on.
func _get_result_of_change(current: int, max_val: int, change: int) -> ChangeResult:
	var new_val: int = clampi(current + change, 0, max_val)
	var change_amount: int = new_val - current

	if infinte_hp:
		new_val = current

	return ChangeResult.new(new_val, change_amount)

#region Death
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

#region Setters & On-Change Funcs
## Setter for the current health. Clamps the new value to the allowed range and updates any connected UI.
func _set_health(new_value: int) -> void:
	var old_health: int = health
	health = clampi(new_value, 0, max_health)
	health_changed.emit(health, old_health)

## Setter for the current shield. Clamps the new value to the allowed range and updates any connected UI.
func _set_shield(new_value: int) -> void:
	var old_shield: int = shield
	shield = clampi(new_value, 0, max_shield)
	shield_changed.emit(shield, old_shield)

## When max health changes, we need to limit the current health value. Usually called by stat mod caches.
func on_max_health_changed(new_max_health: int) -> void:
	health = min(health, new_max_health)
	max_health_changed.emit(new_max_health)

## When max shield changes, we need to limit the current shield value. Usually called by stat mod caches.
func on_max_shield_changed(new_max_shield: int) -> void:
	shield = min(shield, new_max_shield)
	max_shield_changed.emit(new_max_shield)

## Called externally to update the current armor value.
func update_armor(new_armor: int) -> void:
	armor = new_armor

## Setter for the current armor. Clamps the new value to the allowed range.
func _set_armor(new_value: int) -> void:
	armor = clampi(new_value, 0, MAX_ARMOR)
	armor_changed.emit(armor)
#endregion

#region Sound
## Handles playing sounds for this class and respects the fact that multishots should all share a sound.
func _play_sound(sound_name: String, multishot_id: int) -> void:
	var string_name_sound_name: StringName = StringName(sound_name)

	if multishot_id != -1:
		if (string_name_sound_name in current_sounds.keys()) and (multishot_id in current_sounds[string_name_sound_name]):
			return

		var player_inst: AudioPlayerInstance = AudioManager.play_2d(sound_name, entity.global_position, 0, false, -1, Globals.world_root)
		if not player_inst:
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
		AudioManager.add_finish_callable_to_player(player_inst.player, callable)
	else:
		AudioManager.play_2d(sound_name, entity.global_position)
#endregion

#region Popups
## Creates a popup or updates it if it is already created.
func _create_or_update_popup(popup_type: POPUP_TYPE, category: POPUP_CATEGORY, amount: int) -> void:
	if amount == 0:
		return
	if category == POPUP_CATEGORY.HEALTH:
		if health_popup:
			health_popup.update_popup(popup_type, amount)
			health_popup.global_position.x -= 3
			return
	else:
		if shield_popup:
			shield_popup.update_popup(popup_type, amount)
			shield_popup.global_position.x += 3
			return

	var new_popup: EffectPopup = EffectPopup.create_popup(popup_type, amount, entity)
	new_popup.tree_exiting.connect(func() -> void: new_popup.queue_free())
	if category == POPUP_CATEGORY.HEALTH:
		health_popup = new_popup
		health_popup.global_position.x -= 3
	else:
		shield_popup = new_popup
		shield_popup.global_position.x += 3
#endregion

#region Debug
## Increases or decreases hp based on the amount.
func change_hp_by_amount(amount: int) -> void:
	if amount >= 0:
		change_by_dh_type(amount, POPUP_TYPE.AUTO, Globals.DHTypes.HEALTH_THEN_SHIELD)
	else:
		change_by_dh_type(amount, POPUP_TYPE.AUTO, Globals.DHTypes.SHIELD_THEN_HEALTH)
#endregion
