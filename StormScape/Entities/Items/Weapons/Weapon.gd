@tool
extends EquippableItem
class_name Weapon
## The base class for all equippable weapons in the game.

var pullout_delay_timer: Timer = TimerHelpers.create_one_shot_timer(self) ## The timer managing the delay after a weapon is equipped before it can be used.


#region Saving & Loading
func _on_before_load_game() -> void:
	source_entity.hands.weapon_mod_manager.remove_all_mods_from_weapon(stats)
#endregion

## Edits warnings for the editor for easier debugging.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	for sprite_node: Node2D in sprites_to_tint:
		if not sprite_node.material is ShaderMaterial:
			warnings.append("Weapon sprites must have the \"TintAndGlow\" shader applied.")
			break
	return warnings

## Calls the super method to set the stats.
func _set_stats(new_stats: ItemResource) -> void:
	super._set_stats(new_stats)

func _ready() -> void:
	super._ready()

	if stats.pullout_delay > 0:
		pullout_delay_timer.start(stats.pullout_delay)
