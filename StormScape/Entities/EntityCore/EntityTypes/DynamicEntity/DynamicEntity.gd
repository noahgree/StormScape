extends CharacterBody2D
class_name DynamicEntity
## An entity that has vitals stats and can move.
##
## This should be used by things like players, enemies, moving environmental entities, etc.
## This should not be used by things like weapons or trees.

@export var team: GlobalData.Teams = GlobalData.Teams.PLAYER ## What the effects received by this entity should consider as this entity's team.
@export_group("Status Effects & Stat Mods")
@export var stats: StatModsCacheResource = StatModsCacheResource.new() ## The resource that will cache and work with all stat mods for this entity.

@onready var sprite: Node2D = $EntitySprite ## The visual representation of the entity. Needs to have the EntityEffectShader applied.
@onready var effect_receiver: EffectReceiverComponent = get_node_or_null("EffectReceiverComponent") ## The component that handles incoming effect sources.
@onready var effects: StatusEffectManager = get_node_or_null("StatusEffectManager") ## The node that will cache and manage all status effects for this entity.
@onready var move_fsm: MoveStateMachine = $MoveStateMachine ## The FSM controlling the entity's movement.
@onready var health_component: HealthComponent = $HealthComponent ## The component in charge of entity health and shield.
@onready var stamina_component: StaminaComponent = $StaminaComponent ## The component in charge of entity stamina and hunger.
@onready var inv: ItemReceiverComponent = get_node_or_null("ItemReceiverComponent") ## The inventory component for the entity.
@onready var hands: HandsComponent = get_node_or_null("HandsComponent") ## The hands item component for the entity.

var time_snare_counter: float = 0 ## The ticker that slows down delta when under a time snare.
var snare_factor: float = 0 ## Multiplier for delta time during time snares.
var snare_timer: Timer ## A reference to a timer that might currently be tracking a time snare instance.
var current_stealth: int = 0 ## The extra amount of closeness this entity can achieve to an enemy before being detected.


## Recalculates the stats in the stat mods cache to be base values just before mods get reapplied on load.
func _on_load_game() -> void:
	if stats: stats.reinit_on_load()

## Making sure we know we have save logic, even if not set in editor.
func _ready() -> void:
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

	snare_factor = factor

	add_child(snare_timer)

func die() -> void:
	move_fsm.die()

## Updates the shader every frame with information on the position of a sprite frame within its sprite sheet. Needed
## to make the glow not produce artifacts along the edges of the sprite when using an animated sprite node.
func _update_shader_with_new_sprite_frame_size() -> void:
	if sprite is AnimatedSprite2D:
		sprite.material.set_shader_parameter("enable_fading", true)

		var current_animation = sprite.animation
		var current_frame = sprite.frame
		var texture = sprite.sprite_frames.get_frame_texture(current_animation, current_frame)

		var frame_uv_min = Vector2(0.0, 0.0)
		var frame_uv_max = Vector2(1.0, 1.0)

		var region

		# Ensure the texture is valid
		if texture == null:
			print("No texture found for the current frame.")
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
			print("Unsupported texture type.")
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
