@icon("res://Utilities/Debug/EditorIcons/entity_sprite.svg")
extends Node2D
class_name EntitySprite
## The main sprite node that is attached to any game entity.

@export var disable_floor_light: bool = false ## When true, the light that shines at the base of the sprite in response to status effects will be disabled.
@export var floor_colors: Dictionary[StringName, Color] = { ## The status effect names that have associated colors to change the floor light to.
	&"Frostbite" : Color(0.435, 0.826, 1),
	&"Burning" : Color(1, 0.582, 0.484),
	&"Poison" : Color(0, 0.933, 0.469),
	&"Slowness" : Color(1, 0.568, 0.56),
	&"StormSyndrome" : Color(0.861, 0.573, 1),
	&"Confusion" : Color(0.73, 0.703, 0.701),
	&"Regen" : Color(0, 0.85, 0.393),
	&"Speed" : Color(0.692, 0.76, 0),
	&"Untouchable" : Color(0.29, 0.713, 0.75),
	&"Stun" : Color(1, 0.909, 0.544),
	&"TimeSnare": Color(1, 0.4, 0.463)
}
@export var overlay_colors: Dictionary[StringName, Color] = { ## The status effect names that have associated colors to change the overlay to.
	&"Frostbite" : Color(0.435, 0.826, 1),
	&"Burning" : Color(1, 0.582, 0.484),
	&"Poison" : Color(0, 0.933, 0.469),
	&"Slowness" : Color(1, 0.568, 0.56),
	&"StormSyndrome" : Color(0.861, 0.573, 1),
	&"Confusion" : Color(0.73, 0.703, 0.701),
	&"Regen" : Color(0, 0.8, 0.3),
	&"Speed" : Color(0.692, 0.76, 0),
	&"Untouchable" : Color(0.29, 0.713, 0.75),
	&"Stun" : Color(1, 0.909, 0.544),
	&"TimeSnare": Color(1, 0.4, 0.463)
}

@onready var floor_light: PointLight2D = $FloorLight ## The light with the effect color that is shining up on the entity.
@onready var overlay: TextureRect = $Overlay ## The color overlay that shows when a status effect triggers it.

var floor_light_tween: Tween = null ## The tween controlling the floor light's self-modulate.
var overlay_color_tween: Tween = null ## The tween controlling the overlay color.
var current_floor_light_names: Array[String] = [] ## The queue for the next colors to show when the previous ones finish.
var current_sprite_glow_names: Array[String] = [] ## The queue for the next colors to show when the previous ones finish.
var hitflash_tween: Tween ## The tween that animates the hitflash effect.
const HITFLASH_DURATION: float = 0.05 ## The duration of the hitflash effect.


#region Saving & Loading
func _on_before_load_game() -> void:
	current_floor_light_names = []
	current_sprite_glow_names = []
#endregion

func _ready() -> void:
	add_to_group("has_save_logic")

	var sprite_size: Vector2 = SpriteHelpers.SpriteDetails.get_frame_rect(self, false)

	if not disable_floor_light:
		_setup_floor_light_size(sprite_size)
	else:
		floor_light.queue_free()

	call_deferred("_setup_overlay_size", sprite_size)

## Sets up the floor light size to be proportional to the sprite boundaries.
func _setup_floor_light_size(sprite_size: Vector2) -> void:
	floor_light.scale *= Vector2(sprite_size.x / 32.0, sprite_size.y / 32.0)
	floor_light.position = Vector2(-position.x, (sprite_size.y / 2.0))

	floor_light.hide()

## Sets up the overlay size to be twice as big at the sprite boundaries.
func _setup_overlay_size(sprite_size: Vector2) -> void:
	overlay.size = sprite_size * 2
	overlay.position = Vector2(overlay.size.y * -0.5, overlay.size.x * 0.5)

## Updates the floor light using tweening.
func update_floor_light(effect_name: String, kill: bool = false) -> void:
	if disable_floor_light:
		return

	if floor_light_tween:
		floor_light_tween.kill()

	var change_time_start: float = 0.3 if effect_name != "Stun" else 0.1
	var change_time_end: float = 1.5 if effect_name != "Stun" else 0.1

	if not kill:
		current_floor_light_names.append(effect_name)
	else:
		var removal_index: int = current_floor_light_names.find(effect_name)
		if removal_index != -1: current_floor_light_names.remove_at(removal_index)

	if current_floor_light_names.is_empty():
		floor_light_tween = create_tween()
		floor_light_tween.tween_property(floor_light, "energy", 0, change_time_end)
		floor_light_tween.tween_callback(func() -> void: floor_light.hide())
	else:
		var effect: String = current_floor_light_names[0]
		floor_light.show()

		floor_light_tween = create_tween()
		if effect_name != "Stun":
			floor_light_tween.set_loops()
		if current_floor_light_names.size() == 1:
			floor_light.color = floor_colors.get(effect, Color.WHITE)

		floor_light_tween.tween_property(floor_light, "color", floor_colors.get(effect, Color.WHITE), change_time_start).set_delay(0.01 if effect != "Stun" else 0.05)
		floor_light_tween.chain().tween_property(floor_light, "energy", 1.65, change_time_start).set_delay(0.01 if effect != "Stun" else 0.05)
		floor_light_tween.tween_property(floor_light, "energy", 1.4, 0.3).set_delay(1.0)

## Updates the overlay using tweening.
func update_overlay_color(effect_name: String, kill: bool = false) -> void:
	if overlay_color_tween:
		overlay_color_tween.kill()

	var change_time_start: float = 0.2 if effect_name != "Stun" else 0.05
	var change_time_end: float = 0.2 if effect_name != "Stun" else 0.05

	if not kill:
		current_sprite_glow_names.append(effect_name)
	else:
		var removal_index: int = current_sprite_glow_names.find(effect_name)
		if removal_index != -1: current_sprite_glow_names.remove_at(removal_index)

	if current_sprite_glow_names.is_empty():
		overlay_color_tween = create_tween()
		overlay_color_tween.tween_property(overlay, "self_modulate:a", 0, change_time_end)
	else:
		overlay_color_tween = create_tween()
		var effect: String = current_sprite_glow_names[0]
		var new_color: Color = overlay_colors.get(effect, Color.WHITE)

		overlay.texture.gradient.set_color(0, new_color)
		overlay_color_tween.tween_property(overlay, "self_modulate:a", 1.0, change_time_start)

## Starts a hitflash effect based on the color defined in the effect source that caused it. Optionally tweens it in for gentler things
## like healing.
func start_hitflash(flash_color: Color = Color(1, 1, 1, 0.6), tween_in: bool = false) -> void:
	if hitflash_tween:
		hitflash_tween.kill()
	hitflash_tween = create_tween()

	set_instance_shader_parameter("use_override_color", true)

	if tween_in:
		hitflash_tween.tween_property(self, "instance_shader_parameters/override_color", flash_color, 0.1)
		hitflash_tween.tween_interval(HITFLASH_DURATION)
	else:
		set_instance_shader_parameter("override_color", flash_color)
		hitflash_tween.tween_interval(HITFLASH_DURATION)

	hitflash_tween.tween_property(self, "instance_shader_parameters/override_color", Color.TRANSPARENT, 0.1)
	hitflash_tween.tween_callback(func() -> void: set_instance_shader_parameter("use_override_color", false))
