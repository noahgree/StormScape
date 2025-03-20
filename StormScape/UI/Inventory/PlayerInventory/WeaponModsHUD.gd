extends NinePatchRect
class_name WeaponModsHUD
## This is responsible for displaying the mods on the HUD (not in the focused inventory).

var mod_slots: Array[ModSlot] = [] ## The slots that are used to display active weapon mods.


func _ready() -> void:
	call_deferred("_setup_slots")

## Sets up the hotbar slots by clearing out any existing slot children and readding them with their needed params.
func _setup_slots() -> void:
	var i: int = 1 # 1 since we are using the actual index of the last crafting slot to start with
	for slot: ModSlot in get_node("WeaponModsHUDStack").get_children():
		slot.name = "Wpn_Mods_HUD_Slot_" + str(i - 1)
		slot.is_hud_ui_preview_slot = true
		slot.synced_inv = GlobalData.player_node.inv
		slot.index = GlobalData.player_node.get_node("%CraftingManager").output_slot.index + i
		mod_slots.append(slot)
		i += 1
