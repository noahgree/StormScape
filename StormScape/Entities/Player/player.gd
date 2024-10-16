extends DynamicEntity
class_name Player
## The main class for the player character.

@onready var state_machine: CharStateMachine = $CharStateMachine ## The FSM controlling the player.
@onready var health_component: HealthComponent = $HealthComponent ## The component in charge of player health and shield.
@onready var stamina_component: StaminaComponent = $StaminaComponent ## The component in charge of player stamina and hunger.

## Initializes the FSM that controls this player.
func _ready() -> void:
	state_machine.init(self)

func _process(delta: float) -> void:
	state_machine.state_machine_process(delta)

func _physics_process(delta: float) -> void:
	state_machine.state_machine_physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	state_machine.state_machine_handle_input(event)
