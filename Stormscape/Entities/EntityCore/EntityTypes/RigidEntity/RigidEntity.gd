@tool
extends Entity
class_name RigidEntity
## An entity that can move and rotate with physics and that also cannot have non-HP stats like stamina and hunger.
##
## This would be used for things like blocks that respond to explosions and that also need potential health.
## This should not be used for static environmental entities like trees and also not for players
## or moving enemies.

@export var immovable: bool = false ## When true, this will not be able to be moved around by impulse forces.

@onready var anim_tree: AnimationTree = $AnimationTree ## The animation tree controlling this entity's animation states.
@onready var facing_component: FacingComponent = $FacingComponent ## The component in charge of choosing the entity animation directions.


func _ready() -> void:
	super()
	class_type = ClassType.RIGID

	self.mass = 3
	self.linear_damp = 4.5
	var phys_material: PhysicsMaterial = PhysicsMaterial.new()
	phys_material.friction = 1.0
	phys_material.rough = true
	self.physics_material_override = phys_material
	if immovable:
		self.freeze = true
