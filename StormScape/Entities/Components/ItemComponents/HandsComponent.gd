@icon("res://Utilities/Debug/EditorIcons/hands_component.svg")
extends Node2D
class_name HandsComponent
## This component allows the entity to hold an item and interact with it.

@export var default_main_hand_pos: Vector2 = Vector2(6, 1)
@export var main_hand_with_proj_weapon_pos: Vector2 = Vector2(11, 0)
@export var main_hand_with_melee_weapon_pos: Vector2 = Vector2(8, 0)
@export var mouth_pos: Vector2 = Vector2(0, -8) ## Used for emitting food particles.

@onready var hands_anchor: Node2D = $HandsAnchor
@onready var main_hand: Node2D = $HandsAnchor/MainHand
@onready var main_hand_sprite: Sprite2D = $HandsAnchor/MainHandSprite
@onready var off_hand_sprite: Sprite2D = $OffHandSprite

var equipped_item: EquippableItem
var current_x_direction: int = 1
var scale_is_lerping: bool = false
var is_mouse_button_held = false
var been_holding_time: float = 0


func _ready() -> void:
	main_hand_sprite.visible = false
	off_hand_sprite.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if equipped_item != null and not scale_is_lerping:
			if event.is_pressed():
				equipped_item.activate()
			is_mouse_button_held = event.pressed

func _process(delta: float) -> void:
	if equipped_item != null and not scale_is_lerping:
		if is_mouse_button_held:
			been_holding_time += delta
			equipped_item.hold_activate(been_holding_time)
			return
		else:
			if been_holding_time > delta:
				equipped_item.release_hold_activate(been_holding_time)

	been_holding_time = 0

func on_equipped_item_change(inv_item_slot: Slot) -> void:
	if equipped_item != null:
		equipped_item.exit()
		equipped_item.queue_free()

	if inv_item_slot.item == null:
		set_physics_process(false)
		main_hand_sprite.visible = false
		off_hand_sprite.visible = false
		get_parent().move_fsm.rotation_smoothing_factor = get_parent().move_fsm.DEFAULT_ROTATION_SMOOTHING_FACTOR
		return

	equipped_item = EquippableItem.create_from_slot(inv_item_slot)
	hands_anchor.scale = Vector2(1, 1)
	hands_anchor.global_rotation = 0
	get_parent().move_fsm.rotation_smoothing_factor = equipped_item.stats.rotation_smoothing
	scale_is_lerping = false
	been_holding_time = 0
	_change_off_hand_sprite_visibility(true)

	match equipped_item.stats.item_type:
		GlobalData.ItemType.WEAPON:
			main_hand_sprite.visible = false
			if equipped_item is ProjectileWeapon:
				main_hand.position = main_hand_with_proj_weapon_pos
				_manage_proj_weapon_hands(_get_anim_vector())
			elif equipped_item is MeleeWeapon:
				main_hand.position = main_hand_with_melee_weapon_pos
				_manage_melee_weapon_hands(_get_anim_vector())
		GlobalData.ItemType.CONSUMABLE:
			main_hand.position.y = default_main_hand_pos.y - int(floor(equipped_item.stats.thumbnail.get_height() / 2.0))
			main_hand.position.x = default_main_hand_pos.x
			main_hand_sprite.position = default_main_hand_pos
			main_hand_sprite.visible = true
			_manage_consumable_hands(_get_anim_vector())

	main_hand.add_child(equipped_item)
	equipped_item.enter()
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	if equipped_item == null:
		set_physics_process(false)
		return

	match equipped_item.stats.item_type:
		GlobalData.ItemType.WEAPON:
			if equipped_item is ProjectileWeapon:
				_manage_proj_weapon_hands(_get_anim_vector())
			elif equipped_item is MeleeWeapon:
				_manage_melee_weapon_hands(_get_anim_vector())
		GlobalData.ItemType.CONSUMABLE:
			_manage_consumable_hands(_get_anim_vector())

func _manage_proj_weapon_hands(anim_vector: Vector2) -> void:
	_change_z_index(anim_vector)
	_handle_y_scale_lerping(anim_vector)

	if anim_vector.x < 0:
		_change_off_hand_sprite_visibility(false)
	else:
		_change_off_hand_sprite_visibility(true)

	var sprite_pos_with_offsets: Vector2 = hands_anchor.global_position + Vector2(0, equipped_item.proj_origin.y)
	hands_anchor.global_rotation = get_parent().move_fsm.get_lerped_mouse_direction_to_pos(Vector2.RIGHT.rotated(hands_anchor.global_rotation), sprite_pos_with_offsets).angle()

func _manage_melee_weapon_hands(anim_vector: Vector2) -> void:
	if not equipped_item.is_node_ready():
		_do_melee_weapon_hand_placement(anim_vector)
	elif not equipped_item.anim_player.is_playing():
		_do_melee_weapon_hand_placement(anim_vector)

func _do_melee_weapon_hand_placement(anim_vector: Vector2) -> void:
	_change_z_index(anim_vector)
	_handle_y_scale_lerping(anim_vector)

	if hands_anchor.scale.y < 0.95 and hands_anchor.scale.y > -0.95:
		scale_is_lerping = true
	else:
		scale_is_lerping = false

	hands_anchor.global_rotation = get_parent().move_fsm.curr_mouse_direction.angle() - (hands_anchor.scale.y * deg_to_rad(equipped_item.stats.swing_angle / 2.0)) + (hands_anchor.scale.y * deg_to_rad(equipped_item.sprite_visual_rotation))

func _manage_consumable_hands(anim_vector: Vector2) -> void:
	_change_z_index(anim_vector)

	if anim_vector.y < 0:
		hands_anchor.scale.x = -1
		_change_off_hand_sprite_visibility(false)
	else:
		hands_anchor.scale.x = 1
		_change_off_hand_sprite_visibility(true)

func _change_off_hand_sprite_visibility(show_off_hand: bool) -> void:
	if equipped_item != null:
		if show_off_hand and equipped_item.stats.is_gripped_by_one_hand:
			off_hand_sprite.visible = true
		else:
			off_hand_sprite.visible = false
	else:
		off_hand_sprite.visible = false

func _change_z_index(anim_vector: Vector2) -> void:
	if anim_vector.y < 0:
		z_index = -2
	else:
		z_index = 0

func _handle_y_scale_lerping(anim_vector: Vector2) -> void:
	if anim_vector.x > 0.12:
		current_x_direction = 1
	elif anim_vector.x < -0.12:
		current_x_direction = -1

	hands_anchor.scale.y = lerp(hands_anchor.scale.y, -1.0 if current_x_direction == -1 else 1.0, 0.22)

func _get_anim_vector() -> Vector2:
	return get_parent().move_fsm.anim_vector
