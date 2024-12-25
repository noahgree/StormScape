extends SaveData
class_name StaticEntityData

# StaticEntity Core
@export var position: Vector2
@export var sprite_frames_path: String
@export var sprite_texture_path: String

# Stats
@export var stat_mods: Dictionary[StringName, Dictionary]

# Effects
@export var current_effects: Dictionary[String, StatusEffect]
@export var saved_times_left: Dictionary[String, float]

# HealthComponent
@export var health: int
@export var shield: int
@export var armor: int

# DmgHandler
@export var saved_dots: Dictionary[String, Array]

# HealHandler
@export var saved_hots: Dictionary[String, Array]

# ItemReceiverComponent
@export var inv: Array[InvItemResource]
@export var pickup_range: int
