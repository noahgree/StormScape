@tool
@icon("res://Utilities/Debug/EditorIcons/particle_emission_component.svg")
extends Node2D
class_name ParticleEmissionComponent
## Manages the positioning and extents of particle applications to this entity. Leave all extent vectors
## as (0, 0) to use default placement.
##
## Does not handle time tracking for particle node children, only their existence.

enum Area { BELOW, ABOVE, COVER } ## The types of areas that can be set and retrieved.

@export var show_debug_boxes: bool = false: ## When not using default placements, show the modified debug boxes.
	set(new_value):
		show_debug_boxes = new_value
		_update_all_boxes()

@export_group("Below")
@export var below_extents: Vector2: ## The extents of the emission area at the entity's feet.
	set(new_value):
		below_extents = new_value
		_update_below_box()
@export var below_origin: Vector2: ## The origin of the emission area at the entity's feet.
	set(new_value):
		below_origin = new_value
		_update_below_box()

@export_group("Above")
@export var above_extents: Vector2: ## The extents of the emission area above the entity.
	set(new_value):
		above_extents = new_value
		_update_above_box()
@export var above_origin: Vector2: ## The origin of the emission area above the entity.
	set(new_value):
		above_origin = new_value
		_update_above_box()

@export_group("Cover")
@export var cover_extents: Vector2: ## The extents of the emission area covering the entity.
	set(new_value):
		cover_extents = new_value
		_update_cover_box()
@export var cover_origin: Vector2: ## The origin of the emission area covering the entity.
	set(new_value):
		cover_origin = new_value
		_update_cover_box()

@onready var below_box: DebugBox = $BelowBox ## The debug box showing the area at the entity's feet.
@onready var above_box: DebugBox = $AboveBox ## The debug box showing the area above the entity.
@onready var cover_box: DebugBox = $CoverBox ## The debug box showing the area covering the entity.

var active_nodes: Dictionary[Condition.ID, ParticleEffect] ## A mapping of active particle node children based on their condition id.


## Gets the origin for the emission area.
func _get_origin(area: Area) -> Vector2:
	var sprite_rect: Vector2 = SpriteHelpers.SpriteDetails.get_frame_rect(owner.sprite, true)
	match area:
		Area.BELOW:
			if below_extents == Vector2.ZERO:
				return Vector2(0, -1)
			return below_origin
		Area.ABOVE:
			if above_extents == Vector2.ZERO:
				return Vector2(0, -sprite_rect.y + 4)
			return above_origin
		Area.COVER:
			if cover_extents == Vector2.ZERO:
				return Vector2(0, -sprite_rect.y / 2.0)
			return cover_origin
		_:
			return Vector2.ZERO

## Gets the extents for the emission area.
func _get_extents(area: Area) -> Vector2:
	var sprite_rect: Vector2 = SpriteHelpers.SpriteDetails.get_frame_rect(owner.sprite, true)
	match area:
		Area.BELOW:
			if below_extents == Vector2.ZERO:
				return Vector2(sprite_rect.x / 3.2, 1)
			return below_extents
		Area.ABOVE:
			if above_extents == Vector2.ZERO:
				return Vector2(sprite_rect.x / 3.2, 3)
			return above_extents
		Area.COVER:
			if cover_extents == Vector2.ZERO:
				return Vector2(sprite_rect.x / 3.2, sprite_rect.y / 3.2)
			return cover_origin
		_:
			return Vector2.ZERO

## Starts the particles by instantiating a new packed version, setting it up with position and extents.
func start_particles(condition_id: Condition.ID) -> void:
	var existing_node: ParticleEffect = active_nodes.get(condition_id, null)
	if existing_node:
		var emission_area: Area = existing_node.emission_area
		active_nodes[condition_id].start(_get_origin(emission_area), _get_extents(emission_area))
		return
	var packed_scene: PackedScene = FXLibrary.get_condition_fx(condition_id)
	if packed_scene == null:
		return

	var particle_node: ParticleEffect = packed_scene.instantiate()
	add_child(particle_node)
	active_nodes[condition_id] = particle_node

	particle_node.fade_out_complete.connect(_remove_active_node)
	var area: Area = particle_node.emission_area
	particle_node.start(_get_origin(area), _get_extents(area))

## Tells the node that matches the conditon ID to stop itself, allowing fade out time if necessary.
func stop_particles(condition_id: Condition.ID) -> void:
	var node_to_stop: ParticleEffect = active_nodes.get(condition_id, null)
	if node_to_stop == null:
		return
	node_to_stop.stop()

## Removes the node from the active nodes tracker and frees it.
func _remove_active_node(node: ParticleEffect, condition_id: Condition.ID) -> void:
	active_nodes.erase(condition_id)
	node.queue_free()

#region DEBUG
## Updates all boxes if they can be updated.
func _update_all_boxes() -> void:
	_update_below_box()
	_update_above_box()
	_update_cover_box()

## Updates the below box with the new values when in the editor.
func _update_below_box() -> void:
	if below_box and Engine.is_editor_hint():
		below_box.update_debug_box_with_extents(below_origin, below_extents)

## Updates the above box with the new values when in the editor.
func _update_above_box() -> void:
	if above_box and Engine.is_editor_hint():
		above_box.update_debug_box_with_extents(above_origin, above_extents)

## Updates the cover box with the new values when in the editor.
func _update_cover_box() -> void:
	if cover_box and Engine.is_editor_hint():
		cover_box.update_debug_box_with_extents(cover_origin, cover_extents)
#endregion
