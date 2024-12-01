extends StatusEffect
class_name StunEffect

@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var stun_time: float = 0 ## The amount of time the damage recipient should be stunned for. Note that this only stuns on the first damage tick regardless of DOT settings.
