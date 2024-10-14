extends DynamicEntity
class_name Player

@onready var state_machine: CharStateMachine = $CharStateMachine
@onready var health_component: HealthComponent = $HealthComponent
@onready var stamina_component: StaminaComponent = $StaminaComponent


func _ready() -> void:
	state_machine.init(self)

func _process(delta: float) -> void:
	state_machine.state_machine_process(delta)

func _physics_process(delta: float) -> void:
	state_machine.state_machine_physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	state_machine.state_machine_handle_input(event)
