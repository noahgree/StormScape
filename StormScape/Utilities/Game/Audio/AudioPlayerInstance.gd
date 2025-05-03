extends RefCounted
class_name AudioPlayerInstance

var player: Variant
var id: String


func _init(stream_player: Variant, uid: String) -> void:
	player = stream_player
	id = uid
