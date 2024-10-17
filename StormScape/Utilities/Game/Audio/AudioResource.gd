extends Resource
class_name AudioResource
## A resource for linking a sound file path with an associated volume, pitch settings, name, and max concurrent streams.

@export var name: String ## The main name of the sound.
@export_file("*.mp3", "*.wav", "*.ogg") var sound_file_path: String ## The file path to the sound. Restricted to mp3, wav, and ogg. Wav is highly recommended because of its efficiency.
@export_range(1, 10, 1) var concurrent_limit: int = 1 ## The max number of instances of this sound that can be played at the same time.
@export_range(-40, 20, 0.1, "suffix:db") var volume = 0 ## The default volume associated with this sound.
@export_range(0.0, 4.0, 0.01) var pitch_scale = 1.0 ## The default pitch scale to give this sound.
@export_range(0.0, 1.0, 0.01) var pitch_randomness = 0.0 ## The range that the randomness can apply to the pitch scale.
@export var restart_if_at_limit: bool = false ## If a current stream of this sound should restart when we request to play this audio but no streams are available. 
@export var should_loop: bool = false ## Whether the sound should loop until it is asked to stop.

@export_group("Spatial")
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var max_distance: int = 2000
@export_exp_easing("attenuation") var attentuation_falloff: float = 1.0

var current_count = 0 ## How many instances of this sound are currently being played.

## Changes the current number of instances value.
func change_current_count(amount: int) -> void:
	current_count = max(0, current_count + amount)

## Checks if the current number of instances is less than the allowed concurrent_limit.
func has_available_stream() -> bool:
	return current_count < concurrent_limit

## Called when the connected "finished" signal from the AudioStream created using this resource finishes playing.
func on_audio_finished() -> void:
	change_current_count(-1)
