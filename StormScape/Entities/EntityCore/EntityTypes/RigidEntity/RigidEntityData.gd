extends SaveData
class_name RigidEntityData

# RigidEntity Core
@export var position: Vector2
@export var sprite_frames_path: String
@export var sprite_texture_path: String

# Stats
@export var stat_mods: Dictionary

# Effects
@export var current_effects: Dictionary
@export var saved_times_left: Dictionary

# HealthComponent
@export var health: int
@export var shield: int
@export var armor: int

# DmgHandler
@export var saved_dots: Dictionary

# HealHandler
@export var saved_hots: Dictionary

# ItemReceiverComponent
@export var inv: Array[InvItemResource]
@export var pickup_range: int
