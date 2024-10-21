extends Resource
class_name EntityStatMod
## A resource that holds information on how to modify a base entity stat like max_speed. 
##
## These are intended to be stacked and read out by whatever component handles using the base stat.

@export var mod_id: String ## The id of the specific mod applied to some stat.
@export_enum("+", "-", "*", "/") var operation: String = "*" ## The operation by which to apply the value.
@export var value: float ## The value that will be applied according to the specified operation.
@export_range(1, 5, 1) var priority: int = 1 ## The relative ordering in which it should be applied. 5 goes first. 
@export var can_stack: bool = false ## Whether to stack the value if the mod gets applied more than once.
@export var max_stack_count: int = 3 ## The max number of times this can stack, if possible.

var stack_count: int = 1 ## The current number of times this mod is applied (via stacking).
var before_stack_value: float = 0 ## The original value before stacking got applied.


func _init(id: String = "UntitledMod", op: String = "*", val: float = 1.0, prio: int = 1, 
			stacks: bool = false, max_stack: int = 3):
	mod_id = id
	operation = op
	value = val
	priority = prio
	can_stack = stacks
	max_stack_count = max_stack
	before_stack_value = val

func apply(value_before_mod: float) -> float:
	match operation:
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
		_:
			return value_before_mod
