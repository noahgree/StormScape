class_name StringHelpers
## A collection of helper methods for dealing with strings.


static func remove_trailing_zero(string: String) -> String:
	var new_string: String = string
	if string.ends_with(".0"):
		new_string = string.substr(0, new_string.length() - 2)
	return new_string
