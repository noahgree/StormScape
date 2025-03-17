extends InventoryUI
class_name PlayerInvUI

@export var hotbar_ui: NinePatchRect ## The hotbar UI to control visibility for.
@export var wpn_mod_slots_ui: NinePatchRect ## The weapon mod slots UI to control visibility for.
@export var btn_up_texture: Texture2D
@export var btn_down_texture: Texture2D

@onready var sort_by_name: NinePatchRect = %SortByName
@onready var sort_by_type: NinePatchRect = %SortByType
@onready var sort_by_rarity: NinePatchRect = %SortByRarity
@onready var auto_stack: NinePatchRect = %AutoStack
@onready var craft: NinePatchRect = %Craft

var is_open: bool = false:
	set(new_value):
		is_open = new_value
		visible = new_value
		GlobalData.focused_ui_is_open = new_value
		hotbar_ui.visible = !new_value
		wpn_mod_slots_ui.visible = !new_value
		get_tree().paused = new_value
		if new_value:
			SignalBus.focused_ui_opened.emit()
		else:
			SignalBus.focused_ui_closed.emit()


## Checks when we open and close the player inventory based on certain key inputs.
func _unhandled_key_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("player_inventory"):
		is_open = !is_open
	elif Input.is_action_just_pressed("esc"):
		is_open = false

	# If we are dragging when we press any key, end the drag.
	if get_viewport().gui_is_dragging():
		var drag_end_event: InputEventMouseButton = InputEventMouseButton.new()
		drag_end_event.button_index = MOUSE_BUTTON_LEFT
		drag_end_event.position = position
		drag_end_event.pressed = false
		Input.parse_input_event(drag_end_event)

## When we click the empty space around this player inventory, change needed visibilities.
func _on_blank_space_input_event(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("primary"):
		is_open = false

## Activates sorting this inventory by name.
func _on_sort_by_name_btn_pressed() -> void:
	GlobalData.player_node.get_node("ItemReceiverComponent").activate_sort_by_name()
func _on_sort_by_name_btn_button_down() -> void:
	sort_by_name.texture = btn_down_texture
func _on_sort_by_name_btn_button_up() -> void:
	sort_by_name.texture = btn_up_texture

## Activates sorting this inventory by rarity.
func _on_sort_by_rarity_btn_pressed() -> void:
	GlobalData.player_node.get_node("ItemReceiverComponent").activate_sort_by_rarity()
func _on_sort_by_rarity_btn_button_down() -> void:
	sort_by_rarity.texture = btn_down_texture
func _on_sort_by_rarity_btn_button_up() -> void:
	sort_by_rarity.texture = btn_up_texture

## Activates sorting this inventory by count.
func _on_sort_by_type_btn_pressed() -> void:
	GlobalData.player_node.get_node("ItemReceiverComponent").activate_sort_by_type()
func _on_sort_by_type_btn_button_down() -> void:
	sort_by_type.texture = btn_down_texture
func _on_sort_by_type_btn_button_up() -> void:
	sort_by_type.texture = btn_up_texture

## Activates auto-stacking this inventory.
func _on_auto_stack_btn_pressed() -> void:
	GlobalData.player_node.get_node("ItemReceiverComponent").activate_auto_stack()
func _on_auto_stack_btn_button_down() -> void:
	auto_stack.texture = btn_down_texture
func _on_auto_stack_btn_button_up() -> void:
	auto_stack.texture = btn_up_texture

## Attempts to craft whatever is shown in the output slot of the crafting UI.
func _on_craft_btn_pressed() -> void:
	get_node("%CraftingManager").attempt_craft()
func _on_craft_btn_button_down() -> void:
	craft.texture = btn_down_texture
func _on_craft_btn_button_up() -> void:
	craft.texture = btn_up_texture
