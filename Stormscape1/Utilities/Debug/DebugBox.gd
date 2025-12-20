@tool
extends Polygon2D
class_name DebugBox
## A helper scene and script that can be synced to another tool script to update its visible boundaries
## for debugging purposes.
##
## Great for visualizing particle emission areas.


func _ready() -> void:
	if not Engine.is_editor_hint():
		hide()

## Updates the visual extents with an origin and the extents themselves.
func update_debug_box_with_extents(origin: Vector2, extents: Vector2) -> void:
	if not Engine.is_editor_hint():
		return
	var top_left: Vector2 = origin - extents
	var bottom_right: Vector2 = origin + extents
	var points: Array[Vector2] = [top_left, Vector2(bottom_right.x, top_left.y), bottom_right, Vector2(top_left.x, bottom_right.y)]
	polygon = points


## Updates the visual extents with the top left and bottom right corners.
func update_debug_box_with_corners(top_left: Vector2, bottom_right: Vector2) -> void:
	if not Engine.is_editor_hint():
		return
	var points: Array[Vector2] = [top_left, Vector2(bottom_right.x, top_left.y), bottom_right, Vector2(top_left.x, bottom_right.y)]
	polygon = points
