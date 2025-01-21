extends State
class_name SpawnState
## Handles when the entity is actively spawning.


func enter() -> void:
	fsm.can_receive_effects = false
	fsm.anim_tree["parameters/playback"].travel("spawn")

func exit() -> void:
	fsm.can_receive_effects = true

func _on_spawn_anim_ended() -> void:
	call_deferred("_transition_out_of_spawn")

func _transition_out_of_spawn() -> void:
	transitioned.emit(self, "Idle")
