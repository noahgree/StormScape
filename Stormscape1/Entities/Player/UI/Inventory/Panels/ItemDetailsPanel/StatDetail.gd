extends Resource
class_name StatDetail
## This is used to define extra details that should populate the item details panel of the item viewer in the
## player inventory.

@export var title: String ## The all caps name of the detail.
@export var stat_array: Array[String] = [] ## The array of stats to be summed together.
@export var up_is_good: bool = true ## When true, a higher than base stat value (usually because of mods) is a good thing.
@export var suffix: String = "" ## The suffix to place before the up or down arrow (like "s" for seconds).
@export var multiplier: float = 1.0 ## An arbitrary multiplier to apply to the final stat sum. Helpful for certain formatting like turning something into a percentage.
@export var addition: float = 0.0 ## Can arbitrarily add a constant value to the final stat sum, once again being helpful for certain formatting.
@export var fraction_of_orig: bool = false ## When true, the resulting value will be returned as (new_val/orig_val).
