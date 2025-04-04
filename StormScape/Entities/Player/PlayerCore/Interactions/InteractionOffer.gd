extends Resource
class_name InteractionOffer
## Holds data about an interaction offer and what to do if accepted.

@export var title: String
@export var info: String
@export var remove_on_accept: bool

@export_storage var accept_callable: Callable
