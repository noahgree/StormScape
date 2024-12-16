extends NinePatchRect
class_name HotbarUI
## The player's hotbar UI controller. Handles logic for the hotbar shown when the inventory is not open.

@export var slot_scene: PackedScene = load("res://UI/Inventory/InventoryCore/Slot/Slot.tscn") ## The slot scene to be instantiated as children.
@export var player_inv: Inventory ## The connected player inventory to reflect as a UI.

@onready var hotbar: HBoxContainer = %HotbarUISlotGrid ## The container that holds the hotbar slots.
@onready var scroll_debounce_timer: Timer = $ScrollDebounceTimer

var hotbar_slots: Array[Slot] = [] ## Local representation of the hotbar slots, updated when changed externally.
var active_slot: Slot ## The slot that is currently selected in the hotbar and potentially contains an equipped item.


## Connects the hotbar slots to the signal needed to keep them up to date.
func _ready() -> void:
	player_inv.slot_updated.connect(_on_slot_updated)
	_setup_slots()

func _setup_slots() -> void:
	hotbar_slots.clear()
	for child: Slot in hotbar.get_children():
		child.queue_free()

	for i: int in range(player_inv.hotbar_size):
		var slot: Slot = slot_scene.instantiate()
		slot.is_hotbar_ui_preview_slot = true
		slot.synced_inv = player_inv
		slot.index = (player_inv.inv_size - player_inv.hotbar_size) + i
		hotbar_slots.append(slot)
		hotbar.add_child(slot)

	active_slot = hotbar_slots[0]
	await get_tree().process_frame
	_apply_selected_slot_fx()

## When receiving the signal that a slot has changed, update the visuals.
func _on_slot_updated(index: int, item: InvItemResource) -> void:
	var hotbar_starting_index: int = player_inv.inv_size - player_inv.hotbar_size
	var hotbar_index: int = index - hotbar_starting_index

	if (index >= hotbar_starting_index) and (index < player_inv.inv_size):
		if index == active_slot.index:
			hotbar_slots[hotbar_index].item = item
			GlobalData.player_node.hands.on_equipped_item_change(active_slot)
		else:
			hotbar_slots[hotbar_index].item = item

func _input(_event: InputEvent) -> void:
	if DebugFlags.HotbarFlags.use_scroll_debounce and not scroll_debounce_timer.is_stopped(): return

	if Input.is_action_just_released("scroll_up", false):
		_change_active_slot_by_count(1)
		scroll_debounce_timer.start()
	elif Input.is_action_just_released("scroll_down", false):
		_change_active_slot_by_count(-1)
		scroll_debounce_timer.start()

func _change_active_slot_by_count(index_count: int) -> void:
	_remove_selected_slot_fx()
	var non_hotbar_size: int = player_inv.inv_size - player_inv.hotbar_size
	var new_index: int = ((active_slot.index - non_hotbar_size) + index_count) % hotbar_slots.size()
	if new_index < 0:
		new_index += hotbar_slots.size()
	active_slot = hotbar_slots[new_index]
	_apply_selected_slot_fx()
	GlobalData.player_node.hands.on_equipped_item_change(active_slot)

func _change_active_slot_to_index_relative_to_full_inventory_size(new_index: int) -> void:
	_remove_selected_slot_fx()
	active_slot = hotbar_slots[new_index - (player_inv.inv_size - player_inv.hotbar_size)]
	_apply_selected_slot_fx()

	GlobalData.player_node.hands.on_equipped_item_change(active_slot)

func _remove_selected_slot_fx() -> void:
	active_slot.selected_texture.hide()
	active_slot.texture = active_slot.default_slot_texture
	active_slot.scale = Vector2.ONE
	active_slot.z_index = 0

func _apply_selected_slot_fx() -> void:
	active_slot.selected_texture.show()
	active_slot.texture = active_slot.no_item_slot_texture
	active_slot.scale = Vector2(1.15, 1.15)
	active_slot.z_index = 1

func _on_visibility_changed() -> void:
	if visible and is_node_ready():
		await get_tree().process_frame
		await get_tree().process_frame
		_apply_selected_slot_fx()
