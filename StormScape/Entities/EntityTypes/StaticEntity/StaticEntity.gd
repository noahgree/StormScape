extends StaticBody2D
class_name StaticEntity
## An entity without the ability to move at all and that also cannot have non HP stats like stamina and hunger.
##
## This would be used for things like trees or blocks or buildings that need collision and also potential health.
## This should not be used for moving environmental entities like players and also not for inventory entities like weapons.

@export var team: GlobalData.Teams = GlobalData.Teams.PLAYER ## What the effects received by this entity should consider as this entity's team.

var stat_mods: Dictionary = {}
