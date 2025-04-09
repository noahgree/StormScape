extends Node
## This autoload handles the transitioning between day and night as well as the in-game time.

signal time_tick(day: int, hour: int, minute: int) ## Emitted every time change.
signal day_started ## Emitted at 7am when daytime is in full swing.
signal night_started ## Emitted at 8pm when nighttime is in full swing.

@export var color_gradient: GradientTexture1D ## The color gradient responsible for coloring the canvas modulate based on time.
@export var game_day_time_scale: float = 1.0 ## The number of minutes to pass in game per second of the real world.
@export var current_hour: int = 9: ## The in-game hour.
	set(new_value):
		current_hour = new_value
		time_counter = GAME_TO_IRL_MINUTE * new_value * 60

@onready var canvas_modulate: CanvasModulate = $CanvasModulate ## The modulate rect that affects the colors.

var time_counter: float = 0 ## The elapsed engine time that determines game time once digested by the sin calculation.
var previously_emitted_minute: int = -1 ## The last known minute of game time. Used to determine when the minute has changed.
const MINUTES_PER_DAY: int = 1440 ## How many in game minutes per in game day.
const GAME_TO_IRL_MINUTE: float = (2 * PI) / MINUTES_PER_DAY ## Splits the sin function's result range into a slices where each slice is one minute of in game time.


func _ready() -> void:
	change_time(current_hour)

	DebugConsole.add_command("time", change_time)
	DebugConsole.add_command("time_scale", func(new_value: float) -> void: game_day_time_scale = new_value)

func _process(delta: float) -> void:
	time_counter += delta * GAME_TO_IRL_MINUTE * game_day_time_scale
	var day_offset: float = (sin(time_counter - (0.5 * PI)) + 1.0) / 2.0

	canvas_modulate.color = color_gradient.gradient.sample(day_offset)

	_tick_game_time()

## Ticks the game time ahead and emits signals when needed.
func _tick_game_time() -> void:
	var total_minutes: int = int(time_counter / GAME_TO_IRL_MINUTE)
	var curr_day: int = int(total_minutes / float(MINUTES_PER_DAY))
	var curr_day_minutes_elapsed: int = total_minutes % MINUTES_PER_DAY
	var curr_day_hour: int = int(curr_day_minutes_elapsed / 60.0)
	var curr_hour_min: int = int(curr_day_minutes_elapsed % 60)

	if curr_day_hour == 20 and curr_hour_min == 0:
		night_started.emit()
	elif curr_day_hour == 7 and curr_hour_min == 0:
		day_started.emit()

	if previously_emitted_minute != curr_hour_min:
		time_tick.emit(curr_day, curr_day_hour, curr_hour_min)
		previously_emitted_minute = curr_hour_min

## Changes the current game time by setting the current hour.
func change_time(new_hour: int) -> void:
	current_hour = new_hour
