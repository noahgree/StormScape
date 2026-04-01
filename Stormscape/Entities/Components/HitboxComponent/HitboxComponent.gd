@icon("res://Utilities/Debug/EditorIcons/hitbox_component.svg")
extends Area2D
class_name HitboxComponent
## The area2d that defines where an effect source comes from.

# Only set these manually if using this as a standalone hitbox and not attached to a projectile or other weapon!
@export_group("Standalone Hitbox Properties")
@export var effect_source: EffectSource ## The effect source to be applied when this hitbox hits an esi receiver.
@export var source_entity: Entity ## The entity that the effect was produced by.
@export var use_self_position: bool = false ## When using the hitbox as a standalone area2d, make this property true so that it uses its own position to handle effects like knockback.

@onready var collider: CollisionShape2D = $CollisionShape2D ## The collision shape for this hitbox.

var esi: ESI ## The effect source instance to use when this hitbox hits an esi receiver.
var source_ii: WeaponII ## The reference to the weapon item instance that used this hitbox, if any.
var movement_direction: Vector2 = Vector2.ZERO ## The current movement direction for this hitbox.


## Setup the area detection signal and turn on monitorable just in case it was toggled off somewhere. It needs
## to be on or for some reason it cannot detect bodies (it'll still detect areas, just not bodies).
## Also set collision mask to the matching flags.
func _ready() -> void:
	self.area_entered.connect(_on_area_entered)
	self.body_entered.connect(_on_body_entered)
	collision_layer = 0
	if effect_source:
		esi = ESI.new()
		esi.es = effect_source
		collision_mask = effect_source.scanned_phys_layers

## When detecting an area, start having it handled. This method can be overridden in subclasses.
func _on_area_entered(area: Area2D) -> void:
	if (area.get_parent() == source_entity) and (esi.es) and (not esi.es.can_hit_self):
		return

	if area is ESIReceiverComponent:
		_start_being_handled(area)

	_process_hit(area)

## If we hit a body, process it. Any body you wish to make block or handle attacks should be given an effect
## receiver.
func _on_body_entered(body: Node2D) -> void:
	if body is TileMapLayer:
		_process_hit(body)

## Meant to interact with an ESIReceiverComponent that can handle effect sources supplied by this instance.
## This version of the method handles the general case, but specific behaviors defined in certain
## weapon hitboxes may want to override it.
func _start_being_handled(handling_area: ESIReceiverComponent) -> void:
	if handling_area.absorb_full_hit:
		collider.set_deferred("disabled", true) # Does not apply to hitscans

	var esi_copy: ESI = esi.copy()
	if esi.es.source_type == EffectSource.SourceType.FROM_PROJECTILE:
		esi_copy.movement_direction = movement_direction
	esi_copy.contact_position = get_parent().global_position if not use_self_position else global_position
	esi_copy.set_source_info(source_entity, source_ii)
	handling_area.handle_esi(esi_copy)

## Meant to be overridden by subclasses to determine what to do after hitting an object.
func _process_hit(_object: Node2D) -> void:
	pass
