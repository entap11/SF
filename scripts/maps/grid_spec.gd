extends RefCounted

var grid_w: int
var grid_h: int
var cell_size: float
var origin: Vector2
var center_offset: float = 0.5

func configure(w: int, h: int, cell_px: float, origin_px: Vector2, center_offset_in: float = 0.5) -> void:
	grid_w = w
	grid_h = h
	cell_size = cell_px
	origin = origin_px
	center_offset = center_offset_in

func grid_to_world(cell: Vector2i) -> Vector2:
	return origin + Vector2(
		(float(cell.x) + center_offset) * cell_size,
		(float(cell.y) + center_offset) * cell_size
	)

func world_to_grid(pos: Vector2) -> Vector2i:
	var local := pos - origin
	return Vector2i(
		int(floor(local.x / cell_size)),
		int(floor(local.y / cell_size))
	)
