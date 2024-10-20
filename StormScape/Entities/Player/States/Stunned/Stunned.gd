extends State
## Handles when the entity is stunned. This is a required state for all dynamic entities.

@onready var stunned_timer: Timer = %StunnedTimer


func enter() -> void:
	fsm.anim_tree["parameters/playback"].travel("idle") # FIXME: Shouldn't just be idle anim for stun.
	fsm.wait_time = fsm.stun_time
	stunned_timer.start()
	_animate()

func exit() -> void:
	pass

func state_physics_process(delta: float) -> void:
	var knockback: Vector2 = fsm.knockback_vector
	if knockback != Vector2.ZERO: # let knockback take control if there is any
		dynamic_entity.velocity = knockback
	
	if dynamic_entity.velocity.length() > (fsm.friction * delta): # no input, still slowing
		dynamic_entity.velocity -= dynamic_entity.velocity.normalized() * (fsm.friction * delta)
	else:
		dynamic_entity.velocity = Vector2.ZERO
	dynamic_entity.move_and_slide()

func _animate() -> void:
	fsm.anim_tree.set("parameters/idle/blendspace2d/blend_position", fsm.anim_vector)

func _on_stunned_timer_timeout() -> void:
	Transitioned.emit(self, "Idle")
