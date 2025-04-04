@tool
extends Area2D
class_name PhysicalInventory
## An interactable inventory in the game world.

@export var inv: InventoryResource = InventoryResource.new() ## The inventory for this physical inventory.
@export var interact_radius: float = 15.0: ## How far away interactions can be triggered.
	set(new_radius):
		interact_radius = new_radius
		if interaction_collider:
			interaction_collider.shape.radius = new_radius
@export var interaction_offer: InteractionOffer ## The details for the interaction offer when in range.

@onready var interaction_collider: CollisionShape2D = $CollisionShape2D ## The collider checking for interactions.
@onready var sprite: Sprite2D = $Sprite2D ## The sprite for this inventory.


var player_in_range: bool = false ## When true, the player is in range and can interact.


func _ready() -> void:
	if Engine.is_editor_hint():
		interaction_collider.shape = interaction_collider.shape.duplicate()
		return

	inv.initialize_inventory(self)
	interaction_collider.shape.radius = interact_radius

	interaction_offer.accept_callable = Callable(func() -> void: SignalBus.alternate_inv_open_request.emit(self))

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.interaction_handler.offer_interaction(interaction_offer)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		body.interaction_handler.revoke_offer(interaction_offer)
