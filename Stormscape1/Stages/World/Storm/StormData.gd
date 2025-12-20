extends SaveData
class_name StormData

@export var is_enabled: bool
@export var zone_count: int

@export var global_pos: Vector2
@export var current_radius: float

@export var transform_queue: Array[StormTransform]
@export var recent_visuals: StormVisuals
@export var recent_effect: StatusEffect
