extends CharacterBody2D
class_name DynamicEntity
## An entity that has vitals stats and can move.
##
## This should be used by things like players, enemies, moving environmental entities, etc.
## This should not be used by things like weapons or trees.

@export var team: GlobalData.Teams = GlobalData.Teams.PLAYER ## What the effects received by this entity should consider as this entity's team.
@export var stats: StatModsCacheResource = StatModsCacheResource.new() ## The resource that will cache and work with all stat mods for this entity.

@onready var sprite: Node2D = $EntitySprite ## The visual representation of the entity. Needs to have the EntityEffectShader applied.
@onready var effect_receiver: EffectReceiverComponent = get_node_or_null("EffectReceiverComponent") ## The component that handles incoming effect sources.
@onready var effects: StatusEffectManager = get_node_or_null("StatusEffectManager") ## The node that will cache and manage all status effects for this entity.
@onready var move_fsm: MoveStateMachine = $MoveStateMachine ## The FSM controlling the entity's movement.
@onready var health_component: HealthComponent = $HealthComponent ## The component in charge of entity health and shield.
@onready var stamina_component: StaminaComponent = get_node_or_null("StaminaComponent") ## The component in charge of entity stamina and hunger.
@onready var inv: ItemReceiverComponent = get_node_or_null("ItemReceiverComponent") ## The inventory component for the entity.
@onready var hands: HandsComponent = get_node_or_null("HandsComponent") ## The hands item component for the entity.

var time_snare_counter: float = 0 ## The ticker that slows down delta when under a time snare.
var snare_factor: float = 0 ## Multiplier for delta time during time snares.
var snare_timer: Timer ## A reference to a timer that might currently be tracking a time snare instance.
var current_stealth: int = 0 ## The extra amount of closeness this entity can achieve to an enemy before being detected.


#region Save & Load
func _on_save_game(save_data: Array[SaveData]) -> void:
	var data: DynamicEntityData = DynamicEntityData.new()

	data.scene_path = scene_file_path

	data.position = global_position
	data.velocity = velocity

	data.stat_mods = stats.stat_mods

	if effects != null:
		data.current_effects = effects.current_effects
		data.saved_times_left = effects.saved_times_left

	if sprite is AnimatedSprite2D:
		data.sprite_frames_path = sprite.sprite_frames.resource_path
	else:
		data.sprite_texture_path = sprite.texture.resource_path

	data.health = health_component.health
	data.shield = health_component.shield
	data.armor = health_component.armor

	data.anim_vector = move_fsm.anim_vector
	data.knockback_vector = move_fsm.knockback_vector

	if stamina_component != null:
		data.stamina = stamina_component.stamina
		data.can_use_stamina = stamina_component.can_use_stamina
		data.stamina_to_hunger_count = stamina_component.stamina_to_hunger_count
		data.hunger_bars = stamina_component.hunger_bars
		data.can_use_hunger_bars = stamina_component.can_use_hunger_bars

	if effect_receiver.has_node("DmgHander"):
		data.saved_dots = effect_receiver.get_node("DmgHandler").saved_dots
	if effect_receiver.has_node("HealHandler"):
		data.saved_hots = effect_receiver.get_node("HealHandler").saved_hots

	if inv != null:
		data.inv = inv.inv
		data.pickup_range = inv.pickup_range

	data.snare_factor = snare_factor
	if snare_timer != null: data.snare_time_left = snare_timer.time_left
	else: data.snare_time_left = 0

	if self.name == "Player":
		data.is_player = true
		data.active_slot_index = $PlayerUILayer/HotbarUI.active_slot.index

	save_data.append(data)

func _is_instance_on_load_game(data: DynamicEntityData) -> void:
	global_position = data.position
	velocity = data.velocity

	if not data.is_player:
		GlobalData.world_root.add_child(self)

	stats.stat_mods = data.stat_mods
	stats.reinit_on_load()

	if effects != null:
		effects.current_effects = data.current_effects
		effects.saved_times_left = data.saved_times_left

	if sprite is AnimatedSprite2D:
		sprite.sprite_frames = load(data.sprite_frames_path)
	else:
		sprite.texture = load(data.texture_path)

	health_component.health = data.health
	health_component.shield = data.shield
	health_component.armor = data.armor

	move_fsm.anim_vector = data.anim_vector
	move_fsm.knockback_vector = data.knockback_vector
	move_fsm.verify_anim_vector()
	if velocity.length() > 0 and move_fsm.has_node("Run"):
		move_fsm._on_child_transition(move_fsm.current_state, "Run")

	if stamina_component != null:
		stamina_component.stamina = data.stamina
		stamina_component.can_use_stamina = data.can_use_stamina
		stamina_component.stamina_to_hunger_count = data.stamina_to_hunger_count
		stamina_component.hunger_bars = data.hunger_bars
		stamina_component.can_use_hunger_bars = data.can_use_hunger_bars

	if effect_receiver.has_node("DmgHander"):
		effect_receiver.get_node("DmgHandler").saved_dots = data.saved_dots
	if effect_receiver.has_node("HealHandler"):
		effect_receiver.get_node("HealHandler").saved_hots = data.saved_hots

	if inv != null:
		inv.inv_to_load_from_save = data.inv
		inv.pickup_range = data.pickup_range

	snare_factor = 0
	if snare_timer != null: snare_timer.queue_free()
	if data.snare_time_left > 0: request_time_snare(data.snare_factor, data.snare_time_left)

	if data.is_player:
		$PlayerUILayer/HotbarUI._change_active_slot_to_index_relative_to_full_inventory_size(data.active_slot_index)
#endregion

## Making sure we know we have save logic, even if not set in editor.
func _ready() -> void:
	assert(has_node("MoveStateMachine"), name + " is a DynamicEntity but does not have a MoveStateMachine.")
	assert(has_node("HealthComponent"), name + " is a DynamicEntity but does not have a HealthComponent.")

	add_to_group("has_save_logic")
	if team == GlobalData.Teams.PLAYER:
		add_to_group("player_entities")
	elif team == GlobalData.Teams.ENEMY:
		add_to_group("enemy_entities")

	if sprite.material != null and sprite.material.shader != null:
		_update_shader_with_new_sprite_frame_size()

func _process(delta: float) -> void:
	move_fsm.state_machine_process(delta)

func _physics_process(delta: float) -> void:
	if snare_factor > 0:
		time_snare_counter += delta * snare_factor
		while time_snare_counter > delta:
			time_snare_counter -= delta
			move_fsm.state_machine_physics_process(delta)
	else:
		move_fsm.state_machine_physics_process(delta)

	_update_shader_with_new_sprite_frame_size()

func _unhandled_input(event: InputEvent) -> void:
	move_fsm.state_machine_handle_input(event)

func request_stun(duration: float) -> void:
	move_fsm.request_stun(duration)

func request_knockback(knockback: Vector2) -> void:
	move_fsm.request_knockback(knockback)

func request_time_snare(factor: float, snare_time: float) -> void:
	snare_timer = Timer.new()
	snare_timer.one_shot = true
	snare_timer.autostart = true
	snare_timer.wait_time = max(0.001, snare_time)
	snare_timer.timeout.connect(func(): snare_factor = 0)
	snare_timer.timeout.connect(snare_timer.queue_free)
	snare_timer.timeout.connect(func(): effects._stop_effect_fx("Time Snare"))

	snare_factor = factor

	add_child(snare_timer)

func die() -> void:
	move_fsm.die()

## Updates the shader every frame with information on the position of a sprite frame within its sprite sheet. Needed
## to make the glow not produce artifacts along the edges of the sprite when using an animated sprite node.
func _update_shader_with_new_sprite_frame_size() -> void:
	if sprite is AnimatedSprite2D:
		sprite.material.set_shader_parameter("enable_fading", true)

		var texture = SpriteHelpers.SpriteDetails.get_frame_texture(sprite)

		var frame_uv_min = Vector2(0.0, 0.0)
		var frame_uv_max = Vector2(1.0, 1.0)

		var region

		# Ensure the texture is valid
		if texture == null:
			sprite.material.set_shader_parameter("enable_fading", false)
			return

		# Calculate UV coordinates based on texture type
		if texture is AtlasTexture:
			var atlas_texture = texture as AtlasTexture
			var atlas_source = atlas_texture.atlas
			region = atlas_texture.region
			var atlas_size = atlas_source.get_size()

			# Calculate UV coordinates
			frame_uv_min = Vector2(region.position.x / atlas_size.x, region.position.y / atlas_size.y)
			frame_uv_max = Vector2(
				(region.position.x + region.size.x) / atlas_size.x,
				(region.position.y + region.size.y) / atlas_size.y
			)
		elif texture is Texture2D:
			# For regular textures, the UVs are (0,0) to (1,1)
			frame_uv_min = Vector2(0.0, 0.0)
			frame_uv_max = Vector2(1.0, 1.0)
		else:
			push_error("Unsupported texture type for adjusting glow shader on an entity.")
			sprite.material.set_shader_parameter("enable_fading", false)
			return

		# Pass frame_uv_min and frame_uv_max to the shader
		sprite.material.set_shader_parameter("frame_uv_min", frame_uv_min)
		sprite.material.set_shader_parameter("frame_uv_max", frame_uv_max)

		# Calculate the UV pixel size
		var frame_size = region.size if texture is AtlasTexture else texture.get_size()
		var uv_pixel_size = Vector2(1.0 / frame_size.x, 1.0 / frame_size.y)
		sprite.material.set_shader_parameter("uv_pixel_size", uv_pixel_size)
	else:
		sprite.material.set_shader_parameter("enable_fading", false)
