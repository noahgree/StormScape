extends Resource
class_name AudioResource
## A resource for linking a sound file path with an associated volume, pitch settings, name, and max concurrent streams.

enum Category { SFX, MUSIC } ## The kinds of sounds these resources can define.

@export var id: StringName ## The main id of the sound. [b]Must be unique.[/b]
@export var category: Category = Category.SFX ## What kind of sound this resource defines.
@export_dir var sound_files_folder: String ## The folder containing all the sound files that can be played for this resource.
@export_file("*.mp3", "*.wav", "*.ogg") var sound_file_paths: Array[String] ## The file paths to the sound variations. Restricted to mp3, wav, and ogg. Wav is highly recommended because of its efficiency. This array gets filled with everything in the "sound_files_folder" at game load as well.
@export_range(1, 25, 1) var concurrent_limit: int = 20 ## The max number of instances of this sound that can be played at the same time.
@export var rhythmic_delay: float ## The time after a sound ends that should pass before decrementing the current count. Used for when short sounds must be played rythmically even when being triggered quickly and at random.
@export_range(-40, 20, 0.1, "suffix:db") var volume: float ## The default volume associated with this sound.
@export_range(0.0, 4.0, 0.01) var pitch_scale: float = 1.0 ## The default pitch scale to give this sound.
@export_range(0.0, 1.0, 0.001) var pitch_randomness: float ## The range that the randomness can apply to the pitch scale.
@export var restart_if_at_limit: bool = false ## If a current stream of this sound should restart when we request to play this audio but no streams are available.
@export var should_loop: bool = false ## Whether the sound should loop until it is asked to stop.

@export_group("Spatial")
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var max_distance: int = 500 ## The max number of pixels away that the audio can be heard.
@export_exp_easing("attenuation") var attentuation_falloff: float = 1.0 ## The exponent that attenuates the volume as the distance grows towards the max_distance.

var current_count: int = 0 ## How many instances of this sound are currently being played.
var instantiation_id: int = 0 ## Incremented when audio stream players using this sound are instantiated to keep names unique
var preloaded_streams: Array[AudioStream] = [] ## A reference to the preloaded streams this resource uses. Gets cleared out when no scene needs this resource anymore.

## Changes the current number of instances value.
func increment_current_count() -> void:
	instantiation_id += 1
	current_count += 1

## Called when the connected "finished" signal from the AudioStream created using this resource finishes playing.
func decrement_current_count() -> void:
	current_count -= 1

## Checks if the current number of instances is less than the allowed concurrent_limit.
func has_available_stream() -> bool:
	return current_count < concurrent_limit
