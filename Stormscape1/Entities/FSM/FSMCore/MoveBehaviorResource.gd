extends Resource
class_name MoveBehaviorResource
## Defines the values to pass with a call to direct an AI's movement.

@export_range(-1, 1, 0.01) var seek_weight: float = 1.0 ## How much we should move towards the target. Positives move towards, negatives move away.
@export_range(-1, 1, 0.01) var orbit_weight: float = 0.0 ## How much priority should be given to orbiting the target. Positive orbits clockwise (right). Negative orbits counterclockwise (left).
@export var preferred_distance: float = 50.0 ## The distance that the entity would *like* to be away from its target.
@export_range(-1, 1, 0.01) var distance_weight: float = 1.0 ## How much to try and incorporate the preferred distance.
@export var max_turn_rate: float = 1.35 ## How strongly the entity should turn.
