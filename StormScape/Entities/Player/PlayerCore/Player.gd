extends DynamicEntity
class_name Player
## The main class for the player character. Mostly handles player-specific save and load logic.

@export var player_name: String = "Player1" ## The string name of the player.


func _ready() -> void:
	super._ready()
	SignalBus.player_ready.emit(self)

#region Save & Load
func _on_save_game(save_data: Array[SaveData]) -> void:
	var data: PlayerData = PlayerData.new()

	data.position = global_position
	data.stat_mods = stats.stat_mods
	data.current_effects = effects.current_effects
	data.saved_times_left = effects.saved_times_left
	data.velocity = velocity
	data.snare_factor = snare_factor
	data.sprite_frames = $AnimatedSprite2D.sprite_frames.resource_path
	data.health = $HealthComponent.health
	data.shield = $HealthComponent.shield
	data.armor = $HealthComponent.armor
	data.stamina = $StaminaComponent.stamina
	data.can_use_stamina = $StaminaComponent.can_use_stamina
	data.stamina_to_hunger_count = $StaminaComponent.stamina_to_hunger_count
	data.hunger_bars = $StaminaComponent.hunger_bars
	data.can_use_hunger_bars = $StaminaComponent.can_use_hunger_bars
	data.saved_dots = $EffectReceiverComponent/DmgHandler.saved_dots
	data.saved_hots = $EffectReceiverComponent/HealHandler.saved_hots
	data.anim_vector = $MoveStateMachine.anim_vector
	data.knockback_vector = $MoveStateMachine.knockback_vector
	data.inv = $ItemReceiverComponent.inv
	data.pickup_range = $ItemReceiverComponent.pickup_range

	if snare_timer != null:
		data.snare_time_left = snare_timer.time_left
	else: data.snare_time_left = 0

	save_data.append(data)

func _on_load_game_player(data: PlayerData) -> void:
	global_position = data.position
	stats.stat_mods = data.stat_mods
	effects.current_effects = data.current_effects
	effects.saved_times_left = data.saved_times_left
	velocity = data.velocity
	snare_factor = 0
	$AnimatedSprite2D.sprite_frames = load(data.sprite_frames)
	$HealthComponent.health = data.health
	$HealthComponent.shield = data.shield
	$HealthComponent.armor = data.armor
	$StaminaComponent.stamina = data.stamina
	$StaminaComponent.can_use_stamina = data.can_use_stamina
	$StaminaComponent.stamina_to_hunger_count = data.stamina_to_hunger_count
	$StaminaComponent.hunger_bars = data.hunger_bars
	$StaminaComponent.can_use_hunger_bars = data.can_use_hunger_bars
	$EffectReceiverComponent/DmgHandler.saved_dots = data.saved_dots
	$EffectReceiverComponent/HealHandler.saved_hots = data.saved_hots
	$MoveStateMachine.anim_vector = data.anim_vector
	$MoveStateMachine.knockback_vector = data.knockback_vector
	$ItemReceiverComponent.inv_to_load_from_save = data.inv
	$ItemReceiverComponent.pickup_range = data.pickup_range

	move_fsm.verify_anim_vector()
	if velocity.length() > 0:
		move_fsm._on_child_transition(move_fsm.current_state, "Run")
	if snare_timer != null: snare_timer.queue_free()
	if data.snare_time_left > 0: request_time_snare(data.snare_factor, data.snare_time_left)
#endregion
