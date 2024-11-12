extends ItemResource
class_name ConsumableResource

@export_group("General Consumable Details")
@export var effect_source: EffectSource = EffectSource.new() ## The resource that defines what happens to the entity that consumes this consumable. Includes things like damage and status effects.
@export var hunger_bar_gain: int = 1
@export var hunger_bar_deduction: int = 0
