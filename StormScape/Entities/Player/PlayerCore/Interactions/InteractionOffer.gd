extends Resource
class_name InteractionOffer
## Holds data about an interaction offer and what to do if accepted.

@export var title: String ## The title of this offer.
@export var title_color: Color = Globals.ui_colors["ui_light_tan"] ## The color of the title text.
@export var title_outline_color: Color = Globals.ui_colors["ui_text_outline"] ## The color of the title text outline.
@export var info: String ## The info string about this offer.
@export var info_color: Color = Globals.ui_colors["ui_tan"] ## The color of the info text.
@export var info_outline_color: Color = Globals.ui_colors["ui_text_outline"] ## The color of the info text outline.
@export var icon: Texture2D = preload("uid://cd22xh5jduxd6") ## The image icon to show when showing this offer.
@export var remove_on_accept: bool = false ## When true, accepting this offer is a one time thing and it will be taken out of the queue afterwards. When false, it will stay on top of the queue and can be accepted multiple times until manually removed.

var accept_callable: Callable ## The function to be called when the offer is accepted.
var ui_anchor_node: Node2D ## The node to base the ui position off of.
var ui_offset: Vector2 ## The offset for the position of the ui relevant to the ui anchor node.


## Init function for creating interaction offers in code.
static func create(title_txt: String = "Interact", title_clr: Color = Globals.ui_colors["ui_light_tan"],
			title_out_clr: Color = Globals.ui_colors["ui_text_outline"], info_txt: String = "",
			info_clr: Color = Globals.ui_colors["ui_tan"],
			info_out_clr: Color = Globals.ui_colors["ui_text_outline"],
			icon_path: String = "uid://cd22xh5jduxd6", remove_after_accept: bool = false,
			on_accept_callable: Callable = Callable(), anchor_node: Node2D = null,
			ui_offset_vector: Vector2 = Vector2.ZERO) -> InteractionOffer:
	var io: InteractionOffer = InteractionOffer.new()
	io.title = title_txt
	io.title_color = title_clr
	io.title_outline_color = title_out_clr
	io.info = info_txt
	io.info_color = info_clr
	io.info_outline_color = info_out_clr
	io.icon = load(icon_path)
	io.remove_on_accept = remove_after_accept
	io.accept_callable = on_accept_callable
	io.ui_anchor_node = anchor_node
	io.ui_offset = ui_offset_vector
	io.resource_local_to_scene = true
	return io
