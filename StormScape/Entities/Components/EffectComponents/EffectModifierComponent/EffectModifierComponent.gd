@icon("res://Utilities/Debug/EditorIcons/effect_modifier_component.svg")
extends StatBasedComponent
class_name EffectModifierComponent
## The component that holds the stats and logic for how the entity should receive effects.
##
## This handles things like fire & poison damage not taking into account armor, etc.


func _ready() -> void: 
	var moddable_stats: Dictionary = {
		
	}
	add_moddable_stats(moddable_stats)
