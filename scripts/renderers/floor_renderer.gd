# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only emit intents/requests and render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
class_name FloorRenderer
extends Node2D

@export var floor_color := Color(0.9, 0.9, 0.92)
@export var floor_texture: Texture2D = null
@export var margin_px: float = 0.0

var _size_px := Vector2.ZERO

func configure(grid_w: int, grid_h: int, cell_size: float) -> void:
	var w: float = maxf(0.0, float(grid_w) * cell_size)
	var h: float = maxf(0.0, float(grid_h) * cell_size)
	_size_px = Vector2(w, h)
	queue_redraw()

func _draw() -> void:
	if _size_px.x <= 0.0 or _size_px.y <= 0.0:
		return
	var margin: float = maxf(0.0, margin_px)
	var rect: Rect2 = Rect2(Vector2(-margin, -margin), _size_px + Vector2(margin * 2.0, margin * 2.0))
	if floor_texture != null:
		draw_texture_rect(floor_texture, rect, false)
	else:
		draw_rect(rect, floor_color, true)
