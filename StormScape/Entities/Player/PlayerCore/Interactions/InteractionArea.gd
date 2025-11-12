@tool
extends Area2D
class_name InteractionArea
## The reusable interaction area scene that defines an interaction offer and prompt display positioning.

@export var prompt_radius: float = 15.0:
	set(new_radius):
		prompt_radius = new_radius
		if interaction_collider:
			interaction_collider.shape.radius = new_radius
@export var radius_offset: Vector2 = Vector2.ZERO: ## The offset for where the interaction radius should be placed.
	set(new_offset):
		radius_offset = new_offset
		if interaction_collider:
			interaction_collider.position = radius_offset
@export var interaction_offer: InteractionOffer ## The details for the interaction offer when in range.
@export var prompt_offset: Vector2: ## Where the interaction prompt should be.
	set(new_pos):
		prompt_offset = new_pos
		if prompt_offset_marker:
			prompt_offset_marker.position = prompt_offset

@onready var interaction_collider: CollisionShape2D = $CollisionShape2D ## The collider checking for interactions.
@onready var prompt_offset_marker: Marker2D = %PromptOffsetMarker ## The marker that displays where the prompt offset has been set to. Only set the offset via the prompt_offset export var, don't move this node.


func _ready() -> void:
	if interaction_offer and not interaction_offer.resource_local_to_scene:
		push_error(get_parent().name + " has an interaction area with an interaction offer that is not local to scene.")
	prompt_radius = prompt_radius
	radius_offset = radius_offset
	prompt_offset = prompt_offset

## Sets the interaction offer's accept callable to a new one.
func set_accept_callable(new_callable: Callable) -> void:
	interaction_offer.accept_callable = new_callable

## When the player enters the interaction area, offer the interaction.
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body is Player:
		interaction_offer.ui_offset = prompt_offset_marker.position
		interaction_offer.ui_anchor_node = self
		Globals.player_node.interaction_handler.offer_interaction(interaction_offer)

## When the player leaves the interaction area, revoke the interaction offer.
func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body is Player:
		Globals.player_node.interaction_handler.revoke_offer(interaction_offer)
