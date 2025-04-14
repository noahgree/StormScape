extends State
class_name SpawnState
## Handles when the entity is actively spawning.


func _init() -> void:
	state_id = "spawn"

func enter() -> void:
	controller.can_receive_effects = false
	entity.anim_tree.animation_finished.connect(_on_spawn_anim_ended, CONNECT_ONE_SHOT)
	entity.facing_component.travel_anim_tree("spawn")

func exit() -> void:
	controller.can_receive_effects = true
	if entity.anim_tree.animation_finished.is_connected(_on_spawn_anim_ended):
		entity.anim_tree.animation_finished.disconnect(_on_spawn_anim_ended)

func _on_spawn_anim_ended(_anim_name: StringName) -> void:
	call_deferred("_transition_out_of_spawn")

func _transition_out_of_spawn() -> void:
	controller.notify_spawn_ended()
