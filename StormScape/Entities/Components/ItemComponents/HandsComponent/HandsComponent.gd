@icon("res://Utilities/Debug/EditorIcons/hands_component.svg")
extends Node2D
class_name HandsComponent
## This component allows the entity to hold an item and interact with it.

@export var hand_texture: Texture2D ## The hand texture that will be used for all EntityHandSprites on this entity.
@export var active_slot_info: MarginContainer ## UI for displaying information about the active slot's item. Only for the player.
@export var main_hand_with_held_item_pos: Vector2 = Vector2(6, 1) ## The position the main hand would be while doing nothing.
@export var main_hand_with_proj_weapon_pos: Vector2 = Vector2(11, 0) ## The position the main hand would start at while holding a projectile weapon. This will most likely be farther out in the x-direction to give more rotational room for the weapon.
@export var main_hand_with_melee_weapon_pos: Vector2 = Vector2(8, 0) ## The position the main hand would start at while holding a melee weapon. This will most likely be farther out in the x-direction to give more rotational room for the weapon.
@export var mouth_pos: Vector2 = Vector2(0, -8) ## Used for emitting food particles from wherever the mouth should be.

@onready var hands_anchor: Node2D = $HandsAnchor ## The anchor for rotating and potentially scaling the hands.
@onready var main_hand: Node2D = $HandsAnchor/MainHand ## The main hand node who's child will any equipped item.
@onready var main_hand_sprite: Sprite2D = $HandsAnchor/MainHandSprite ## The main hand sprite to draw if that equipped item needs it.
@onready var off_hand_sprite: Sprite2D = $OffHandSprite ## The off hand sprite that is drawn when holding a one handed weapon.
@onready var drawn_off_hand: Sprite2D = $HandsAnchor/DrawnOffHand ## The extra off hand sprite that is drawn on top of a weapon that needs it. See the equippability details inside the item resources for more info.
@onready var smoke_particles: CPUParticles2D = $HandsAnchor/SmokeParticles ## The smoke particles used when an item has overheated.
@onready var entity: Entity = get_parent().get_parent() ## The entity using this hands component.

var equipped_item: EquippableItem = null ## The currently equipped equippable item that the entity is holding.
var current_x_direction: int = 1 ## A pos or neg toggle for which direction the anim vector has us facing. Used to flip the x-scale.
var scale_is_lerping: bool = false ## Whether or not the scale is currently lerping between being negative or positive.
var trigger_pressed: bool = false ## If we are currently considering the trigger button to be held down.
var should_rotate: bool = true ## If the equipped item should rotate with the character.
var starting_hands_component_height: float ## The height relative to the bottom of the entity sprite that this component operates at.
var starting_off_hand_sprite_height: float ## The height relative to the hands component scene that the off hand sprite node starts at (and is usually animated from).
var debug_origin_of_projectile_vector: Vector2 ## Used for debug drawing the origin of the projectile aiming vector.
var aim_target_pos: Vector2 = Vector2.ZERO ## The target position of what the hands component should be aiming at when holding something that requires aiming.


#region Save & Load
func _on_before_load_game() -> void:
	unequip_current_item()
#endregion

#region Debug
func _draw() -> void:
	if not equipped_item or not DebugFlags.show_aiming_direction:
		return

	if equipped_item is ProjectileWeapon:
		var local_position: Vector2 = to_local(debug_origin_of_projectile_vector)
		draw_circle(local_position, 4, Color.CORAL)

		var direction_vector: Vector2 = Vector2.RIGHT.rotated(hands_anchor.rotation)
		draw_line(local_position, local_position + direction_vector * 50, Color.GREEN, 0.3)
	elif equipped_item is MeleeWeapon:
		var local_position: Vector2 = to_local(entity.hands.main_hand.global_position)
		draw_circle(local_position, 4, Color.CORAL)

		var direction_vector: Vector2 = Vector2.RIGHT.rotated(hands_anchor.global_rotation)
		draw_line(local_position, local_position + direction_vector * 50, Color.GREEN, 0.3)
#endregion

func _ready() -> void:
	main_hand_sprite.visible = false
	off_hand_sprite.visible = false
	drawn_off_hand.visible = false

	SignalBus.focused_ui_opened.connect(func() -> void: trigger_pressed = false)

	# Make sure to update item rotation on game resume
	if entity is Player:
		SignalBus.focused_ui_closed.connect(func() -> void: handle_aim(CursorManager.get_cursor_mouse_position()))

	starting_hands_component_height = position.y
	starting_off_hand_sprite_height = off_hand_sprite.position.y

#region Inputs
func handle_trigger_pressed() -> void:
	if equipped_item != null and equipped_item.enabled and not scale_is_lerping:
		equipped_item.activate()
	trigger_pressed = true

func handle_trigger_released() -> void:
	if equipped_item != null and equipped_item.enabled and not scale_is_lerping:
		equipped_item.release_hold_activate()
	trigger_pressed = false

func handle_reload() -> void:
	if equipped_item != null and equipped_item is ProjectileWeapon:
		equipped_item.reload()

func handle_aim(new_target_pos: Vector2) -> void:
	aim_target_pos = new_target_pos

## Handles player input responses.
func _unhandled_input(event: InputEvent) -> void:
	if not entity is Player:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			handle_trigger_pressed()
		else:
			handle_trigger_released()
	elif event.is_action_pressed("reload"):
		handle_reload()
#endregion

## Continuously sends the hold activate call when the trigger is pressed as long as the focused ui is fully closed
## and the equipped item is enabled and not lerping.
func _process(delta: float) -> void:
	if Globals.focused_ui_is_open or Globals.focused_ui_is_closing_debounce:
		return
	handle_aim(CursorManager.get_cursor_mouse_position())
	if (equipped_item == null) or (not equipped_item.enabled) or (scale_is_lerping):
		return
	if trigger_pressed:
		equipped_item.hold_activate(delta)
	elif equipped_item is Weapon:
		equipped_item.hold_time = max(0, equipped_item.hold_time - delta)

## Removes the currently equipped item after letting it clean itself up.
func unequip_current_item() -> void:
	if active_slot_info:
		active_slot_info.update_mag_ammo(-1)
		active_slot_info.update_inv_ammo(-1)
		active_slot_info.update_item_name("")

	if entity is Player:
		entity.overhead_ui.reset_all()

	if equipped_item != null:
		trigger_pressed = false
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
		entity.facing_component.rotation_lerping_factor = entity.facing_component.DEFAULT_ROTATION_LERPING_FACTOR
		CursorManager.reset()
		return

	equipped_item = EquippableItem.create_from_slot(inv_item_slot)

	_update_anchor_scale("x", 1)
	_update_anchor_scale("y", 1)
	main_hand.rotation = 0
	entity.facing_component.rotation_lerping_factor = equipped_item.stats.s_mods.get_stat("rotation_lerping") if equipped_item is Weapon else equipped_item.stats.rotation_lerping
	scale_is_lerping = false

	_change_off_hand_sprite_visibility(true)
	_check_for_drawing_off_hand()

	if equipped_item.stats.item_type == Globals.ItemType.WEAPON:
		main_hand_sprite.visible = false
		if equipped_item is ProjectileWeapon:
			main_hand.position = main_hand_with_proj_weapon_pos + equipped_item.stats.holding_offset
			main_hand.rotation += deg_to_rad(equipped_item.stats.holding_degrees)
			snap_y_scale()
			_prep_for_pullout_anim()
			_manage_proj_weapon_hands(_get_facing_dir())
		elif equipped_item is MeleeWeapon:
			main_hand.position = main_hand_with_melee_weapon_pos + equipped_item.stats.holding_offset
			main_hand.rotation += deg_to_rad(equipped_item.stats.holding_degrees)
			snap_y_scale()
			_prep_for_pullout_anim()
			_manage_melee_weapon_hands(_get_facing_dir())
	elif equipped_item.stats.item_type in [Globals.ItemType.CONSUMABLE, Globals.ItemType.WORLD_RESOURCE]:
		hands_anchor.global_rotation = 0
		main_hand.position = main_hand_with_held_item_pos + equipped_item.stats.holding_offset
		main_hand.rotation += deg_to_rad(equipped_item.stats.holding_degrees)
		main_hand_sprite.position = main_hand_with_held_item_pos + equipped_item.stats.main_hand_offset
		main_hand_sprite.visible = true
		_manage_normal_hands(_get_facing_dir())

	equipped_item.ammo_ui = active_slot_info

	if equipped_item.stats.cursors != null:
		CursorManager.change_cursor(equipped_item.stats.cursors, &"default", Color.WHITE)
	else:
		CursorManager.reset()

	main_hand.add_child(equipped_item)
	equipped_item.enter()
	set_physics_process(true)

## Based on the current anim vector, we artificially move the rotation of the hands over before
## the items to simulate a pullout animation.
func _prep_for_pullout_anim() -> void:
	if equipped_item.stats is WeaponResource and equipped_item.stats.s_mods.get_stat("pullout_delay") == 0:
		return

	if _get_facing_dir().x > 0:
		hands_anchor.global_rotation += PI/5
	else:
		hands_anchor.global_rotation -= PI/5

func _physics_process(_delta: float) -> void:
	if Globals.focused_ui_is_open:
		return

	if equipped_item == null:
		set_physics_process(false)
		return

	if equipped_item.stats.item_type == Globals.ItemType.WEAPON:
		if equipped_item is ProjectileWeapon:
			_manage_proj_weapon_hands(_get_facing_dir())
		elif equipped_item is MeleeWeapon:
			if not equipped_item.is_node_ready():
				_manage_melee_weapon_hands(_get_facing_dir())
			elif not equipped_item.anim_player.is_playing():
				_manage_melee_weapon_hands(_get_facing_dir())
	elif equipped_item.stats.item_type in [Globals.ItemType.CONSUMABLE, Globals.ItemType.WORLD_RESOURCE]:
		_manage_normal_hands(_get_facing_dir())

## Manages the placement of the hands when holding a projectile weapon.
func _manage_proj_weapon_hands(facing_dir: Vector2) -> void:
	_change_y_sort(facing_dir)
	_handle_y_scale_lerping(facing_dir)

	if facing_dir.x < -0.12:
		_change_off_hand_sprite_visibility(false)
	elif facing_dir.x > 0.12:
		_change_off_hand_sprite_visibility(true)

	if not should_rotate:
		return

	var y_offset: float = equipped_item.proj_origin.y + equipped_item.stats.holding_offset.y
	y_offset *= hands_anchor.scale.y

	var rotated_offset: Vector2 = Vector2(0, y_offset).rotated(hands_anchor.global_rotation)
	var sprite_pos_with_offsets: Vector2 = hands_anchor.global_position + rotated_offset

	var curr_direction: Vector2 = Vector2.RIGHT.rotated(hands_anchor.global_rotation)

	var lerped_direction_angle: float = LerpHelpers.lerp_direction(
		curr_direction, aim_target_pos, sprite_pos_with_offsets,
		entity.facing_component.rotation_lerping_factor
		).angle()
	hands_anchor.global_rotation = lerped_direction_angle

	# Debug drawing
	debug_origin_of_projectile_vector = sprite_pos_with_offsets
	queue_redraw()

## Manages the placement of the hands when holding a melee weapon.
func _manage_melee_weapon_hands(facing_dir: Vector2) -> void:
	_change_y_sort(facing_dir)
	_handle_y_scale_lerping(facing_dir)

	if facing_dir.x < -0.12:
		_change_off_hand_sprite_visibility(false)
	elif facing_dir.x > 0.12:
		_change_off_hand_sprite_visibility(true)

	if hands_anchor.scale.y < 0.95 and hands_anchor.scale.y > -0.95:
		scale_is_lerping = true
	else:
		scale_is_lerping = false

	if not should_rotate:
		return

	var offset: Vector2 = Vector2(equipped_item.stats.holding_offset.x, equipped_item.stats.holding_offset.x)
	offset.y *= hands_anchor.scale.y

	var swing_angle_offset: float = hands_anchor.scale.y * deg_to_rad(equipped_item.stats.swing_angle / 2.0)
	var sprite_visual_rot_offset: float = hands_anchor.scale.y * deg_to_rad(equipped_item.sprite_visual_rotation)

	var rotated_offset: Vector2 = offset.rotated(hands_anchor.global_rotation)
	var sprite_pos_with_offsets: Vector2 = hands_anchor.global_position + rotated_offset

	var adjusted_aim_pos: Vector2 = (aim_target_pos - sprite_pos_with_offsets).rotated(sprite_visual_rot_offset - swing_angle_offset)

	var curr_direction: Vector2 = Vector2.RIGHT.rotated(hands_anchor.global_rotation)

	var lerped_direction_angle: float = LerpHelpers.lerp_direction_vectors(
		curr_direction, adjusted_aim_pos, entity.facing_component.rotation_lerping_factor
		).angle()

	hands_anchor.global_rotation = lerped_direction_angle

	# Debug drawing
	queue_redraw()

## This manages how the hands operate when not holding a melee or projectile weapon.
func _manage_normal_hands(facing_dir: Vector2) -> void:
	_change_y_sort(facing_dir)

	if facing_dir.y < 0:
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
		drawn_off_hand.position = Vector2(off_hand_sprite.position.x, starting_off_hand_sprite_height) + equipped_item.stats.draw_off_hand_offset + equipped_item.stats.holding_offset
		drawn_off_hand.visible = true

func _change_y_sort(facing_dir: Vector2) -> void:
	if facing_dir.y < 0: # Facing up
		position = entity.sprite.position - Vector2(0, 1)
		hands_anchor.position.y = starting_hands_component_height - position.y
		off_hand_sprite.position.y = starting_off_hand_sprite_height + starting_hands_component_height - position.y
	else:
		if entity.effects != null:
			# Needed to place held items over the status effect particles on the entity when facing down
			position = entity.effects.position + Vector2(0, 1)
			hands_anchor.position.y = starting_hands_component_height - position.y
			off_hand_sprite.position.y = starting_off_hand_sprite_height + starting_hands_component_height - position.y
		else: # If no effects node, this handles facing down normally
			position = Vector2(0, starting_hands_component_height)
			hands_anchor.position.y = 0
			off_hand_sprite.position.y = starting_off_hand_sprite_height

func _handle_y_scale_lerping(facing_dir: Vector2) -> void:
	if facing_dir.x > 0.12:
		current_x_direction = 1
	elif facing_dir.x < -0.12:
		current_x_direction = -1

	_update_anchor_scale("y", lerp(hands_anchor.scale.y, -1.0 if current_x_direction == -1 else 1.0, 0.24))

func snap_y_scale() -> void:
	if _get_facing_dir().x > 0.12:
		current_x_direction = 1
	elif _get_facing_dir().x < -0.12:
		current_x_direction = -1
	_update_anchor_scale("y", -1.0 if current_x_direction == -1 else 1.0)

func _update_anchor_scale(coord: String, new_value: float) -> void:
	if should_rotate:
		if coord == "y":
			hands_anchor.scale.y = new_value
		else:
			hands_anchor.scale.x = new_value

func _get_facing_dir() -> Vector2:
	return entity.facing_component.facing_dir

#region Debug
## Tries to add a mod (given by its cache id) to the currently equipped weapon that the player is holding.
func add_mod_to_weapon_by_id(mod_cache_id: StringName) -> void:
	if not Globals.player_node.hands.equipped_item:
		return
	var equipped_stats: ItemResource = Globals.player_node.hands.equipped_item.stats
	if equipped_stats is not WeaponResource:
		return
	var mod: ItemResource = CraftingManager.get_item_by_id(mod_cache_id, true)
	if mod == null or mod is not WeaponMod:
		printerr("The mod of id \"" + mod_cache_id + "\" does not exist.")
		return
	WeaponModsManager.handle_weapon_mod(
		Globals.player_node.hands.equipped_item.stats, mod, WeaponModsManager.get_next_open_mod_slot(equipped_stats), Globals.player_node
	)

## Tries to toggle a weapon between using hitscan or not.
func toggle_hitscan() -> void:
	if not Globals.player_node.hands.equipped_item:
		return
	var equipped_stats: ItemResource = Globals.player_node.hands.equipped_item.stats
	if equipped_stats is not WeaponResource:
		return
	Globals.player_node.hands.equipped_item.stats.is_hitscan = not Globals.player_node.hands.equipped_item.stats.is_hitscan
#endregion
