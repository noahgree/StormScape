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
@export_range(0, 100, 1) var base_armor: int = 0 ## The initial percentage of damage deflected.
@export var infinte_hp: bool = false ## When true, the entity cannot run out of health or shield.

@onready var entity: PhysicsBody2D = get_parent()

var health: int: set = _set_health ## The current health of the entity.
var shield: int: set = _set_shield ## The current shield of the entity.
var armor: int = 0: set = _set_armor ## The current armor of the entity. This is the percent of dmg that is blocked.
var is_dying: bool = false ## Whether the entity is actively dying or not.
var popups: Dictionary[String, EffectPopup] = {} ## The current effect popup displays that are active and can be added to.
var current_sounds: Dictionary[StringName, Array] = {}
const MAX_ARMOR: int = 100 ## The maximum amount of armor the entity can have.


#region Setup
func _ready() -> void:
	var moddable_stats: Dictionary[StringName, float] = {
		&"max_health" : _max_health, &"max_shield" : _max_shield
	}
	entity.stats.add_moddable_stats(moddable_stats)
	call_deferred("_emit_initial_values")

## Called from a deferred method caller in order to let any associated ui ready up first.
## Then it emits the initially loaded values.
func _emit_initial_values() -> void:
	@warning_ignore("narrowing_conversion") health = entity.stats.get_stat("max_health")
	@warning_ignore("narrowing_conversion") shield = entity.stats.get_stat("max_shield")
	armor = base_armor
#endregion

#region Utils: Taking Damage
## Takes damage to both health and shield, starting with available shield then applying any remaining amount to health.
func damage_shield_then_health(amount: int, source_type: String, was_crit: bool, multishot_id: int) -> void:
	if amount > 0 and not is_dying:
		if shield > 0:
			var src_type: String = source_type if source_type != "BasicDamage" else "ShieldDamage"
			_create_or_update_popup_for_src_type(src_type, false, was_crit, min(shield, amount))
			_play_sound("PlayerShieldDamage", multishot_id)
		if amount - shield > 0:
			var src_type: String = source_type if source_type != "BasicDamage" else "HealthDamage"
			_create_or_update_popup_for_src_type(src_type, false, was_crit, (amount - shield))

	if infinte_hp:
		return

	var spillover_damage: int = max(0, amount - shield)
	@warning_ignore("narrowing_conversion") shield = max(0, shield - amount)

	if spillover_damage > 0:
		@warning_ignore("narrowing_conversion") health = max(0, health - spillover_damage)
	_check_for_death()

## Decrements only the health value by the passed in amount.
func damage_health(amount: int, source_type: String, was_crit: bool, _multishot_id: int) -> void:
	if not is_dying:
		if not infinte_hp:
			health = max(0, health - amount)
		var src_type: String = source_type if source_type != "BasicDamage" else "HealthDamage"
		_create_or_update_popup_for_src_type(src_type, false, was_crit, amount)
		_check_for_death()

## Decrements only the shield value by the passed in amount.
func damage_shield(amount: int, source_type: String, was_crit: bool, multishot_id: int) -> void:
	if not is_dying:
		if not infinte_hp:
			shield = max(0, shield - amount)
		var src_type: String = source_type if source_type != "BasicDamage" else "ShieldDamage"
		_create_or_update_popup_for_src_type(src_type, false, was_crit, amount)
		if amount > 0: _play_sound("PlayerShieldDamage", multishot_id)

## Handles what happens when health reaches 0 for the entity.
func _check_for_death() -> void:
	if health <= 0 and not is_dying:
		is_dying = true
		var loot_table: LootTableComponent = entity.get_node_or_null("LootTableComponent")
		if loot_table != null: loot_table.handle_death()

		if entity.has_method("die"):
			entity.die()
		else:
			entity.queue_free()
#endregion

#region Changing Armor
## Called externally to update the current armor value.
func set_armor(new_armor: int) -> void:
	armor = new_armor
#endregion

#region Utils: Applying Healing
## Heals to both health and shield, starting with health then applying any remaining amount to shield.
func heal_health_then_shield(amount: int, source_type: String, _multishot_id: int) -> void:
	if not is_dying:
		if health < entity.stats.get_stat("max_health"):
			var src_type: String = source_type if source_type != "BasicHealing" else "HealthHealing"
			_create_or_update_popup_for_src_type(src_type, true, false, amount)
		else:
			var src_type: String = source_type if source_type != "BasicHealing" else "ShieldHealing"
			_create_or_update_popup_for_src_type(src_type, true, false, amount)

		var spillover_health: int = max(0, (amount + health) - entity.stats.get_stat("max_health"))
		@warning_ignore("narrowing_conversion") health = clampi(health + amount, 0, entity.stats.get_stat("max_health"))

		if spillover_health > 0:
			@warning_ignore("narrowing_conversion") shield = clampi(shield + spillover_health, 0, entity.stats.get_stat("max_shield"))

## Heals only health.
func heal_health(amount: int, source_type: String, _multishot_id: int) -> void:
	if not is_dying:
		health = min(health + amount, entity.stats.get_stat("max_health"))
		var src_type: String = source_type if source_type != "BasicHealing" else "HealthHealing"
		_create_or_update_popup_for_src_type(src_type, true, false, amount)

## Heals only shield.
func heal_shield(amount: int, source_type: String, _multishot_id: int) -> void:
	if not is_dying:
		shield = min(shield + amount, entity.stats.get_stat("max_shield"))
		var src_type: String = source_type if source_type != "BasicHealing" else "ShieldHealing"
		_create_or_update_popup_for_src_type(src_type, true, false, amount)
#endregion

#region Setters & On-Change Funcs
## Setter for the current health. Clamps the new value to the allowed range and updates any connected UI.
func _set_health(new_value: int) -> void:
	@warning_ignore("narrowing_conversion") health = clampi(new_value, 0, entity.stats.get_stat("max_health"))
	if stats_ui and stats_ui.has_method("on_health_changed"):
		stats_ui.on_health_changed(health)

## Setter for the current shield. Clamps the new value to the allowed range and updates any connected UI.
func _set_shield(new_value: int) -> void:
	@warning_ignore("narrowing_conversion") shield = clampi(new_value, 0, entity.stats.get_stat("max_shield"))
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

## Handles playing sounds for this class and respects the fact that multishots should all share a sound.
func _play_sound(sound_name: String, multishot_id: int) -> void:
	var string_name_sound_name: StringName = StringName(sound_name)

	if multishot_id != -1:
		if (string_name_sound_name in current_sounds.keys()) and (multishot_id in current_sounds[string_name_sound_name]):
			return

		var player: Variant = AudioManager.play_and_get_sound(sound_name, AudioManager.SoundType.SFX_2D, GlobalData.world_root, 0, entity.global_position)
		if player != null:
			if string_name_sound_name in current_sounds.keys():
				current_sounds[string_name_sound_name].append(multishot_id)
			else:
				current_sounds[string_name_sound_name] = [multishot_id]

			var callable: Callable = Callable(func() -> void:
				current_sounds[string_name_sound_name].erase(multishot_id)
				if current_sounds[string_name_sound_name].is_empty():
					current_sounds.erase(string_name_sound_name)
				)
			var finish_callables: Variant = player.get_meta("finish_callables")
			finish_callables.append(callable)
			player.set_meta("finish_callables", finish_callables)
	else:
		AudioManager.play_sound(sound_name, AudioManager.SoundType.SFX_2D, entity.global_position)
#endregion

#region Popups
func _create_or_update_popup_for_src_type(src_type: String, was_healing: bool, was_crit: bool, amount: int) -> void:
	if src_type in popups:
		popups[src_type].update_popup(amount, was_crit)
	else:
		var new_popup: EffectPopup = EffectPopup.create_popup(src_type, was_healing, was_crit, amount, entity)
		new_popup.tree_exiting.connect(_on_popup_completed.bind(src_type))
		popups[src_type] = new_popup

func _on_popup_completed(src_type: String) -> void:
	if src_type in popups:
		popups.erase(src_type)
#endregion
