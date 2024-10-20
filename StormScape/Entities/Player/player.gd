extends DynamicEntity
class_name Player
## The main class for the player character.

@onready var health_component: HealthComponent = %HealthComponent ## The component in charge of player health and shield.
@onready var stamina_component: StaminaComponent = %StaminaComponent ## The component in charge of player stamina and hunger.

## Initializes the FSM that controls this player.
func _ready() -> void:
	move_fsm.init(self)

func _process(delta: float) -> void:
	move_fsm.state_machine_process(delta)

func _physics_process(delta: float) -> void:
	move_fsm.state_machine_physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	move_fsm.state_machine_handle_input(event)
