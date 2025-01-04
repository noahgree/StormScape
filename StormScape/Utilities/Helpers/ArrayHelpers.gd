class_name ArrayHelpers
## A helper class with additional functions for arrays.


## Gets an element at an array index or returns the default value if it doesn't exist.
static func get_or_default(array: Array, index: int, default: Variant) -> Variant:
	if index >= 0 and index < array.size():
		return array[index]
	else:
		return default
