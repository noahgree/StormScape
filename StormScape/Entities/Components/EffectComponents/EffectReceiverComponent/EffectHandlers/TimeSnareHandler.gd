@icon("res://Utilities/Debug/EditorIcons/time_snare_handler.svg")
extends StatBasedComponent
class_name TimeSnareHandler
## A handler for using the data provided in the effect source to apply time snare in different ways.

@onready var effect_receiver: EffectReceiverComponent = get_parent() ## The receiver that passes the effect to this handler node.


## Sets up moddable stats.
func _ready() -> void:
	assert(get_parent().get_parent() is DynamicEntity, get_parent().affected_entity.name + " has an effect receiver intended to handle time snares, but the affected entity is not a DynamicEntity.")

func handle_time_snare(time_snare_effect: TimeSnareEffect) -> void:
	if effect_receiver.affected_entity is DynamicEntity:
		effect_receiver.affected_entity.request_time_snare(time_snare_effect.time_multiplier, time_snare_effect.snare_time)
