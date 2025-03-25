extends Resource
class_name ItemDetail
## This is used to define extra details that should populate the item details panel of the item viewer in the
## player inventory.

@export var title: String ## The all caps name of the detail.
@export var stat_array: Array[String] = [] ## The array of stats to be summed together.
@export var up_is_good: bool = true ## When true, a higher than base stat value (usually because of mods) is a good thing.
@export var suffix: String = "" ## The suffix to place before the up or down arrow (like "s" for seconds).
