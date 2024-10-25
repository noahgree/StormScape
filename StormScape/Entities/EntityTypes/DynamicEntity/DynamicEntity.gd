extends CharacterBody2D
class_name DynamicEntity
## An entity that has vitals stats and can move.
## 
## This should be used by things like players, enemies, moving environmental entities, etc. 
## This should not be used by things like weapons or trees.

@export var team: GlobalData.Teams = GlobalData.Teams.PLAYER ## What the effects received by this entity should consider as this entity's team.
@export_group("Other")
@export var rigid_entity_push_force: float = 10.0 ## How much impulse this dynamic entity should apply to any rigid body it interacts with in order to move it.

@onready var move_fsm: MoveStateMachine = %MoveStateMachine ## The FSM controlling the player.
@onready var health_component: HealthComponent = %HealthComponent ## The component in charge of player health and shield.
@onready var stamina_component: StaminaComponent = %StaminaComponent ## The component in charge of player stamina and hunger.


func _process(delta: float) -> void:
	move_fsm.state_machine_process(delta)

func _physics_process(delta: float) -> void:
	move_fsm.state_machine_physics_process(delta)
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		var collider = c.get_collider()
		if collider is RigidEntity:
			collider.apply_central_impulse(-c.get_normal() * rigid_entity_push_force)

func _unhandled_input(event: InputEvent) -> void:
	move_fsm.state_machine_handle_input(event)

func request_stun(duration: float) -> void:
	move_fsm.request_stun(duration)

func request_knockback(knockback: Vector2) -> void:
	move_fsm.request_knockback(knockback)
