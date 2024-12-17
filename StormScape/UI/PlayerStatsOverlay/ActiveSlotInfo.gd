extends CenterContainer
## Updates the info for the player's UI that shows the active slot item and any extra necessary info.

@onready var item_name: Label = $VBoxContainer/ItemName
@onready var mag_ammo: Label = $VBoxContainer/AmmoInfo/MagAmmo
@onready var inv_ammo: Label = $VBoxContainer/AmmoInfo/InvAmmo
@onready var ammo_info_hbox: HBoxContainer = $VBoxContainer/AmmoInfo


func _ready() -> void:
	item_name.text = ""
	mag_ammo.text = ""
	inv_ammo.text = ""

func update_mag_ammo(mag_count: int) -> void:
	if mag_count == -1:
		mag_ammo.text = ""
	else:
		mag_ammo.text = str(mag_count)

func update_inv_ammo(inv_count: int) -> void:
	if inv_count == -1:
		inv_ammo.text = ""
		ammo_info_hbox.add_theme_constant_override("separation", 0)
	else:
		inv_ammo.text = "/ " + str(inv_count)
		ammo_info_hbox.add_theme_constant_override("Separation", 2)

func update_item_name(item_name_string: String) -> void:
	item_name.text = item_name_string
