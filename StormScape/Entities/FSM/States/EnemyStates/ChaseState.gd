extends State
class_name ChaseState
## Handles when an entity is pursuing an enemy.

@export var chase_speed_mult: float = 1.0 ## A non-moddable modifier to the chase speed of the entity using this state.
@export var chase_sprint_speed_mult: float = 1.0 ## A non-moddable modifier to the sprint chase spweed of the entity using this state.
@export_subgroup("Animation Constants")
@export var DEFAULT_RUN_ANIM_TIME_SCALE: float = 1.5 ## How fast the run anim should play before stat mods.
@export var MAX_RUN_ANIM_TIME_SCALE: float = 4.0 ## How fast the run anim can play at most.


func _init() -> void:
	state_id = "chase"

func enter() -> void:
	entity.facing_component.travel_anim_tree("run")
	call_deferred("_equip_primary_item")

func exit() -> void:
	pass

func state_process(_delta: float) -> void:
	var aim_position: Vector2 = entity.global_position + (entity.facing_component.facing_dir * 25.0)
	entity.hands.handle_aim(aim_position)
	entity.hands.handle_trigger_pressed()

func state_physics_process(delta: float) -> void:
	_do_entity_chase(delta)
	_animate()

func _do_entity_chase(delta: float) -> void:
	var stats: StatModsCacheResource = entity.stats
	StateFunctions.handle_run_logic(delta, entity, controller, stats, MAX_RUN_ANIM_TIME_SCALE, DEFAULT_RUN_ANIM_TIME_SCALE, chase_speed_mult, chase_sprint_speed_mult)

func _equip_primary_item() -> void:
	entity.hands.on_equipped_item_change(entity.inv.inv[0].stats, 0)

func _animate() -> void:
	entity.facing_component.update_blend_position("run")
