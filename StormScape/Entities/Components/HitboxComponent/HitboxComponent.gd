extends Area2D
class_name HitboxComponent
## The area2d that defines where an effect source comes from. 

@export var effect_source: EffectSource ## The effect to be applied when this hitbox hits an effect receiver.
@export var source_entity: PhysicsBody2D ## The entity that the effect was produced by.


## Setup the area detection signal and turn off monitorable for performance. 
## Also set collision mask to the matching flags.
func _ready() -> void:
	self.area_entered.connect(_on_area_entered)
	monitorable = false
	collision_layer = 0
	collision_mask = effect_source.scanned_phys_layers
	
	effect_source.source_entity = self
	effect_source.source_team = source_entity.team


## When detecting an area, start having it handled. This method can be overridden in subclasses.
func _on_area_entered(area: Area2D) -> void:
	if effect_source is MovingEffectSource:
		effect_source.movement_direction = get_parent().movement_direction
		effect_source.is_source_moving_type = true
	_start_being_handled(area)

## Meant to interact with an EffectReceiverComponent that can handle effects supplied by this instance.
func _start_being_handled(handling_area: Area2D) -> void:
	if handling_area is EffectReceiverComponent:
		effect_source.contact_position = get_parent().global_position
		handling_area.handle_effect_source(effect_source)
