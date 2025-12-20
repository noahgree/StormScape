@icon("res://Utilities/Debug/EditorIcons/stamina_component.svg")
extends Node
class_name StaminaComponent
## A component for handling stamina and hunger for a dynamic entity.
##
## Has functions for handling using stamina and hunger.
## This class should always remain agnostic about the entity, and the UI it updates is optional.

signal stamina_changed(new_stamina: float, old_stamina: float)
signal max_stamina_changed(new_max_stamina: float)
signal hunger_bars_changed(new_hunger_bars: int, old_hunger_bars: int)
signal max_hunger_bars_changed(new_max_hunger_bars: int)
signal stamina_use_per_hunger_deduction_changed(new_stamina_use_per_hunger_deduction: float)

@export var _max_stamina: float = 100.0 ## The max amount of stamina the entity can have.
@export_custom(PROPERTY_HINT_NONE, "suffix:per second") var _stamina_recharge_rate: float = 15.0 ## The amount of stamina that recharges per second during recharge.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var _stamina_recharge_delay: float = 5.0 ## The delay after using stamina before it starts recharging.
@export var _max_hunger_bars: int = 100 ## The max amount of hunger bars the entity can have.
@export var _stamina_use_per_hunger_deduction: float = 100.0 ## The amount of stamina the entity has to use before it can deduct the _hunger_cost_per_stamina_bar from the hunger bar.
@export_custom(PROPERTY_HINT_NONE, "suffix:hunger") var _hunger_cost_per_stamina_bar: int = 5 ## The amount of hunger to deduct per _stamina_use_per_hunger_deduction amount of stamina.

@onready var stamina_wait_timer: Timer = TimerHelpers.create_one_shot_timer(self, 5.0, _on_stamina_wait_timer_timeout) ## The wait between using stamina and when it starts recharging.

var stamina: float: set = _set_stamina ## The current stamina remaining for the entity.
var can_use_stamina: bool = true ## Whether the entity can currently use its stamina.
var stamina_to_hunger_count: float = 0.0: set = _set_stamina_to_hunger_count ## A counter for tracking when enough stamina has been used to deduct the hunger_ticks_per_stamina_bar value from hunger.
var hunger_bars: int: set = _set_hunger_bars ## The current hunger bars of the entity.
var can_use_hunger_bars: bool = true ## Whether the entity can currently have hunger bars deducted.
var stamina_recharge_tween: Tween ## A tween for slowly incrementing the stamina value during recharge.


## Asserts that the parent is a DynamicEntity and then sets up modifiable var dictionary for the stat mod handler.
func _ready() -> void:
	assert(get_parent() is DynamicEntity, get_parent().name + " has a StaminaComponent but is not a DynamicEntity.")

	var moddable_stats_with_callables: Dictionary[StringName, Array] = {
		&"max_stamina" : [_max_stamina, on_max_stamina_changed],
		&"max_hunger_bars" : [_max_hunger_bars, on_max_hunger_bars_changed],
		&"stamina_use_per_hunger_deduction" : [_stamina_use_per_hunger_deduction, on_stamina_use_per_hunger_deduction_changed]
	}
	var moddable_stats: Dictionary[StringName, float] = {
		&"stamina_recharge_rate" : _stamina_recharge_rate,
		&"hunger_cost_per_stamina_bar" : _hunger_cost_per_stamina_bar,
		&"stamina_recharge_delay" : _stamina_recharge_delay
	}
	get_parent().stats.add_moddable_stats_with_associated_callables(moddable_stats_with_callables)
	get_parent().stats.add_moddable_stats(moddable_stats)
	call_deferred("_emit_initial_values")

## Checks whether stamina use is allowed, deducts the amount if so, and returns whether or not the amount was used.
## This also tells the wait timer for stamina recharge to restart if stamina was used as well as
## increments the stamina_to_hunger_count appropriately.
func use_stamina(amount: float) -> bool:
	if !can_use_stamina:
		return false

	if stamina < amount:
		return false
	else:
		stamina -= amount
		if stamina_recharge_tween:
			stamina_recharge_tween.kill()
		stamina_wait_timer.stop()
		stamina_wait_timer.start(get_parent().stats.get_stat("stamina_recharge_delay"))

		stamina_to_hunger_count += amount
		if stamina_to_hunger_count / get_parent().stats.get_stat("stamina_use_per_hunger_deduction") >= 0.99:
			stamina_to_hunger_count = 0
			hunger_bars = max(0, hunger_bars - get_parent().stats.get_stat("hunger_cost_per_stamina_bar"))

		return true

## Increases the current stamina value by a passed in amount.
func gain_stamina(amount: float) -> void:
	stamina = min(stamina + amount, get_parent().stats.get_stat("max_stamina"))

## Checks whether hunger is allowed to be used and deducts the amount if so.
func use_hunger_bars(amount: int) -> bool:
	if !can_use_hunger_bars:
		return false

	if hunger_bars < amount:
		return false
	else:
		hunger_bars -= amount
		return true

## Increases current number of hunger bars based on a passed in amount.
func gain_hunger_bars(amount: int) -> void:
	hunger_bars = min(get_parent().stats.get_stat("max_hunger_bars"), hunger_bars + amount)

## Setter for stamina. Clamps the new value to the allowed range.
func _set_stamina(new_value: float) -> void:
	var old_stamina: float = stamina
	stamina = clampf(new_value, 0, get_parent().stats.get_stat("max_stamina"))
	stamina_changed.emit(stamina, old_stamina)

## Setter for hunger. Clamps the new value to the allowed range.
func _set_hunger_bars(new_value: int) -> void:
	var old_hunger_bars: int = hunger_bars
	hunger_bars = clampi(new_value, 0, int(get_parent().stats.get_stat("max_hunger_bars")))
	hunger_bars_changed.emit(hunger_bars, old_hunger_bars)

## Setter for stamina_to_hunger_count. Clamps the new value to the allowed range.
func _set_stamina_to_hunger_count(new_value: float) -> void:
	stamina_to_hunger_count = new_value

## When max stamina gets changed by something like a stat mod, we need to make sure the recharge delay timer starts.
## We also need to make sure the curret stamina gets limited to the new max value. Usually called by
## stat mod caches.
func on_max_stamina_changed(new_max_stamina: float) -> void:
	stamina = min(stamina, new_max_stamina)
	if stamina < new_max_stamina and stamina_wait_timer.is_stopped():
		stamina_wait_timer.stop()
		stamina_wait_timer.start(get_parent().stats.get_stat("stamina_recharge_delay"))
	max_stamina_changed.emit(new_max_stamina)

## We need to make sure the curret hunger bars get limited to the new max value. Usually called by stat mod caches.
func on_max_hunger_bars_changed(new_max_hunger_bars: int) -> void:
	hunger_bars = min(hunger_bars, new_max_hunger_bars)
	max_hunger_bars_changed.emit(new_max_hunger_bars)

## Emits that the rate of stamina use per hunger deduction has changed. Usually called by stat mod caches.
func on_stamina_use_per_hunger_deduction_changed(new_stamina_use_per_hunger_deduction: float) -> void:
	stamina_use_per_hunger_deduction_changed.emit(new_stamina_use_per_hunger_deduction)

## Called from a deferred method caller in order to let any associated ui ready up first.
## Then it emits the initially loaded values.
func _emit_initial_values() -> void:
	stamina = get_parent().stats.get_stat("max_stamina")
	hunger_bars = int(get_parent().stats.get_stat("max_hunger_bars"))
	stamina_to_hunger_count = 0
	stamina_wait_timer.start(get_parent().stats.get_stat("stamina_recharge_delay"))

## When the stamina recharge wait timer ends, this handles creating a tweener that slowly increments the new stamina.
func _on_stamina_wait_timer_timeout() -> void:
	if stamina_recharge_tween:
		if stamina_recharge_tween.is_running():
			return
		else:
			stamina_recharge_tween.kill()
	stamina_recharge_tween = create_tween()
	stamina_recharge_tween.tween_method(_set_stamina, stamina, get_parent().stats.get_stat("max_stamina"), (get_parent().stats.get_stat("max_stamina") - stamina) / get_parent().stats.get_stat("stamina_recharge_rate"))

## Returns if the current stamina is greater than or equal to the needed stamina.
func has_enough_stamina(needed: float) -> bool:
	return stamina >= needed

#region Debug
## Increases or decreases stamina based on amount.
func change_stamina_by_amount(amount: float) -> void:
	if amount >= 0:
		gain_stamina(amount)
		if stamina_recharge_tween:
			stamina_recharge_tween.kill()
		stamina_wait_timer.stop()
		_on_stamina_wait_timer_timeout()
	else:
		use_stamina(-amount)

## Increases or decreases hunger bars based on amount.
func change_hunger_bars_by_amount(amount: int) -> void:
	if amount >= 0:
		gain_hunger_bars(amount)
	else:
		use_hunger_bars(-amount)
#endregion
