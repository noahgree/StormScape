@tool
extends EquippableItem
class_name Weapon
## The base class for all equippable weapons in the game.

@export var particle_emission_extents: Vector2:
	set(new_value):
		particle_emission_extents = new_value
		if debug_emission_box:
			_debug_update_particle_emission_box()
@export var particle_emission_origin: Vector2:
	set(new_value):
		particle_emission_origin = new_value
		if debug_emission_box:
			_debug_update_particle_emission_box()

@onready var anim_player: AnimationPlayer = $AnimationPlayer ## The animation controller for this weapon.
@onready var debug_emission_box: Polygon2D = get_node_or_null("DebugEmissionBox")

var pullout_delay_timer: Timer = TimerHelpers.create_one_shot_timer(self) ## The timer managing the delay after a weapon is equipped before it can be used.
var hold_time: float = 0 ## How long we have been holding down the trigger for.


#region Debug
## Edits warnings for the editor for easier debugging.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	for sprite_node: Node2D in sprites_to_tint:
		if not sprite_node.material is ShaderMaterial:
			warnings.append("Weapon sprites in the \"sprites_to_tint\" must have the \"TintAndGlow\" shader applied.")
			break
	return warnings

func _debug_update_particle_emission_box() -> void:
	if debug_emission_box == null or not Engine.is_editor_hint():
		return
	var top_left: Vector2 = particle_emission_origin - particle_emission_extents
	var bottom_right: Vector2 = particle_emission_origin + particle_emission_extents
	var points: Array[Vector2] = [
		top_left, Vector2(bottom_right.x, top_left.y), bottom_right, Vector2(top_left.x, bottom_right.y)
		]
	debug_emission_box.polygon = points
#endregion
