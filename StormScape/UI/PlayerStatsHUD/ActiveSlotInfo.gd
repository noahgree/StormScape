@icon("res://Utilities/Debug/EditorIcons/active_slot_info.svg")
extends Control
## Updates the info for the player's UI that shows the active slot item and any extra necessary info.

@onready var item_name: Label = %ItemName ## The label that shows the item name.
@onready var mag_ammo: Label = %MagAmmo ## The label that shows the mag ammo.
@onready var inv_ammo: Label = %InvAmmo ## The label that shows the inventory ammo.
@onready var ammo_info_hbox: HBoxContainer = %AmmoInfoHBox ## The HBox that determines ammo label separation.
@onready var info_margins: MarginContainer = %ActiveSlotInfoMargins ## The margins for the active slot info labels.

func _ready() -> void:
	item_name.text = ""
	mag_ammo.text = ""
	inv_ammo.text = ""

	SignalBus.focused_ui_opened.connect(func() -> void: visible = not Globals.player_inv_is_open)
	SignalBus.focused_ui_closed.connect(func() -> void: visible = not Globals.player_inv_is_open)

	if not Globals.player_node:
		await Globals.ready

	SignalBus.focused_ui_closed.connect(calculate_inv_ammo)
	Globals.player_node.stamina_component.max_stamina_changed.connect(func(_new_max_stamina: float) -> void: calculate_inv_ammo())

## Updates the magazine ammo portion of the current equipped item info.
func update_mag_ammo(mag_count: int) -> void:
	if mag_count == -1:
		mag_ammo.text = ""
		mag_ammo.hide()
	else:
		mag_ammo.text = str(mag_count)
		mag_ammo.show()
	_check_both_ammo_labels_visibility()

## Updates the inventory ammo portion of the current equipped item info.
func update_inv_ammo(inv_count: int) -> void:
	if inv_count == -1:
		inv_ammo.text = ""
		ammo_info_hbox.add_theme_constant_override("separation", 0)
		inv_ammo.hide()
	else:
		inv_ammo.text = "/ " + str(inv_count)
		ammo_info_hbox.add_theme_constant_override("separation", 2)
		inv_ammo.show()
	_check_both_ammo_labels_visibility()

## Updates the name portion of the current equipped item info.
func update_item_name(item_name_string: String) -> void:
	item_name.text = item_name_string

## Alter the label margins depending on which ones are showing.
func _check_both_ammo_labels_visibility() -> void:
	if not mag_ammo.visible and not inv_ammo.visible:
		info_margins.add_theme_constant_override("margin_top", 1)
	else:
		info_margins.add_theme_constant_override("margin_top", 0)

## Gets the cumulative total of the ammo that corresponds to the currently equipped item.
func calculate_inv_ammo() -> void:
	if Globals.player_node.hands.equipped_item == null:
		update_inv_ammo(-1)
		return
	var current_item_stats: ItemResource = Globals.player_node.hands.equipped_item.stats
	if current_item_stats is WeaponResource and current_item_stats.hide_ammo_ui:
		update_inv_ammo(-1)
		return

	var count: int = -1
	if current_item_stats is ProjWeaponResource:
		if current_item_stats.ammo_type not in [ProjWeaponResource.ProjAmmoType.NONE, ProjWeaponResource.ProjAmmoType.STAMINA, ProjWeaponResource.ProjAmmoType.SELF, ProjWeaponResource.ProjAmmoType.CHARGES]:
			count = 0
			for i: int in range(Globals.player_node.inv.main_inv_size + Globals.HOTBAR_SIZE):
				var item: InvItemResource = Globals.player_node.inv.inv[i]
				if item != null and (item.stats is ProjAmmoResource) and (item.stats.ammo_type == current_item_stats.ammo_type):
					count += item.quantity
		elif current_item_stats.ammo_type == ProjWeaponResource.ProjAmmoType.STAMINA:
			count = int(floor(Globals.player_node.stats.get_stat("max_stamina")))
	elif current_item_stats is MeleeWeaponResource:
			count = int(floor(Globals.player_node.stats.get_stat("max_stamina")))
	update_inv_ammo(count)
