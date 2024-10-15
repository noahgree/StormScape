extends State
## Handles when the character is moving, including both running and sprinting.

@export var max_speed: float = 150
@export var acceleration: float = 1250
@export var friction: float = 1550
@export var sprint_multiplier: float = 1.5

var movement_vector: Vector2 = Vector2.ZERO

func enter() -> void:
	anim_tree["parameters/playback"].travel("run")

func exit() -> void:
	pass

func state_physics_process(delta: float) -> void:
	do_character_movement(delta)
	check_for_dash_request()
	animate()

func do_character_movement(delta: float) -> void:
	movement_vector = calculate_move_vector()
	var request_sprint = Input.is_action_pressed("sprint")
	
	if movement_vector == Vector2.ZERO:
		if parent.velocity.length() > (friction * delta): # no input, still slowing
			parent.velocity -= parent.velocity.normalized() * (friction * delta)
		else: # no input, stopped
			parent.velocity = Vector2.ZERO
			Transitioned.emit(self, "Idle")
	else:
		# this if-else handles smoothing out the beginning of animation transitions
		if parent.velocity.length() > max_speed * 0.10:
			state_machine.anim_pos = parent.velocity.normalized()
		else:
			state_machine.anim_pos = movement_vector
		
		if request_sprint and stamina_component.use_stamina(state_machine.sprint_stamina_usage * delta): # sprint
			anim_tree.set("parameters/run/TimeScale/scale", 1.5 * sprint_multiplier)
			parent.velocity += (movement_vector * acceleration * sprint_multiplier * delta)
			parent.velocity = parent.velocity.limit_length(max_speed * sprint_multiplier)
		else: # move without sprint
			anim_tree.set("parameters/run/TimeScale/scale", 1.5)
			parent.velocity += (movement_vector * acceleration * delta)
			parent.velocity = parent.velocity.limit_length(max_speed)
	
	parent.move_and_slide()

func calculate_move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()

func check_for_dash_request() -> void:
	if Input.is_action_pressed("dash") and state_machine.dash_cooldown_timer.is_stopped():
		if stamina_component.use_stamina(state_machine.dash_stamina_usage):
			Transitioned.emit(self, "Dash")

func animate() -> void:
	anim_tree.set("parameters/run/blendspace2d/blend_position", state_machine.anim_pos)
