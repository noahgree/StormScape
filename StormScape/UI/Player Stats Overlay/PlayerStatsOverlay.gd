extends Control
class_name PlayerStatsOverlay
## Updates and displays the player's health, shield, stamina, and hunger.
## 
## Recieves signals from the global signal bus for when to update and what to update to.

@export var player: Player

@onready var hunger_bar: TextureProgressBar = %HungerBar
@onready var hunger_change: TextureProgressBar = %HungerChange
@onready var hunger_progress_bar: TextureProgressBar = %HungerProgressBar
@onready var stamina_bar: TextureProgressBar = %StaminaBar
@onready var stamina_change: TextureProgressBar = %StaminaChange
@onready var stamina_recharge_bar: TextureProgressBar = %StaminaRechargeBar
@onready var shield_bar: TextureProgressBar = %ShieldBar
@onready var shield_change: TextureProgressBar = %ShieldChange
@onready var health_bar: TextureProgressBar = %HealthBar
@onready var health_change: TextureProgressBar = %HealthChange
@onready var health_changed_timer: Timer = %HealthChangedTimer
@onready var shield_changed_timer: Timer = %ShieldChangedTimer
@onready var hunger_changed_timer: Timer = %HungerChangedTimer
@onready var stamina_changed_timer: Timer = %StaminaChangedTimer
@onready var stamina_recharge_timer: Timer = %StaminaRechargeTimer


var previous_health: int ## The last health value to be receieved.
var previous_shield: int ## The last shield value to be receieved.
var previous_hunger: int ## The last hunger value to be receieved.
var previous_stamina: float ## The last stamina value to be receieved.
var stamina_recharge_tween: Tween ## A tween for animating the stamina recharge delay indicator.


 
func on_health_changed(new_health: int) -> void:
	health_bar.value = new_health
	health_changed_timer.stop()
	if new_health < previous_health:
		health_changed_timer.start()
	else:
		health_change.value = health_bar.value
	previous_health = new_health

func on_max_health_changed(new_max_health: int) -> void:
	health_bar.max_value = new_max_health
	health_change.max_value = new_max_health

func on_shield_changed(new_shield: int) -> void:
	shield_bar.value = new_shield
	shield_changed_timer.stop()
	if new_shield < previous_shield:
		shield_changed_timer.start()
	else:
		shield_change.value = shield_bar.value
	previous_shield = new_shield

func on_max_shield_changed(new_max_shield: int) -> void:
	shield_bar.max_value = new_max_shield
	shield_change.max_value = new_max_shield

func on_hunger_changed(new_hunger: int) -> void:
	hunger_bar.value = new_hunger
	hunger_changed_timer.stop()
	if new_hunger < previous_hunger:
		hunger_changed_timer.start()
	else:
		hunger_change.value = hunger_bar.value
	previous_hunger = new_hunger

func on_stamina_changed(new_stamina: float) -> void:
	stamina_bar.value = new_stamina
	stamina_changed_timer.stop()
	stamina_recharge_timer.stop()
	
	if new_stamina < previous_stamina:
		stamina_changed_timer.start()
	else:
		stamina_change.value = stamina_bar.value
		stamina_recharge_timer.start()
	previous_stamina = new_stamina
	
	var tween = create_tween()
	tween.tween_property(stamina_bar, "material:shader_parameter/opacity", 0.385, 0.2)
	stamina_bar.material.set_shader_parameter("progress", 1.0 - new_stamina / player.stamina_component.max_stamina)

func on_hunger_ticks_changed(new_hunger_ticks: float) -> void:
	hunger_progress_bar.value = new_hunger_ticks

func on_stamina_wait_timer_state_change(wait_time: float, started: bool) -> void:
	if started:
		if not stamina_recharge_tween:
			stamina_recharge_tween = create_tween()
		stamina_recharge_tween.tween_property(stamina_recharge_bar, "value", 100, wait_time)
	else:
		if stamina_recharge_tween:
			stamina_recharge_tween.kill()
			stamina_recharge_tween = null
		stamina_recharge_bar.value = 0



func _on_health_changed_timer_timeout() -> void:
	var tween = create_tween()
	tween.tween_property(health_change, "value", health_bar.value, 0.2)

func _on_shield_changed_timer_timeout() -> void:
	var tween = create_tween()
	tween.tween_property(shield_change, "value", shield_bar.value, 0.2)

func _on_hunger_changed_timer_timeout() -> void:
	var tween = create_tween()
	tween.tween_property(hunger_change, "value", hunger_bar.value, 1.5)

func _on_stamina_changed_timer_timeout() -> void:
	var tween = create_tween()
	tween.tween_property(stamina_change, "value", stamina_bar.value, 0.2)
	tween.parallel().tween_property(stamina_bar, "material:shader_parameter/opacity", 0, 0.2) 

func _on_stamina_recharge_timer_timeout() -> void: # when stamina recharge has ended
	var tween = create_tween()
	tween.tween_property(stamina_bar, "material:shader_parameter/opacity", 0, 0.2)
