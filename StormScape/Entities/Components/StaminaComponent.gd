@icon("res://Utilities/Debug/EditorIcons/stamina_component.svg")
extends Node
class_name StaminaComponent
## A component for handling stamina and hunger for an entity.
## 
## Has functions for handling using stamina and hunger.
## This class should always remain agnostic about the entity and the entity's UI it updates.


@export var stats_ui: Control ## The UI that will reflect this component's values.
@export var max_stamina: float = 100.0 ## The max amount of stamina the entity can have.
@export_custom(PROPERTY_HINT_NONE, "suffix:per second") var stamina_recharge_rate: float = 15.0 ## The amount of stamina that recharges per second during recharge.
@export var max_hunger: int = 100 ## The max amount of hunger (or really satiation) the entity can have.
@export_custom(PROPERTY_HINT_NONE, "suffix:hunger") var stamina_to_hunger_cost: int = 5 ## The amount of hunger to deduct per max_stamina amount of stamina.

@onready var stamina_wait_timer: Timer = %StaminaWaitTimer ## The wait between using stamina and when it starts recharging.

var stamina: float: set = _set_stamina ## The current stamina remaining for the entity.
var can_use_stamina: bool = true ## Whether the entity can currently use its stamina.
var stamina_to_hunger_count: float = 0.0: set = _set_stamina_to_hunger_count ## A counter for tracking when enough stamina has been used to deduct the hunger_ticks_per_stamina_bar value from hunger.
var hunger: int: set = _set_hunger ## The current hunger of the entity.
var can_use_hunger: bool = true ## Whether the entity can currently have hunger deducted.
var stamina_recharge_tween: Tween ## A tween for slowly incrementing the stamina value during recharge.


func _ready() -> void:
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
		stamina_wait_timer.start()
		set_stamina_wait_timer_state_change(true)
		
		stamina_to_hunger_count += amount
		if stamina_to_hunger_count / max_stamina >= 0.99:
			stamina_to_hunger_count = 0
			hunger = max(0, hunger - stamina_to_hunger_cost)
		
		return true

## Checks whether hunger is allowed to be used and deducts the amount if so.
func use_hunger(amount: int) -> bool:
	if !can_use_hunger:
		return false
	
	if hunger < amount:
		return false
	else:
		hunger -= amount
		return true

## Setter for stamina. Clamps the new value to the allowed range and attempts to tell a linked ui about the update.
func _set_stamina(new_value: float) -> void:
	stamina = clampf(new_value, 0, max_stamina)
	if stats_ui and stats_ui.has_method("on_stamina_changed"):
		stats_ui.on_stamina_changed(stamina)

## Setter for hunger. Clamps the new value to the allowed range and attempts to tell a linked ui about the update.
func _set_hunger(new_value: int) -> void:
	hunger = clampi(new_value, 0, max_hunger)
	if stats_ui and stats_ui.has_method("on_hunger_changed"):
		stats_ui.on_hunger_changed(hunger)

## Setter for stamina_to_hunger_count. Clamps the new value to the allowed range and attempts to tell a linked ui about the update.
func _set_stamina_to_hunger_count(new_value: float) -> void:
	stamina_to_hunger_count = new_value
	if stats_ui and stats_ui.has_method("on_hunger_ticks_changed"):
		stats_ui.on_hunger_ticks_changed(stamina_to_hunger_count)

## Used to attempt to tell a linked ui that the stamina recharge wait timer has either stopped or started.
func set_stamina_wait_timer_state_change(started: bool) -> void:
	if stats_ui and stats_ui.has_method("on_stamina_wait_timer_state_change"):
		stats_ui.on_stamina_wait_timer_state_change(stamina_wait_timer.wait_time, started)

func get_can_use_stamina() -> bool:
	return can_use_stamina

func set_can_use_stamina(flag: bool) -> void:
	can_use_stamina = flag

func get_can_use_hunger() -> bool:
	return can_use_hunger

func set_can_use_hunger(flag: bool) -> void:
	can_use_hunger = flag

## Called from a deferred method caller in order to let any associated ui ready up first. 
## Then it emits the initially loaded values.
func _emit_initial_values() -> void:
	stamina = max_stamina
	hunger = max_hunger
	stamina_to_hunger_count = 0
	set_stamina_wait_timer_state_change(false)

## When the stamina recharge wait timer ends, this handles creating a tweener that slowly increments the new stamina.
func _on_stamina_wait_timer_timeout() -> void:
	if stamina < max_stamina:
		if stamina_recharge_tween:
			if stamina_recharge_tween.is_running():
				return
			else:
				stamina_recharge_tween.kill()
		stamina_recharge_tween = create_tween()
		stamina_recharge_tween.tween_method(_set_stamina, stamina, max_stamina, (max_stamina - stamina) / stamina_recharge_rate)
