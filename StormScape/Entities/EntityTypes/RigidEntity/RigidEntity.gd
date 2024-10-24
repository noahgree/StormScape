extends RigidBody2D
class_name RigidEntity
## An entity that can move with physics and that also cannot have non-HP stats like stamina and hunger.
##
## This would be used for things like blocks that respond to explosions and that also need potential health.
## This should not be used for static environmental entities like trees and also not for players or moving enemies.

@export var team: EnumUtils.Teams = EnumUtils.Teams.PLAYER ## What the effects received by this entity should consider as this entity's team.


func _ready() -> void:
	mass = 3
	linear_damp = 2.5
	var phys_material = PhysicsMaterial.new()
	phys_material.friction = 1.0
	self.physics_material_override = phys_material
