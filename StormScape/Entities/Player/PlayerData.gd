extends SaveData
class_name PlayerData

# Player
@export var position: Vector2
@export var stat_mods: Dictionary
@export var velocity: Vector2
@export var snare_factor: float
@export var snare_time_left: float
# AnimatedSprite2D
@export var sprite_frames: String
# HealthComponent
@export var health: int
@export var shield: int
@export var armor: int
# StaminaComponent
@export var stamina: float
@export var can_use_stamina: bool
@export var stamina_to_hunger_count: float
@export var hunger_bars: int
@export var can_use_hunger_bars: bool
# EffectReceiverComponent/StatusEffectManager
@export var current_effects: Dictionary
@export var saved_times_left: Dictionary
# DmgHandler
@export var saved_dots: Dictionary
# HealHandler
@export var saved_hots: Dictionary
# MoveStateMachine
@export var anim_vector: Vector2
@export var knockback_vector: Vector2
