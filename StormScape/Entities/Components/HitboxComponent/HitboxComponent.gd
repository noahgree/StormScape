extends Area2D
class_name HitboxComponent
## The area2d that defines where an effect source comes from.

@export var effect_source: EffectSource ## The effect to be applied when this hitbox hits an effect receiver.
@export var source_entity: PhysicsBody2D ## The entity that the effect was produced by.
@export var use_self_position: bool = false ## When using the hitbox as a standalone area2d, make this property true so that it uses its own position to handle effects like knockback.

@onready var collider: CollisionShape2D = $CollisionShape2D ## The collision shape for this hitbox.

var movement_direction: Vector2 = Vector2.ZERO ## The current movement direction for this hitbox.


## Setup the area detection signal and turn off monitorable for performance.
## Also set collision mask to the matching flags.
func _ready() -> void:
	self.area_entered.connect(_on_area_entered)
	self.body_entered.connect(_on_body_entered)
	monitorable = true
	collision_layer = 0
	if effect_source:
		collision_mask = effect_source.scanned_phys_layers

## When detecting an area, start having it handled. This method can be overridden in subclasses.
func _on_area_entered(area: Area2D) -> void:
	if (area.get_parent() == source_entity) and not effect_source.can_hit_self:
		return

	if area is EffectReceiverComponent:
		_start_being_handled(area as EffectReceiverComponent)

	_process_hit(area)

## If we hit a body, process it. Any body you wish to make block or handle attacks should be given an effect receiver.
func _on_body_entered(body: Node2D) -> void:
	if body is TileMapLayer:
		_process_hit(body)

## Meant to interact with an EffectReceiverComponent that can handle effects supplied by this instance. This version of the method
## handles the general case, but specific behaviors defined in certain weapon weapon hitboxes may want to override it.
func _start_being_handled(handling_area: EffectReceiverComponent) -> void:
	effect_source = effect_source.duplicate()

	if effect_source.source_type == GlobalData.EffectSourceSourceType.FROM_PROJECTILE:
		effect_source.movement_direction = movement_direction
	if not use_self_position:
		effect_source.contact_position = get_parent().global_position
	else:
		effect_source.contact_position = global_position

	if handling_area.absorb_full_hit:
		collider.set_deferred("disabled", true) # Does not apply to hitscans.
	handling_area.handle_effect_source(effect_source, source_entity)

## Meant to be overridden by subclasses to determine what to do after hitting an object.
func _process_hit(_object: Node2D) -> void:
	pass
