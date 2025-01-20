@tool
@icon("res://Utilities/Debug/EditorIcons/particle_emission_component.svg")
extends Node
class_name ParticleEmissionComponent
## Manages the positioning and extents of particle applications to this entity. Leave all extent vectors
## as (0, 0) to use default placement.

enum Boxes { BELOW, ABOVE, COVER } ## The types of areas that can be set and retrieved.

@export_group("Below")
@export var below_extents: Vector2: ## The extents of the emission area at the entity's feet.
	set(new_value):
		below_extents = new_value
		if below_box:
			if new_value == Vector2.ZERO: below_box.hide()
			else: below_box.show()
			_update_below_box()
@export var below_origin: Vector2: ## The origin of the emission area at the entity's feet.
	set(new_value):
		below_origin = new_value
		if below_box: _update_below_box()

@export_group("Above")
@export var above_extents: Vector2: ## The extents of the emission area above the entity.
	set(new_value):
		above_extents = new_value
		if above_box:
			if new_value == Vector2.ZERO: above_box.hide()
			else: above_box.show()
			_update_above_box()
@export var above_origin: Vector2: ## The origin of the emission area above the entity.
	set(new_value):
		above_origin = new_value
		if above_box: _update_above_box()

@export_group("Cover")
@export var cover_extents: Vector2: ## The extents of the emission area covering the entity.
	set(new_value):
		cover_extents = new_value
		if cover_box:
			if new_value == Vector2.ZERO: cover_box.hide()
			else: cover_box.show()
			_update_cover_box()
@export var cover_origin: Vector2: ## The origin of the emission area covering the entity.
	set(new_value):
		cover_origin = new_value
		if cover_box: _update_cover_box()

@onready var below_box: DebugBox = $BelowBox ## The debug box showing the area at the entity's feet.
@onready var above_box: DebugBox = $AboveBox ## The debug box showing the area above the entity.
@onready var cover_box: DebugBox = $CoverBox ## The debug box showing the area covering the entity.


func _ready() -> void:
	if Engine.is_editor_hint():
		if above_extents == Vector2.ZERO: above_box.hide()
		if below_extents == Vector2.ZERO: below_box.hide()
		if cover_extents == Vector2.ZERO: cover_box.hide()

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

## Gets the origin for the emission area.
func get_origin(box: Boxes) -> Vector2:
	var sprite_rect: Vector2 = SpriteHelpers.SpriteDetails.get_frame_rect(owner.sprite, true)
	match box:
		Boxes.BELOW:
			if below_extents == Vector2.ZERO:
				return Vector2(0, -1)
			return below_origin
		Boxes.ABOVE:
			if above_extents == Vector2.ZERO:
				return Vector2(0, -sprite_rect.y + 4)
			return above_origin
		Boxes.COVER:
			if cover_extents == Vector2.ZERO:
				return Vector2(0, -sprite_rect.y / 2.0)
			return cover_origin
		_:
			return Vector2.ZERO

## Gets the extents for the emission area.
func get_extents(box: Boxes) -> Vector2:
	var sprite_rect: Vector2 = SpriteHelpers.SpriteDetails.get_frame_rect(owner.sprite, true)
	match box:
		Boxes.BELOW:
			if below_extents == Vector2.ZERO:
				return Vector2(sprite_rect.x / 2.25, 1)
			return below_extents
		Boxes.ABOVE:
			if above_extents == Vector2.ZERO:
				return Vector2(sprite_rect.x / 2.25, 3)
			return above_extents
		Boxes.COVER:
			if cover_extents == Vector2.ZERO:
				return Vector2(sprite_rect.x / 2.25, sprite_rect.y / 2.25)
			return cover_origin
		_:
			return Vector2.ZERO
