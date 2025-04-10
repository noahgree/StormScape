extends Node2D
## A global singleton that caches the location of all audio resources.
##
## Interface with this singleton to play any music or sound effect, optionally providing a location to make it 2d.

@export_dir var music_resources_folder: String ## The folder holding all .tres music files.
@export_dir var sfx_resources_folder: String ## The folder holding all .tres sfx files.
enum SoundSpace { GLOBAL, SPATIAL } ## A specifier for determining global vs spatial (2d) audio.

const DISTANCE_FROM_PLAYER_BUFFER: int = 100 ## How far beyond max_distance the player can from the sound origin for a 2d sound to still get created.
const MAX_SPATIAL_POOL_SIZE: int = 12 ## How many 2d audio player nodes can be waiting around in the pool.
const MAX_GLOBAL_POOL_SIZE: int = 15 ## How many global audio player nodes can be waiting around in the pool.
var sound_cache: Dictionary[StringName, AudioResource] = {} ## The dict of the file paths to all sound resources, using the id as the key.
var scene_ref_counts: Dictionary[StringName, int] = {} ## The number of scenes needing access to certain sound ids.
var spatial_pool: Array[AudioStreamPlayer2D] ## The 2d audio players current waiting around in memory.
var global_pool: Array[AudioStreamPlayer] ## The global audio players current waiting around in memory.

#region Setup & Cache
func _ready() -> void:
	if OS.get_unique_id() == "W1RHWL2KQ6": # Needed to make audio work on Noah's computer, only affects him
		var devices: PackedStringArray = AudioServer.get_output_device_list()
		var macbook_device_index: int = devices.find("Macbook")
		var macbook_device: String = devices[macbook_device_index]
		AudioServer.output_device = macbook_device if DebugFlags.set_debug_output_device else "Default"

	_cache_audio_resources(music_resources_folder, sound_cache)
	_cache_audio_resources(sfx_resources_folder, sound_cache)

	var pool_trim_timer: Timer = TimerHelpers.create_repeating_autostart_timer(self, 15.0, _trim_pools)
	pool_trim_timer.name = "PoolingTrimDaemon"

	DebugConsole.add_command("sound", _play_sound_globally_by_id)
	DebugConsole.add_command("stop_sound", stop_sound_id)
	DebugConsole.add_command("sound_volume", change_volume_by_sound_name)

## Stores a key-value pair in the appropriate cache dict using the id specified in the sound resource as the key.
## Given a key, the cache created by this method will return a file path to the specified audio id.
func _cache_audio_resources(folder_path: String, cache: Dictionary[StringName, AudioResource]) -> void:
	var folder: DirAccess = DirAccess.open(folder_path)
	folder.list_dir_begin()

	var file_name: String = folder.get_next()
	while file_name != "":
		if not folder.current_is_dir() and file_name.ends_with(".tres"):
			var resource_path: String = folder_path + "/" + file_name
			var resource: AudioResource = load(resource_path)

			if resource.sound_files_folder == "":
				push_error(resource.id + " audio resource does not have a sound files folder specified.")
				file_name = folder.get_next()
				continue

			var sound_files_folder: DirAccess = DirAccess.open(resource.sound_files_folder)
			sound_files_folder.list_dir_begin()
			var sound_path: String = sound_files_folder.get_next()
			while sound_path != "":
				if not sound_files_folder.current_is_dir():
					if sound_path.ends_with(".mp3") or sound_path.ends_with(".wav") or sound_path.ends_with(".ogg"):
						resource.sound_file_paths.append(resource.sound_files_folder + "/" + sound_path)
				sound_path = sound_files_folder.get_next()
			sound_files_folder.list_dir_end()

			if resource and resource is AudioResource:
				var audio_resource: AudioResource = resource as AudioResource
				cache[audio_resource.id] = audio_resource

		file_name = folder.get_next()
	folder.list_dir_end()

## Registers a scene as using a certain audio resource, ensuring that its streams are preloaded.
func register_scene_audio_resource_use(sound_id: StringName) -> void:
	if scene_ref_counts.has(sound_id):
		scene_ref_counts[sound_id] += 1
	else:
		var audio_resource: AudioResource = sound_cache.get(sound_id, null)
		if audio_resource:
			scene_ref_counts[sound_id] = 1
			if audio_resource.preloaded_streams.is_empty():
				for file_path: String in audio_resource.sound_file_paths:
					var stream: AudioStream = load(file_path)
					if stream:
						audio_resource.preloaded_streams.append(stream)

				if DebugFlags.sound_preload_changes:
					print_rich("[color=Seagreen]PRELOADED AUDIO RESOURCE STREAMS[/color]: \"[b]" + sound_id + "[/b]\"")
		else:
			push_error("\"" + sound_id + "\" was trying to register as a sound resource but does not exist in the cache.")

	if DebugFlags.sound_refcount_changes:
		_debug_print_single_ref_count(sound_id)

## Unregisters a scene as using a certain audio resource, removing the streams from memory if the reference count
## is at 0.
func unregister_scene_audio_resource_use(sound_id: StringName) -> void:
	if not scene_ref_counts.has(sound_id):
		return

	scene_ref_counts[sound_id] -= 1
	if scene_ref_counts[sound_id] <= 0:
		scene_ref_counts.erase(sound_id)
		var audio_resource: AudioResource = sound_cache.get(sound_id, null)
		if audio_resource:
			audio_resource.preloaded_streams.clear()

			if DebugFlags.sound_preload_changes:
				print_rich("[color=Firebrick]UNLOADED AUDIO RESOURCE STREAMS[/color]: \"[b]" + sound_id + "[/b]\"")
		else:
			push_error("\"" + sound_id + "\" was trying to UNregister as a sound resource but does not exist in the cache. This should never happen.")

	if DebugFlags.sound_refcount_changes:
		_debug_print_single_ref_count(sound_id)

## Attempts to retrive an AudioStreamPlayer or AudioStreamPlayer2D from the list of active nodes.
## If there is no active stream under the given id, the function returns null.
func _get_active_audio_players_by_sound_name(sound_id: StringName) -> Array:
	return get_tree().get_nodes_in_group(sound_id)
#endregion

#region Pooling
## Gets a 2d audio player from the pool or creates one if they are all busy.
func _get_or_create_2d_player() -> AudioStreamPlayer2D:
	if spatial_pool.size() > 0: return spatial_pool.pop_front()
	else:
		var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		player.tree_exiting.connect(_open_audio_resource_spot.bind(player, false))
		return player

## Gets a global audio player from the pool or creates one if they are all busy.
func _get_or_create_global_player() -> AudioStreamPlayer:
	if global_pool.size() > 0: return global_pool.pop_front()
	else:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.tree_exiting.connect(_open_audio_resource_spot.bind(player, false))
		return player

## Puts an audio player back in the pool and removes it from the tree.
func _return_player_to_pool(audio_player: Variant) -> void:
	audio_player.get_parent().remove_child(audio_player)

	if audio_player is AudioStreamPlayer2D:
		spatial_pool.append(audio_player)
	elif audio_player is AudioStreamPlayer:
		global_pool.append(audio_player)

## Trims the amount of audio players kept waiting around in the pool when there get to be too many not being used.
func _trim_pools() -> void:
	while spatial_pool.size() > MAX_SPATIAL_POOL_SIZE:
		var player: AudioStreamPlayer2D = spatial_pool.pop_back()
		player.queue_free()
	while global_pool.size() > MAX_GLOBAL_POOL_SIZE:
		var player: AudioStreamPlayer = global_pool.pop_back()
		player.queue_free()
#endregion

#region Starting Sounds
## Plays a sound in 2D at a given location. The sound can optionally be faded in and parented to any node.
## The resulting audio player is returned if successful.
func play_2d(sound_id: StringName, location: Vector2 = Vector2.ZERO, fade_in_time: float = 0,
				parent_node: Node = self) -> Variant:
	if sound_id == "":
		return null
	var audio_player: Variant = _create_audio_player(sound_id, SoundSpace.SPATIAL, location, fade_in_time, parent_node)
	return audio_player

## Plays a sound globally (has no location, can be heard everywhere). The sound can optionally be faded in
## and parented to any node.
## The resulting audio player is returned if successful.
func play_global(sound_id: StringName, fade_in_time: float = 0, parent_node: Node = self) -> Variant:
	if sound_id == "":
		return null
	var audio_player: Variant = _create_audio_player(sound_id, SoundSpace.GLOBAL, Vector2.ZERO, fade_in_time, parent_node)
	return audio_player

## Pulls a sound resource from one of the caches and sends it to be setup if it exists.
func _create_audio_player(sound_id: StringName, space: SoundSpace, location: Vector2,
							fade_in_time: float, parent_node: Node) -> Variant:
	var is_2d: bool = space == SoundSpace.SPATIAL

	var audio_resource: AudioResource = sound_cache.get(sound_id, null)
	if audio_resource == null:
		push_error("Sound id: \"" + sound_id + "\" did not exist as a sound resource in the cache.")
		return null

	if is_2d and not _is_close_enough_to_play_2d(audio_resource, location):
		return null

	var audio_stream: AudioStream = _pick_stream_resource_from_audio_resource(audio_resource)
	if audio_stream == null:
		return null

	var audio_player: Variant = _create_or_restart_audio_player_from_resource(audio_resource, is_2d, location)
	if audio_player:
		audio_player.stream = audio_stream
	else:
		return null

	_add_audio_player_to_tree_at_node(audio_player, parent_node)
	_start_audio_player_in_tree(audio_player, audio_resource.volume, fade_in_time)
	return audio_player

## Applies the settings from the audio resource to the audio player and returns it if it isn't null.
func _create_or_restart_audio_player_from_resource(audio_resource: AudioResource, is_2d: bool,
													location: Vector2) -> Variant:
	if (not audio_resource.has_available_stream()) and (not audio_resource.restart_if_at_limit):
		return null
	else:
		if (not audio_resource.has_available_stream()) and (audio_resource.restart_if_at_limit):
			_stop_sound_by_name_due_to_limit(audio_resource.id)

		audio_resource.increment_current_count()

		var audio_player: Variant
		if is_2d:
			audio_player = _get_or_create_2d_player()
			audio_player.name = "2D" + audio_resource.id + "@" + str(audio_resource.instantiation_id)
			audio_player.position = location
			audio_player.attenuation = audio_resource.attentuation_falloff
			audio_player.max_distance = audio_resource.max_distance
		else:
			audio_player = _get_or_create_global_player()
			audio_player.name = "GLOBAL" + audio_resource.id + "@" + str(audio_resource.instantiation_id)

		if audio_resource.category == AudioResource.Category.MUSIC:
			audio_player.bus = "Music"
		else:
			audio_player.bus = "SFX"

		audio_player.add_to_group(str(audio_resource.id))
		audio_player.set_meta("sound_id", str(audio_resource.id))
		audio_player.set_meta("loops_completed", 0)

		audio_player.volume_db = audio_resource.volume
		audio_player.pitch_scale = audio_resource.pitch_scale
		audio_player.pitch_scale += randf_range(-audio_resource.pitch_randomness, audio_resource.pitch_randomness)

		audio_player.finished.connect(_on_player_finished_playing.bind(audio_player))
		var callable: Callable
		if audio_resource.should_loop:
			callable = Callable(self, "_on_looped_audio_player_end").bind(audio_player)
		else:
			callable = Callable(self, "_open_audio_resource_spot").bind(audio_player, true)
		audio_player.set_meta("finish_callables", [callable])

		return audio_player

## Adds an audio player to the tree as a child of the passed in node.
func _add_audio_player_to_tree_at_node(audio_player: Variant, parent_node: Node) -> void:
	parent_node.add_child(audio_player)

## Starts an audio player that is already in the tree, either by fade or immediately.
func _start_audio_player_in_tree(audio_player: Variant, volume: float, fade_in_time: float) -> void:
	if fade_in_time > 0:
		_start_audio_player_fade_in(audio_player, volume, fade_in_time)
	else:
		audio_player.play()
		if DebugFlags.sounds_starting:
			print_rich("\"[b]" + audio_player.get_meta("sound_id") + "[/b]\" sound is starting")

## Stops the first sound in the group belonging to the passed in sound id, fading if necessary.
func _stop_sound_by_name_due_to_limit(sound_id: StringName) -> void:
	var playing_sounds: Array = _get_active_audio_players_by_sound_name(sound_id)
	if playing_sounds[0]:
		stop_audio_player(playing_sounds[0])

## Picks a random sound from the array of preloaded resources if they exist, falling back to simply loading a
## random stream on the spot if not.
func _pick_stream_resource_from_audio_resource(audio_resource: AudioResource) -> AudioStream:
	if audio_resource.preloaded_streams.size() > 0:
		return audio_resource.preloaded_streams[randi_range(0, audio_resource.preloaded_streams.size() - 1)]
	else:
		#push_warning("\"" + audio_resource.id + "\" did not have its streams preloaded when it was requested.")
		var sound_file: String = audio_resource.sound_file_paths[randi_range(0, audio_resource.sound_file_paths.size() - 1)]
		return load(sound_file)

## Checks if a 2d sound is close enough to the player to start playing in an effort to save off screen resources.
func _is_close_enough_to_play_2d(audio_resource: AudioResource, location: Vector2) -> bool:
	var distance_to_player: float = Globals.player_node.global_position.distance_to(location)
	if distance_to_player > (audio_resource.max_distance + DISTANCE_FROM_PLAYER_BUFFER):
		return false
	else:
		return true

## Handles fading in the audio player up to the originally specified volume over the specified duration.
func _start_audio_player_fade_in(audio_player: Variant, final_volume: float, fade_in_time: float) -> void:
	var tween: Tween = create_tween().bind_node(audio_player)
	audio_player.volume_db = -40.0
	audio_player.play()
	tween.tween_property(audio_player, "volume_db", final_volume, fade_in_time)

## Keeps a looped audio from stopping once it ends.
func _on_looped_audio_player_end(audio_player: Variant) -> void:
	var loops_completed: int = audio_player.get_meta("loops_completed", 0)
	loops_completed += 1
	audio_player.set_meta("loops_completed", loops_completed)

	audio_player.play()
#endregion

#region Changing Active Sounds
## Changes the volume of all streams of an active sound by either adjusting it by an amount or setting
## it to that amount.
func change_volume_by_sound_name(sound_id: StringName, amount: float, set_to_amount: bool = false) -> void:
	var playing_sounds: Array = _get_active_audio_players_by_sound_name(sound_id)
	for sound: Variant in playing_sounds:
		if sound:
			if set_to_amount:
				sound.volume_db = clampf(amount, -40, 20)
			else:
				sound.volume_db = clampf(sound.volume_db + amount, -40, 20)
	if playing_sounds.is_empty():
		push_warning("There were no sounds with the ID \"" + sound_id + "\" playing when trying to change their volume.")

## Changes the pitch of all streams of an active sound by either adjusting it by an amount or setting
## it to that amount.
func change_pitch_by_sound_name(sound_id: StringName, amount: float, set_to_amount: bool = false) -> void:
	var playing_sounds: Array = _get_active_audio_players_by_sound_name(sound_id)
	for sound: Variant in playing_sounds:
		if sound:
			if set_to_amount:
				sound.pitch_scale = clampf(amount, 0, 4)
			else:
				sound.pitch_scale = clampf(sound.pitch_scale + amount, 0, 4)

## Sets the attenuation max distance for the sound.
func change_attenuation_distance_by_sound_name(sound_id: StringName, distance: int) -> void:
	var playing_sounds: Array = _get_active_audio_players_by_sound_name(sound_id)
	for sound: Variant in playing_sounds:
		if sound is AudioStreamPlayer2D:
			sound.max_distance = max(1, distance)

## Sets the attenuation falloff exponent for the sound.
func change_attenuation_exponent_by_sound_name(sound_id: StringName, exponent: float) -> void:
	var playing_sounds: Array = _get_active_audio_players_by_sound_name(sound_id)
	for sound: Variant in playing_sounds:
		if sound is AudioStreamPlayer2D:
			sound.attenuation = max(0, exponent)

## Changes the minimum interval between an audio ending and a spot opening up for when things like footsteps
##need to occur at different rhythms and not in bursts. Resets to default on game load.
func change_sfx_resource_rhythmic_delay(sound_id: StringName, new_delay: float) -> void:
	var audio_resource: AudioResource = sound_cache.get(sound_id, null)
	if audio_resource:
		audio_resource.rhythmic_delay = max(0, new_delay)
#endregion

#region Stopping Sounds
## Calls all needed callables after finishing playing.
## Each added callable with a lambda must check if the audio player is valid within it:
## [codeblock]
## var callable: Callable = Callable(func() -> void:
##     if is_instance_valid(player):
##         current_impact_sounds.erase(multishot_id)
## )
## var finish_callables: Variant = player.get_meta("finish_callables")
## finish_callables.append(callable)
## player.set_meta("finish_callables", finish_callables)
## [/codeblock]
func _on_player_finished_playing(audio_player: Variant) -> void:
	var loops_completed: int = audio_player.get_meta("loops_completed", 0)
	var finish_callables: Variant = audio_player.get_meta("finish_callables", [])

	for custom_callable: Callable in finish_callables:
		if custom_callable.is_valid():
			if loops_completed > 0 and custom_callable.get_method() != "_on_looped_audio_player_end":
				continue
			custom_callable.call()

## Stops all sounds of a sound id by default, or can stop a specific number if given a value besides 0.
func stop_sound_id(sound_id: StringName, fade_out_time: float = 0,
					number_of_instances_to_stop: int = 0, open_spots_during_fade: bool = false) -> void:
	_destroy_sounds_by_sound_name(sound_id, number_of_instances_to_stop, fade_out_time, open_spots_during_fade)

## Stops a single sound via stopping its audio player, optionally wide a fade out.
## This is called to stop a stored audio player after using play_and_get_sound.
func stop_audio_player(audio_player: Variant, fade_out_time: float = 0, open_spot_during_fade: bool = false) -> void:
	if fade_out_time > 0:
		_start_audio_player_fade_out(audio_player, fade_out_time, open_spot_during_fade)
	else:
		_open_audio_resource_spot(audio_player, true)

## Handles destroying a certain number of audio stream players for a sound id and optionally fading them out.
func _destroy_sounds_by_sound_name(sound_id: StringName, number_of_instances_to_stop: int,
					fade_out_time: float, open_spots_during_fade: bool) -> void:
	var playing_sounds: Array = _get_active_audio_players_by_sound_name(sound_id)
	if number_of_instances_to_stop != 0:
		var validated_number_to_stop: int = min(playing_sounds.size(), number_of_instances_to_stop)
		for i: int in range(validated_number_to_stop):
			if playing_sounds[i]:
				if fade_out_time > 0:
					_start_audio_player_fade_out(playing_sounds[i], fade_out_time, open_spots_during_fade)
				else:
					_open_audio_resource_spot(playing_sounds[i], true)
	else:
		for player: Variant in playing_sounds:
			if player:
				if fade_out_time > 0:
					_start_audio_player_fade_out(player, fade_out_time, open_spots_during_fade)
				else:
					_open_audio_resource_spot(player, true)

## Handles fading out the audio player and calling the proper deletion method once the fade out ends.
## If specified, it can choose to immediately tell the audio resource there is an open spot while fading instead of
## once the fade is over.
func _start_audio_player_fade_out(audio_player: Variant, fade_out_time: float, open_spots_during_fade: bool) -> void:
	var tween: Tween = create_tween()

	if open_spots_during_fade:
		_open_audio_resource_spot(audio_player, false)
		tween.finished.connect(func() -> void: _return_audio_player(audio_player))
	else:
		tween.finished.connect(func() -> void: _open_audio_resource_spot(audio_player, true))

	tween.tween_property(audio_player, "volume_db", -40.0, fade_out_time)

## Tell the audio resource that we can open up a spot by decrementing the current count of the sound playing.
## Also removes it from its group.
func _open_audio_resource_spot(audio_player: Variant, return_player_to_pool: bool) -> void:
	var sound_id: String = audio_player.get_meta("sound_id", "")
	if sound_id == "": # When audio players are freed before ending, they always call this method, but they may not have been set up with a sound yet, so this checks for that
		return

	_remove_meta_from_audio_player(audio_player)
	audio_player.remove_from_group(sound_id)

	var audio_resource: AudioResource = sound_cache.get(sound_id, null)
	if audio_resource:
		if audio_resource.rhythmic_delay > 0:
			get_tree().create_timer(audio_resource.rhythmic_delay, false, false, true).timeout.connect(func() -> void: audio_resource.decrement_current_count())
		else:
			audio_resource.decrement_current_count()

	if return_player_to_pool:
		_return_audio_player(audio_player)

## Removes the callable and sound id meta from the audio player.
func _remove_meta_from_audio_player(audio_player: Variant) -> void:
	audio_player.set_meta("finish_callables", [])
	audio_player.finished.disconnect(_on_player_finished_playing)
	audio_player.set_meta("sound_id", null)
	audio_player.set_meta("loops_completed", null)

## Returns the audio stream player to its pool after.
func _return_audio_player(audio_player: Variant) -> void:
	audio_player.stop()
	_return_player_to_pool(audio_player)
#endregion

#region Debug
## Prints all sounds' current refcounts according to the manual refcount dict and how many preloaded streams they have.
func _debug_print_all_ref_counts() -> void:
	for key: StringName in scene_ref_counts.keys():
		var audio_resource: AudioResource = sound_cache.get(key, null)
		var preloaded_count: int = audio_resource.preloaded_streams.size() if audio_resource != null else 0
		print("Resource: ", key, " | RefCount: ", scene_ref_counts[key], " | Preloaded Streams: ", preloaded_count)

## Prints a single sound's refcounts and preloaded streams.
func _debug_print_single_ref_count(sound_id: StringName) -> void:
	if sound_cache.has(sound_id):
		var audio_resource: AudioResource = sound_cache.get(sound_id, null)
		var preloaded_count: int = audio_resource.preloaded_streams.size() if audio_resource != null else 0
		var ref_count: int = scene_ref_counts.get(sound_id, 0)
		print("Resource: ", sound_id, " | RefCount: ", ref_count, " | Preloaded Streams: ", preloaded_count)

## Plays a sound globally given its sound id. Passing any volume other than 0 will override the default sound volume.
func _play_sound_globally_by_id(sound_id: StringName, volume: float = 0) -> void:
	var player: AudioStreamPlayer = play_global(sound_id)
	if player == null:
		printerr("The requested sound \"" + sound_id + "\" failed to play because it does not exist.")
		return
	if volume != 0:
		player.volume_db = volume
#endregion
