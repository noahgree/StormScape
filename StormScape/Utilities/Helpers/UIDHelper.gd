class_name UIDHelper
## A class for generating uids for refcounted instances like resources.

static var session_uid_counter: int = 0 ## The session uid counter that gets reset on game load or at game start.


## Generates a session uid and returns it.
static func generate_session_uid() -> int:
	session_uid_counter += 1
	return session_uid_counter
