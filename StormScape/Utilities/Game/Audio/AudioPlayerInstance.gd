extends RefCounted
class_name AudioPlayerInstance
## A simple type to hold a reference to an audio player and an id that goes along with it.
##
## Useful to see if that player has been repurposed, since it's local name (which is used as its id) may change
## but the id tracked here in this object will not.

var player: Variant ## The pooled player to reference.
var id: String ## The id set on creation.


func _init(stream_player: Variant, uid: String) -> void:
	player = stream_player
	id = uid
