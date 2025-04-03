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
	SignalBus.focused_ui_opened.connect(hide)
	SignalBus.focused_ui_closed.connect(show)

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

func _check_both_ammo_labels_visibility() -> void:
	if not mag_ammo.visible and not inv_ammo.visible:
		info_margins.add_theme_constant_override("margin_top", 1)
	else:
		info_margins.add_theme_constant_override("margin_top", 0)
