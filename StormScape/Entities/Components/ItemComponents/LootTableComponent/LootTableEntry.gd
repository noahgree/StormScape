extends Resource
class_name LootTableEntry

@export var item: ItemResource
@export var quantity: int = 1
@export var weighting: float = 1.0


# Unique Properties #
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NO_EDITOR) var last_used: int = 0
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_NO_EDITOR) var spawn_count: int = 0
