extends Control
class_name PlayerOverheadUI
## A collection of UI elements that appear above the player's head.

@export var tintable_overheat_progress_texture: Texture2D
@export var max_overheat_progress_tint_color: Color

@onready var overheat_bar: TextureProgressBar = $VBoxContainer/OverheatBar
@onready var charge_bar: TextureProgressBar = $VBoxContainer/ChargeBar
@onready var reload_bar: TextureProgressBar = $VBoxContainer/ReloadBar

var default_overheat_progress_texture: Texture2D ## The default overheat progress texture used when not at max overheat.
var overheat_tween: Tween = null ## The tween responsible for pulsing the overheat bar when at max overheat.


func _ready() -> void:
	default_overheat_progress_texture = overheat_bar.texture_progress
	reset_all()

## Reset all aspects of this UI.
func reset_all() -> void:
	if overheat_tween: overheat_tween.kill()
	overheat_bar.hide()
	charge_bar.hide()
	reload_bar.hide()
	overheat_bar.value = 0
	charge_bar.value = 0
	reload_bar.value = 0
	overheat_bar.tint_progress = Color.WHITE
	overheat_bar.texture_progress = default_overheat_progress_texture

## Provides the reload progress bar with a new value.
func update_reload_progress(value: int) -> void:
	reload_bar.value = value
	reload_bar.tint_progress = lerp(Color.DARK_CYAN, Color.CYAN, value / 100.0)
	reload_bar.visible = value > 1

## Provides the overheat progress bar with a new value.
func update_overheat_progress(value: int) -> void:
	overheat_bar.value = value
	overheat_bar.tint_under = lerp(Color.LIGHT_GOLDENROD.darkened(0.7), Color.RED.darkened(0.7), value / 100.0)
	overheat_bar.visible = value > 3 # Using 3 since it looks empty when below that

## Provides the charge progress bar with a new value.
func update_charge_progress(value: int) -> void:
	charge_bar.value = value
	charge_bar.tint_under = lerp(Color.FIREBRICK.darkened(0.7), Color.LAWN_GREEN.darkened(0.7), value / 100.0)
	charge_bar.tint_progress = lerp(Color.FIREBRICK, Color.LAWN_GREEN, value / 100.0)
	charge_bar.visible = value > 5 # Using 5 since we need to ensure they meant to hold down a charge

## Either enables or disables the max overheat visuals.
func update_visuals_for_max_overheat(start: bool) -> void:
	if overheat_tween:
		overheat_tween.kill()

	if start:
		update_overheat_progress(100)
		overheat_bar.texture_progress = tintable_overheat_progress_texture
		overheat_tween = create_tween().set_loops()
		overheat_tween.tween_property(overheat_bar, "tint_progress", max_overheat_progress_tint_color, 0.3).set_delay(0.1)
		overheat_tween.tween_property(overheat_bar, "tint_progress", Color.WHITE, 0.3).set_delay(0.1)
	else:
		overheat_bar.texture_progress = default_overheat_progress_texture
		overheat_bar.tint_progress = Color.WHITE
