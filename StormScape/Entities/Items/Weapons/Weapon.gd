@tool
extends EquippableItem
class_name Weapon
## The base class for all equippable weapons in the game.

@onready var weapon_mod_manager: WeaponModManager = $WeaponModManager ## The node managing weapon mods.

var pullout_delay_timer: Timer = TimerHelpers.create_one_shot_timer(self) ## The timer managing the delay after a weapon is equipped before it can be used.


#region Saving & Loading
func _on_before_load_game() -> void:
	for weapon_mod: WeaponMod in stats.current_mods.values():
		weapon_mod_manager.request_mod_removal(weapon_mod.mod_name)
	stats.current_mods.clear()
#endregion

## Edits warnings for the editor for easier debugging.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	for sprite_node: Node2D in sprites_to_tint:
		if not sprite_node.material is ShaderMaterial:
			warnings.append("Weapon sprites must have the \"TintAndGlow\" shader applied. Also ensure the shader is set to \"Local to Scene\".")
			break
	if not has_node("WeaponModManager"):
		warnings.append("This node must have a WeaponModManager attached.")
	return warnings

## Calls the super method to set the stats.
func _set_stats(new_stats: ItemResource) -> void:
	super._set_stats(new_stats)

func _ready() -> void:
	assert(has_node("WeaponModManager"), name + " does not have a weapon mod manager node attached.")
	super._ready()

	if stats.pullout_delay > 0:
		pullout_delay_timer.start(stats.pullout_delay)
