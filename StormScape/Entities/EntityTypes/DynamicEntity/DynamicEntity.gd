extends CharacterBody2D
class_name DynamicEntity
## An entity that has vitals stats and can move.
## 
## This should be used by things like players, enemies, moving environmental entities, etc. 
## This should not be used by things like weapons or trees.

@export var team: GlobalData.Teams = GlobalData.Teams.PLAYER ## What the effects received by this entity should consider as this entity's team.

@onready var move_fsm: MoveStateMachine = %MoveStateMachine ## The FSM controlling the player.
@onready var health_component: HealthComponent = %HealthComponent ## The component in charge of player health and shield.
@onready var stamina_component: StaminaComponent = %StaminaComponent ## The component in charge of player stamina and hunger.

var time_snare_counter: float = 0
var snare_factor: float = 0 ## Multiplier for delta time during time snares.
var current_stealth: int = 0 ## The extra amount of closeness this entity can achieve to an enemy before being detected.


func _process(delta: float) -> void:
	move_fsm.state_machine_process(delta)

func _physics_process(delta: float) -> void:
	if snare_factor > 0:
		time_snare_counter += delta * snare_factor
		while time_snare_counter > delta:
			time_snare_counter -= delta
			move_fsm.state_machine_physics_process(delta)
	else:
		move_fsm.state_machine_physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	move_fsm.state_machine_handle_input(event)

func request_stun(duration: float) -> void:
	move_fsm.request_stun(duration)

func request_knockback(knockback: Vector2) -> void:
	move_fsm.request_knockback(knockback)

func request_time_snare(factor: float, snare_time: float) -> void:
	var timer = Timer.new()
	timer.one_shot = true
	timer.autostart = true
	timer.wait_time = max(0.001, snare_time)
	timer.timeout.connect(func(): snare_factor = 0)
	timer.timeout.connect(timer.queue_free)
	
	snare_factor = factor
	
	add_child(timer)

func die() -> void:
	move_fsm.die()
