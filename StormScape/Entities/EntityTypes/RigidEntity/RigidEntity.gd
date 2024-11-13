extends RigidBody2D
class_name RigidEntity
## An entity that can move with physics and that also cannot have non-HP stats like stamina and hunger.
##
## This would be used for things like blocks that respond to explosions and that also need potential health.
## This should not be used for static environmental entities like trees and also not for players or moving enemies.

@export var team: GlobalData.Teams = GlobalData.Teams.PLAYER ## What the effects received by this entity should consider as this entity's team.
@export_group("Status Effects & Stat Mods")
@export var stats: StatModsCacheResource = StatModsCacheResource.new() ## The resource that will cache and work with all stat mods for this entity.

@onready var effects: StatusEffectManager = get_node_or_null("StatusEffectManager") ## The node that will cache and manage all status effects for this entity.
@onready var inv: ItemReceiverComponent = get_node_or_null("ItemReceiverComponent")


## Recalculates the stats in the stat mods cache to be base values just before mods get reapplied on load.
func _on_load_game() -> void:
	if stats: stats.reinit_on_load()

## Making sure we know we have save logic, even if not set in editor. Then set up rigid body physics.
func _ready() -> void:
	add_to_group("has_save_logic")

	mass = 3
	linear_damp = 4.5
	var phys_material = PhysicsMaterial.new()
	phys_material.friction = 1.0
	phys_material.rough = true
	self.physics_material_override = phys_material
	collision_layer = 0b00100000
	collision_mask = 0b11110101
