@icon("res://Utilities/Debug/EditorIcons/entity_shadow.svg")
@tool
extends NinePatchRect
class_name EntityShadow
## A preset selection of sizes for use as shadow sprites under entities.

enum ShadowType { TINY, SMALL, MEDIUM, LARGE, EXTRA_LARGE } ## The options for size.

@export var type: ShadowType = ShadowType.SMALL: set = set_type ## Sets the size and texture used for the shadow.

const SHADOW_PATHS: Dictionary[int, String] = { ## The texture paths corresponding to each size.
	0 : "res://Entities/EntityCore/Shadow/shadow_tiny.png",
	1 : "res://Entities/EntityCore/Shadow/shadow_small.png",
	2 : "res://Entities/EntityCore/Shadow/shadow_medium.png",
	3 : "res://Entities/EntityCore/Shadow/shadow_large.png",
	4 : "res://Entities/EntityCore/Shadow/shadow_extra_large.png"
}
const PATCH_MARGINS: Dictionary[int, int] = { ## The patch margins corresponding to each size.
	0 : 3,
	1 : 3,
	2 : 5,
	3 : 8,
	4 : 12
}


## Sets the type by ensuring we are in the editor and then assigning size, texture, and margin.
func set_type(new_type: ShadowType) -> void:
	if not Engine.is_editor_hint():
		return
	if not SHADOW_PATHS.has(new_type):
		return

	type = new_type

	var margin: int = PATCH_MARGINS.get(new_type)
	patch_margin_bottom = margin
	patch_margin_top = margin
	patch_margin_left = margin
	patch_margin_right = margin

	texture = load(SHADOW_PATHS.get(new_type))

	var tex_size: Vector2 = texture.get_size()
	var tex_size_int: Vector2i = Vector2i(ceili(tex_size.x), ceili(tex_size.y))
	if tex_size_int.x % 2 != 0:
		tex_size_int.x += 1
	if tex_size_int.y % 2 != 0:
		tex_size_int.y += 1
	size = tex_size_int
	position = Vector2(-size.x / 2, -size.y / 2)
