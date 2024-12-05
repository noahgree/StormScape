extends Node2D
class_name WorldItemsManager
## Manages all world floor items by attempting to combine them into stacks every so often.

const GRID_SIZE: float = 30.0 ## The size of the grid partitions in pixels.
var grid: Dictionary = {} ## The grid containing all floor item locations & node references.
var combination_attempt_timer: Timer = Timer.new() ## The timer that delays attempts to combine near floor items.


func _on_before_load_game() -> void:
	grid.clear()

func _ready() -> void:
	add_child(combination_attempt_timer)
	combination_attempt_timer.one_shot = true
	combination_attempt_timer.wait_time = randf_range(1.5, 5.0)
	combination_attempt_timer.timeout.connect(_on_combination_attempt_timer_timeout)
	combination_attempt_timer.start()

## When the timer ends, start attempting to combine nearby items on the ground. This also cleans up empty grid locations from our
## dict afterwards.
func _on_combination_attempt_timer_timeout() -> void:
	var processed_items: Dictionary = {}
	for grid_pos: Vector2 in grid.keys():
		if grid[grid_pos].is_empty():
			grid.erase(grid_pos)
			continue

		for item: Item in grid[grid_pos]:
			if not processed_items.has(item):
				_find_and_combine_neighbors(item, processed_items)

	combination_attempt_timer.wait_time = randf_range(1.5, 5.0)
	combination_attempt_timer.start()

## Gets a world position in terms of the grid coordinates.
func _to_grid_position(pos: Vector2) -> Vector2:
	return Vector2(floor(pos.x / GRID_SIZE), floor(pos.y / GRID_SIZE))

## Called anytime we spawn something on the ground and want it to be considered in our combination grid.
func add_item(item: Item) -> void:
	add_child(item)

	var grid_pos: Vector2 = _to_grid_position(item.position)
	if not grid.has(grid_pos):
		grid[grid_pos] = []
	grid[grid_pos].append(item)

	item.tree_exiting.connect(remove_item.bind(item))

## Removes an item from the combination grid.
func remove_item(item: Item) -> void:
	var grid_pos: Vector2 = _to_grid_position(item.position)
	if grid.has(grid_pos):
		grid[grid_pos].erase(item)

## Searches the current grid location and the 8 surrounding locations for items to combine with.
func _find_and_combine_neighbors(item: Item, processed_items: Dictionary) -> void:
	var grid_pos: Vector2 = _to_grid_position(item.position)
	var neighbors: Array[Item] = []
	for x: int in range(-1, 2):
		for y: int in range(-1, 2):
			var neighbor_pos: Vector2 = grid_pos + Vector2(x, y)
			if grid.has(neighbor_pos):
				var items_at_pos: Array = grid[neighbor_pos]
				for neighbor: Item in items_at_pos:
					neighbors.append(neighbor as Item)

	for neighbor: Item in neighbors:
		if neighbor != item and item.stats.is_same_as(neighbor.stats):
			_combine_items(item, neighbor)
			processed_items[neighbor] = true

## Combines the items by adding the quantities. Removes the old item after tweening its location and scale.
func _combine_items(item_1: Item, item_2: Item) -> void:
	item_1.quantity += item_2.quantity
	remove_item(item_2)
	item_2.can_be_picked_up_at_all = false

	item_2.z_index = item_1.z_index - 1
	var tween: Tween = create_tween()
	tween.tween_property(item_2, "global_position", item_1.global_position, 0.15)
	tween.parallel().tween_property(item_2.thumbnail, "scale", Vector2(0.5, 0.5), 0.15)
	tween.chain().tween_callback(item_2.queue_free)
