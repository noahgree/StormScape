extends EquippableItem
class_name Consumable

@onready var hand_location: Marker2D = $HandLocation


func activate(source_entity: PhysicsBody2D = null) -> void:
	consume(source_entity)

func consume(_source_entity: PhysicsBody2D) -> void:
	pass
