extends Node2D
class_name EquippableItem
## The base class for all items that can be used by the HandsComponent. In order to be equipped and shown on screen in
## some place other than the inventory, the item resource must have an associated equippable item scene.

@export_storage var stats: ItemResource = null: set = _set_stats ## The resource driving the stats and type of item.
@export var sprites_to_tint: Array[Node2D] ## All sprites that should be affected by tinting during events such as "disable".

@onready var sprite: Node2D = $ItemSprite ## The main sprite for the equippable item. Should have the entity effect shader attached.
@onready var clipping_detector: Area2D = get_node_or_null("ClippingDetector") ## Used to detect when the item is overlapping with an in-game object that should block its use (i.e. a wall or tree).

var stats_already_duplicated: bool = false ## Whether the stats have already been duplicated when they were first created in the slot.
var source_slot: Slot ## The slot this equippable item is in whilst equipped.
var source_entity: PhysicsBody2D ## The entity that is holding the equippable item.
var ammo_ui: MarginContainer ## The ui assigned by the hands component that displays the ammo. Only for the player.
var enabled: bool = true: ## When false, any activation or reload actions are blocked.
	set(new_value):
		enabled = new_value
		if not enabled:
			disable()
			for sprite_node: Node2D in sprites_to_tint:
				sprite_node.set_instance_shader_parameter("tint_color", Color(1, 0.188, 0.345, 0.45))
				sprite_node.set_instance_shader_parameter("final_alpha", 0.65)
		else:
			for sprite_node: Node2D in sprites_to_tint:
				sprite_node.set_instance_shader_parameter("tint_color", Color(1.0, 1.0, 1.0, 0.0))
				sprite_node.set_instance_shader_parameter("final_alpha", 1.0)
			enable()


## Creates an equippable item to be used via the slot it is currently in.
static func create_from_slot(item_source_slot: Slot) -> EquippableItem:
	var item: EquippableItem = item_source_slot.item.stats.item_scene.instantiate()
	item.source_slot = item_source_slot
	item.stats = item_source_slot.item.stats
	item.stats_already_duplicated = true
	item.source_entity = item_source_slot.synced_inv.source_node
	return item

## Sets the item stats when changed. Can be overridden by child classes to do specific things on change.
func _set_stats(new_stats: ItemResource) -> void:
	if not stats_already_duplicated:
		stats = new_stats.duplicate_with_suid()
	source_slot.synced_inv.inv[source_slot.index].stats = stats
	source_slot.item.stats = stats

func _ready() -> void:
	_set_stats(stats)

	if clipping_detector != null:
		clipping_detector.area_entered.connect(_on_item_enters_clipping_area)
		clipping_detector.area_exited.connect(_on_item_leaves_clipping_area)

## Disables the item when it starts to clip. Only applies to items with clipping detectors.
func _on_item_enters_clipping_area(area: Area2D) -> void:
	if area.owner != source_entity:
		enabled = false

## Enables the item when it stops clipping. Only applies to items with clipping detectors.
func _on_item_leaves_clipping_area(area: Area2D) -> void:
	var overlaps: Array[Node2D] = clipping_detector.get_overlapping_bodies()
	if (overlaps.is_empty() and area.owner != source_entity) or (overlaps.size() == 1 and overlaps[0].owner == source_entity):
		enabled = true

## Intended to be overridden by child classes in order to specify what to do when this item is disabled.
func disable() -> void:
	pass

## Intended to be overridden by child classes in order to specify what to do when this item is enabled.
func enable() -> void:
	pass

## Intended to be overridden by child classes in order to specify what to do when this item is used.
func activate() -> void:
	pass

## Intended to be overridden by child classes in order to specify what to do when this item
## is used after a hold click.
func hold_activate(_hold_time: float) -> void:
	pass

## Intended to be overridden by child classes in order to specify what to do when this
## item is used after a released hold click.
func release_hold_activate(_hold_time: float) -> void:
	pass

## Intended to be overridden by child classes in order to specify what to do when this item is equipped.
func enter() -> void:
	pass

## Intended to be overridden by child classes in order to specify what to do when this item
## is unequipped. Should call super.exit() first, though.
func exit() -> void:
	set_process(false)
