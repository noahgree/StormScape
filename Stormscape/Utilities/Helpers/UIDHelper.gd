class_name UIDHelper
## A class for generating uids for refcounted instances like resources.

static var uid_counter: int = 0 ## The uid counter.
static var multishot_uid_counter: int = 0 ## The multishot uid counter.

## Generates a session uid and returns it.
static func uid() -> int:
	uid_counter += 1
	return uid_counter

## Generates a multishot uid and returns it.
static func generate_multishot_uid()  -> int:
	multishot_uid_counter += 1
	return multishot_uid_counter
