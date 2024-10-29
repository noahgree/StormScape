extends Camera2D

@export var player: Player
@export var smoothing_enabled: bool = false
@export_range(1, 100, 1) var smoothing_factor: int = 7
@export var drag_vertical: float = 0.1
@export var drag_horizontal: float = 0.2

func _ready() -> void:
	global_position = player.global_position

func _physics_process(delta: float) -> void:
	if player != null:
		if smoothing_enabled:
			var camera_pos: Vector2 = global_position
			var screen_size = get_viewport_rect().size
			var vertical_limit = screen_size.y * drag_vertical
			var horizontal_limit = screen_size.x * drag_horizontal
			var player_screen_pos = to_local(player.global_position)

			
			# Check vertical threshold
			if player_screen_pos.y < -vertical_limit:
				camera_pos.y = lerp(camera_pos.y, player.global_position.y + vertical_limit, float(smoothing_factor) * delta)
			elif player_screen_pos.y > vertical_limit:
				camera_pos.y = lerp(camera_pos.y, player.global_position.y - vertical_limit, float(smoothing_factor) * delta)

			# Check horizontal threshold
			if player_screen_pos.x > horizontal_limit:
				camera_pos.x = lerp(camera_pos.x, player.global_position.x - horizontal_limit, float(smoothing_factor) * delta)
			elif player_screen_pos.x < -horizontal_limit:
				camera_pos.x = lerp(camera_pos.x, player.global_position.x + horizontal_limit, float(smoothing_factor) * delta)
			
			global_position = camera_pos
		else:
			global_position = player.global_position
