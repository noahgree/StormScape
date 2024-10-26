extends DynamicState
## Handles when the character is actively dying.


func enter() -> void:
	fsm.can_receive_effects = false
	fsm.anim_tree["parameters/playback"].travel("die")

func exit() -> void:
	pass

func _on_die_anim_ended() -> void:
	call_deferred("_transition_out_of_die")

func _transition_out_of_die() -> void:
	print("Die animation done! Need to implement the rest of this function once game loop is working.")
