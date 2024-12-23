extends Node
class_name UIDHelper
## A class for generating uids for refcounted instances like resources.

static var session_uid_counter: int = 0 ## The session uid counter that gets reset on game load or at game start.
static var multishot_uid_counter: int = 0 ## The multishot uid counter that gets reset on game load or at game start.
static var multishot_reset_timer: Timer = Timer.new() ## The multishot counter reset daemon timer.


func _ready() -> void:
	add_child(multishot_reset_timer)
	multishot_reset_timer.start(100)
	multishot_reset_timer.timeout.connect(func() -> void: multishot_uid_counter = 0)

## Generates a session uid and returns it.
static func generate_session_uid() -> int:
	session_uid_counter += 1
	return session_uid_counter

## Generates a multishot uid and returns it.
static func generate_multishot_uid()  -> int:
	multishot_uid_counter += 1
	return multishot_uid_counter
