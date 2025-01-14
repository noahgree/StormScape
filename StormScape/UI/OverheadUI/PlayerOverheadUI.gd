extends Control
class_name PlayerOverheadUI
## A collection of UI elements that appear above the player's

@export var tintable_overheat_progress_texture: Texture2D
@export var max_overheat_progress_tint_color: Color

@onready var reload_bar: TextureProgressBar = $VBoxContainer/ReloadBar
@onready var overheat_bar: TextureProgressBar = $VBoxContainer/OverheatBar

var default_overheat_progress_texture: Texture2D ## The default overheat progress texture used when not at max overheat.
var overheat_tween: Tween = null ## The tween responsible for pulsing the overheat bar when at max overheat.


func _ready() -> void:
	default_overheat_progress_texture = overheat_bar.texture_progress
	reset_all()

## Reset all aspects of this UI.
func reset_all() -> void:
	if overheat_tween: overheat_tween.kill()
	reload_bar.hide()
	overheat_bar.hide()
	reload_bar.value = 0
	overheat_bar.value = 0
	overheat_bar.tint_progress = Color.WHITE
	overheat_bar.texture_progress = default_overheat_progress_texture

## Provides the reload progress bar with a new value.
func update_reload_progress(value: int) -> void:
	reload_bar.value = value

## Provides the overheat progress bar with a new value.
func update_overheat_progress(value: int) -> void:
	overheat_bar.value = value

## Either enables or disables the max overheat visuals.
func update_visuals_for_max_overheat(reset: bool = false) -> void:
	if overheat_tween:
		overheat_tween.kill()

	if not reset:
		overheat_bar.texture_progress = tintable_overheat_progress_texture
		overheat_tween = create_tween().set_loops()
		overheat_tween.tween_property(overheat_bar, "tint_progress", max_overheat_progress_tint_color, 0.3).set_delay(0.1)
		overheat_tween.tween_property(overheat_bar, "tint_progress", Color.WHITE, 0.3).set_delay(0.1)
	else:
		overheat_bar.texture_progress = default_overheat_progress_texture
		overheat_bar.tint_progress = Color.WHITE
