extends Node
class_name StaminaComponent


# dependencies on these max values exist in the PlayerHealthbar.gd script for shaders, be warned
@export var max_stamina: float = 100.0
@export var stamina_recharge_rate: float = 15.0 # amount per second
@export var max_hunger: int = 100
@export var hunger_ticks_per_stamina_bar: int = 10

@onready var stamina_wait_timer: Timer = %StaminaWaitTimer

var stamina: float: set = _set_stamina
var can_use_stamina: bool = true
var stamina_to_hunger_count: float = 0: set = _set_stamina_to_hunger_count
var hunger: int: set = _set_hunger
var can_use_hunger: bool = true
var ready_to_broadcast: bool # makes sure the call deffered's have been called already
var stamina_recharge_tween: Tween


func _ready() -> void:
	stamina = max_stamina
	hunger = max_hunger
	call_deferred("_emit_initial_values")


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
		SignalBus.PlayerStaminaWaitTimerStateChange.emit(stamina_wait_timer.wait_time, false)
		stamina_wait_timer.start()
		SignalBus.PlayerStaminaWaitTimerStateChange.emit(stamina_wait_timer.wait_time, true)
		
		stamina_to_hunger_count += amount
		if stamina_to_hunger_count / max_stamina >= 0.99:
			stamina_to_hunger_count = 0
			hunger = max(0, hunger - hunger_ticks_per_stamina_bar)
		
		return true

func use_hunger(amount: int) -> bool:
	if !can_use_hunger:
		return false
	
	if hunger < amount:
		return false
	else:
		hunger -= amount
		return true


func _set_stamina(new_value: float) -> void:
	stamina = clampf(new_value, 0, max_stamina)
	if ready_to_broadcast:
		SignalBus.PlayerStaminaChanged.emit(stamina)

func _set_hunger(new_value: int) -> void:
	hunger = clampi(new_value, 0, max_hunger)
	if ready_to_broadcast:
		SignalBus.PlayerHungerChanged.emit(hunger)

func get_can_use_stamina() -> bool:
	return can_use_stamina

func set_can_use_stamina(flag: bool) -> void:
	can_use_stamina = flag

func get_can_use_hunger() -> bool:
	return can_use_hunger

func set_can_use_hunger(flag: bool) -> void:
	can_use_hunger = flag

func _emit_initial_values() -> void:
	SignalBus.PlayerHungerChanged.emit(hunger)
	SignalBus.PlayerStaminaChanged.emit(stamina)
	SignalBus.PlayerHungerTicksChanged.emit(stamina_to_hunger_count)
	ready_to_broadcast = true

func _on_stamina_wait_timer_timeout() -> void:
	if stamina < max_stamina:
		if stamina_recharge_tween:
			if stamina_recharge_tween.is_running():
				return
			else:
				stamina_recharge_tween.kill()
		if 1 == 1:
			stamina_recharge_tween = create_tween()
			stamina_recharge_tween.tween_method(_set_stamina, stamina, max_stamina, (max_stamina - stamina) / stamina_recharge_rate)

func _set_stamina_to_hunger_count(new_value: float) -> void:
	stamina_to_hunger_count = new_value
	if ready_to_broadcast:
		SignalBus.PlayerHungerTicksChanged.emit(stamina_to_hunger_count)
