extends RefCounted

var grid_w: int
var grid_h: int
var cell_size: float
var origin: Vector2

func configure(w: int, h: int, cell_px: float, origin_px: Vector2) -> void:
	grid_w = w
	grid_h = h
	cell_size = cell_px
	origin = origin_px

func grid_to_world(cell: Vector2i) -> Vector2:
	return origin + Vector2(
		(float(cell.x) + 0.5) * cell_size,
		(float(cell.y) + 0.5) * cell_size
	)

func world_to_grid(pos: Vector2) -> Vector2i:
	var local := pos - origin
	return Vector2i(
		int(floor(local.x / cell_size)),
		int(floor(local.y / cell_size))
	)
