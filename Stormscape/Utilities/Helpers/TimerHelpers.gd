class_name TimerHelpers
## Timer helpers that create and return timers using one-liners.


## Creates and returns a one shot timer with its timeout callable already connected if specified.
static func create_one_shot_timer(parent: Node, wait_time: float = -1, timeout_callable: Callable = Callable(),
									timer_name: String = "Timer") -> Timer:
	var timer: Timer = Timer.new()
	timer.name = timer_name

	if wait_time != -1:
		timer.wait_time = wait_time
	if timeout_callable != Callable():
		timer.timeout.connect(timeout_callable)
	timer.one_shot = true

	parent.add_child(timer)

	return timer

## Creates and returns a repeating and autostarting timer with its timeout callable already connected if
## specified.
static func create_repeating_autostart_timer(parent: Node, wait_time: float, timeout_callable: Callable = Callable(), 												timer_name: String = "Timer") -> Timer:
	var timer: Timer = Timer.new()
	timer.name = timer_name

	timer.wait_time = wait_time
	if timeout_callable != Callable():
		timer.timeout.connect(timeout_callable)
	timer.autostart = true

	parent.add_child(timer)

	return timer

## Creates and returns a repeating and non-autostarting timer with its timeout callable already
## connected if specified.
static func create_repeating_timer(parent: Node, wait_time: float = -1, timeout_callable: Callable = Callable(),
									timer_name: String = "Timer") -> Timer:
	var timer: Timer = Timer.new()
	timer.name = timer_name

	if wait_time != -1:
		timer.wait_time = wait_time
	if timeout_callable != Callable():
		timer.timeout.connect(timeout_callable)

	parent.add_child(timer)

	return timer

## Deletes all timers for a source type from the timer cache dict. Can optionally send a single timer
## to be the only one removed.
static func delete_timers_from_cache(timers_array: Array, specific_timer: Timer = null) -> void:
	var to_remove: Array[int] = [] # The indices from the timer array that we will remove from after the loop
	var i: int = 0
	for timer: Variant in timers_array:
		if timer != null:
			if timer == specific_timer:
				timer.queue_free()
				timers_array.remove_at(i)
				return
			else:
				timer.queue_free()
		else:
			to_remove.append(i)
		i += 1

	to_remove.reverse()
	for index: int in to_remove:
		timers_array.remove_at(index)

## Frees all delay timers from a delay timers array if they weren't already null.
static func delete_delay_timers_from_cache(delay_timers_array: Array) -> void:
	delay_timers_array = delay_timers_array.filter(func(timer: Variant) -> bool:
		if timer != null:
			timer.queue_free()
		return false
		)

## Adds a timer to the timer dict cache with the source type as the key.
static func add_timer_to_cache(source_type: String, timer: Timer, cache: Dictionary) -> void:
	if source_type in cache:
		cache[source_type].append(timer)
	else:
		cache[source_type] = [timer]
