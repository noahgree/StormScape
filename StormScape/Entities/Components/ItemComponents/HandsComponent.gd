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


func _ready() -> void:
	main_hand_sprite.visible = false
	off_hand_sprite.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if equipped_item != null:
			equipped_item.activate()

func on_equipped_item_change(inv_item_slot: Slot) -> void:
	if equipped_item != null:
		equipped_item.exit()
		equipped_item.queue_free()
	if inv_item_slot.item == null:
		set_physics_process(false)
		main_hand_sprite.visible = false
		off_hand_sprite.visible = false
		return

	equipped_item = EquippableItem.create_from_slot(inv_item_slot)

	hands_anchor.scale = Vector2(1, 1)
	hands_anchor.global_rotation = 0
	_change_off_hand_sprite_visibility(true)

	match equipped_item.stats.item_type:
		GlobalData.ItemType.WEAPON:
			main_hand_sprite.visible = false
			if equipped_item is ProjectileWeapon:
				main_hand.position = main_hand_with_proj_weapon_pos
			elif equipped_item is MeleeWeapon:
				main_hand.position = main_hand_with_melee_weapon_pos
		GlobalData.ItemType.CONSUMABLE:
			main_hand.position.y = default_main_hand_pos.y - int(floor(equipped_item.stats.thumbnail.get_height() / 3.0))
			main_hand.position.x = default_main_hand_pos.x + int(floor(equipped_item.stats.thumbnail.get_width() / 2.0))
			main_hand_sprite.position = default_main_hand_pos
			main_hand_sprite.visible = true

	main_hand.add_child(equipped_item)
	equipped_item.enter()
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	if equipped_item == null:
		set_physics_process(false)
		return

	var anim_vector: Vector2 = get_parent().move_fsm.anim_vector

	match equipped_item.stats.item_type:
		GlobalData.ItemType.WEAPON:
			if equipped_item is ProjectileWeapon:
				_manage_proj_weapon_hands(anim_vector)
			elif equipped_item is MeleeWeapon:
				_manage_melee_weapon_hands(anim_vector)
		GlobalData.ItemType.CONSUMABLE:
			_manage_consumable_hands(anim_vector)

func _manage_proj_weapon_hands(anim_vector: Vector2) -> void:
	hands_anchor.global_rotation = (get_global_mouse_position() - hands_anchor.global_position).angle()

	if anim_vector.y < 0:
		z_index = -2
	else:
		z_index = 0

	if anim_vector.x < 0:
		hands_anchor.scale.y = -1
		_change_off_hand_sprite_visibility(false)
	else:
		hands_anchor.scale.y = 1
		_change_off_hand_sprite_visibility(true)

func _manage_melee_weapon_hands(anim_vector: Vector2) -> void:
	if not equipped_item.anim_player.is_playing():
		hands_anchor.global_rotation = get_parent().move_fsm.curr_mouse_direction.angle()

		if anim_vector.y < 0:
			z_index = -2
		else:
			z_index = 0

		if anim_vector.x < 0:
			_change_off_hand_sprite_visibility(false)
		else:
			_change_off_hand_sprite_visibility(true)

func _manage_consumable_hands(anim_vector: Vector2) -> void:
	if anim_vector.y < 0:
		z_index = -2
		hands_anchor.scale.x = -1
		_change_off_hand_sprite_visibility(false)
	else:
		z_index = 0
		hands_anchor.scale.x = 1
		_change_off_hand_sprite_visibility(true)

func _change_off_hand_sprite_visibility(show_off_hand: bool) -> void:
	if equipped_item != null:
		if show_off_hand and equipped_item.is_gripped_by_one_hand:
			off_hand_sprite.visible = true
		else:
			off_hand_sprite.visible = false
	else:
		off_hand_sprite.visible = false
