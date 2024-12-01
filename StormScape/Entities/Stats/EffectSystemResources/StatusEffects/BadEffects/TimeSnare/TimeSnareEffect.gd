extends StatusEffect
class_name TimeSnareEffect

@export_range(0.0, 1.0, 0.01) var time_multiplier: float = 0.5 ## What to multiply delta by to slow things down.
@export var snare_time: float = 3.0 ## How long the time snare should last for.
