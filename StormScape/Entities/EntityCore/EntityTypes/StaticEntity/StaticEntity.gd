@tool
extends StaticBody2D
class_name StaticEntity
## An entity without the ability to move at all and that also cannot have non HP stats like stamina and hunger.
##
## This would be used for things like trees or blocks or buildings that need collision and also potential health.
## This should not be used for moving environmental entities like players and also not for inventory entities like weapons.

@export var team: Globals.Teams = Globals.Teams.PLAYER ## What the effects received by this entity should consider as this entity's team.
@export var is_object: bool = false ## When true, this entity's collision logic will follow that of a world object, regardless of team.

@onready var sprite: EntitySprite = $EntitySprite ## The visual representation of the entity. Needs to have the EntityEffectShader applied.
@onready var anim_tree: AnimationTree = $AnimationTree ## The animation tree controlling this entity's animation states.
@onready var effect_receiver: EffectReceiverComponent = get_node_or_null("EffectReceiverComponent") ## The component that handles incoming effect sources.
@onready var effects: StatusEffectsComponent = get_node_or_null("%StatusEffectsComponent") ## The node that will cache and manage all status effects for this entity.
@onready var emission_mgr: ParticleEmissionComponent = $ParticleEmissionComponent ## The component responsible for determining the extents and origins of different particle placements.
@onready var facing_component: FacingComponent = $FacingComponent ## The component in charge of choosing the entity animation directions.
@onready var detection_component: DetectionComponent = $DetectionComponent ## The component that defines the radius around this entity that an enemy must enter for that enemy to be alerted.
@onready var health_component: HealthComponent = $HealthComponent ## The component in charge of entity health and shield.
@onready var inv: ItemReceiverComponent = get_node_or_null("ItemReceiverComponent") ## The inventory for the entity.
@onready var hands: HandsComponent = get_node_or_null("%HandsComponent") ## The hands item component for the entity.

var stats: StatModsCacheResource = StatModsCacheResource.new() ## The resource that will cache and work with all stat mods for this entity.
var wearables: Array[Dictionary] = [{ &"1" : null }, { &"2" : null }, { &"3" : null }, { &"4" : null }, { &"5" : null }] ## The equipped wearables on this entity.


#region Save & Load
func _on_save_game(save_data: Array[SaveData]) -> void:
	var data: StaticEntityData = StaticEntityData.new()

	data.scene_path = scene_file_path

	data.position = global_position

	data.stat_mods = stats.stat_mods

	data.sprite_frames_path = sprite.sprite_frames.resource_path

	data.health = health_component.health
	data.shield = health_component.shield
	data.armor = health_component.armor

	data.facing_dir = facing_component.facing_dir

	if inv != null:
		data.inv = inv.inv
		data.pickup_range = inv.pickup_range

	save_data.append(data)

func _on_before_load_game() -> void:
	queue_free()

func _is_instance_on_load_game(data: StaticEntityData) -> void:
	global_position = data.position

	Globals.world_root.add_child(self)

	stats.stat_mods = data.stat_mods
	stats.reinit_on_load()

	sprite.sprite_frames = load(data.sprite_frames_path)

	health_component.just_loaded = true
	health_component.health = data.health
	health_component.shield = data.shield
	health_component.armor = data.armor

	facing_component.facing_dir = data.facing_dir

	if inv != null:
		inv.inv_to_load_from_save = data.inv
		inv.pickup_range = data.pickup_range
#endregion

## Edits editor warnings for easier debugging.
func _get_configuration_warnings() -> PackedStringArray:
	if get_node_or_null("%EntitySprite") == null or not %EntitySprite is EntitySprite:
		return [
			"This entity must have an EntitySprite typed sprite node. Make sure its name is unique with a %."
			]
	return []

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	assert(has_node("DetectionComponent"), name + " is a StaticEntity but does not have a DetectionComponent.")

	add_to_group("has_save_logic")
	if is_object:
		collision_layer = 0b100000
		match team:
			Globals.Teams.PLAYER:
				add_to_group("player_entities")
			Globals.Teams.ENEMY:
				add_to_group("enemy_entities")
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
