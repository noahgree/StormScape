@tool
extends CharacterBody2D
class_name DynamicEntity
## An entity that has vitals stats and can move.
##
## This should be used by things like players, enemies, moving environmental entities, etc.
## This should not be used by things like weapons or trees.

@export var team: Globals.Teams = Globals.Teams.PLAYER ## What the effects received by this entity should consider as this entity's team.

@onready var sprite: EntitySprite = %EntitySprite ## The visual representation of the entity. Needs to have the EntityEffectShader applied.
@onready var anim_tree: AnimationTree = $AnimationTree ## The animation tree controlling this entity's animation states.
@onready var effect_receiver: EffectReceiverComponent = get_node_or_null("EffectReceiverComponent") ## The component that handles incoming effect sources.
@onready var effects: StatusEffectsComponent = get_node_or_null("%StatusEffectsComponent") ## The node that will cache and manage all status effects for this entity.
@onready var emission_mgr: ParticleEmissionComponent = $ParticleEmissionComponent ## The component responsible for determining the extents and origins of different particle placements.
@onready var fsm: StateMachine = $StateMachine ## The FSM controlling the entity.
@onready var facing_component: FacingComponent = $FacingComponent ## The component in charge of choosing the entity animation directions.
@onready var detection_component: DetectionComponent = $DetectionComponent ## The component that defines the radius around this entity that an enemy must enter for that enemy to be alerted.
@onready var health_component: HealthComponent = $HealthComponent ## The component in charge of entity health and shield.
@onready var stamina_component: StaminaComponent = get_node_or_null("StaminaComponent") ## The component in charge of entity stamina and hunger.
@onready var inv: ItemReceiverComponent = get_node_or_null("ItemReceiverComponent") ## The inventory for the entity.
@onready var hands: HandsComponent = get_node_or_null("%HandsComponent") ## The hands item component for the entity.

var stats: StatModsCacheResource = StatModsCacheResource.new() ## The resource that will cache and work with all stat mods for this entity.
var time_snare_counter: float = 0 ## The ticker that slows down delta when under a time snare.
var snare_factor: float = 0 ## Multiplier for delta time during time snares.
var snare_timer: Timer ## A reference to a timer that might currently be tracking a time snare instance.


#region Save & Load
func _on_save_game(save_data: Array[SaveData]) -> void:
	var data: DynamicEntityData = DynamicEntityData.new()

	data.scene_path = scene_file_path

	data.position = global_position
	data.velocity = velocity

	data.stat_mods = stats.stat_mods

	data.sprite_frames_path = sprite.sprite_frames.resource_path

	data.health = health_component.health
	data.shield = health_component.shield
	data.armor = health_component.armor

	data.facing_dir = facing_component.facing_dir
	data.knockback_vector = fsm.controller.knockback_vector

	if stamina_component != null:
		data.stamina = stamina_component.stamina
		data.can_use_stamina = stamina_component.can_use_stamina
		data.stamina_to_hunger_count = stamina_component.stamina_to_hunger_count
		data.hunger_bars = stamina_component.hunger_bars
		data.can_use_hunger_bars = stamina_component.can_use_hunger_bars

	if inv != null:
		data.inv = inv.inv
		data.pickup_range = inv.pickup_range

	data.snare_factor = snare_factor
	if snare_timer != null: data.snare_time_left = snare_timer.time_left
	else: data.snare_time_left = 0

	if self.name == "Player":
		data.is_player = true
		data.active_slot_index = %HotbarUI.active_slot.index

	save_data.append(data)

func _on_before_load_game() -> void:
	if not self is Player:
		queue_free()

func _is_instance_on_load_game(data: DynamicEntityData) -> void:
	global_position = data.position
	velocity = data.velocity

	if not data.is_player:
		Globals.world_root.add_child(self)

	stats.stat_mods = data.stat_mods
	stats.reinit_on_load()

	sprite.sprite_frames = load(data.sprite_frames_path)

	health_component.just_loaded = true
	health_component.health = data.health
	health_component.shield = data.shield
	health_component.armor = data.armor

	facing_component.facing_dir = data.facing_dir
	fsm.controller.knockback_vector = data.knockback_vector
	fsm.controller.update_animation()

	if stamina_component != null:
		stamina_component.stamina = data.stamina
		stamina_component.can_use_stamina = data.can_use_stamina
		stamina_component.stamina_to_hunger_count = data.stamina_to_hunger_count
		stamina_component.hunger_bars = data.hunger_bars
		stamina_component.can_use_hunger_bars = data.can_use_hunger_bars

	if inv != null:
		inv.inv_to_load_from_save = data.inv
		inv.pickup_range = data.pickup_range

	snare_factor = 0
	if snare_timer != null: snare_timer.queue_free()
	if data.snare_time_left > 0: request_time_snare(data.snare_factor, data.snare_time_left)

	if data.is_player:
		%HotbarUI._change_active_slot_to_index_relative_to_full_inventory_size(data.active_slot_index)
#endregion

## Edits editor warnings for easier debugging.
func _get_configuration_warnings() -> PackedStringArray:
	if get_node_or_null("%EntitySprite") == null or not %EntitySprite is EntitySprite:
		return ["This entity must have an EntitySprite typed sprite node. Make sure its name is unique with a %."]
	return []

## Making sure we know we have save logic, even if not set in editor.
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	assert(has_node("StateMachine"), name + " is a DynamicEntity but does not have a StateMachine.")
	assert(has_node("HealthComponent"), name + " is a DynamicEntity but does not have a HealthComponent.")
	assert(has_node("DetectionComponent"), name + " is a DynamicEntity but does not have a DetectionComponent.")

	add_to_group("has_save_logic")

	if self is Player:
		collision_layer = 0b1
		add_to_group("player_entities")
	elif team == Globals.Teams.PLAYER:
		collision_layer = 0b10
		add_to_group("player_entities")
	elif team == Globals.Teams.ENEMY:
		add_to_group("enemy_entities")
		collision_layer = 0b100
	elif team == Globals.Teams.PASSIVE:
		collision_layer = 0b1000

	collision_mask = 0b1101111

	stats.affected_entity = self
	sprite.entity = self

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	fsm.controller.controller_process(delta)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if snare_factor > 0:
		time_snare_counter += delta * snare_factor
		while time_snare_counter > delta:
			time_snare_counter -= delta
			fsm.controller.controller_physics_process(delta)
	else:
		fsm.controller.controller_physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	fsm.controller.controller_handle_input(event)

## Sends a request to the move fsm for entering the stun state using a given duration.
func request_stun(duration: float) -> void:
	fsm.controller.notify_requested_stun(duration)

## Requests changing the knockback vector using the incoming knockback.
func request_knockback(knockback: Vector2) -> void:
	fsm.controller.notify_requested_knockback(knockback)

## Requests to start a time snare effect on the entity.
func request_time_snare(factor: float, snare_time: float) -> void:
	if snare_timer != null and is_instance_valid(snare_timer) and not snare_timer.is_stopped():
		snare_timer.stop()
		snare_timer.wait_time = max(0.001, snare_time)
		snare_timer.start()
	else:
		var timeout_callable: Callable = Callable(func() -> void:
			snare_factor = 0
			snare_timer.queue_free()
			)
		snare_timer = TimerHelpers.create_one_shot_timer(self, max(0.001, snare_time), timeout_callable)
		snare_timer.start()

	snare_factor = factor

## Requests performing whatever dying logic is given in the move fsm.
func die() -> void:
	fsm.controller.die()
