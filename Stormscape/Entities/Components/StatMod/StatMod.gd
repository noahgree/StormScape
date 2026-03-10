extends Resource
class_name StatMod
## A resource that holds information on how to modify a base stat like max_speed.

@export var stat_id: StringName ## The id of the specific stat to get modded.
@export var mod_id: StringName ## The id of the specific mod applied to some stat.
@export_enum("+%", "-%", "+", "-", "*", "/", "=") var operation: String = "+%" ## The operation to apply the value. [b]+% adds the percentage[/b] of the base stat value. [b]-% subtracts the percentage[/b] of the base state value. [b]+ adds[/b] the value to the existing stat value. [b]- subtracts[/b] the value from the existing stat value. [b]* multiplies[/b] the value by the existing stat value. [b]/ divides[/b] the value by the existing stat value. [b]= sets the stat equal[/b] to the value (use [b]override_all[/b] to make this the only determinant of the stat).
@export var value: float ## The value that will be applied according to the specified operation.
@export_enum("Exact", "Round Up", "Round Down", "Round Closest") var rounding: String = "Exact" ## How to round the value after the operation.

@export_group("Priority & Stacking")
@export_range(1, 5, 1) var priority: int = 1 ## The relative ordering in which it should be applied. 5 goes first.
@export var max_stack_count: int = 1 ## The max number of times this can stack. 1 is the default, meaning no stacking.
@export var override_all: bool = false ## Whether this effect should become the only applied effect on this stat.

@export_group("Stat Panel Details")
@export var panel_title: String = "" ## When not a blank string, this stat mod as part of a weapon mod will populate with this title in the item details panel. Use title case.
@export var panel_suffix: String = "" ## When including in the panel, this will be the suffix.
@export var is_good_mod: bool = true ## When true, the value will be displayed as green, when false, it will be red.

var stack_count: int = 1 ## The current number of times this mod is applied (via stacking).
var before_stack_value: float = 0 ## The original value before stacking got applied.


func apply(base_stat_value: float, value_before_mod: float) -> float:
	var new_value: float = value
	match operation:
		"+%":
			new_value = value_before_mod + (base_stat_value * (value / 100))
		"-%":
			new_value = value_before_mod - (base_stat_value * (value / 100))
		"+":
			new_value = value_before_mod + value
		"-":
			new_value = value_before_mod - value
		"*":
			new_value = value_before_mod * value
		"/":
			if value != 0:
				new_value = value_before_mod / value
			else:
				new_value = value_before_mod
		"=":
			new_value = value
		_:
			new_value = value_before_mod

	match rounding:
		"Exact":
			return new_value
		"Round Up":
			return ceilf(new_value)
		"Round Down":
			return floorf(new_value)
		"Round Closest":
			return roundf(new_value)
		_:
			return new_value
