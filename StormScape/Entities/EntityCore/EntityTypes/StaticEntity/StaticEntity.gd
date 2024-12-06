extends StaticBody2D
class_name StaticEntity
## An entity without the ability to move at all and that also cannot have non HP stats like stamina and hunger.
##
## This would be used for things like trees or blocks or buildings that need collision and also potential health.
## This should not be used for moving environmental entities like players and also not for inventory entities like weapons.

@export var team: GlobalData.Teams = GlobalData.Teams.PLAYER ## What the effects received by this entity should consider as this entity's team.
@export var stats: StatModsCacheResource = StatModsCacheResource.new() ## The resource that will cache and work with all stat mods for this entity.

@onready var sprite: Node2D = $EntitySprite ## The visual representation of the entity. Needs to have the EntityEffectShader applied.
@onready var effect_receiver: EffectReceiverComponent = get_node_or_null("EffectReceiverComponent") ## The component that handles incoming effect sources.
@onready var effects: StatusEffectManager = get_node_or_null("StatusEffectManager") ## The node that will cache and manage all status effects for this entity.
@onready var inv: ItemReceiverComponent = get_node_or_null("ItemReceiverComponent")


#region Save & Load
func _on_save_game(save_data: Array[SaveData]) -> void:
	var data: StaticEntityData = StaticEntityData.new()

	data.scene_path = scene_file_path

	data.position = global_position

	data.stat_mods = stats.stat_mods

	if effects != null:
		data.current_effects = effects.current_effects
		data.saved_times_left = effects.saved_times_left

	if sprite is AnimatedSprite2D:
		data.sprite_frames_path = sprite.sprite_frames.resource_path
	else:
		data.sprite_texture_path = sprite.texture.resource_path

	if has_node("HealthComponent"):
		data.health = $HealthComponent.health
		data.shield = $HealthComponent.shield
		data.armor = $HealthComponent.armor

	if has_node("EffectReceiverComponent/DmgHandler"):
		data.saved_dots = effect_receiver.get_node("DmgHandler").saved_dots
	if has_node("EffectReceiverComponent/HealHandler"):
		data.saved_hots = effect_receiver.get_node("HealHandler").saved_hots

	if inv != null:
		data.inv = inv.inv
		data.pickup_range = inv.pickup_range

	save_data.append(data)

func _on_before_load_game() -> void:
	queue_free()

func _is_instance_on_load_game(data: StaticEntityData) -> void:
	global_position = data.position

	GlobalData.world_root.add_child(self)

	stats.stat_mods = data.stat_mods
	stats.reinit_on_load()

	if effects != null:
		effects.current_effects = data.current_effects
		effects.saved_times_left = data.saved_times_left

	if sprite is AnimatedSprite2D:
		sprite.sprite_frames = load(data.sprite_frames_path)
	else:
		sprite.texture = load(data.sprite_texture_path)

	if has_node("HealthComponent"):
		$HealthComponent.health = data.health
		$HealthComponent.shield = data.shield
		$HealthComponent.armor = data.armor

	if has_node("EffectReceiverComponent/DmgHandler"):
		effect_receiver.get_node("DmgHandler").saved_dots = data.saved_dots
	if has_node("EffectReceiverComponent/HealHandler"):
		effect_receiver.get_node("HealHandler").saved_hots = data.saved_hots

	if inv != null:
		inv.inv_to_load_from_save = data.inv
		inv.pickup_range = data.pickup_range
#endregion

func _ready() -> void:
	add_to_group("has_save_logic")
	if team == GlobalData.Teams.PLAYER:
		add_to_group("player_entities")
	elif team == GlobalData.Teams.ENEMY:
		add_to_group("enemy_entities")

	collision_layer = 0b00010000
	collision_mask = 0b11110101

func _physics_process(_delta: float) -> void:
	_update_shader_with_new_sprite_frame_size()

## Updates the shader every frame with information on the position of a sprite frame within its sprite sheet. Needed
## to make the glow not produce artifacts along the edges of the sprite when using an animated sprite node.
func _update_shader_with_new_sprite_frame_size() -> void:
	if sprite.material.get_shader_parameter("glow_size") <= 0.0:
		return

	if sprite is AnimatedSprite2D:
		sprite.material.set_shader_parameter("enable_fading", true)

		var texture: Texture2D = SpriteHelpers.SpriteDetails.get_frame_texture(sprite)

		var frame_uv_min: Vector2 = Vector2(0, 0)
		var frame_uv_max: Vector2 = Vector2(1, 1)

		var region: Rect2

		# Ensure the texture is valid
		if texture == null:
			sprite.material.set_shader_parameter("enable_fading", false)
			return

		# Calculate UV coordinates based on texture type
		if texture is AtlasTexture:
			var atlas_texture: AtlasTexture = texture as AtlasTexture
			var atlas_source: Texture2D = atlas_texture.atlas
			region = atlas_texture.region
			var atlas_size: Vector2 = atlas_source.get_size()

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
		var frame_size: Vector2 = region.size if texture is AtlasTexture else texture.get_size()
		var uv_pixel_size: Vector2 = Vector2(1.0 / frame_size.x, 1.0 / frame_size.y)
		sprite.material.set_shader_parameter("uv_pixel_size", uv_pixel_size)
	else:
		sprite.material.set_shader_parameter("enable_fading", false)
		sprite.material.set_shader_parameter("frame_uv_min", Vector2(0.0, 0.0))
		sprite.material.set_shader_parameter("frame_uv_max", Vector2(1.0, 1.0))
