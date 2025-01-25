@tool
extends Area2D
class_name Item
## Base class for all items in the game. Defines logic for interacting with entities that can pick it up.

static var item_scene: PackedScene = preload("res://Entities/Items/ItemCore/Item.tscn") ## The item scene to be instantiated when items are dropped onto the ground.

@export var stats: ItemResource = null: set = _set_item ## The item resource driving the stats and type of item.
@export var quantity: int = 1 ## The quantity associated with the physical item.

@onready var collision_shape: CollisionShape2D = $CollisionShape2D ## The active collision shape for the item to be interacted with.
@onready var icon: Sprite2D = $Sprite2D ## The sprite that shows the item's texture.
@onready var ground_glow: Sprite2D = $GroundGlowScaler/GroundGlow ## The fake light that immitates a glowing effect on the ground.
@onready var particles: CPUParticles2D = $Particles ## The orb particles that spawn on higher rarity items.
@onready var line_particles: CPUParticles2D = $LineParticles ## The line particles that spawn on the highest rarity items.
@onready var anim_player: AnimationPlayer = $AnimationPlayer ## The animation player controlling the hover, spawn, and remove anims.

var can_be_auto_picked_up: bool = false ## Whether the item can currently be auto picked up by walking over it.
var can_be_picked_up_at_all: bool = true ## When true, the item is in a state where it cannot be picked up by any means.
var lifetime_timer: Timer = TimerHelpers.create_one_shot_timer(self, 300, remove_from_world) ## The timer tracking how long the item has left to exist on the ground.


func _set_item(item_stats: ItemResource) -> void:
	stats = item_stats
	if stats and icon:
		$CollisionShape2D.shape.radius = stats.pickup_radius
		icon.texture = stats.ground_icon
		icon.position.y = -icon.texture.get_height() / 2.0
		if ground_glow:
			ground_glow.scale.x = 0.05 * (icon.texture.get_width() / 16.0)
			ground_glow.scale.y = 0.05 * (icon.texture.get_height() / 32.0)
			ground_glow.position.y = ceil(icon.texture.get_height() / 2.0) + ceil(7.0 / 2.0) - 2 + icon.position.y

## Spawns an item with the passed in details on the ground. Keep suid means we should duplicate the item's stats and pass the
## old session uid along to it.
static func spawn_on_ground(item_stats: ItemResource, quant: int, location: Vector2,
							location_range: float, keep_suid: bool = true) -> void:
	var quantity_count: int = quant
	while quantity_count > 0:
		var item_to_spawn: Item = item_scene.instantiate()
		item_to_spawn.stats = item_stats.duplicate_with_suid() if keep_suid else item_stats.duplicate()

		var quant_to_use: int = min(quantity_count, item_stats.stack_size)
		item_to_spawn.quantity = quant_to_use
		quantity_count -= quant_to_use

		@warning_ignore("narrowing_conversion") item_to_spawn.global_position = location + Vector2(randi_range((-location_range - 6) / 2.0, (location_range - 6) / 2.0) + 6, randi_range(0, (location_range - 6)) + 6)

		var spawn_callable: Callable = GlobalData.world_root.get_node("WorldItemsManager").add_item.bind(item_to_spawn)
		spawn_callable.call_deferred()

#region Save & Load
func _on_save_game(save_data: Array[SaveData]) -> void:
	var data: ItemData = ItemData.new()
	data.scene_path = scene_file_path
	data.position = global_position
	data.stats = stats
	data.quantity = quantity

	save_data.append(data)

func _on_before_load_game() -> void:
	queue_free()

func _is_instance_on_load_game(item_data: ItemData) -> void:
	global_position = item_data.position
	stats = item_data.stats
	quantity = item_data.quantity

	GlobalData.world_root.get_node("WorldItemsManager").add_item(self)

func _on_load_game() -> void:
	pass
#endregion

func _ready() -> void:
	_set_item(stats)

	if not Engine.is_editor_hint():
		add_to_group("items_on_ground")
		particles.emitting = false
		_set_rarity_colors()
		icon.set_instance_shader_parameter("random_start_offset", randf() * 2.0)

		lifetime_timer.start()

	if not can_be_auto_picked_up:
		await get_tree().create_timer(1.0, false, false, false).timeout
		can_be_auto_picked_up = true

## Sets the rarity FX using the colors associated with that rarity, given by the dictionary in the GlobalData.
func _set_rarity_colors() -> void:
	icon.material.set_shader_parameter("width", 0.5)
	ground_glow.self_modulate = GlobalData.rarity_colors.ground_glow.get(stats.rarity)
	icon.material.set_shader_parameter("outline_color", GlobalData.rarity_colors.outline_color.get(stats.rarity))
	icon.material.set_shader_parameter("tint_color", GlobalData.rarity_colors.tint_color.get(stats.rarity))
	var gradient_texture: GradientTexture1D = GradientTexture1D.new()
	gradient_texture.gradient = Gradient.new()
	gradient_texture.gradient.add_point(0, GlobalData.rarity_colors.glint_color.get(stats.rarity))
	icon.material.set_shader_parameter("color_gradient", gradient_texture)
	if stats.rarity == GlobalData.ItemRarity.EPIC or stats.rarity == GlobalData.ItemRarity.LEGENDARY or stats.rarity == GlobalData.ItemRarity.SINGULAR:
		particles.color = GlobalData.rarity_colors.ground_glow.get(stats.rarity)
		particles.emitting = true
	if stats.rarity == GlobalData.ItemRarity.SINGULAR:
		particles.amount *= 3

## When the spawn animation finishes, start hovering and emitting particles if needed.
func _on_spawn_anim_completed() -> void:
	anim_player.play("hover")
	if stats.rarity == GlobalData.ItemRarity.LEGENDARY or stats.rarity == GlobalData.ItemRarity.SINGULAR:
		line_particles.color = GlobalData.rarity_colors.tint_color.get(stats.rarity)
		line_particles.emitting = true

## Removes the item from the world
func remove_from_world() -> void:
	anim_player.play("remove")

func _on_remove_anim_completed() -> void:
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if not can_be_picked_up_at_all: return

	if area is ItemReceiverComponent and area.get_parent() is Player:
		if stats.auto_pickup and can_be_auto_picked_up:
			(area as ItemReceiverComponent).pickup_item(self)
		else:
			(area as ItemReceiverComponent).add_to_in_range_queue(self)

		if not area.items_in_range.is_empty():
			for item: Item in (area as ItemReceiverComponent).items_in_range:
				item.icon.material.set_shader_parameter("outline_color", GlobalData.rarity_colors.outline_color.get(item.stats.rarity))
				item.icon.material.set_shader_parameter("width", 0.5)

			(area as ItemReceiverComponent).items_in_range[area.items_in_range.size() - 1].icon.material.set_shader_parameter("outline_color", Color.WHITE)
			(area as ItemReceiverComponent).items_in_range[area.items_in_range.size() - 1].icon.material.set_shader_parameter("width", 0.82)

func _on_area_exited(area: Area2D) -> void:
	if area is ItemReceiverComponent and area.get_parent() is Player:
		(area as ItemReceiverComponent).remove_from_in_range_queue(self)

		icon.material.set_shader_parameter("outline_color", GlobalData.rarity_colors.outline_color.get(stats.rarity))
		icon.material.set_shader_parameter("width", 0.5)
		if not (area as ItemReceiverComponent).items_in_range.is_empty():
			(area as ItemReceiverComponent).items_in_range[area.items_in_range.size() - 1].icon.material.set_shader_parameter("outline_color", Color.WHITE)
			(area as ItemReceiverComponent).items_in_range[area.items_in_range.size() - 1].icon.material.set_shader_parameter("width", 0.82)
