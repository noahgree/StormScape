extends Resource
class_name StormTransform
## A resource for defining the parameters on how to change the current zone.

@export var new_location: Vector2 = Vector2.ZERO ## The new location in global world coords to move to.
@export var offset_location: bool = false ## When true, the new_location vector will be added to the current location rather than moving to that global position.
@export_custom(PROPERTY_HINT_NONE, "suffix:pixels") var new_radius: float = 50 ## The new radius to resize to.
@export var offset_radius: bool = false ## When true, the new_radius will be added to the current radius rather than using it to set the radius directly.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var delay: float = 0 ## The delay after this phase is started before the size and location start changing.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var time_to_move: float = 10.0 ## The time it takes for the moving to complete.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var time_to_resize: float = 10.0 ## The time it takes for the resizing to complete.
@export var status_effect: StatusEffect = null ## The new status effect to apply. Leave null to keep the old one.

@export_subgroup("Visual Overrides")
@export var override_visuals: bool = false ## Whether to use the visual overrides for this phase.
@export var storm_visuals: StormVisuals = StormVisuals.new()
