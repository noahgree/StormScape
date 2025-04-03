extends MarginContainer
class_name HotbarUI
## The player's hotbar UI controller. Handles logic for the hotbar shown when the inventory is not open.

@export var slot_scene: PackedScene = preload("res://UI/Inventory/InventoryCore/Slot/SlotCore/Slot.tscn") ## The slot scene to be instantiated as children.
@export var player_inv: Inventory ## The connected player inventory to reflect as a UI.
@export var active_slot_info: Control ## The node that controls displaying the info about the active slot.

@onready var hotbar: HBoxContainer = %HotbarUISlotGrid ## The container that holds the hotbar slots.

var scroll_debounce_timer: Timer = TimerHelpers.create_one_shot_timer(self, 0.1) ## A timer used in debug that restricts scrolling speed of the slots.
var hotbar_slots: Array[Slot] = [] ## Local representation of the hotbar slots, updated when changed externally.
var active_slot: Slot ## The slot that is currently selected in the hotbar and potentially contains an equipped item.


## Connects the hotbar slots to the signal needed to keep them up to date.
func _ready() -> void:
	player_inv.slot_updated.connect(_on_slot_updated)

	_setup_slots()

	if not Globals.player_node:
		await SignalBus.player_ready

	Globals.player_node.stamina_component.max_stamina_changed.connect(func(_new_max_stamina: float) -> void: _update_inv_ammo_ui())

	SignalBus.focused_ui_closed.connect(_update_inv_ammo_ui)
	SignalBus.focused_ui_opened.connect(hide)
	SignalBus.focused_ui_closed.connect(show)

## Sets up the hotbar slots by clearing out any existing slot children and readding them with their needed params.
func _setup_slots() -> void:
	var i: int = 0
	for slot: Slot in hotbar.get_children():
		slot.name = "Hotbar_HUD_Slot_" + str(i)
		slot.is_hud_ui_preview_slot = true
		slot.synced_inv = player_inv
		slot.index = player_inv.main_inv_size + i
		hotbar_slots.append(slot)
		i += 1

	active_slot = hotbar_slots[0]

	await get_tree().process_frame
	_apply_selected_slot_fx()

## When receiving the signal that a slot has changed, update the visuals.
func _on_slot_updated(index: int, item: InvItemResource) -> void:
	var hotbar_starting_index: int = player_inv.main_inv_size

	if (index >= hotbar_starting_index) and (index < (hotbar_starting_index + player_inv.hotbar_size)):
		var index_within_hotbar: int = index - hotbar_starting_index

		if index == active_slot.index:
			if (active_slot.item != null and item != null) and item.stats.is_same_as(active_slot.item.stats):
				hotbar_slots[index_within_hotbar].item = item
			else:
				hotbar_slots[index_within_hotbar].item = item
				_update_hands_about_new_active_item()
		else:
			hotbar_slots[index_within_hotbar].item = item

	_update_inv_ammo_ui()
	_default_ammo_update_method() # Called after the hotbar item is updated above to reflect the new item
	update_hotbar_tint_progresses()

## Updates the hands component with the new active slot and associated item if any. Then updates the
## UI for the new item name. This must happen here since the signal's order isn't guaranteed,
## and we need the active slot to update first.
func _update_hands_about_new_active_item() -> void:
	Globals.player_node.hands.on_equipped_item_change(active_slot)

	if active_slot.item != null:
		active_slot_info.update_item_name(active_slot.item.stats.name)
	else:
		active_slot_info.update_item_name("Empty")

## This will update the mag ammo display with the item quantity by default if no ammo method is
## defined in the equippable item subclass.
func _default_ammo_update_method() -> void:
	if active_slot.item != null:
		var equipped_item: EquippableItem = Globals.player_node.hands.equipped_item
		if not equipped_item:
			return

		if not equipped_item.has_method("_update_ammo_ui"):
			active_slot_info.update_mag_ammo(active_slot.item.quantity)

## Updates all tint progresses for cooldowns on the hotbar slots.
func update_hotbar_tint_progresses() -> void:
	for slot: Slot in hotbar_slots:
		if slot.item != null:
			slot.update_tint_progress(
				Globals.player_node.inv.auto_decrementer.get_cooldown(slot.item.stats.get_cooldown_id())
				)
		else:
			slot.update_tint_progress(0)

## Updates the ammo UI with the cumulative total of the ammo that corresponds to the currently equipped item.
func _update_inv_ammo_ui() -> void:
	var count: int = -1

	if active_slot.item != null:
		var stats: ItemResource = active_slot.item.stats
		if stats is ProjWeaponResource and not stats.hide_ammo_ui:
			if stats.ammo_type not in [ProjWeaponResource.ProjAmmoType.NONE, ProjWeaponResource.ProjAmmoType.STAMINA, ProjWeaponResource.ProjAmmoType.SELF, ProjWeaponResource.ProjAmmoType.CHARGES]:
				count = 0
				for i: int in range(player_inv.main_inv_size + player_inv.hotbar_size):
					var item: InvItemResource = player_inv.inv[i]
					if item != null and (item.stats is ProjAmmoResource) and (item.stats.ammo_type == active_slot.item.stats.ammo_type):
						count += item.quantity
			elif stats.ammo_type == ProjWeaponResource.ProjAmmoType.STAMINA:
				count = int(floor(Globals.player_node.stats.get_stat("max_stamina")))
		elif stats is MeleeWeaponResource:
			count = int(floor(Globals.player_node.stats.get_stat("max_stamina")))

	active_slot_info.update_inv_ammo(count)

## Handles input mainly relating to changing the active slot.
func _unhandled_input(event: InputEvent) -> void:
	if Globals.focused_ui_is_open:
		return

	if DebugFlags.HotbarFlags.use_scroll_debounce and not scroll_debounce_timer.is_stopped():
		return

	if Input.is_action_just_released("scroll_up", false):
		_change_active_slot_by_count(1)
		scroll_debounce_timer.start()
	elif Input.is_action_just_released("scroll_down", false):
		_change_active_slot_by_count(-1)
		scroll_debounce_timer.start()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_1:
				_change_active_slot_to_hotbar_index(0)
			KEY_2:
				_change_active_slot_to_hotbar_index(1)
			KEY_3:
				_change_active_slot_to_hotbar_index(2)
			KEY_4:
				_change_active_slot_to_hotbar_index(3)
			KEY_5:
				_change_active_slot_to_hotbar_index(4)

## Changes the active hotbar slot by the passed in count. Handles wrapping values to the number of slots.
func _change_active_slot_by_count(index_count: int) -> void:
	var non_hotbar_size: int = player_inv.main_inv_size
	var new_index: int = ((active_slot.index - non_hotbar_size) + index_count) % hotbar_slots.size()
	if new_index < 0:
		new_index += hotbar_slots.size()
	if new_index == hotbar_slots.find(active_slot):
		return

	_remove_selected_slot_fx()
	active_slot = hotbar_slots[new_index]
	_setup_after_active_slot_change()

## Changes the active slot to the exact index within the hotbar that is passed in. If you want the leftmost
## hotbar slot, pass in 0, and so on.rd
func _change_active_slot_to_hotbar_index(new_index: int) -> void:
	if new_index == hotbar_slots.find(active_slot):
		return
	new_index = min(new_index, player_inv.hotbar_size)

	_remove_selected_slot_fx()
	active_slot = hotbar_slots[new_index]
	_setup_after_active_slot_change()

## Changes the active slot relative to the full size of the inventory.
## Used at game load when restoring the active slot.
func change_active_slot_to_index_relative_to_full_inventory_size(new_index: int) -> void:
	await get_tree().process_frame # Need to wait for the slots to be updated with the items before signaling the hands component

	_remove_selected_slot_fx()
	active_slot = hotbar_slots[new_index - (player_inv.main_inv_size)]
	_setup_after_active_slot_change()

## Performs the needed work after the active slot has changed, such as applying the slot FX and updating the
## hands component.
func _setup_after_active_slot_change() -> void:
	_apply_selected_slot_fx()
	_update_hands_about_new_active_item()
	_update_inv_ammo_ui()
	_default_ammo_update_method()

## Removes the scaling and texture changes of the active slot to prep for adding them to the new one.
func _remove_selected_slot_fx() -> void:
	active_slot.selected_texture.hide()
	active_slot.texture = active_slot.default_slot_texture
	active_slot.scale = Vector2.ONE
	active_slot.z_index = 0

## Adds the scaling and texture changes to a new active slot.
func _apply_selected_slot_fx() -> void:
	active_slot.selected_texture.show()
	active_slot.texture = null if active_slot.item != null else active_slot.no_item_slot_texture
	active_slot.scale = Vector2(1.15, 1.15)
	active_slot.z_index = 1

## When the visibility of the hotbar changes, make sure to reapply the texture and scaling fx to the
## active slot if it is visible again.
func _on_visibility_changed() -> void:
	if visible and is_node_ready():
		await get_tree().process_frame
		await get_tree().process_frame
		_apply_selected_slot_fx()
