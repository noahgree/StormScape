extends Control
class_name EntityOverheadUI
## Handles overhead displays for entities other than the player.

@export var health_component: HealthComponent

@onready var health_bar: TextureProgressBar = %OverheadHealthBar
@onready var shield_bar: TextureProgressBar = %OverheadShieldBar
@onready var self_hide_timer: Timer = TimerHelpers.create_one_shot_timer(self, 3.5, _hide_bars)


func _ready() -> void:
	health_component.health_changed.connect(update_health_bar)
	health_component.shield_changed.connect(update_shield_bar)

## Provides the health progress bar with a new value.
func update_health_bar(value: int, _old_value: int) -> void:
	health_bar.value = value
	health_bar.visible = value > 0
	shield_bar.visible = value > 0
	self_hide_timer.stop()
	self_hide_timer.start()

## Provides the shield progress bar with a new value.
func update_shield_bar(value: int, _old_value: int) -> void:
	shield_bar.value = value
	health_bar.visible = health_bar.value > 0
	shield_bar.visible = health_bar.value > 0
	self_hide_timer.stop()
	self_hide_timer.start()

## Hides the bars.
func _hide_bars() -> void:
	health_bar.hide()
	shield_bar.hide()
