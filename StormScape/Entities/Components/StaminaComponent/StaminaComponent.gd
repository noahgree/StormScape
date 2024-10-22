@icon("res://Utilities/Debug/EditorIcons/stamina_component.svg")
extends StatBasedComponent
class_name StaminaComponent
## A component for handling stamina and hunger for a dynamic entity.
## 
## Has functions for handling using stamina and hunger.
## This class should always remain agnostic about the entity, and the UI it updates is optional.

@export var _max_stamina: float = 100.0 ## The max amount of stamina the entity can have.
@export_custom(PROPERTY_HINT_NONE, "suffix:per second") var _stamina_recharge_rate: float = 15.0 ## The amount of stamina that recharges per second during recharge.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var _stamina_recharge_delay: float = 5.0 ## The delay after using stamina before it starts recharging.
@export var _max_hunger_bars: int = 100 ## The max amount of hunger bars the entity can have.
@export var _stamina_use_per_hunger_deduction: float = 100.0 ## The amount of stamina the entity has to use before it can deduct the _hunger_cost_per_stamina_bar from the hunger bar.
@export_custom(PROPERTY_HINT_NONE, "suffix:hunger") var _hunger_cost_per_stamina_use: int = 5 ## The amount of hunger to deduct per _stamina_use_per_hunger_deduction amount of stamina.

@onready var stamina_wait_timer: Timer = %StaminaWaitTimer ## The wait between using stamina and when it starts recharging.

var stamina: float: set = _set_stamina ## The current stamina remaining for the entity.
var can_use_stamina: bool = true ## Whether the entity can currently use its stamina.
var stamina_to_hunger_count: float = 0.0: set = _set_stamina_to_hunger_count ## A counter for tracking when enough stamina has been used to deduct the hunger_ticks_per_stamina_bar value from hunger.
var hunger_bars: int: set = _set_hunger_bars ## The current hunger bars of the entity.
var can_use_hunger_bars: bool = true ## Whether the entity can currently have hunger bars deducted.
var stamina_recharge_tween: Tween ## A tween for slowly incrementing the stamina value during recharge.


## Asserts that the parent is a DynamicEntity and then sets up modifiable var dictionary for the stat mod handler.
func _ready() -> void:
	assert(get_parent() is DynamicEntity, get_parent().name + " has a StaminaComponent but is not a DynamicEntity.")
	
	var moddable_stats: Dictionary = {
		"max_stamina" : _max_stamina, "max_hunger_bars" : _max_hunger_bars, 
		"stamina_recharge_rate" : _stamina_recharge_rate, 
		"stamina_use_per_hunger_deduction" : _stamina_use_per_hunger_deduction,
		"hunger_cost_per_stamina_use" : _hunger_cost_per_stamina_use,
		"stamina_recharge_delay" : _stamina_recharge_delay
	}
	add_moddable_stats(moddable_stats)
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
		set_stamina_wait_timer_state_change(false)
		stamina_wait_timer.start(get_stat("stamina_recharge_delay"))
		set_stamina_wait_timer_state_change(true)
		
		stamina_to_hunger_count += amount
		if stamina_to_hunger_count / get_stat("stamina_use_per_hunger_deduction") >= 0.99:
			stamina_to_hunger_count = 0
			hunger_bars = max(0, hunger_bars - get_stat("hunger_cost_per_stamina_use"))
		
		return true

## Increases the current stamina value by a passed in amount.
func gain_stamina(amount: float) -> void:
	stamina = min(stamina + amount, get_stat("max_stamina"))

## Checks whether hunger is allowed to be used and deducts the amount if so.
func use_hunger_bars(amount: int) -> bool:
	if !can_use_hunger_bars:
		return false
	
	if hunger_bars < amount:
		return false
	else:
		hunger_bars -= amount
		return true

## Setter for stamina. Clamps the new value to the allowed range and attempts to tell a linked ui about the update.
func _set_stamina(new_value: float) -> void:
	stamina = clampf(new_value, 0, get_stat("max_stamina"))
	if stats_ui and stats_ui.has_method("on_stamina_changed"):
		stats_ui.on_stamina_changed(stamina)

## Setter for hunger. Clamps the new value to the allowed range and attempts to tell a linked ui about the update.
func _set_hunger_bars(new_value: int) -> void:
	@warning_ignore("narrowing_conversion") hunger_bars = clampi(new_value, 0, get_stat("max_hunger_bars"))
	if stats_ui and stats_ui.has_method("on_hunger_bars_changed"):
		stats_ui.on_hunger_bars_changed(hunger_bars)

## Setter for stamina_to_hunger_count. Clamps the new value to the allowed range and attempts to tell a linked ui about the update.
func _set_stamina_to_hunger_count(new_value: float) -> void:
	stamina_to_hunger_count = new_value
	if stats_ui and stats_ui.has_method("on_hunger_ticks_changed"):
		stats_ui.on_hunger_ticks_changed(stamina_to_hunger_count)

## Used to attempt to tell a linked ui that the stamina recharge wait timer has either stopped or started.
func set_stamina_wait_timer_state_change(should_start: bool) -> void:
	if stats_ui and stats_ui.has_method("on_stamina_wait_timer_state_change"):
		stats_ui.on_stamina_wait_timer_state_change(get_stat("stamina_recharge_delay"), should_start)

## When max stamina gets changed by something like a stat mod, we need to make sure the recharge delay timer starts.
## We also need to make sure the curret stamina gets limited to the new max value.
func on_max_stamina_changed(new_max_stamina: float) -> void:
	stamina = min(stamina, new_max_stamina)
	if stamina < new_max_stamina and stamina_wait_timer.is_stopped():
		stamina_wait_timer.stop()
		set_stamina_wait_timer_state_change(false)
		stamina_wait_timer.start(get_stat("stamina_recharge_delay"))
		set_stamina_wait_timer_state_change(true)

## We need to make sure the curret hunger bars get limited to the new max value.
func on_max_hunger_bars_changed(new_max_hunger_bars: int) -> void:
	hunger_bars = min(hunger_bars, new_max_hunger_bars)

func get_can_use_stamina() -> bool:
	return can_use_stamina

func set_can_use_stamina(flag: bool) -> void:
	can_use_stamina = flag

func get_can_use_hunger() -> bool:
	return can_use_hunger_bars

func set_can_use_hunger(flag: bool) -> void:
	can_use_hunger_bars = flag

## Called from a deferred method caller in order to let any associated ui ready up first. 
## Then it emits the initially loaded values.
func _emit_initial_values() -> void:
	stamina = get_stat("max_stamina")
	@warning_ignore("narrowing_conversion") hunger_bars = get_stat("max_hunger_bars")
	stamina_to_hunger_count = 0
	set_stamina_wait_timer_state_change(false)

## When the stamina recharge wait timer ends, this handles creating a tweener that slowly increments the new stamina.
func _on_stamina_wait_timer_timeout() -> void:
	if stamina_recharge_tween:
		if stamina_recharge_tween.is_running():
			return
		else:
			stamina_recharge_tween.kill()
	stamina_recharge_tween = create_tween()
	stamina_recharge_tween.tween_method(_set_stamina, stamina, get_stat("max_stamina"), (get_stat("max_stamina") - stamina) / get_stat("stamina_recharge_rate"))
