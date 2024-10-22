extends Resource
class_name EntityStatMod
## A resource that holds information on how to modify a base entity stat like max_speed. 
##
## These are intended to be stacked and read out by whatever component handles using the base stat.

@export var type: EnumUtils.EntityStatModType
@export var stat_id: String ## The id of the specific stat to get modded.
@export var mod_id: String ## The id of the specific mod applied to some stat.
@export_enum("+%", "-%", "+", "-", "*", "/", "=") var operation: String = "+%" ## The operation to apply the value. [b]+% adds the percentage[/b] of the base stat value. [b]-% subtracts the percentage[/b] of the base state value. [b]+ adds[/b] the value to the existing stat value. [b]- subtracts[/b] the value from the existing stat value. [b]* multiplies[/b] the value by the existing stat value. [b]/ divides[/b] the value by the existing stat value. [b]= sets the stat equal[/b] to the value (use [b]override_all[/b] to make this the only determinant of the stat).
@export var value: float ## The value that will be applied according to the specified operation.

@export_group("More Options")
@export_range(1, 5, 1) var priority: int = 1 ## The relative ordering in which it should be applied. 5 goes first. 
@export var can_stack: bool = false ## Whether to stack the value if the mod gets applied more than once.
@export var max_stack_count: int = 3 ## The max number of times this can stack, if possible.
@export var override_all: bool = false ## Whether this effect should become the only applied effect on this stat.

var stack_count: int = 1 ## The current number of times this mod is applied (via stacking).
var before_stack_value: float = 0 ## The original value before stacking got applied.


func _init(sid: String = "UntitledStat", mid: String = "UntitledMod", op: String = "%", val: float = 1.0, 
			prio: int = 1, stacks: bool = false, max_stack: int = 3, override: bool = false):
	stat_id = sid
	mod_id = mid
	operation = op
	value = val
	priority = prio
	can_stack = stacks
	max_stack_count = max_stack
	before_stack_value = val
	override_all = override

func apply(base_stat_value: float, value_before_mod: float) -> float:
	match operation:
		"+%":
			return value_before_mod + (base_stat_value * (value / 100))
		"-%":
			return value_before_mod - (base_stat_value * (value / 100))
		"+":
			return value_before_mod + value
		"-":
			return value_before_mod - value
		"*":
			return value_before_mod * value
		"/":
			if value != 0:
				return value_before_mod / value
			else:
				return value_before_mod
		"=":
			return value
		_:
			return value_before_mod
