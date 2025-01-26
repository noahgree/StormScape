@tool
extends RigidBody2D
class_name RigidEntity
## An entity that can move with physics and that also cannot have non-HP stats like stamina and hunger.
##
## This would be used for things like blocks that respond to explosions and that also need potential health.
## This should not be used for static environmental entities like trees and also not for players
## or moving enemies.

@export var team: GlobalData.Teams = GlobalData.Teams.PLAYER ## What the effects received by this entity should consider as this entity's team.
@export var stats: StatModsCacheResource = StatModsCacheResource.new() ## The resource that will cache and work with all stat mods for this entity.

@onready var sprite: Node2D = %EntitySprite ## The visual representation of the entity. Needs to have the EntityEffectShader applied.
@onready var anim_tree: AnimationTree = $AnimationTree ## The animation tree controlling this entity's animation states.
@onready var effect_receiver: EffectReceiverComponent = get_node_or_null("EffectReceiverComponent") ## The component that handles incoming effect sources.
@onready var effects: StatusEffectsComponent = get_node_or_null("%StatusEffectsComponent") ## The node that will cache and manage all status effects for this entity.
@onready var emission_mgr: ParticleEmissionComponent = $ParticleEmissionComponent ## The component responsible for determining the extents and origins of different particle placements.
@onready var facing_component: FacingComponent = $FacingComponent ## The component in charge of choosing the entity animation directions.
@onready var detection_component: DetectionComponent = $DetectionComponent ## The component that defines the radius around this entity that an enemy must enter for that enemy to be alerted.
@onready var health_component: HealthComponent = $HealthComponent ## The component in charge of entity health and shield.
@onready var inv: ItemReceiverComponent = get_node_or_null("ItemReceiverComponent") ## The inventory for the entity.
@onready var hands: HandsComponent = get_node_or_null("%HandsComponent") ## The hands item component for the entity.


#region Save & Load
func _on_save_game(save_data: Array[SaveData]) -> void:
	var data: RigidEntityData = RigidEntityData.new()

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

func _is_instance_on_load_game(data: RigidEntityData) -> void:
	global_position = data.position

	GlobalData.world_root.add_child(self)

	stats.stat_mods = data.stat_mods
	stats.reinit_on_load()

	sprite.sprite_frames = load(data.sprite_frames_path)

	facing_component.facing_dir = data.facing_dir

	health_component.just_loaded = true
	health_component.health = data.health
	health_component.shield = data.shield
	health_component.armor = data.armor

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

## Making sure we know we have save logic, even if not set in editor. Then set up rigid body physics.
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	assert(has_node("DetectionComponent"), name + " is a RigidEntity but does not have a DetectionComponent.")

	add_to_group("has_save_logic")
	if team == GlobalData.Teams.PLAYER:
		collision_layer = 0b10
		add_to_group("player_entities")
	elif team == GlobalData.Teams.ENEMY:
		add_to_group("enemy_entities")
		collision_layer = 0b100
	elif team == GlobalData.Teams.PASSIVE:
		collision_layer = 0b1000

	collision_mask = 0b1101111

	mass = 3
	linear_damp = 4.5
	var phys_material: PhysicsMaterial = PhysicsMaterial.new()
	phys_material.friction = 1.0
	phys_material.rough = true
	self.physics_material_override = phys_material
