class_name InteractionHandler
## Handles receiving interaction prompts, processing them, and displaying them.

var prompt_ui: InteractionPrompt ## The UI that shows the prompts. Passed in from the creator of this script.
var offers_queue: Array[InteractionOffer] = [] ## The queue of offers.


## Adds the interaction offer to the queue and then updates the UI with it.
func offer_interaction(interaction_offer: InteractionOffer) -> void:
	offers_queue.append(interaction_offer)
	_update_prompt_ui(interaction_offer)

## When there is an offer displaying and the trigger to accept it is activated, call the accept callable on it
## and conditionally delete it from the queue if needed. Then recheck the queue for the next potential offer.
func accept_interaction() -> void:
	if offers_queue.is_empty():
		return

	var offer: InteractionOffer = offers_queue.back()
	if offer.remove_on_accept:
		offers_queue.pop_back()
	if offer.accept_callable.is_valid():
		offer.accept_callable.call()

	recheck_queue()

## Remove an offer from the queue and recheck the queue for the next one in line.
func revoke_offer(interaction_offer: InteractionOffer) -> void:
	offers_queue.erase(interaction_offer)
	recheck_queue()

## Recheck the queue for the next offer in line if one exists.
func recheck_queue() -> void:
	if offers_queue.is_empty():
		prompt_ui.hide()
	else:
		_update_prompt_ui(offers_queue.back())

## Updates the prompt UI with the new interaction offer.
func _update_prompt_ui(interaction_offer: InteractionOffer) -> void:
	prompt_ui.update_and_show(interaction_offer)
