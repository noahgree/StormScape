@tool
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
@onready var effects: StatusEffectsComponent = get_node_or_null("%StatusEffectsComponent") ## The node that will cache and manage all status effects for this entity.
@onready var emission_mgr: ParticleEmissionComponent = $ParticleEmissionComponent ## The component responsible for determining the extents and origins of different particle placements.
@onready var inv: ItemReceiverComponent = get_node_or_null("ItemReceiverComponent")


#region Save & Load
func _on_save_game(save_data: Array[SaveData]) -> void:
	var data: StaticEntityData = StaticEntityData.new()

	data.scene_path = scene_file_path

	data.position = global_position

	data.stat_mods = stats.stat_mods

	if sprite is AnimatedSprite2D:
		data.sprite_frames_path = sprite.sprite_frames.resource_path
	else:
		data.sprite_texture_path = sprite.texture.resource_path

	if has_node("HealthComponent"):
		data.health = $HealthComponent.health
		data.shield = $HealthComponent.shield
		data.armor = $HealthComponent.armor

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

	if sprite is AnimatedSprite2D:
		sprite.sprite_frames = load(data.sprite_frames_path)
	else:
		sprite.texture = load(data.sprite_texture_path)

	if has_node("HealthComponent"):
		$HealthComponent.health = data.health
		$HealthComponent.shield = data.shield
		$HealthComponent.armor = data.armor

	if inv != null:
		inv.inv_to_load_from_save = data.inv
		inv.pickup_range = data.pickup_range
#endregion

## Edits editor warnings for easier debugging.
func _get_configuration_warnings() -> PackedStringArray:
	if get_node_or_null("%EntitySprite") == null or not %EntitySprite is EntitySprite:
		return ["This entity must have an EntitySprite typed sprite node. Make sure its name is unique with a %."]
	return []

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	add_to_group("has_save_logic")
	if team == GlobalData.Teams.PLAYER:
		add_to_group("player_entities")
	elif team == GlobalData.Teams.ENEMY:
		add_to_group("enemy_entities")

	collision_layer = 0b00010000
	collision_mask = 0b11110101
