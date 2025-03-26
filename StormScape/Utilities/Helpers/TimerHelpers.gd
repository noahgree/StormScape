class_name TimerHelpers
## Timer helpers that create and return timers using one-liners.


## Creates and returns a one shot timer with its timeout callable already connected if specified.
static func create_one_shot_timer(parent: Node, wait_time: float = -1,
									timeout_callable: Callable = Callable()) -> Timer:
	var timer: Timer = Timer.new()

	if wait_time != -1:
		timer.wait_time = wait_time
	if timeout_callable != Callable():
		timer.timeout.connect(timeout_callable)
	timer.one_shot = true

	parent.add_child(timer)

	return timer

## Creates and returns a repeating and autostarting timer with its timeout callable already connected if
## specified.
static func create_repeating_autostart_timer(parent: Node, wait_time: float,
											timeout_callable: Callable = Callable()) -> Timer:
	var timer: Timer = Timer.new()

	timer.wait_time = wait_time
	if timeout_callable != Callable():
		timer.timeout.connect(timeout_callable)
	timer.autostart = true

	parent.add_child(timer)

	return timer

## Creates and returns a repeating and non-autostarting timer with its timeout callable already
## connected if specified.
static func create_repeating_timer(parent: Node, wait_time: float = -1,
									timeout_callable: Callable = Callable()) -> Timer:
	var timer: Timer = Timer.new()

	if wait_time != -1:
		timer.wait_time = wait_time
	if timeout_callable != Callable():
		timer.timeout.connect(timeout_callable)

	parent.add_child(timer)

	return timer
