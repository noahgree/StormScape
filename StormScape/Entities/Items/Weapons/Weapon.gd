@tool
extends EquippableItem
class_name Weapon
## The base class for all equippable weapons in the game.

var pullout_delay_timer: Timer = TimerHelpers.create_one_shot_timer(self) ## The timer managing the delay after a weapon is equipped before it can be used.


## Edits warnings for the editor for easier debugging.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	for sprite_node: Node2D in sprites_to_tint:
		if not sprite_node.material is ShaderMaterial:
			warnings.append("Weapon sprites in the \"sprites_to_tint\" must have the \"TintAndGlow\" shader applied.")
			break
	return warnings
