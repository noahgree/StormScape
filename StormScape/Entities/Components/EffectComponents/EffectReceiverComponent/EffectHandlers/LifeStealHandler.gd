@icon("res://Utilities/Debug/EditorIcons/life_steal_handler.svg")
extends Node
class_name LifeStealHandler
## A handler for using the data provided in the effect source to apply life steal in different ways.

@onready var effect_receiver: EffectReceiverComponent = get_parent() ## The receiver that passes the effect to this handler node.

var source_entity: PhysicsBody2D = null ## The source entity of the most recent effect source. Updated by the effect receiver.


func _ready() -> void:
	assert(get_parent().has_node("DmgHandler"), get_parent().get_parent().name + " has a LifeStealHandler but no DmgHandler.")

## Handles a life steal interaction, passing the specified percentage of damage dealt back to the source entity as heals.
func handle_life_steal(dmg_amount: int, percent_to_steal: float) -> void:
	if source_entity != null:
		var src_health_component: HealthComponent = source_entity.get_node("HealthComponent")
		var self_health_component: HealthComponent = effect_receiver.get_parent().get_node("HealthComponent")
		if self_health_component.infinte_hp: # We don't allow life steal on something that has infinite HP
			return
		var self_hp: int = self_health_component.health + self_health_component.shield
		var steal_amount: int = int(floor(min(self_hp, dmg_amount) * (percent_to_steal / 100.0)))

		src_health_component.heal_health_then_shield(max(1, steal_amount), "LifeSteal", -1)
