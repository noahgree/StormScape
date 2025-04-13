extends State
class_name SpawnState
## Handles when the entity is actively spawning.


func _init() -> void:
	state_id = "spawn"

func enter() -> void:
	controller.can_receive_effects = false
	entity.facing_component.travel_anim_tree("spawn")

func exit() -> void:
	controller.can_receive_effects = true

func _on_spawn_anim_ended() -> void:
	call_deferred("_transition_out_of_spawn")

func _transition_out_of_spawn() -> void:
	controller.notify_spawn_ended()
