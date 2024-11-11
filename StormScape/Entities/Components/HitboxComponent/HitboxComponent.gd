extends Area2D
class_name HitboxComponent
## The area2d that defines where an effect source comes from.

@export var effect_source: EffectSource ## The effect to be applied when this hitbox hits an effect receiver.
@export var source_entity: PhysicsBody2D ## The entity that the effect was produced by.

var movement_direction: Vector2 = Vector2.ZERO


## Setup the area detection signal and turn off monitorable for performance.
## Also set collision mask to the matching flags.
func _ready() -> void:
	self.area_entered.connect(_on_area_entered)
	monitorable = false
	collision_layer = 0
	effect_source.source_entity = source_entity
	collision_mask = effect_source.scanned_phys_layers

## When detecting an area, start having it handled. This method can be overridden in subclasses.
func _on_area_entered(area: Area2D) -> void:
	if area.get_parent() != source_entity:
		if area is EffectReceiverComponent:
			if effect_source.is_projectile:
				effect_source.movement_direction = movement_direction

			_start_being_handled(area as EffectReceiverComponent)

		_process_hit(area)

## Meant to interact with an EffectReceiverComponent that can handle effects supplied by this instance.
func _start_being_handled(handling_area: EffectReceiverComponent) -> void:
	effect_source.contact_position = get_parent().global_position
	handling_area.handle_effect_source(effect_source)

## Meant to be overridden by subclasses to determine what to do after hitting an object.
func _process_hit(_area: Area2D) -> void:
	pass
