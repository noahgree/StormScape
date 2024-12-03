extends RigidBody2D
class_name RigidEntity
## An entity that can move with physics and that also cannot have non-HP stats like stamina and hunger.
##
## This would be used for things like blocks that respond to explosions and that also need potential health.
## This should not be used for static environmental entities like trees and also not for players or moving enemies.

@export var team: GlobalData.Teams = GlobalData.Teams.PLAYER ## What the effects received by this entity should consider as this entity's team.
@export var stats: StatModsCacheResource = StatModsCacheResource.new() ## The resource that will cache and work with all stat mods for this entity.

@onready var sprite: Node2D = $EntitySprite ## The visual representation of the entity. Needs to have the EntityEffectShader applied.
@onready var effect_receiver: EffectReceiverComponent = get_node_or_null("EffectReceiverComponent") ## The component that handles incoming effect sources.
@onready var effects: StatusEffectManager = get_node_or_null("StatusEffectManager") ## The node that will cache and manage all status effects for this entity.
@onready var inv: ItemReceiverComponent = get_node_or_null("ItemReceiverComponent")


#region Save & Load
func _on_save_game(save_data: Array[SaveData]) -> void:
	var data: RigidEntityData = RigidEntityData.new()

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

func _is_instance_on_load_game(data: RigidEntityData) -> void:
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

## Making sure we know we have save logic, even if not set in editor. Then set up rigid body physics.
func _ready() -> void:
	add_to_group("has_save_logic")
	if team == GlobalData.Teams.PLAYER:
		add_to_group("player_entities")
	elif team == GlobalData.Teams.ENEMY:
		add_to_group("enemy_entities")

	mass = 3
	linear_damp = 4.5
	var phys_material = PhysicsMaterial.new()
	phys_material.friction = 1.0
	phys_material.rough = true
	self.physics_material_override = phys_material

	collision_layer = 0b00100000
	collision_mask = 0b11110101
