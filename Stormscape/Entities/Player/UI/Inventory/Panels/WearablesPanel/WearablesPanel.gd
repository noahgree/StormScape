extends CenterContainer
class_name WearablesPanel
## Controls populating and syncing the wearable slots in the player inventory.

@onready var wearables_grid: GridContainer = %WearablesGrid ## The grid container for all wearables slots.
@onready var item_details_panel: ItemDetailsPanel = get_parent().get_node("%ItemDetailsPanel")

var wearables_slots: Array[WearableSlot] = [] ## The slots that display the active wearables.
var updating_from_within: bool = false ## When true, the wearables are already getting added by the load or another internal script function, so we shouldn't trigger the _on_slot_changed function as well.


func _ready() -> void:
	SignalBus.ui_focus_opened.connect(func(_node: Node) -> void: _verify_latest_wearables())

## Sets up the wearables slots their needed data.
func setup_slots(inventory_ui: PlayerInvUI) -> void:
	var i: int = 0
	for slot: WearableSlot in wearables_grid.get_children():
		slot.name = "Wearable_Slot_" + str(i)
		slot.wearable_slot_index = i
		slot.synced_inv = inventory_ui.synced_inv_src_node.inv
		slot.item_changed.connect(_on_wearable_slot_changed)
		slot.index = inventory_ui.assign_next_slot_index()
		wearables_slots.append(slot)
		i += 1

## When one of the wearable slot items changes, we need to add or remove the new or old wearable in the data.
func _on_wearable_slot_changed(slot: WearableSlot, old_item: II, new_item: II) -> void:
	if updating_from_within:
		return

	if old_item != null:
		WearablesManager.remove_wearable(Globals.player_node, slot.wearable_slot_index)

	if new_item != null:
		await get_tree().process_frame # Let the drag and drop finish and the removal happen before re-adding
		WearablesManager.handle_wearable(Globals.player_node, new_item.stats, slot.wearable_slot_index)

## When the focused ui is opened (or otherwise), make sure the wearables in the slots are up to date with
## the array in the entity's data.
func _verify_latest_wearables() -> void:
	for wearable_index: int in range(Globals.player_node.current_wearables.size()):
		var wearable_id: StringName = Globals.player_node.current_wearables[wearable_index]
		updating_from_within = true
		if wearable_id == &"":
			wearables_slots[wearable_index].set_ii(null)
		else:
			var wearable_stats: WearableStats = Items.cached_items.get(wearable_id, null)
			if wearable_stats:
				wearables_slots[wearable_index].set_ii(wearable_stats.create_ii(1))
		updating_from_within = false

## When the mouse enters the player icon margin, try and show the player stats.
func _on_player_icon_trigger_margin_mouse_entered() -> void:
	item_details_panel.show_player_stats()

## When the mouse leaves the player icon margin, try and hide the player stats if they are already showing.
func _on_player_icon_trigger_margin_mouse_exited() -> void:
	item_details_panel.hide_player_stats()
