class_name InteractionHandler
## Handles receiving interaction prompts, processing them, and displaying them.

var ui: Control
var offers_queue: Array[InteractionOffer] = []


func offer_interaction(interaction_offer: InteractionOffer) -> void:
	offers_queue.append(interaction_offer)

func revoke_offer(interaction_offer: InteractionOffer) -> void:
	offers_queue.erase(interaction_offer)

func on_interaction_accepted() -> void:
	if offers_queue.is_empty():
		return
	var offer: InteractionOffer = offers_queue.back()
	if offer.remove_on_accept:
		offers_queue.pop_back()
	if offer.accept_callable.is_valid():
		offer.accept_callable.call()
