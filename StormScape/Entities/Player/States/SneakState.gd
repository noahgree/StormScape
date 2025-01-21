extends State
class_name SneakState
## Handles when the dynamic entity is sneaking, passing a stealth factor back up to the parent entity itself.

@export var _max_stealth: int = 100 ## How much closer you can get to an unalereted enemy before alerting them.
@export var _max_sneak_speed: int = 50 ## How fast you can move while sneaking.
@export var _sneak_acceleration: float = 500 ## The increase in speed per second for the entity while sneaking.
@export var _sneak_collision_impulse_factor: float = 1.0 ## A multiplier that controls how much impulse gets applied to rigid entites when colliding with them during the run state.

const DEFAULT_SNEAK_ANIM_TIME_SCALE: float = 0.65 ## How fast the sneak anim should play before stat mods.
var movement_vector: Vector2 = Vector2.ZERO ## The current movement vector for the entity.


func enter() -> void:
	pass

func exit() -> void:
	entity.current_stealth = 0

func _ready() -> void:
	var moddable_stats: Dictionary[StringName, float] = {
		&"max_stealth" : _max_stealth, &"max_sneak_speed" : _max_sneak_speed,
		&"sneak_acceleration" : _sneak_acceleration, &"sneak_collision_impulse_factor" : _sneak_collision_impulse_factor
	}
	get_parent().entity.stats.add_moddable_stats(moddable_stats)

func state_physics_process(delta: float) -> void:
	_do_character_sneak(delta)
	_send_parent_entity_stealth_value()
	_check_if_stopped_sneaking()
	_animate()

func _do_character_sneak(delta: float) -> void:
	movement_vector = _calculate_move_vector()
	var knockback: Vector2 = fsm.knockback_vector

	if knockback.length() > 0: # let knockback take control if there is any
		entity.velocity = knockback
		transitioned.emit(self, "Run")

	if movement_vector == Vector2.ZERO:
		if entity.velocity.length() > (entity.stats.get_stat("friction") * delta): # no input, still slowing
			entity.velocity -= entity.velocity.normalized() * (entity.stats.get_stat("friction") * delta)
		else: # no input, stopped
			fsm.knockback_vector = Vector2.ZERO
			entity.velocity = Vector2.ZERO
	elif knockback == Vector2.ZERO:
		fsm.anim_tree.set("parameters/run/TimeScale/scale", DEFAULT_SNEAK_ANIM_TIME_SCALE * (entity.stats.get_stat("max_sneak_speed") / entity.stats.get_original_stat("max_sneak_speed")))
		entity.velocity += (movement_vector * entity.stats.get_stat("sneak_acceleration") * delta)
		entity.velocity = entity.velocity.limit_length(entity.stats.get_stat("max_sneak_speed"))

	entity.move_and_slide()

	# Handle collisions with rigid entities
	for i: int in entity.get_slide_collision_count():
		var c: KinematicCollision2D = entity.get_slide_collision(i)
		var collider: Object = c.get_collider()
		if collider is RigidEntity:
			collider.apply_central_impulse(-c.get_normal().normalized() * entity.velocity.length() / (15 / (entity.stats.get_stat("sneak_collision_impulse_factor"))))

func _calculate_move_vector() -> Vector2:
	return _get_input_vector()

## Updates the dynamic entity with the amount of stealth we currently have.
func _send_parent_entity_stealth_value() -> void:
	entity.current_stealth = int(entity.stats.get_stat("max_stealth"))

## If the sneak button is still pressed, continue in this state. Otherwise, transition out based on movement vector.
func _check_if_stopped_sneaking() -> void:
	if not _is_sneak_requested():
		if movement_vector == Vector2.ZERO:
			transitioned.emit(self, "Idle")
		else:
			transitioned.emit(self, "Run")

func _animate() -> void: # FIXME: NEED SNEAK ANIMATION!
	if movement_vector == Vector2.ZERO:
		fsm.anim_tree["parameters/playback"].travel("idle")
		fsm.anim_tree.set("parameters/idle/blendspace2d/blend_position", fsm.anim_vector)
	else:
		fsm.anim_tree["parameters/playback"].travel("run")
		fsm.anim_tree.set("parameters/run/blendspace2d/blend_position", fsm.anim_vector)
