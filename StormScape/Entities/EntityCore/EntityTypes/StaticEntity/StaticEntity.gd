extends StaticBody2D
class_name StaticEntity
## An entity without the ability to move at all and that also cannot have non HP stats like stamina and hunger.
##
## This would be used for things like trees or blocks or buildings that need collision and also potential health.
## This should not be used for moving environmental entities like players and also not for inventory entities like weapons.

@export var team: GlobalData.Teams = GlobalData.Teams.PLAYER ## What the effects received by this entity should consider as this entity's team.

@onready var sprite: Node2D = $EntitySprite ## The visual representation of the entity. Needs to have the EntityEffectShader applied.
@onready var inv: ItemReceiverComponent = get_node_or_null("ItemReceiverComponent")

var stat_mods: Dictionary = {}


func _ready() -> void:
	if team == GlobalData.Teams.PLAYER:
		add_to_group("player_entities")
	elif team == GlobalData.Teams.ENEMY:
		add_to_group("enemy_entities")
