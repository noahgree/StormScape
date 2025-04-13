extends State
class_name ChaseState
## Handles when an entity is pursuing an enemy.

@export var chase_speed_mult: float = 1.0 ## A non-moddable modifier to the chase speed of the entity using this state.
@export var chase_sprint_speed_mult: float = 1.0 ## A non-moddable modifier to the sprint chase speed of the entity using this state.
@export_subgroup("Animation Constants")
@export var DEFAULT_RUN_ANIM_TIME_SCALE: float = 1.5 ## How fast the run anim should play before stat mods.
@export var MAX_RUN_ANIM_TIME_SCALE: float = 4.0 ## How fast the run anim can play at most.


func _init() -> void:
	state_id = "chase"

func enter() -> void:
	entity.facing_component.travel_anim_tree("run")

func exit() -> void:
	pass

func state_physics_process(delta: float) -> void:
	_do_entity_chase(delta)
	_animate()

func _do_entity_chase(delta: float) -> void:
	var stats: StatModsCacheResource = entity.stats

	StateFunctions.handle_run_logic(delta, entity, controller, stats, MAX_RUN_ANIM_TIME_SCALE, DEFAULT_RUN_ANIM_TIME_SCALE, chase_speed_mult, chase_sprint_speed_mult)

func _animate() -> void:
	entity.facing_component.update_blend_position("run")
