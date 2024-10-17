@icon("res://Utilities/Debug/EditorIcons/audio_manager.svg")
extends Node2D
## A global singleton that caches the location of all audio resources.
##
## Interface with this singleton to play any music or sound effect, optionally providing a location to make it 2d.

@export_dir var music_resources_folder: String ## The folder holding all .tres music files.
@export_dir var sfx_resources_folder: String ## The folder holding all .tres sfx files.
enum SoundCategory { MUSIC, SFX } ## A specifier for determining music vs sfx.
enum SoundSpace { GLOBAL, SPATIAL } ## A specifier for determining global vs spatial (2d) audio.
enum SoundType { MUSIC_GLOBAL, MUSIC_2D, SFX_GLOBAL, SFX_2D } ## Combines the two settings into one for simplicity.

var sfx_cache: Dictionary = {} ## The dict of the file paths to all sfx resources, using the sfx name as the key.
var music_cache: Dictionary = {} ## The dict of the file paths to all music resources, using the music name as the key.

func _ready() -> void:
	if OS.get_unique_id() == "W1RHWL2KQ6": # needed to make audio work on Noah's computer, only affects him
		AudioServer.output_device = "MacBook Pro Speakers (105)" if DebugFlags.AudioFlags.set_debug_output_device else "Default"
	
	cache_sound_resources(music_resources_folder, music_cache)
	cache_sound_resources(sfx_resources_folder, sfx_cache)

## Stores a key-value pair in the appropriate cache dict using the name specified in the sound resource as the key.
## Given a key, the cache created by this method will return a file path to the specified audio name. 
func cache_sound_resources(folder_path: String, cache: Dictionary) -> void:
	var folder = DirAccess.open(folder_path)
	folder.list_dir_begin()
	
	var file_name = folder.get_next()
	while file_name != "":
		if not folder.current_is_dir() and file_name.ends_with(".tres"):
			var resource_path = folder_path + "/" + file_name
			var resource = load(resource_path)
			if resource and resource is AudioResource:
				var sound_resource = resource as AudioResource
				cache[sound_resource.name] = sound_resource
		
		file_name = folder.get_next()
	folder.list_dir_end()

## Pulls a sound from one of the audio caches and creates it directionally if 2d is specified. 
func create_sound(sound_name: String, type: SoundType, location: Vector2 = Vector2.ZERO) -> void:
	var sound_resource: AudioResource
	var is_2d: bool = false
	var is_music: bool = false
	
	match type:
		SoundType.MUSIC_GLOBAL:
			sound_resource = music_cache.get(sound_name, null)
			is_music = true
		SoundType.MUSIC_2D:
			sound_resource = music_cache.get(sound_name, null)
			is_music = true
			is_2d = true
		SoundType.SFX_GLOBAL:
			sound_resource = sfx_cache.get(sound_name, null)
		SoundType.SFX_2D:
			sound_resource = sfx_cache.get(sound_name, null)
			is_2d = true
	
	if sound_resource:
		var audio_stream = load(sound_resource.sound_file_path)
		if audio_stream and audio_stream is AudioStream:
			if sound_resource.has_available_stream():
				sound_resource.change_current_count(1)
				var audio_player
				
				if is_2d:
					audio_player = AudioStreamPlayer2D.new()
					audio_player.name = "2D" + sound_resource.name + "#" + str(sound_resource.current_count)
					audio_player.position = location
					audio_player.attenuation = sound_resource.attentuation_falloff
					audio_player.max_distance = sound_resource.max_distance
				else:
					audio_player = AudioStreamPlayer.new()
					audio_player.name = "GLOBAL" + sound_resource.name + "#" + str(sound_resource.current_count)
				
				if is_music:
					audio_player.bus = "Music"
				else:
					audio_player.bus = "SFX"
				
				add_child(audio_player)
				audio_player.add_to_group(sound_resource.name)
				
				audio_player.stream = audio_stream
				audio_player.volume_db = sound_resource.volume
				audio_player.pitch_scale = sound_resource.pitch_scale
				audio_player.pitch_scale += randf_range(-sound_resource.pitch_randomness, sound_resource.pitch_randomness)
				
				if sound_resource.should_loop:
					audio_player.finished.connect(func(): _on_looped_audio_end(audio_player))
				else:
					audio_player.finished.connect(sound_resource.on_audio_finished)
					audio_player.finished.connect(func(): _on_audio_player_finished(audio_player, sound_resource.name))
				
				audio_player.play()
			elif sound_resource.restart_if_at_limit:
				var playing_sounds: Array = get_playing_sounds(sound_name)
				if playing_sounds[0]:
					playing_sounds[0].stop()
					playing_sounds[0].play()

## Attempts to retrive an AudioStreamPlayer or AudioStreamPlayer2D from the list of active nodes.
## If there is no active stream under the given name, the function returns null.
func get_playing_sounds(sound_name: String) -> Array:
	return get_tree().get_nodes_in_group(sound_name)

## Changes the volume of all streams of an active sound by either adjusting it by an amount or setting 
## it to that amount.
func change_volume(sound_name: String, amount: float, set_to_amount: bool = false) -> void:
	var playing_sounds = get_playing_sounds(sound_name)
	for sound in playing_sounds:
		if sound: # to eliminate data race conditions
			if set_to_amount:
				sound.volume_db = clampf(amount, -40, 20)
			else:
				sound.volume_db = clampf(sound.volume_db + amount, -40, 20)

## Changes the pitch of all streams of an active sound by either adjusting it by an amount or setting 
## it to that amount.
func change_pitch(sound_name: String, amount: float, set_to_amount: bool = false) -> void:
	var playing_sounds = get_playing_sounds(sound_name)
	for sound in playing_sounds:
		if sound: # to eliminate data race conditions
			if set_to_amount:
				sound.pitch_scale = clampf(amount, 0, 4)
			else:
				sound.pitch_scale = clampf(sound.pitch_scale + amount, 0, 4)

## Sets the attenuation max distance for the sound.
func change_attenuation_distance(sound_name: String, distance: int) -> void:
	var playing_sounds = get_playing_sounds(sound_name)
	for sound in playing_sounds:
		if sound is AudioStreamPlayer2D:
			sound.max_distance = max(1, distance)

## Sets the attenuation falloff exponent for the sound.
func change_attenuation_exponent(sound_name: String, exponent: float) -> void:
	var playing_sounds = get_playing_sounds(sound_name)
	for sound in playing_sounds:
		if sound is AudioStreamPlayer2D:
			sound.attenuation = max(0, exponent)

## Stops all sounds of a sound_name by default, or can stop a specific number if given a value besides 0.
func stop_sounds(sound_name: String, number_of_instances_to_stop: int = 0) -> void:
	var playing_sounds = get_playing_sounds(sound_name)
	if number_of_instances_to_stop != 0:
		var validated_number_to_stop: int = min(playing_sounds.size(), number_of_instances_to_stop)
		for i in range(validated_number_to_stop):
			if playing_sounds[i]: # to eliminate data race conditions
				playing_sounds[i].stop()
				delete_audio_stream(playing_sounds[i], sound_name)
	else:
		for sound in playing_sounds:
			if sound: # to eliminate data race conditions
				sound.stop()
				delete_audio_stream(sound, sound_name)

## Deletes the stream player from the tree after removing it from its group.
func delete_audio_stream(audio_player, sound_name: String) -> void:
	var sound_resource: AudioResource
	if audio_player.bus == "Music":
		sound_resource = music_cache.get(sound_name, null)
	if audio_player.bus == "SFX":
		sound_resource = sfx_cache.get(sound_name, null)
	if sound_resource:
		sound_resource.change_current_count(-1)
	
	audio_player.remove_from_group(sound_name)
	audio_player.queue_free()

func _on_looped_audio_end(audio_player) -> void:
	audio_player.play()

func _on_audio_player_finished(audio_player, sound_name: String) -> void:
	delete_audio_stream(audio_player, sound_name)
