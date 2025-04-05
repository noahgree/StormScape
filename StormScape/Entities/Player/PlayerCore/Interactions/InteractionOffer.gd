extends Resource
class_name InteractionOffer
## Holds data about an interaction offer and what to do if accepted.

@export var title: String ## The title of this offer.
@export var title_color: Color = Globals.ui_colors["ui_light_tan"] ## The color of the title text.
@export var title_outline_color: Color = Globals.ui_colors["ui_text_outline"] ## The color of the title text outline.
@export var info: String ## The info string about this offer.
@export var info_color: Color = Globals.ui_colors["ui_tan"] ## The color of the info text.
@export var info_outline_color: Color = Globals.ui_colors["ui_text_outline"] ## The color of the info text outline.
@export var icon: Texture2D = preload("res://UI/TemporaryElements/InteractionIcons/e_prompt.png") ## The image icon to show when showing this offer.
@export var remove_on_accept: bool ## When true, accepting this offer is a one time thing and it will be taken out of the queue afterwards. When false, it will stay on top of the queue and can be accepted multiple times until manually removed.

var accept_callable: Callable ## The function to be called when the offer is accepted.
var ui_anchor_node: Node2D ## The node to base the ui position off of.
var ui_offset: Vector2 ## The offset for the position of the ui relevant to the ui anchor node.
