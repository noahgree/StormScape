@icon("res://Utilities/Debug/EditorIcons/entity_sprite.svg")
extends Node2D
class_name EntitySprite
## The main sprite node that is attached to any game entity.

@export var disable_floor_light: bool = false ## When true, the light that shines at the base of the sprite in response to status effects will be disabled.
@export var cracks_with_damage: bool = true ## When true, the shader will simulate cracking based on the percentage of health left (note that shield changing does nothing, this only updates with health changes). This only applies to non-dynamic entities.
@export var time_brightness_min_max: Vector2 = Vector2(1.0, 1.0) ## How the brightness of the sprite should change in response to time of day. Anything besides (1, 1) activates this.

## The min values to interpolate to for the cracking shader when health is at its highest (but not completely full).
## The crack_scale will adjust for sprite size automatically upon game start.
@export var min_crack_stats: Dictionary[StringName, float] = {
	&"crack_intensity" : 0.685,
	&"crack_profile" : 1.228,
	&"crack_scale" : 3.838,
}
## The max values to interpolate to for the cracking shader when health is at its lowest.
## The crack_scale will adjust for sprite size automatically upon game start.
@export var max_crack_stats: Dictionary[StringName, float] = {
	&"crack_intensity" : 1.0,
	&"crack_profile" : 2.11,
	&"crack_scale" : 3.838,
}

@export_storage var floor_colors: Dictionary[StringName, Color] = { ## The status effect names that have associated colors to change the floor light to.
	&"frostbite" : Color(0.435, 0.826, 1),
	&"burning" : Color(1, 0.582, 0.484),
	&"poison" : Color(0, 0.933, 0.469),
	&"slowness" : Color(1, 0.568, 0.56),
	&"storm_syndrome" : Color(0.861, 0.573, 1),
	&"confusion" : Color(0.73, 0.703, 0.701),
	&"regen" : Color(0, 0.85, 0.393),
	&"speed" : Color(0.692, 0.76, 0),
	&"untouchable" : Color(0.29, 0.713, 0.75),
	&"stun" : Color(1, 0.909, 0.544),
	&"time_snare": Color(1, 0.4, 0.463)
}
@export_storage var overlay_colors: Dictionary[StringName, Color] = { ## The status effect names that have associated colors to change the overlay to.
	&"frostbite" : Color(0.435, 0.826, 1),
	&"burning" : Color(1, 0.582, 0.484),
	&"poison" : Color(0, 0.933, 0.469),
	&"slowness" : Color(1, 0.568, 0.56),
	&"storm_syndrome" : Color(0.861, 0.573, 1),
	&"confusion" : Color(0.73, 0.703, 0.701),
	&"regen" : Color(0, 0.8, 0.3),
	&"speed" : Color(0.692, 0.76, 0),
	&"sntouchable" : Color(0.29, 0.713, 0.75),
	&"Stun" : Color(1, 0.909, 0.544),
	&"time_snare": Color(1, 0.4, 0.463)
}

@onready var floor_light: PointLight2D = $FloorLight ## The light with the effect color that is shining up on the entity.
@onready var overlay: TextureRect = $Overlay ## The color overlay that shows when a status effect triggers it.

var entity: Entity ## The entity this sprite is attached to.
var floor_light_tween: Tween = null ## The tween controlling the floor light's self-modulate.
var overlay_color_tween: Tween = null ## The tween controlling the overlay color.
var current_floor_light_names: Array[String] = [] ## The queue for the next colors to show when the previous ones finish.
var current_sprite_glow_names: Array[String] = [] ## The queue for the next colors to show when the previous ones finish.
var hitflash_tween: Tween ## The tween that animates the hitflash effect.
var shader_node: Node2D = self
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

	if time_brightness_min_max != Vector2(1.0, 1.0):
		DayNightManager.brightness_signal.connect(_on_day_night_brightness_tick)

	call_deferred("_setup_overlay_size", sprite_size)
	call_deferred("_setup_cracks_with_damage", sprite_size)

## Interpolates the brightness mult on the sprite shader based on the brightness given by the day-night manager.
func _on_day_night_brightness_tick(progress: float) -> void:
	var brightness: float = time_brightness_min_max.y + (time_brightness_min_max.x - time_brightness_min_max.y) * progress
	shader_node.set_instance_shader_parameter("brightness_mult", brightness)

## Sets up the floor light size to be proportional to the sprite boundaries.
func _setup_floor_light_size(sprite_size: Vector2) -> void:
	floor_light.scale *= Vector2(sprite_size.x / 32.0, sprite_size.y / 32.0)
	floor_light.position = Vector2(-position.x, (sprite_size.y / 2.0))

	floor_light.hide()

## Sets up the overlay size to be twice as big at the sprite boundaries.
func _setup_overlay_size(sprite_size: Vector2) -> void:
	overlay.size = sprite_size * 2
	overlay.position = Vector2(overlay.size.y * -0.5, overlay.size.x * 0.5)

## Sets up the potential for showing cracks with damage.
func _setup_cracks_with_damage(sprite_size: Vector2) -> void:
	if not cracks_with_damage or entity is DynamicEntity:
		return

	var health_component: HealthComponent = entity.health_component
	health_component.health_changed.connect(_update_cracking)
	health_component.max_health_changed.connect(_on_max_health_of_entity_changed)

	shader_node.set_instance_shader_parameter("crack_pixelate", sprite_size)
	var scale_scaler: float = max(30.0, maxf(sprite_size.x, sprite_size.y)) / 30.0
	min_crack_stats["crack_scale"] = min_crack_stats["crack_scale"] * scale_scaler
	max_crack_stats["crack_scale"] = max_crack_stats["crack_scale"] * scale_scaler

	_update_cracking(health_component.health, -1)

## Updates the floor light using tweening.
func update_floor_light(effect_id: String, kill: bool = false) -> void:
	if disable_floor_light:
		return

	if floor_light_tween:
		floor_light_tween.kill()

	var change_time_start: float = 0.3 if effect_id != "stun" else 0.1
	var change_time_end: float = 0.35 if effect_id != "stun" else 0.1

	if not kill:
		current_floor_light_names.append(effect_id)
	else:
		var removal_index: int = current_floor_light_names.find(effect_id)
		if removal_index != -1:
			current_floor_light_names.remove_at(removal_index)

	if current_floor_light_names.is_empty():
		floor_light_tween = create_tween()
		floor_light_tween.tween_property(floor_light, "energy", 0, change_time_end)
		floor_light_tween.tween_callback(func() -> void: floor_light.hide())
	else:
		var effect: String = current_floor_light_names[0]
		floor_light.show()

		floor_light_tween = create_tween()
		if effect_id != "stun":
			floor_light_tween.set_loops()
		if current_floor_light_names.size() == 1:
			floor_light.color = floor_colors.get(effect, Color.WHITE)

		floor_light_tween.tween_property(floor_light, "color", floor_colors.get(effect, Color.WHITE), change_time_start).set_delay(0.01 if effect != "Stun" else 0.05)
		floor_light_tween.chain().tween_property(floor_light, "energy", 1.65, change_time_start).set_delay(0.01 if effect != "stun" else 0.05)
		floor_light_tween.tween_property(floor_light, "energy", 1.4, 0.3).set_delay(1.0)

## Updates the overlay using tweening.
func update_overlay_color(effect_id: String, kill: bool = false) -> void:
	if overlay_color_tween:
		overlay_color_tween.kill()

	var change_time_start: float = 0.2 if effect_id != "stun" else 0.05
	var change_time_end: float = 0.2 if effect_id != "stun" else 0.05

	if not kill:
		current_sprite_glow_names.append(effect_id)
	else:
		var removal_index: int = current_sprite_glow_names.find(effect_id)
		if removal_index != -1:
			current_sprite_glow_names.remove_at(removal_index)

	if current_sprite_glow_names.is_empty():
		overlay_color_tween = create_tween()
		overlay_color_tween.tween_property(overlay, "self_modulate:a", 0, change_time_end)
	else:
		overlay_color_tween = create_tween()
		var effect: String = current_sprite_glow_names[0]
		var new_color: Color = overlay_colors.get(effect, Color.WHITE)

		overlay.texture.gradient.set_color(0, new_color)
		overlay_color_tween.tween_property(overlay, "self_modulate:a", 1.0, change_time_start)

## Starts a hitflash effect based on the color defined in the effect source that caused it.
## Optionally tweens it in for gentler things like healing.
func start_hitflash(flash_color: Color = Color(1, 1, 1, 0.6), tween_in: bool = false) -> void:
	if hitflash_tween:
		hitflash_tween.kill()
	hitflash_tween = create_tween()

	shader_node.set_instance_shader_parameter("use_override_color", true)

	if tween_in:
		hitflash_tween.tween_property(shader_node, "instance_shader_parameters/override_color", flash_color, 0.1)
		hitflash_tween.tween_interval(HITFLASH_DURATION)
	else:
		shader_node.set_instance_shader_parameter("override_color", flash_color)
		hitflash_tween.tween_interval(HITFLASH_DURATION)

	hitflash_tween.tween_property(shader_node, "instance_shader_parameters/override_color", Color.TRANSPARENT, 0.1)
	hitflash_tween.tween_callback(func() -> void: shader_node.set_instance_shader_parameter("use_override_color", false))

## Updates the level of cracking shown by the shader. Uses the new current health as a percentage of the max
## health to determine how cracked it should be between the min and max cracking dictionaries.
func _update_cracking(new_health: int, _old_health: int) -> void:
	if new_health == 0:
		return
	var max_health: int = int(entity.stats.get_stat("max_health"))
	var percent_health: float = float(new_health) / float(max_health)
	var crack_depth: float = 0.0

	if percent_health < 0.33:
		crack_depth = 1.15
	else:
		crack_depth = 0.4
	shader_node.set_instance_shader_parameter("crack_depth", crack_depth)

	for value_name: StringName in min_crack_stats:
		var min_value: float = min_crack_stats[value_name]
		var max_value: float = max_crack_stats[value_name]
		var interpolated_value: float = max_value - ((max_value - min_value) * percent_health)
		if value_name == "crack_intensity" and percent_health >= 1.0:
			shader_node.set_instance_shader_parameter("crack_intensity", 0.0)
		else:
			shader_node.set_instance_shader_parameter(value_name, interpolated_value)

## Potentially updates the cracking when the max health changes since it would be at a different level of damage.
func _on_max_health_of_entity_changed(_new_max_health: int) -> void:
	_update_cracking(entity.health_component.health, -1)
