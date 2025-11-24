@tool
extends StaticEntity
class_name StormBase


@export var level: int = 1
@export var default_transform: StormTransform
@export var side_panel: PackedScene

@onready var interaction_area: InteractionArea = $InteractionArea

var storm: Storm
var level_progress: int = 0
var fuel: int = 5: set = _set_fuel
var max_fuel: int = 100
var fuel_change_resize_factor: float = 15.0
var fuel_change_move_factor: float = 40.0


func _ready() -> void:
	if Engine.is_editor_hint():
		default_transform.new_location = global_position
	else:
		storm = Globals.storm
		if global_position != default_transform.new_location:
			push_error("The default transform of the storm base has not automatically updated to the correct position of the storm base.")

		interaction_area.set_accept_callable(add_fuel)
	super()

## Adds fuel to the available amount.
func add_fuel() -> void:
	fuel += 10
	SignalBus.side_panel_open_request.emit(side_panel, self)


func _set_fuel(new_fuel: int) -> void:
	fuel = mini(new_fuel, max_fuel)
	var fuel_left_pct: float = float(fuel) / max_fuel
	var new_radius: float = default_transform.new_radius * fuel_left_pct
	var pos_change_time: float = abs(storm.global_position.distance_to(global_position)) / fuel_change_move_factor
	var rad_change_time: float = abs(storm.current_radius - new_radius) / fuel_change_resize_factor

	var new_transform: StormTransform = StormTransform.create(global_position, false, new_radius, false, 0, pos_change_time, rad_change_time, false)
	if not ((global_position == storm.global_position) and (new_radius == storm.current_radius)):
		storm.replace_current_queue([new_transform])
		storm.force_start_next_phase()
