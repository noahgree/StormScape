extends CharacterBody2D
class_name DynamicEntity
## An entity that has vitals stats and can move.
## 
## This should be used by things like players, enemies, moving environmental entities, etc. 
## This should not be used by things like weapons or trees.

@onready var move_fsm: MoveStateMachine = %MoveStateMachine ## The FSM controlling the player.
@onready var health_component: HealthComponent = %HealthComponent ## The component in charge of player health and shield.
@onready var stamina_component: StaminaComponent = %StaminaComponent ## The component in charge of player stamina and hunger.


func _process(delta: float) -> void:
	move_fsm.state_machine_process(delta)

func _physics_process(delta: float) -> void:
	move_fsm.state_machine_physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	move_fsm.state_machine_handle_input(event)

func request_stun(duration: float) -> void:
	move_fsm.request_stun(duration)

func request_knockback(knockback: Vector2) -> void:
	move_fsm.request_knockback(knockback)
