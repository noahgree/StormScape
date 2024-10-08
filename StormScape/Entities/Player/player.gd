extends DynamicEntity
class_name Player

@onready var state_machine = $CharStateMachine
@onready var stamina_component = $StaminaComponent


func _ready() -> void:
	state_machine.init(self)

func _process(delta: float) -> void:
	state_machine.state_machine_process(delta)

func _physics_process(delta: float) -> void:
	state_machine.state_machine_physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	state_machine.state_machine_handle_input(event)
