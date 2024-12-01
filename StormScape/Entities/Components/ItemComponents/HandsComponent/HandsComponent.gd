@icon("res://Utilities/Debug/EditorIcons/hands_component.svg")
extends Node2D
class_name HandsComponent
## This component allows the entity to hold an item and interact with it.

@export var main_hand_with_held_item_pos: Vector2 = Vector2(6, 1)
@export var main_hand_with_proj_weapon_pos: Vector2 = Vector2(11, 0)
@export var main_hand_with_melee_weapon_pos: Vector2 = Vector2(8, 0)
@export var mouth_pos: Vector2 = Vector2(0, -8) ## Used for emitting food particles.

@onready var hands_anchor: Node2D = $HandsAnchor
@onready var main_hand: Node2D = $HandsAnchor/MainHand
@onready var main_hand_sprite: Sprite2D = $HandsAnchor/MainHandSprite
@onready var off_hand_sprite: Sprite2D = $OffHandSprite
@onready var drawn_off_hand: Sprite2D = $HandsAnchor/DrawnOffHand

var equipped_item: EquippableItem = null
var current_x_direction: int = 1
var scale_is_lerping: bool = false
var is_mouse_button_held = false
var been_holding_time: float = 0
var equipped_item_should_follow_mouse: bool = true


#region Save & Load
func _on_before_load_game() -> void:
	unequip_current_item()
#endregion

func _ready() -> void:
	main_hand_sprite.visible = false
	off_hand_sprite.visible = false
	SignalBus.focused_ui_opened.connect(func():
		is_mouse_button_held = false
		been_holding_time = 0
		)

func _unhandled_input(event: InputEvent) -> void:
	if equipped_item != null:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if not scale_is_lerping:
				if event.is_pressed():
					equipped_item.activate()
			is_mouse_button_held = event.pressed
		elif Input.is_action_pressed("reload") and equipped_item is ProjectileWeapon:
			equipped_item.reload()

func _process(delta: float) -> void:
	if equipped_item != null:
		if is_mouse_button_held:
			been_holding_time += delta
			if not scale_is_lerping:
				equipped_item.hold_activate(been_holding_time)
			return
		else:
			equipped_item.release_hold_activate(been_holding_time)
	been_holding_time = 0

## Removes the currently equipped item after letting it clean itself up.
func unequip_current_item() -> void:
	if equipped_item != null:
		is_mouse_button_held = false
		been_holding_time = 0
		drawn_off_hand.visible = false
		equipped_item.exit()
		equipped_item.queue_free()
		equipped_item = null

## Handles positioning of the hands for the newly equipped item and then lets physics process take over.
func on_equipped_item_change(inv_item_slot: Slot) -> void:
	unequip_current_item()

	if inv_item_slot.item == null or inv_item_slot.item.stats.item_scene == null:
		set_physics_process(false)
		main_hand_sprite.visible = false
		off_hand_sprite.visible = false
		get_parent().move_fsm.rotation_lerping_factor = get_parent().move_fsm.DEFAULT_ROTATION_LERPING_FACTOR
		return

	equipped_item = EquippableItem.create_from_slot(inv_item_slot)

	_update_anchor_scale("x", 1)
	_update_anchor_scale("y", 1)
	main_hand.rotation = 0
	get_parent().move_fsm.rotation_lerping_factor = equipped_item.stats.rotation_lerping
	scale_is_lerping = false
	been_holding_time = 0

	_change_off_hand_sprite_visibility(true)
	_check_for_drawing_off_hand()

	if equipped_item.stats.item_type == GlobalData.ItemType.WEAPON:
		main_hand_sprite.visible = false
		if equipped_item is ProjectileWeapon:
			main_hand.position = main_hand_with_proj_weapon_pos
			snap_y_scale()
			_prep_for_pullout_anim()
			_manage_proj_weapon_hands(_get_anim_vector())
		elif equipped_item is MeleeWeapon:
			main_hand.position = main_hand_with_melee_weapon_pos
			snap_y_scale()
			_prep_for_pullout_anim()
			_manage_melee_weapon_hands(_get_anim_vector())
	elif equipped_item.stats.item_type == GlobalData.ItemType.CONSUMABLE or equipped_item.stats.item_type == GlobalData.ItemType.WORLD_RESOURCE:
		hands_anchor.global_rotation = 0
		main_hand.position.y = main_hand_with_held_item_pos.y + equipped_item.stats.holding_offset.y
		main_hand.position.x = main_hand_with_held_item_pos.x + equipped_item.stats.holding_offset.x
		main_hand.rotation += deg_to_rad(equipped_item.stats.holding_degrees)
		main_hand_sprite.position = main_hand_with_held_item_pos + equipped_item.stats.main_hand_offset
		main_hand_sprite.visible = true
		_manage_normal_hands(_get_anim_vector())

	main_hand.add_child(equipped_item)
	equipped_item.enter()
	set_physics_process(true)

## Based on the current anim vector, we artificially move the rotation of the hands over before the items to simulate
## a pullout animation.
func _prep_for_pullout_anim() -> void:
	if _get_anim_vector().x > 0:
		if _get_anim_vector().y > 0:
			hands_anchor.global_rotation = PI/4
		else:
			hands_anchor.global_rotation = -PI/4
	else:
		if _get_anim_vector().y > 0:
			hands_anchor.global_rotation = PI/2
		else:
			hands_anchor.global_rotation = -PI/2

func _physics_process(_delta: float) -> void:
	if equipped_item == null:
		set_physics_process(false)
		return

	if equipped_item.stats.item_type == GlobalData.ItemType.WEAPON:
		if equipped_item is ProjectileWeapon:
			_manage_proj_weapon_hands(_get_anim_vector())
		elif equipped_item is MeleeWeapon:
			_manage_melee_weapon_hands(_get_anim_vector())
	elif equipped_item.stats.item_type == GlobalData.ItemType.CONSUMABLE or equipped_item.stats.item_type == GlobalData.ItemType.WORLD_RESOURCE:
		_manage_normal_hands(_get_anim_vector())

func _manage_proj_weapon_hands(anim_vector: Vector2) -> void:
	_change_z_index(anim_vector)
	_handle_y_scale_lerping(anim_vector)

	if anim_vector.x < -0.12:
		_change_off_hand_sprite_visibility(false)
	elif anim_vector.x > 0.12:
		_change_off_hand_sprite_visibility(true)

	if equipped_item_should_follow_mouse:
		var sprite_pos_with_offsets: Vector2 = hands_anchor.global_position + Vector2(0, equipped_item.proj_origin.y)
		var direction_vector = Vector2.RIGHT.rotated(hands_anchor.global_rotation)

		var lerped_direction_angle = get_parent().move_fsm.get_lerped_mouse_direction_to_pos(direction_vector, sprite_pos_with_offsets).angle()

		hands_anchor.global_rotation = lerped_direction_angle

func _manage_melee_weapon_hands(anim_vector: Vector2) -> void:
	if not equipped_item.is_node_ready():
		_do_melee_weapon_hand_placement(anim_vector)
	elif not equipped_item.anim_player.is_playing():
		_do_melee_weapon_hand_placement(anim_vector)

func _do_melee_weapon_hand_placement(anim_vector: Vector2) -> void:
	_change_z_index(anim_vector)
	_handle_y_scale_lerping(anim_vector)

	if anim_vector.x < -0.12:
		_change_off_hand_sprite_visibility(false)
	elif anim_vector.x > 0.12:
		_change_off_hand_sprite_visibility(true)

	if hands_anchor.scale.y < 0.95 and hands_anchor.scale.y > -0.95:
		scale_is_lerping = true
	else:
		scale_is_lerping = false

	if equipped_item_should_follow_mouse:
		var swing_angle_offset = hands_anchor.scale.y * deg_to_rad(equipped_item.stats.swing_angle / 2.0)
		var sprite_visual_rotation_offset = hands_anchor.scale.y * deg_to_rad(equipped_item.sprite_visual_rotation)
		var target_position = hands_anchor.global_position - Vector2(0, hands_anchor.global_rotation - swing_angle_offset + sprite_visual_rotation_offset)
		var direction_vector = Vector2.RIGHT.rotated(hands_anchor.global_rotation)

		var lerped_direction_angle = get_parent().move_fsm.get_lerped_mouse_direction_to_pos(direction_vector, target_position).angle()

		hands_anchor.global_rotation = lerped_direction_angle

func _manage_normal_hands(anim_vector: Vector2) -> void:
	_change_z_index(anim_vector)

	if anim_vector.y < 0:
		_update_anchor_scale("x", -1)
		_change_off_hand_sprite_visibility(false)
	else:
		_update_anchor_scale("x", 1)
		_change_off_hand_sprite_visibility(true)

func _change_off_hand_sprite_visibility(show_off_hand: bool) -> void:
	if equipped_item != null:
		if show_off_hand and equipped_item.stats.is_gripped_by_one_hand:
			off_hand_sprite.visible = true
		else:
			off_hand_sprite.visible = false
	else:
		off_hand_sprite.visible = false

func _check_for_drawing_off_hand() -> void:
	if equipped_item.stats.draw_off_hand and not equipped_item.stats.is_gripped_by_one_hand:
		drawn_off_hand.position = off_hand_sprite.position + equipped_item.stats.draw_off_hand_offset
		drawn_off_hand.visible = true

func _change_z_index(anim_vector: Vector2) -> void:
	if anim_vector.y < 0:
		z_index = -2
		drawn_off_hand.z_index = -1
		main_hand_sprite.z_index = -1
	else:
		z_index = 0
		drawn_off_hand.z_index = 0
		main_hand_sprite.z_index = 0

func _handle_y_scale_lerping(anim_vector: Vector2) -> void:
	if anim_vector.x > 0.12:
		current_x_direction = 1
	elif anim_vector.x < -0.12:
		current_x_direction = -1

	_update_anchor_scale("y", lerp(hands_anchor.scale.y, -1.0 if current_x_direction == -1 else 1.0, 0.22))

func snap_y_scale() -> void:
	if _get_anim_vector().x > 0.12:
		current_x_direction = 1
	elif _get_anim_vector().x < -0.12:
		current_x_direction = -1
	_update_anchor_scale("y", -1.0 if current_x_direction == -1 else 1.0)

func _update_anchor_scale(coord: String, new_value: float) -> void:
	if equipped_item_should_follow_mouse:
		if coord == "y":
			hands_anchor.scale.y = new_value
		else:
			hands_anchor.scale.x = new_value

func _get_anim_vector() -> Vector2:
	return get_parent().move_fsm.anim_vector
