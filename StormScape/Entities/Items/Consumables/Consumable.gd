extends EquippableItem
class_name Consumable

@onready var hand_location: Marker2D = $HandLocation
@onready var sprite: Sprite2D = $Sprite2D
@onready var consumption_timer: Timer = $ConsumptionTimer
@onready var consumption_delay_timer: Timer = $ConsumptionDelayTimer
@onready var food_particles: CPUParticles2D = $FoodParticles


func _set_stats(new_stats: ItemResource) -> void:
	stats = new_stats
	if sprite:
		sprite.texture = stats.thumbnail

func activate() -> void:
	consume()

func consume() -> void:
	var stamina_component: StaminaComponent = source_entity.get_node_or_null("StaminaComponent")
	if stamina_component and consumption_delay_timer.is_stopped() and consumption_timer.is_stopped():
		food_particles.global_position = source_entity.hands.global_position + source_entity.hands.mouth_pos
		food_particles.lifetime = max(0.2, stats.consumption_time / 2.0)
		food_particles.color = stats.particles_color
		food_particles.emitting = true

		consumption_timer.start(stats.consumption_time)
		await consumption_timer.timeout

		stamina_component.gain_hunger_bars(stats.hunger_bar_gain)
		stamina_component.use_hunger_bars(stats.hunger_bar_deduction)
		stats.effect_source.source_entity = source_entity
		source_entity.get_node("EffectReceiverComponent").handle_effect_source(stats.effect_source)

		source_slot.synced_inv.remove_item(source_slot.index, 1)

		consumption_delay_timer.start(stats.post_consumption_delay)
