extends Node2D
class_name WorldItems

var grid_size: float = 32.0
var grid: Dictionary = {}
var timer: Timer = Timer.new()


func _ready():
	add_child(timer)
	timer.one_shot = false
	timer.wait_time = 1.5
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

func _on_timer_timeout():
	for grid_pos in grid.keys():
		for item in grid[grid_pos]:
			find_and_combine_neighbors(item)

func _to_grid_position(position: Vector2) -> Vector2:
	return Vector2(floor(position.x / grid_size), floor(position.y / grid_size))

func add_item(item: Node2D):
	var grid_pos = _to_grid_position(item.position)
	if not grid.has(grid_pos):
		grid[grid_pos] = []
	grid[grid_pos].append(item)

func remove_item(item: Node2D):
	var grid_pos = _to_grid_position(item.position)
	if grid.has(grid_pos):
		grid[grid_pos].erase(item)
		if grid[grid_pos].empty():
			grid.erase(grid_pos)

func find_and_combine_neighbors(item: Node2D):
	var grid_pos = _to_grid_position(item.position)
	var neighbors = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			var neighbor_pos = grid_pos + Vector2(x, y)
			if grid.has(neighbor_pos):
				neighbors += grid[neighbor_pos]

	# Implement your combination logic here ## FIXME!!!
	for neighbor in neighbors:
		if neighbor != item and can_combine(item, neighbor):
			combine_items(item, neighbor)

func can_combine(item1: Node2D, item2: Node2D) -> bool:
	# Define your combination criteria
	return false

func combine_items(item1: Node2D, item2: Node2D):
	# Implement your combination logic
	pass
