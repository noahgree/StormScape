extends MarginContainer
## Updates the info for the player's UI that shows the active slot item and any extra necessary info.

@export var ammo_icon_textures: Dictionary

@onready var item_name: Label = $VBoxContainer/ItemName ## The label that shows the item name.
@onready var mag_ammo: Label = $VBoxContainer/AmmoInfo/MagAmmo ## The label that shows the mag ammo.
@onready var inv_ammo: Label = $VBoxContainer/AmmoInfo/InvAmmo ## The label that shows the inventory ammo.
@onready var ammo_info_hbox: HBoxContainer = $VBoxContainer/AmmoInfo ## The HBox that determines ammo label separation.


func _ready() -> void:
	item_name.text = ""
	mag_ammo.text = ""
	inv_ammo.text = ""

## Updates the magazine ammo portion of the current equipped item inf`o.
func update_mag_ammo(mag_count: int) -> void:
	if mag_count == -1:
		mag_ammo.text = ""
	else:
		mag_ammo.text = str(mag_count)

## Updates the inventory ammo portion of the current equipped item info.
func update_inv_ammo(inv_count: int) -> void:
	if inv_count == -1:
		inv_ammo.text = ""
		ammo_info_hbox.add_theme_constant_override("separation", 0)
	else:
		inv_ammo.text = "/ " + str(inv_count)
		ammo_info_hbox.add_theme_constant_override("separation", 2)

## Updates the name portion of the current equipped item info.
func update_item_name(item_name_string: String) -> void:
	item_name.text = item_name_string
