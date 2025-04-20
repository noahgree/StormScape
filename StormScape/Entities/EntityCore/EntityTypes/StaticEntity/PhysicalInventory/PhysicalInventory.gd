@tool
extends StaticEntity
class_name PhysicalInventory
## An interactable inventory in the game world.

@export var interact_radius: float = 15.0: ## How far away interactions can be triggered.
	set(new_radius):
		interact_radius = new_radius
		if interaction_collider:
			interaction_collider.shape.radius = new_radius
@export var interaction_offer: InteractionOffer ## The details for the interaction offer when in range.
@export var prompt_position: Vector2: ## Where the interaction prompt should be.
	set(new_pos):
		prompt_position = new_pos
		if interaction_prompt_pos:
			interaction_prompt_pos.position = prompt_position

@onready var interaction_collider: CollisionShape2D = $InteractionArea/CollisionShape2D ## The collider checking for interactions.
@onready var interaction_prompt_pos: Marker2D = $InteractionPromptPos ## The marker that displays where the prompt offset has been set to. Only set the offset via the prompt_position export var, don't move this node.


func _ready() -> void:
	if Engine.is_editor_hint():
		interaction_collider.shape = interaction_collider.shape.duplicate()
		return
	super()

	interaction_collider.shape.radius = interact_radius

	if interaction_offer == null:
		interaction_offer = InteractionOffer.new() # Temporary workaround until save system is reworked
	interaction_offer.accept_callable = Callable(func() -> void: SignalBus.alternate_inv_open_request.emit(self))

## When the player enters the interaction area, offer the interaction.
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body is Player:
		interaction_offer.ui_offset = interaction_prompt_pos.position
		interaction_offer.ui_anchor_node = self
		Globals.player_node.interaction_handler.offer_interaction(interaction_offer)

## When the player leaves the interaction area, revoke the interaction offer.
func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body is Player:
		Globals.player_node.interaction_handler.revoke_offer(interaction_offer)
