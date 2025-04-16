extends Resource
class_name MoveBehaviorResource
## Defines reusable and passable resources for all the paramaters needed to define how an AI should move.

@export_range(0, 1, 0.01, "suffix:%") var behavior_blend: float = 0.3 ## 0 means only consider global & local movement contributions, 1 means do exactly as the behaviors below say, any blend in between 0 and 1 will compromise between the two accordingly.
@export_range(0, 1, 0.01, "suffix:%") var approach_weight: float = 1.0 ## How much priority should be given to beelining for the target.
@export_range(0, 1, 0.01, "suffix:%") var orbit_weight: float = 0.0 ## How much priority should be given to orbiting the target.
@export_range(0, 1, 0.01, "suffix:%") var retreat_weight: float = 0.0 ## How much priority should be given to running directly away from the target.
@export_range(-1, 1, 2, "suffix:1=CW | -1=CCW") var orbit_dir: int = 1 ## 1=clockwise, -1=counterclockwise for determining the orbit direction.
@export_range(0, 1000, 1, "suffix:pixels") var desired_target_dist: int = 20 ## How far away ideally the entity should be performing these behaviors from its target. When too close or too far, the direction it should move gets stronger to allow it to more directly and accurately reposition.
