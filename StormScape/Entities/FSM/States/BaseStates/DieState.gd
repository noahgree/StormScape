extends State
class_name DieState
## Handles when the entity is actively dying.


func _init() -> void:
	state_id = "die"

func enter() -> void:
	entity.anim_tree.set_callback_mode_process(
		AnimationMixer.AnimationCallbackModeProcess.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		)
	entity.anim_tree.process_mode = Node.PROCESS_MODE_PAUSABLE
	entity.process_mode = Node.PROCESS_MODE_DISABLED
	controller.can_receive_effect_srcs = false
	entity.anim_tree.animation_finished.connect(_on_die_anim_ended, CONNECT_ONE_SHOT)
	entity.facing_component.travel_anim_tree("die")

func exit() -> void:
	if entity.anim_tree.animation_finished.is_connected(_on_die_anim_ended):
		entity.anim_tree.set_callback_mode_process(
		AnimationMixer.AnimationCallbackModeProcess.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		)
		entity.anim_tree.process_mode = Node.PROCESS_MODE_INHERIT
		entity.process_mode = Node.PROCESS_MODE_INHERIT
		entity.anim_tree.animation_finished.disconnect(_on_die_anim_ended)

func _on_die_anim_ended(_anim_name: StringName) -> void:
	_transition_out_of_die()

func _transition_out_of_die() -> void:
	if entity is not Player:
		entity.queue_free()
