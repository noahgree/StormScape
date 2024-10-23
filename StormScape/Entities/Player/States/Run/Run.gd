extends DynamicState
## Handles when the character is moving, including both running and sprinting.

@export var _max_speed: float = 150 ## The maximum speed the entity can travel once fully accelerated. 
@export var _acceleration: float = 1250 ## The increase in speed per second for the entity.
@export var _sprint_multiplier: float = 1.5 ## How much faster the max_speed should be when sprinting.

var movement_vector: Vector2 = Vector2.ZERO ## The current direction of movement.

func _ready() -> void:
	var moddable_stats: Dictionary = {
		"max_speed" : _max_speed, "acceleration" : _acceleration, 
		"sprint_multiplier" : _sprint_multiplier
	}
	fsm.add_moddable_stats(moddable_stats)

func enter() -> void:
	fsm.anim_tree["parameters/playback"].travel("run")

func exit() -> void:
	pass

func state_physics_process(delta: float) -> void:
	_do_character_movement(delta)
	_check_for_dash_request()
	_animate()

## Besides appropriately applying velocity to the parent entity, this checks and potentially activates sprinting 
## as well as calculates what vector the animation state machine should receive to play the matching directional anim.
func _do_character_movement(delta: float) -> void:
	movement_vector = _calculate_move_vector()
	var request_sprint = Input.is_action_pressed("sprint")
	var knockback: Vector2 = fsm.knockback_vector
	
	if knockback.length() > 0: # let knockback take control if there is any
		dynamic_entity.velocity = knockback
	
	if movement_vector == Vector2.ZERO:
		if dynamic_entity.velocity.length() > (fsm.get_stat("friction") * delta): # no input, still slowing
			dynamic_entity.velocity -= dynamic_entity.velocity.normalized() * (fsm.get_stat("friction") * delta)
		else: # no input, stopped
			fsm.knockback_vector = Vector2.ZERO
			dynamic_entity.velocity = Vector2.ZERO
			Transitioned.emit(self, "Idle")
	elif knockback == Vector2.ZERO:
		# this if-else handles smoothing out the beginning of animation transitions
		if dynamic_entity.velocity.length() > fsm.get_stat("max_speed") * 0.10:
			fsm.anim_vector = dynamic_entity.velocity.normalized()
		else:
			fsm.anim_vector = movement_vector
		
		if request_sprint and stamina_component.use_stamina(fsm.get_stat("sprint_stamina_usage") * delta): # sprint
			fsm.anim_tree.set("parameters/run/TimeScale/scale", 1.5 * fsm.get_stat("sprint_multiplier"))
			dynamic_entity.velocity += (movement_vector * fsm.get_stat("acceleration") * fsm.get_stat("sprint_multiplier") * delta)
			dynamic_entity.velocity = dynamic_entity.velocity.limit_length(fsm.get_stat("max_speed") * fsm.get_stat("sprint_multiplier"))
		else: # move without sprint
			fsm.anim_tree.set("parameters/run/TimeScale/scale", 1.5)
			dynamic_entity.velocity += (movement_vector * fsm.get_stat("acceleration") * delta)
			dynamic_entity.velocity = dynamic_entity.velocity.limit_length(fsm.get_stat("max_speed"))
	
	dynamic_entity.move_and_slide()

func _calculate_move_vector() -> Vector2:
	return _get_input_vector()

## If the dash button is pressed and we are not on dash cooldown, we check if we have enough stamina to dash.
## If the use_stamina request is successful, we enter the dash state having already decremented the stamina amount.
func _check_for_dash_request() -> void:
	if _is_dash_requested() and fsm.dash_cooldown_timer.is_stopped() and movement_vector != Vector2.ZERO:
		if stamina_component.use_stamina(fsm.get_stat("dash_stamina_usage")):
			Transitioned.emit(self, "Dash")

func _animate() -> void:
	fsm.anim_tree.set("parameters/run/blendspace2d/blend_position", fsm.anim_vector)
