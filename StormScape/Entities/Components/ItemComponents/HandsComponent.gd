extends Node2D
class_name HandsComponent
## This component allows the entity to hold an item and interact with it.

@onready var hands_anchor: Node2D = $HandsAnchor
@onready var main_hand: Node2D = $HandsAnchor/MainHand
@onready var off_hand_sprite: Sprite2D = $OffHandSprite

var equipped_item: EquippableItem


func _ready() -> void:
	off_hand_sprite.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if equipped_item and equipped_item.has_method("fire"):
			equipped_item.fire(get_parent())

func _physics_process(_delta: float) -> void:
	hands_anchor.global_rotation = (get_global_mouse_position() - hands_anchor.global_position).angle()

	var anim_vector: Vector2 = get_parent().move_fsm.anim_vector
	if anim_vector.y < 0:
		z_index = -2
	else:
		z_index = 0
	if anim_vector.x < 0:
		hands_anchor.scale.y = -1
		_change_hand_sprite_visibilities(false)
	else:
		hands_anchor.scale.y = 1
		_change_hand_sprite_visibilities(true)

func on_equipped_item_change(inv_item: InvItemResource) -> void:
	_create_new_item(inv_item)
	equipped_item.stats = inv_item.stats
	_change_hand_sprite_visibilities(true)

	main_hand.add_child(equipped_item)

func _create_new_item(inv_item: InvItemResource) -> void:
	if equipped_item: equipped_item.queue_free()
	match inv_item.stats.item_type:
		GlobalData.ItemType.WEAPON:
			equipped_item = inv_item.stats.weapon_scene.instantiate()
		_:
			equipped_item = EquippableItem.new()

func _change_hand_sprite_visibilities(show_off_hand: bool) -> void:
	if equipped_item:
		if show_off_hand and equipped_item.is_gripped_by_one_hand:
			off_hand_sprite.visible = true
		else:
			off_hand_sprite.visible = false
	else:
		off_hand_sprite.visible = false
