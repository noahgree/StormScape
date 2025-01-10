@icon("res://Utilities/Debug/EditorIcons/entity_sprite.svg")
extends Node2D
class_name EntitySprite
## The main sprite node that is attached to any game entity.

signal overlay_changed(color: Color)

@export var floor_colors: Dictionary[StringName, Color] = { ## The status effect names that have associated colors to change the floor color to.
	&"Frostbite" : Color(0.435, 0.826, 1, 0.558),
	&"Burning" : Color(1, 0.582, 0.484, 0.5),
	&"Poison" : Color(0, 0.933, 0.469, 0.542),
	&"Slowness" : Color(1, 0.568, 0.56, 0.3),
	&"StormSyndrome" : Color(0.861, 0.573, 1, 0.5),
	&"Confusion" : Color(0.73, 0.703, 0.701, 0.4),
	&"Regen" : Color(0, 0.85, 0.393, 0.526),
	&"Speed" : Color(0.692, 0.76, 0, 0.526),
	&"Untouchable" : Color(0.29, 0.713, 0.75),
	&"Stun" : Color(1, 0.909, 0.544, 0.6),
	&"TimeSnare": Color(1, 0.4, 0.463, 0.599)
}
@export var glow_colors: Dictionary[StringName, Color] = { ## The status effect names that have associated colors to change the floor color to.
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

@onready var floor_color: Sprite2D = $FloorColor ## The floor color sprite that becomes a visible color when triggered.
@onready var overlay: TextureRect = $Overlay ## The color overlay that shows when a status effect triggers it.

var floor_color_tween: Tween = null ## The tween controlling the floor color's self-modulate.
var glow_color_tween: Tween = null ## The tween controlling the glow color.
var current_floor_color_names: Array[String] = [] ## The queue for the next colors to show when the previous ones finish.
var current_sprite_glow_names: Array[String] = [] ## The queue for the next colors to show when the previous ones finish.


#region Saving & Loading
func _on_before_load_game() -> void:
	current_floor_color_names = []
	current_sprite_glow_names = []
#endregion

func _ready() -> void:
	add_to_group("has_save_logic")

	var sprite_size: Vector2 = SpriteHelpers.SpriteDetails.get_frame_rect(self, false)
	_setup_floor_color_size(sprite_size)
	call_deferred("_setup_overlay_size", sprite_size)

## Sets up the floor color size to be proportional to the sprite boundaries.
func _setup_floor_color_size(sprite_size: Vector2) -> void:
	floor_color.scale *= Vector2(sprite_size.x / 32.0, sprite_size.y / 32.0)
	floor_color.position = Vector2(-position.x, (sprite_size.y / 2.0))

	floor_color.self_modulate = Color.TRANSPARENT
	floor_color.show()

## Sets up the overlay size to be twice as big at the sprite boundaries.
func _setup_overlay_size(sprite_size: Vector2) -> void:
	overlay.size = sprite_size * 2
	overlay.position = Vector2(overlay.size.y * -0.5, overlay.size.x * 0.5)

## Updates the floor color using tweening.
func update_floor_color(effect_name: String, kill: bool = false) -> void:
	if floor_color_tween:
		floor_color_tween.kill()

	var change_time_start: float = 0.3 if effect_name != "Stun" else 0.1
	var change_time_end: float = 1.25 if effect_name != "Stun" else 0.1

	if not kill:
		current_floor_color_names.append(effect_name)
	else:
		var removal_index: int = current_floor_color_names.find(effect_name)
		if removal_index != -1: current_floor_color_names.remove_at(removal_index)

	if current_floor_color_names.is_empty():
		floor_color_tween = create_tween()
		floor_color_tween.tween_property(floor_color, "self_modulate", Color.TRANSPARENT, change_time_end)
	else:
		floor_color_tween = create_tween()
		if effect_name != "Stun":
			floor_color_tween.set_loops()

		var effect: String = current_floor_color_names[0]

		floor_color_tween.tween_property(floor_color, "self_modulate", floor_colors.get(effect, Color.TRANSPARENT), change_time_start).set_delay(0.1 if effect != "Stun" else 0.05)
		floor_color_tween.tween_property(floor_color, "self_modulate:a", floor_colors.get(effect, Color.TRANSPARENT).a * 0.75, 0.3).set_delay(1.0)

## Updates the glow color using tweening.
func update_glow_color(effect_name: String, kill: bool = false) -> void:
	if glow_color_tween:
		glow_color_tween.kill()

	var change_time_start: float = 0.2 if effect_name != "Stun" else 0.05
	var change_time_end: float = 0.2 if effect_name != "Stun" else 0.05

	if not kill:
		current_sprite_glow_names.append(effect_name)
	else:
		var removal_index: int = current_sprite_glow_names.find(effect_name)
		if removal_index != -1: current_sprite_glow_names.remove_at(removal_index)

	if current_sprite_glow_names.is_empty():
		glow_color_tween = create_tween()
		glow_color_tween.tween_property(overlay, "self_modulate:a", 0, change_time_end)
		overlay_changed.emit(Color.TRANSPARENT)
	else:
		glow_color_tween = create_tween()
		var effect: String = current_sprite_glow_names[0]
		var new_color: Color = glow_colors.get(effect, Color.WHITE)

		overlay.texture.gradient.set_color(0, new_color)
		glow_color_tween.tween_property(overlay, "self_modulate:a", 0.25, change_time_start)
		overlay_changed.emit(new_color)
