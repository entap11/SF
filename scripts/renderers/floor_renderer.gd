# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only emit intents/requests and render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
class_name FloorRenderer
extends Node2D

@export var floor_color: Color = Color(0.9, 0.9, 0.92)
@export var floor_texture: Texture2D = null
@export var overlay_texture: Texture2D = null
@export var margin_px: float = 0.0
@export var origin_px: Vector2 = Vector2.ZERO

var _size_px: Vector2 = Vector2.ZERO
@onready var _base_floor: Sprite2D = $BaseFloor
@onready var _overlay_floor: Sprite2D = $FloorOverlay

func configure(grid_w: int, grid_h: int, cell_size: float, origin: Vector2 = Vector2.ZERO) -> void:
	var w: float = maxf(0.0, float(grid_w) * cell_size)
	var h: float = maxf(0.0, float(grid_h) * cell_size)
	_size_px = Vector2(w, h)
	origin_px = origin
	_apply_floor_layout()
	queue_redraw()

func get_floor_bounds_rect() -> Rect2:
	return Rect2(origin_px, _size_px)

func get_base_floor_sprite() -> Sprite2D:
	if _base_floor != null and is_instance_valid(_base_floor):
		return _base_floor
	return null

func get_overlay_floor_sprite() -> Sprite2D:
	if _overlay_floor != null and is_instance_valid(_overlay_floor):
		return _overlay_floor
	return null

func _draw() -> void:
	if _ensure_floor_sprites():
		return
	if _size_px.x <= 0.0 or _size_px.y <= 0.0:
		return
	var margin: float = maxf(0.0, margin_px)
	var rect: Rect2 = Rect2(origin_px - Vector2(margin, margin), _size_px + Vector2(margin * 2.0, margin * 2.0))
	if floor_texture != null:
		draw_texture_rect(floor_texture, rect, false)
	else:
		draw_rect(rect, floor_color, true)

func _ready() -> void:
	_apply_floor_layout()

func _ensure_floor_sprites() -> bool:
	var base_ok := _base_floor != null and is_instance_valid(_base_floor)
	var overlay_ok := _overlay_floor != null and is_instance_valid(_overlay_floor)
	if not base_ok or not overlay_ok:
		return false
	if floor_texture == null and overlay_texture == null:
		return false
	_base_floor.texture = floor_texture
	_overlay_floor.texture = overlay_texture
	_base_floor.visible = floor_texture != null
	_overlay_floor.visible = overlay_texture != null
	_apply_floor_layout()
	return true

func _apply_floor_layout() -> void:
	if _size_px.x <= 0.0 or _size_px.y <= 0.0:
		return
	var base_ok := _base_floor != null and is_instance_valid(_base_floor)
	var overlay_ok := _overlay_floor != null and is_instance_valid(_overlay_floor)
	if not base_ok or not overlay_ok:
		return
	var margin: float = maxf(0.0, margin_px)
	var size: Vector2 = _size_px + Vector2(margin * 2.0, margin * 2.0)
	var center: Vector2 = origin_px + Vector2(_size_px.x * 0.5, _size_px.y * 0.5)
	_base_floor.position = center
	_overlay_floor.position = center
	if floor_texture != null:
		var tex_size: Vector2 = Vector2(float(floor_texture.get_width()), float(floor_texture.get_height()))
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			_base_floor.scale = Vector2(size.x / tex_size.x, size.y / tex_size.y)
	if overlay_texture != null:
		var overlay_size: Vector2 = Vector2(float(overlay_texture.get_width()), float(overlay_texture.get_height()))
		if overlay_size.x > 0.0 and overlay_size.y > 0.0:
			_overlay_floor.scale = Vector2(size.x / overlay_size.x, size.y / overlay_size.y)
