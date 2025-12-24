extends Node2D

const COLS := 12
const ROWS := 8
const CELL_SIZE := 64

var selected_cell := Vector2i(-1, -1)
var selected_hive_id := -1
var hives: Array = []

func _ready() -> void:
	_init_hives()

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
			selected_cell = Vector2i(cx, cy)
			print("SF: Hive selected id=%d owner=%d at %d,%d" % [hive["id"], hive["owner"], cx, cy])
		else:
			selected_hive_id = -1
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

func _find_hive_at_cell(cell: Vector2i):
	for hive in hives:
		if hive["grid_pos"] == cell:
			return hive
	return null

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
