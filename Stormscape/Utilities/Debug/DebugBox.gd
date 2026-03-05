@tool
extends Polygon2D
class_name DebugBox
## A helper scene and script that can be synced to another tool script to update its visible boundaries
## for debugging purposes.
##
## Great for visualizing particle emission areas.

var is_zero: bool = true ## When true, the debug box extents are effectively zero and should not be shown.


func _ready() -> void:
	visible = _check_if_can_show_debug_boxes()

## Updates the visual extents with an origin and the extents themselves.
func update_debug_box_with_extents(origin: Vector2, extents: Vector2) -> void:
	is_zero = (extents.x == 0 or extents.y == 0)
	if not _check_if_can_show_debug_boxes():
		hide()
		return
	var top_left: Vector2 = origin - extents
	var bottom_right: Vector2 = origin + extents
	var points: Array[Vector2] = [top_left, Vector2(bottom_right.x, top_left.y), bottom_right, Vector2(top_left.x, bottom_right.y)]
	polygon = points
	show()

## Updates the visual extents with the top left and bottom right corners.
func update_debug_box_with_corners(top_left: Vector2, bottom_right: Vector2) -> void:
	if not _check_if_can_show_debug_boxes():
		hide()
		return
	var points: Array[Vector2] = [top_left, Vector2(bottom_right.x, top_left.y), bottom_right, Vector2(top_left.x, bottom_right.y)]
	polygon = points
	show()

## Determines if we can show the debug box in editor.
func _check_if_can_show_debug_boxes() -> bool:
	if is_zero:
		return false
	if (not Engine.is_editor_hint()) or (get_parent() == null):
		return false
	if (not "show_debug_boxes" in get_parent()) or (get_parent().show_debug_boxes == false):
		return false
	return true
