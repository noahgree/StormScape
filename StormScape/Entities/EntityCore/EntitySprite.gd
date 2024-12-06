extends Node2D
class_name EntitySprite
## The main sprite node that is attached to any game entity.

@export var floor_colors: Dictionary = { ## The status effect names that have associated colors to change the floor color to.
	"Frostbite" : Color(0.435, 0.826, 1, 0.558),
	"Burning" : Color(1, 0.582, 0.484, 0.5),
	"Poison" : Color(0, 0.933, 0.469, 0.542),
	"Slowness" : Color(1, 0.568, 0.56, 0.3),
	"Storm Syndrome" : Color(0.861, 0.573, 1, 0.5),
	"Confusion" : Color(0.73, 0.703, 0.701, 0.4),
	"Regen" : Color(0, 0.85, 0.393, 0.526),
	"Speed" : Color(0.692, 0.76, 0, 0.526),
	"Untouchable" : Color(0.29, 0.713, 0.75),
	"Stun" : Color(1, 0.909, 0.544, 0.6),
	"Time Snare": Color(1, 0.4, 0.463, 0.599)
}
@export var glow_colors: Dictionary = { ## The status effect names that have associated colors to change the floor color to.
	"Frostbite" : Color(0.435, 0.826, 1),
	"Burning" : Color(1, 0.582, 0.484),
	"Poison" : Color(0, 0.933, 0.469),
	"Slowness" : Color(1, 0.568, 0.56),
	"Storm Syndrome" : Color(0.861, 0.573, 1),
	"Confusion" : Color(0.73, 0.703, 0.701),
	"Regen" : Color(0, 0.8, 0.3),
	"Speed" : Color(0.692, 0.76, 0),
	"Untouchable" : Color(0.29, 0.713, 0.75),
	"Stun" : Color(1, 0.909, 0.544),
	"Time Snare": Color(1, 0.4, 0.463)
}

@onready var floor_color: Sprite2D = $FloorColor ## The floor color sprite that becomes a visible color when triggered.

var floor_color_tween: Tween = null ## The tween controlling the floor color's self-modulate.
var glow_color_tween: Tween = null ## The tween controlling the glow color.
var current_floor_color_names: Array[String] = [] ## The queue for the next colors to show when the previous ones finish.
var current_sprite_glow_names: Array[String] = [] ## The queue for the next colors to show when the previous ones finish.


func _ready() -> void:
	var frame_rect: Vector2 = SpriteHelpers.SpriteDetails.get_frame_rect(self, false)
	floor_color.scale *= Vector2(frame_rect.x / 32.0, frame_rect.y / 32.0)
	floor_color.position = Vector2(-position.x, (frame_rect.y / 2.0))

	floor_color.self_modulate = Color(0.0, 0.0, 0.0, 0.0)
	floor_color.show()

	material.set_shader_parameter("glow_size", 0.0)

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
		floor_color_tween.tween_property(floor_color, "self_modulate", Color(0.0, 0.0, 0.0, 0.0), change_time_end)
	else:
		floor_color_tween = create_tween()
		if effect_name != "Stun":
			floor_color_tween.set_loops()

		var effect: String = current_floor_color_names[0]

		floor_color_tween.tween_property(floor_color, "self_modulate", floor_colors.get(effect, Color(1.0, 1.0, 1.0, 0.0)), change_time_start).set_delay(0.1 if effect != "Stun" else 0.05)
		floor_color_tween.tween_property(floor_color, "self_modulate:a", floor_colors.get(effect, Color(1.0, 1.0, 1.0, 0.0)).a * 0.75, 0.3).set_delay(1.0)

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
		glow_color_tween.tween_property(material, "shader_parameter/glow_size", 0.0, change_time_end)
	else:
		glow_color_tween = create_tween()
		if effect_name != "Stun":
			glow_color_tween.set_loops()

		var effect: String = current_sprite_glow_names[0]

		glow_color_tween.tween_property(material, "shader_parameter/glow_color", glow_colors.get(effect, Color(1.0, 1.0, 1.0, 1.0)), change_time_start)
		glow_color_tween.tween_property(material, "shader_parameter/glow_size", 5.0, change_time_start)
