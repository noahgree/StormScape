extends State


@export var max_speed: float = 150
@export var acceleration: float = 1250
@export var friction: float = 1550

@export var sprint_multiplier: float = 1.5
@export var sprint_stamina_usage: float = 15.0 # per second


func enter() -> void:
	pass

func exit() -> void:
	pass

func state_physics_process(delta: float) -> void:
	do_player_movement(delta)

func do_player_movement(delta: float) -> void:
	var move_vector = get_input_vector()
	var request_sprint = Input.is_action_pressed("shift")
	
	if move_vector == Vector2.ZERO:
		if parent.velocity.length() > (friction * delta): # no input, still slowing
			parent.velocity -= parent.velocity.normalized() * (friction * delta)
		else: # no input, stopped
			parent.velocity = Vector2.ZERO
			Transitioned.emit(self, "Idle")
	else:
		if request_sprint and stamina_component.use_stamina(sprint_stamina_usage * delta): # move with sprint
			parent.velocity += (move_vector * acceleration * sprint_multiplier * delta)
			parent.velocity = parent.velocity.limit_length(max_speed * sprint_multiplier)
		else: # move without sprint
			parent.velocity += (move_vector * acceleration * delta)
			parent.velocity = parent.velocity.limit_length(max_speed)
	
	parent.move_and_slide()

func get_input_vector() -> Vector2:
	var input = Vector2.ZERO
	input.x = int(Input.is_action_pressed("d")) - int(Input.is_action_pressed("a"))
	input.y = int(Input.is_action_pressed("s")) - int(Input.is_action_pressed("w"))
	return input.normalized()
