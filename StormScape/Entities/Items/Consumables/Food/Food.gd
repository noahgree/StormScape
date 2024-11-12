extends Consumable
class_name Food

@onready var sprite: Sprite2D = $Sprite2D


func _set_stats(new_stats: ItemResource) -> void:
	stats = new_stats
	if sprite:
		sprite.texture = stats.thumbnail

func consume(source_entity: PhysicsBody2D) -> void:
	var stamina_component: StaminaComponent = source_entity.get_node_or_null("StaminaComponent")
	if stamina_component:
		stamina_component.gain_hunger_bars(stats.hunger_bar_gain)
		stamina_component.use_hunger_bars(stats.hunger_bar_deduction)

		source_slot.synced_inv.remove_item(source_slot.index, 1)
