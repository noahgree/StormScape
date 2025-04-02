extends VBoxContainer
class_name WearablesPanel
## Controls populating and syncing the wearable slots in the player inventory.

@onready var wearables_grid: GridContainer = %WearablesGrid ## The grid container for all wearables slots.
@onready var player_icon: TextureRect = %PlayerIcon ## The texture displaying the player's look.

var wearables_slots: Array[WearableSlot] = [] ## The slots that display the active wearables.
var updating_from_within: bool = false ## When true, the wearables are already getting added by the load or another internal script function, so we shouldn't trigger the _on_slot_changed function as well.


#region Saving & Loading
func _on_before_load_game() -> void:
	for slot: WearableSlot in wearables_slots:
		slot.item = null

func _on_load_game() -> void:
	updating_from_within = true
	var i: int = 0
	for wearable_dict: Dictionary in Globals.player_node.wearables:
		if wearable_dict.values()[0] != null:
			wearables_slots[i].item = InvItemResource.new(wearable_dict.values()[0], 1)
		i += 1
	updating_from_within = false
#endregion

func _ready() -> void:
	call_deferred("_setup_slots")
	SignalBus.focused_ui_opened.connect(_on_focused_ui_opened)

## Sets up the wearables slots their needed data.
func _setup_slots() -> void:
	var inv: Inventory = Globals.player_node.inv
	var i: int = 1 # 1 since we are using the actual index of the item viewer slot to start with
	for slot: WearableSlot in wearables_grid.get_children():
		slot.name = "Wearable_Slot_" + str(i - 1)
		slot.wearable_slot_index = (i - 1)
		slot.synced_inv = inv
		slot.item_changed.connect(_on_wearable_slot_changed)
		slot.index = Globals.player_node.get_node("%ItemDetailsPanel").item_viewer_slot.index + i
		wearables_slots.append(slot)
		i += 1

## When one of the wearable slot items changes, we need to add or remove the new or old wearable in the data.
func _on_wearable_slot_changed(slot: WearableSlot, old_item: InvItemResource, new_item: InvItemResource) -> void:
	if updating_from_within:
		return

	if old_item != null:
		WearablesManager.remove_wearable(Globals.player_node, old_item.stats, slot.wearable_slot_index)

	if new_item != null:
		await get_tree().process_frame # Let the drag and drop finish and the removal happen before re-adding
		WearablesManager.handle_wearable(Globals.player_node, new_item.stats, slot.wearable_slot_index)

## When the focused ui is opened, make sure the wearables in the slots are up to date with the array
## in the entity's data.
func _on_focused_ui_opened() -> void:
	_verify_latest_wearables()

## Verifies up to date wearables with the entity data.
func _verify_latest_wearables() -> void:
	var i: int = 0
	for wearable_dict: Dictionary in Globals.player_node.wearables:
		if wearable_dict.values()[0] != wearables_slots[i]:
			updating_from_within = true
			if wearable_dict.values()[0] == null:
				wearables_slots[i].item = null
			else:
				wearables_slots[i].item = InvItemResource.new(wearable_dict.values()[0], 1)
			updating_from_within = false
		i += 1
