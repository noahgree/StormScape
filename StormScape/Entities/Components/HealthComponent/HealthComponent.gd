@icon("res://Utilities/Debug/EditorIcons/health_component.svg")
extends Node
class_name HealthComponent
## A component for handling health and shield for an entity.
##
## Has functions for handling taking damage and healing.
## This class should always remain agnostic about the entity and the entity's UI it updates.

@export var stats_ui: Control
@export var _max_health: int = 100 ## The maximum amount of health the entity can have.
@export var _max_shield: int = 100 ## The maximum amount of shield the entity can have.
@export_range(0, 100, 1) var base_armor: int = 0

var health: int: set = _set_health ## The current health of the entity.
var shield: int: set = _set_shield ## The current shield of the entity.
var armor: int = 0: set = _set_armor ## The current armor of the entity. This is the percent of dmg that is blocked.
const MAX_ARMOR: int = 100 ## The maximum amount of armor the entity can have.


#region Setup
func _ready() -> void:
	var moddable_stats: Dictionary = {
		"max_health" : _max_health, "max_shield" : _max_shield
	}
	get_parent().stats.add_moddable_stats(moddable_stats)
	call_deferred("_emit_initial_values")

## Called from a deferred method caller in order to let any associated ui ready up first.
## Then it emits the initially loaded values.
func _emit_initial_values() -> void:
	@warning_ignore("narrowing_conversion") health = get_parent().stats.get_stat("max_health")
	@warning_ignore("narrowing_conversion") shield = get_parent().stats.get_stat("max_shield")
	armor = base_armor
#endregion

#region Utils: Taking Damage
## Takes damage to both health and shield, starting with available shield then applying any remaining amount to health.
func damage_shield_then_health(amount: int, was_crit: bool = false) -> void:
	if amount > 0:
		if shield > 0:
			EffectPopup.create_popup(EffectPopup.PopupTypes.CRIT_DMG if was_crit else EffectPopup.PopupTypes.SHIELD_DMG, amount, get_parent())
			_play_shield_damage_sound()
		else:
			EffectPopup.create_popup(EffectPopup.PopupTypes.CRIT_DMG if was_crit else EffectPopup.PopupTypes.HEALTH_DMG, amount, get_parent())
	var spillover_damage: int = max(0, amount - shield)
	@warning_ignore("narrowing_conversion") shield = clampi(shield - amount, 0, get_parent().stats.get_stat("max_shield"))

	if spillover_damage > 0:
		@warning_ignore("narrowing_conversion") health = clampi(health - spillover_damage, 0, get_parent().stats.get_stat("max_health"))
	_check_for_death()

## Decrements only the health value by the passed in amount.
func damage_health(amount: int, was_crit: bool = false) -> void:
	health = max(0, health - amount)
	EffectPopup.create_popup(EffectPopup.PopupTypes.CRIT_DMG if was_crit else EffectPopup.PopupTypes.HEALTH_DMG, amount, get_parent())
	_check_for_death()

## Decrements only the shield value by the passed in amount.
func damage_shield(amount: int, was_crit: bool = false) -> void:
	shield = max(0, shield - amount)
	EffectPopup.create_popup(EffectPopup.PopupTypes.CRIT_DMG if was_crit else EffectPopup.PopupTypes.SHIELD_DMG, amount, get_parent())
	if amount > 0: _play_shield_damage_sound()

## Handles what happens when health reaches 0 for the entity.
func _check_for_death() -> void:
	if health <= 0:
		var loot_table: LootTableComponent = get_parent().get_node_or_null("LootTableComponent")
		if loot_table != null: loot_table.handle_death()

		if get_parent().has_method("die"):
			get_parent().die()
		else:
			get_parent().queue_free()
#endregion

#region Changing Armor
## Called externally to update the current armor value.
func set_armor(new_armor: int) -> void:
	armor = new_armor
#endregion

#region Utils: Applying Healing
## Heals to both health and shield, starting with health then applying any remaining amount to shield.
func heal_health_then_shield(amount: int) -> void:
	if health < get_parent().stats.get_stat("max_health"):
		EffectPopup.create_popup(EffectPopup.PopupTypes.HEALTH_HEAL, amount, get_parent())
	else:
		EffectPopup.create_popup(EffectPopup.PopupTypes.SHIELD_HEAL, amount, get_parent())

	var spillover_health: int = max(0, (amount + health) - get_parent().stats.get_stat("max_health"))
	@warning_ignore("narrowing_conversion") health = clampi(health + amount, 0, get_parent().stats.get_stat("max_health"))

	if spillover_health > 0:
		@warning_ignore("narrowing_conversion") shield = clampi(shield + spillover_health, 0, get_parent().stats.get_stat("max_shield"))

## Heals only health.
func heal_health(amount: int) -> void:
	health = min(health + amount, get_parent().stats.get_stat("max_health"))
	EffectPopup.create_popup(EffectPopup.PopupTypes.HEALTH_HEAL, amount, get_parent())

## Heals only shield.
func heal_shield(amount: int) -> void:
	shield = min(shield + amount, get_parent().stats.get_stat("max_shield"))
	EffectPopup.create_popup(EffectPopup.PopupTypes.SHIELD_HEAL, amount, get_parent())
#endregion

#region Setters & On-Change Funcs
## Setter for the current health. Clamps the new value to the allowed range and updates any connected UI.
func _set_health(new_value: int) -> void:
	@warning_ignore("narrowing_conversion") health = clampi(new_value, 0, get_parent().stats.get_stat("max_health"))
	if stats_ui and stats_ui.has_method("on_health_changed"):
		stats_ui.on_health_changed(health)

## Setter for the current shield. Clamps the new value to the allowed range and updates any connected UI.
func _set_shield(new_value: int) -> void:
	@warning_ignore("narrowing_conversion") shield = clampi(new_value, 0, get_parent().stats.get_stat("max_shield"))
	if stats_ui and stats_ui.has_method("on_shield_changed"):
		stats_ui.on_shield_changed(shield)

## Setter for the current armor. Clamps the new value to the allowed range.
func _set_armor(new_value: int) -> void:
	armor = clampi(new_value, 0, MAX_ARMOR)

## When max health changes, we need to limit the current health value.
func on_max_health_changed(new_max_health: int) -> void:
	health = min(health, new_max_health)

## When max shield changes, we need to limit the current shield value.
func on_max_shield_changed(new_max_shield: int) -> void:
	shield = min(shield, new_max_shield)

func _play_shield_damage_sound() -> void:
	AudioManager.play_sound("PlayerShieldDamage", AudioManager.SoundType.SFX_2D, get_parent().global_position)
#endregion
