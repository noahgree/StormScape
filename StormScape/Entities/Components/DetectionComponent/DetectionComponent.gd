@tool
@icon("res://Utilities/Debug/EditorIcons/detection_component.svg")
extends Area2D
class_name DetectionComponent
## This component handles the detection radius for an entity. Any enemy that comes within this radius
## will be alerted of the presence of this entity.
##
## This component goes on the entity being detected so that it can work with the stealth factor system
## to scale up and down. Note that the effect receiver of the entity detecting this component is what
## determines the collision shape for what interacts with this zone.

signal enemies_in_range_changed(enemies_in_range: Array[PhysicsBody2D]) ## Emitted when the enemies in range array is altered.

@export_custom(PROPERTY_HINT_NONE, "suffix:pixels") var radius: float = 150: ## The detection radius.
	set(new_value):
		radius = new_value
		if collider: collider.shape.radius = radius
@export var show_debug_radius: bool = false: ## Whether to show the debug radius in editor.
	set(new_value):
		show_debug_radius = new_value
		if collider: collider.visible = show_debug_radius

@onready var collider: CollisionShape2D = $CollisionShape2D ## The collision shape for this detection component.

var entity: PhysicsBody2D ## The ntity that this detection component belongs to.
var original_radius: float = radius ## The original radius used to readjust the calculations after stealth.
var current_stealth: int = 0 ## The extra percentage of closeness this entity can achieve to an enemy before being detected.
var enemies_in_range: Array[PhysicsBody2D] = [] ## The enemies that we can see due to being inside the detection component radius of each of them. Array updated by detection components of those other entities.


func _ready() -> void:
	collider.shape.radius = radius
	collider.visible = show_debug_radius
	if Engine.is_editor_hint():
		return

	entity = get_parent()

	collision_layer = 0
	if entity.team == GlobalData.Teams.PLAYER:
		collision_mask = 0b100 # Enemy mask
	elif entity.team == GlobalData.Teams.ENEMY:
		collision_mask = 0b11 # Player & Player Ally mask

## Called to update the detection radius based on the new stealth.
func update_stealth(new_value: int) -> void:
	current_stealth = clampi(new_value, 0, 100)
	var stealth_percent: float = float(current_stealth) / 100.0
	radius = max(10, original_radius * (1 - stealth_percent))

func _on_area_entered(area: Area2D) -> void:
	if area is not EffectReceiverComponent:
		return
	area.affected_entity.detection_component.enemy_entered(entity)

func _on_area_exited(area: Area2D) -> void:
	if area is not EffectReceiverComponent:
		return
	area.affected_entity.detection_component.enemy_exited(entity)

func enemy_entered(body: PhysicsBody2D) -> void:
	enemies_in_range.append(body)
	body.tree_exiting.connect(_remove_from_enemies_in_range.bind(body))
	enemies_in_range_changed.emit(enemies_in_range)

func enemy_exited(body: PhysicsBody2D) -> void:
	_remove_from_enemies_in_range(body)
	body.tree_exiting.disconnect(_remove_from_enemies_in_range)

func _remove_from_enemies_in_range(body: PhysicsBody2D) -> void:
	enemies_in_range.erase(body)
	enemies_in_range_changed.emit(enemies_in_range)
