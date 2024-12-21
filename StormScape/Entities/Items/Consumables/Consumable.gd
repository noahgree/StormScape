extends EquippableItem
class_name Consumable

@onready var consumption_timer: Timer = $ConsumptionTimer
@onready var food_particles: CPUParticles2D = $FoodParticles


func _set_stats(new_stats: ItemResource) -> void:
	super._set_stats(new_stats)

	if sprite:
		sprite.texture = stats.in_hand_icon

func activate() -> void:
	consume()

func consume() -> void:
	var stamina_component: StaminaComponent = source_entity.get_node_or_null("StaminaComponent")
	if stamina_component and source_entity.hands.cooldown_manager.get_cooldown(stats.get_cooldown_id()) == 0 and consumption_timer.is_stopped():
		food_particles.global_position = source_entity.hands.global_position + source_entity.hands.mouth_pos
		food_particles.lifetime = max(0.2, stats.consumption_time / 2.0)
		food_particles.color = stats.particles_color
		food_particles.emitting = true

		consumption_timer.start(stats.consumption_time)
		await consumption_timer.timeout
		source_entity.hands.cooldown_manager.add_cooldown(stats.get_cooldown_id(), stats.consumption_cooldown)

		stamina_component.gain_hunger_bars(stats.hunger_bar_gain)
		stamina_component.use_hunger_bars(stats.hunger_bar_deduction)
		source_entity.effect_receiver.handle_effect_source(stats.effect_source, source_entity)

		source_slot.synced_inv.remove_item(source_slot.index, 1)
