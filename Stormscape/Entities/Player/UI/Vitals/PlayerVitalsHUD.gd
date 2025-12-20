@icon("res://Utilities/Debug/EditorIcons/stats_hud.svg")
extends Control
## Updates and displays the player's health, shield, stamina, and hunger.
##
## Recieves signals from the global signal bus for when to update and what to update to.

@export var health_component: HealthComponent
@export var stamina_component: StaminaComponent

@onready var hunger_bar: TextureProgressBar = %HungerBar
@onready var hunger_change_bar: TextureProgressBar = %HungerChangeBar
@onready var stamina_bar: TextureProgressBar = %StaminaBar
@onready var stamina_change_bar: TextureProgressBar = %StaminaChangeBar
@onready var shield_bar: TextureProgressBar = %ShieldBar
@onready var shield_change_bar: TextureProgressBar = %ShieldChangeBar
@onready var health_bar: TextureProgressBar = %HealthBar
@onready var health_change_bar: TextureProgressBar = %HealthChangeBar

var health_changed_timer: Timer = TimerHelpers.create_one_shot_timer(self, 0.5, _on_health_changed_timer_timeout)
var shield_changed_timer: Timer = TimerHelpers.create_one_shot_timer(self, 0.5, _on_shield_changed_timer_timeout)
var stamina_changed_timer: Timer = TimerHelpers.create_one_shot_timer(self, 0.5, _on_stamina_changed_timer_timeout)
var hunger_changed_timer: Timer = TimerHelpers.create_one_shot_timer(self, 0.5, _on_hunger_changed_timer_timeout)


func _ready() -> void:
	health_component.health_changed.connect(on_health_changed)
	health_component.max_health_changed.connect(on_max_health_changed)
	health_component.shield_changed.connect(on_shield_changed)
	health_component.max_shield_changed.connect(on_max_shield_changed)
	stamina_component.stamina_changed.connect(on_stamina_changed)
	stamina_component.max_stamina_changed.connect(on_max_stamina_changed)
	stamina_component.hunger_bars_changed.connect(on_hunger_bars_changed)
	stamina_component.max_hunger_bars_changed.connect(on_max_hunger_bars_changed)

	SignalBus.ui_focus_opened.connect(func(_node: Node) -> void: visible = not Globals.ui_focus_open)
	SignalBus.ui_focus_closed.connect(func(_node: Node) -> void: visible = not Globals.ui_focus_open)

## When health changes, update the bar and tween the change bar after a delay.
## Only activate the delay timer that triggers the tween if we are decreasing the amount.
func on_health_changed(new_health: int, old_health: int) -> void:
	health_bar.value = new_health
	health_changed_timer.stop()
	if new_health < old_health:
		health_changed_timer.start()
	else:
		health_change_bar.value = health_bar.value

## Trigger health change so the on_health_changed function will recalculate where the bars need to be
## according to the new max_health amount.
func on_max_health_changed(new_max_health: int) -> void:
	var old_health: int = int(health_bar.value)
	health_bar.max_value = new_max_health
	hunger_change_bar.max_value = new_max_health
	on_health_changed(int(health_bar.value), old_health)

## When shield changes, update the bar and tween the change bar after a delay.
## Only activate the delay timer that triggers the tween if we are decreasing the amount.
func on_shield_changed(new_shield: int, old_shield: int) -> void:
	shield_bar.value = new_shield
	shield_changed_timer.stop()
	if new_shield < old_shield:
		shield_changed_timer.start()
	else:
		shield_change_bar.value = shield_bar.value

## Trigger shield change so the on_shield_changed function will recalculate where the bars need to be
## according to the new max_shield amount.
func on_max_shield_changed(new_max_shield: int) -> void:
	var old_shield: int = int(shield_bar.value)
	shield_bar.max_value = new_max_shield
	shield_change_bar.max_value = new_max_shield
	on_shield_changed(int(shield_bar.value), old_shield)

## When stamina changes, update the bar and tween the change bar after a delay. Also enable the tip shader.
## Only activate the delay timer that triggers the tween if we are decreasing the amount.
func on_stamina_changed(new_stamina: float, old_stamina: float) -> void:
	stamina_bar.value = new_stamina
	stamina_changed_timer.stop()
	if new_stamina < old_stamina:
		stamina_changed_timer.start()
	else:
		stamina_change_bar.value = stamina_bar.value

## Trigger stamina change so the on_stamina_changed function will recalculate where the bars need to be
## according to the new max_stamina amount.
func on_max_stamina_changed(new_max_stamina: float) -> void:
	var old_stamina: float = stamina_bar.value
	stamina_bar.max_value = new_max_stamina
	stamina_change_bar.max_value = new_max_stamina
	on_stamina_changed(stamina_bar.value, old_stamina)

## When hunger changes, update the bar and tween the change bar after a delay.
## Only activate the delay timer that triggers the tween if we are decreasing the amount.
func on_hunger_bars_changed(new_hunger_bars: int, old_hunger_bars: int) -> void:
	hunger_bar.value = new_hunger_bars
	hunger_changed_timer.stop()
	if new_hunger_bars < old_hunger_bars:
		hunger_changed_timer.start()
	else:
		hunger_change_bar.value = hunger_bar.value

## Trigger hunger bars change so the on_hunger_bars_changed function will recalculate where the bars need to be
## according to the new max_hunger_bars amount.
func on_max_hunger_bars_changed(new_max_hunger_bars: int) -> void:
	var old_hunger_bars: int = int(hunger_bar.value)
	hunger_bar.max_value = new_max_hunger_bars
	hunger_change_bar.max_value = new_max_hunger_bars
	on_hunger_bars_changed(int(hunger_bar.value), old_hunger_bars)

func _on_health_changed_timer_timeout() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(health_change_bar, "value", health_bar.value, 0.2)

func _on_shield_changed_timer_timeout() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(shield_change_bar, "value", shield_bar.value, 0.2)

func _on_stamina_changed_timer_timeout() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(stamina_change_bar, "value", stamina_bar.value, 0.2)

func _on_hunger_changed_timer_timeout() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(hunger_change_bar, "value", hunger_bar.value, 1.5)
