extends State
class_name DieState
## Handles when the entity is actively dying.


func enter() -> void:
	controller.can_receive_effects = false
	entity.facing_component.travel_anim_tree("die")

func exit() -> void:
	pass

func _on_die_anim_ended() -> void:
	call_deferred("_transition_out_of_die")

func _transition_out_of_die() -> void:
	pass
