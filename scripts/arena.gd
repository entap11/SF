extends Node2D

const COLS := 12
const ROWS := 8
const CELL_SIZE := 64

var selected_cell := Vector2i(-1, -1)
var selected_hive_id := -1
var selected_lane_id := -1
var hives: Array = []
var lanes: Array = []

func _ready() -> void:
	_init_hives()
	_init_lanes()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos := to_local(event.position)
		var cx := int(local_pos.x / CELL_SIZE)
		var cy := int(local_pos.y / CELL_SIZE)
		cx = max(0, min(COLS - 1, cx))
		cy = max(0, min(ROWS - 1, cy))
		var hive := _find_hive_at_cell(Vector2i(cx, cy))
		if hive != null:
			selected_hive_id = hive["id"]
			selected_lane_id = -1
			selected_cell = Vector2i(cx, cy)
			print("SF: Hive selected id=%d owner=%d at %d,%d" % [hive["id"], hive["owner"], cx, cy])
			queue_redraw()
			return
		var lane_hit := _pick_lane(local_pos)
		if lane_hit != null:
			selected_hive_id = -1
			selected_lane_id = lane_hit["id"]
			selected_cell = Vector2i(cx, cy)
			print("SF: Lane selected id=%d a=%d b=%d dir=%d" % [lane_hit["id"], lane_hit["a_id"], lane_hit["b_id"], lane_hit["dir"]])
			queue_redraw()
			return
		selected_hive_id = -1
		selected_lane_id = -1
		selected_cell = Vector2i(cx, cy)
		print("SF: Cell selected %d,%d" % [cx, cy])
		queue_redraw()

func _draw() -> void:
	var grid_color := Color(0.25, 0.25, 0.25)
	var grid_width := COLS * CELL_SIZE
	var grid_height := ROWS * CELL_SIZE
	if selected_cell.x >= 0 and selected_cell.y >= 0:
		var rect := Rect2(
			selected_cell.x * CELL_SIZE,
			selected_cell.y * CELL_SIZE,
			CELL_SIZE,
			CELL_SIZE
		)
		draw_rect(rect, Color(0.2, 0.6, 1.0, 0.35), true)
	for lane in lanes:
		var a_pos := _cell_center(_find_hive_by_id(lane["a_id"])["grid_pos"])
		var b_pos := _cell_center(_find_hive_by_id(lane["b_id"])["grid_pos"])
		var src_pos := a_pos if lane["dir"] == 1 else b_pos
		var dst_pos := b_pos if lane["dir"] == 1 else a_pos
		var line_color := Color(0.15, 0.55, 0.15)
		var width := 2.0
		if lane["id"] == selected_lane_id:
			line_color = Color(0.9, 0.9, 0.2)
			width = 4.0
		draw_line(src_pos, dst_pos, line_color, width)
		_draw_arrowhead(src_pos, dst_pos, line_color)
	for hive in hives:
		var center := _cell_center(hive["grid_pos"])
		var fill := _owner_color(hive["owner"])
		draw_circle(center, CELL_SIZE * 0.28, fill)
		if hive["id"] == selected_hive_id:
			draw_arc(center, CELL_SIZE * 0.34, 0.0, TAU, 28, Color(1.0, 1.0, 1.0), 2.0)
	for x in range(COLS + 1):
		var px := x * CELL_SIZE
		draw_line(Vector2(px, 0), Vector2(px, grid_height), grid_color, 1.0)
	for y in range(ROWS + 1):
		var py := y * CELL_SIZE
		draw_line(Vector2(0, py), Vector2(grid_width, py), grid_color, 1.0)

func _init_hives() -> void:
	hives = [
		{"id": 1, "grid_pos": Vector2i(1, 2), "owner": 1, "kind": "Hive"},
		{"id": 2, "grid_pos": Vector2i(3, 5), "owner": 1, "kind": "Hive"},
		{"id": 3, "grid_pos": Vector2i(6, 3), "owner": 0, "kind": "Hive"},
		{"id": 4, "grid_pos": Vector2i(8, 1), "owner": 2, "kind": "Hive"},
		{"id": 5, "grid_pos": Vector2i(10, 6), "owner": 2, "kind": "Hive"}
	]

func _init_lanes() -> void:
	lanes = [
		{"id": 1, "a_id": 1, "b_id": 3, "dir": 1},
		{"id": 2, "a_id": 2, "b_id": 3, "dir": -1},
		{"id": 3, "a_id": 2, "b_id": 4, "dir": 1},
		{"id": 4, "a_id": 3, "b_id": 4, "dir": 1},
		{"id": 5, "a_id": 3, "b_id": 5, "dir": 1},
		{"id": 6, "a_id": 4, "b_id": 5, "dir": -1},
		{"id": 7, "a_id": 1, "b_id": 2, "dir": 1},
		{"id": 8, "a_id": 1, "b_id": 5, "dir": -1}
	]

func _find_hive_at_cell(cell: Vector2i):
	for hive in hives:
		if hive["grid_pos"] == cell:
			return hive
	return null

func _find_hive_by_id(hive_id: int) -> Dictionary:
	for hive in hives:
		if hive["id"] == hive_id:
			return hive
	return {}

func _pick_lane(local_pos: Vector2):
	var best_lane = null
	var best_dist := INF
	for lane in lanes:
		var a := _find_hive_by_id(lane["a_id"])
		var b := _find_hive_by_id(lane["b_id"])
		if a.is_empty() or b.is_empty():
			continue
		var a_pos := _cell_center(a["grid_pos"])
		var b_pos := _cell_center(b["grid_pos"])
		var dist := _distance_point_to_segment(local_pos, a_pos, b_pos)
		if dist <= 12.0 and dist < best_dist:
			best_dist = dist
			best_lane = lane
	return best_lane

func _distance_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	if ab.length_squared() == 0.0:
		return p.distance_to(a)
	var t := (p - a).dot(ab) / ab.length_squared()
	t = clamp(t, 0.0, 1.0)
	var proj := a + ab * t
	return p.distance_to(proj)

func _draw_arrowhead(from_pos: Vector2, to_pos: Vector2, color: Color) -> void:
	var dir := (to_pos - from_pos).normalized()
	if dir.length() == 0.0:
		return
	var size := 10.0
	var tip := to_pos
	var left := tip - dir * size + dir.rotated(PI * 0.6) * size * 0.5
	var right := tip - dir * size + dir.rotated(-PI * 0.6) * size * 0.5
	draw_colored_polygon([tip, left, right], color)

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * CELL_SIZE + CELL_SIZE * 0.5,
		cell.y * CELL_SIZE + CELL_SIZE * 0.5
	)

func _owner_color(owner: int) -> Color:
	match owner:
		0:
			return Color(0.6, 0.6, 0.6)
		1:
			return Color(0.2, 0.7, 1.0)
		2:
			return Color(1.0, 0.4, 0.4)
		_:
			return Color(0.8, 0.8, 0.8)
