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
@export var auto_advance: bool = true ## When false, the storm queue will not advance past the end of this phase until manually called upon to do so.

@export_subgroup("Status Effect")
@export_enum("Override", "Revert to Default", "Keep Previous") var effect_setting: String = "Keep Previous" ## Determines how to change the status effect for this incoming phase.
@export var status_effect: StatusEffect = null ## The new status effect to apply. Leave null to keep the old one. [b]MUST NOT REQUIRE AN EFFECT SOURCE[/b] because no source entity or movement direction information will be passed (Knockback, LifeSteal).

@export_subgroup("Visuals")
@export_enum("Override", "Revert to Default", "Keep Previous") var visuals_setting: String = "Keep Previous" ## Determines how to apply visuals for this incoming phase.
@export var storm_visuals: StormVisuals = null ## The storm visuals to apply when the override option is chosen for this phase.
