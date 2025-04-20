class_name ArrayHelpers
## A helper class with additional functions for arrays.


## Gets an element at an array index or returns the default value if it doesn't exist.
static func get_or_default(array: Array, index: int, default: Variant) -> Variant:
	if index >= 0 and index < array.size():
		return array[index]
	else:
		return default

## Finds the index holding the maximum value in the array and returns it. Returns -1 if the array was empty.
static func get_max_value_index(array: Array) -> int:
	var max_index: int = -1
	if array.is_empty():
		return max_index
	var max_value: Variant = array[0]

	for i: int in range(array.size()):
		if array[i] > max_value:
			max_value = array[i]
			max_index = i

	return max_index
