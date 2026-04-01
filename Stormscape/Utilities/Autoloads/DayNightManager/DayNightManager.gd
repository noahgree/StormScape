extends Node

signal time_tick(day: int, hour: int, minute: int)
signal day_started
signal night_started
signal brightness_progress_signal(progress: float)

@export var color_gradient: GradientTexture1D
@export var game_day_time_scale: float = 1.0
@export var starting_hour: int = 9

@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var shadow_material: ShaderMaterial = load("uid://dbpk21y6ho24t")

const MINUTES_PER_DAY: int = 1440
const RADIANS_PER_GAME_MINUTE: float = TAU / MINUTES_PER_DAY

var time_counter: float = 0.0
var current_day: int = 0
var current_hour: int = 9
var current_minute: int = 0
var day_progress: float = 0.0
var last_emitted_total_minutes: int = -1
var force_emit_tick: bool = false


func _ready() -> void:
	set_time(0, starting_hour, 0)

	DebugConsole.add_command("time", set_hour)
	DebugConsole.add_command("time_scale", func(new_value: float) -> void:
		game_day_time_scale = new_value
	)


func _process(delta: float) -> void:
	time_counter += delta * RADIANS_PER_GAME_MINUTE * game_day_time_scale

	var progress: float = _get_day_progress()
	var day_offset: float = (sin(progress * TAU - PI / 2.0) + 1.0) / 2.0

	canvas_modulate.color = color_gradient.gradient.sample(day_offset)

	_tick_game_time()
	_update_entity_shadows()


func _input(_event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_RIGHT):
		set_hour(wrapi(current_hour + 1, 0, 24))
	elif Input.is_key_pressed(KEY_LEFT):
		set_hour(wrapi(current_hour - 1, 0, 24))


func _tick_game_time() -> void:
	var total_minutes: int = int(time_counter / RADIANS_PER_GAME_MINUTE)
	current_day = floori(total_minutes / float(MINUTES_PER_DAY))

	var day_minutes: int = total_minutes % MINUTES_PER_DAY
	current_hour = floori(day_minutes / 60.0)
	current_minute = day_minutes % 60
	day_progress = day_minutes / float(MINUTES_PER_DAY)

	if total_minutes != last_emitted_total_minutes or force_emit_tick:
		if current_hour == 7 and current_minute == 0:
			day_started.emit()
		elif current_hour == 20 and current_minute == 0:
			night_started.emit()

		time_tick.emit(current_day, current_hour, current_minute)
		brightness_progress_signal.emit(_get_brightness_progress(current_hour, current_minute))

		last_emitted_total_minutes = total_minutes
		force_emit_tick = false


func _get_day_progress() -> float:
	var total_minutes: int = int(time_counter / RADIANS_PER_GAME_MINUTE)
	var day_minutes: int = total_minutes % MINUTES_PER_DAY
	return day_minutes / float(MINUTES_PER_DAY)


func _get_brightness_progress(hour: int, minute: int) -> float:
	var total_minutes: int = hour * 60 + minute

	if total_minutes >= 19 * 60 and total_minutes <= 21 * 60:
		return 1.0 - (total_minutes - 19 * 60) / 120.0
	elif total_minutes >= 4 * 60 and total_minutes <= 6 * 60:
		return (total_minutes - 4 * 60) / 120.0
	elif total_minutes > 6 * 60 and total_minutes < 19 * 60:
		return 1.0
	else:
		return 0.0


func _update_entity_shadows() -> void:
	var angle: float = day_progress * TAU
	var shear_amount: float = sin(angle)
	shadow_material.set_shader_parameter("shear_amount", shear_amount)


func set_hour(new_hour: int) -> void:
	set_time(current_day, new_hour, 0)


func set_time(day: int, hour: int, minute: int) -> void:
	var total_minutes: int = day * MINUTES_PER_DAY + hour * 60 + minute
	time_counter = total_minutes * RADIANS_PER_GAME_MINUTE
	force_emit_tick = true
