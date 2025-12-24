extends Node2D

const COLS := 12
const ROWS := 8
const CELL_SIZE := 64

var selected_cell := Vector2i(-1, -1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos := to_local(event.position)
		var cx := int(local_pos.x / CELL_SIZE)
		var cy := int(local_pos.y / CELL_SIZE)
		cx = max(0, min(COLS - 1, cx))
		cy = max(0, min(ROWS - 1, cy))
		selected_cell = Vector2i(cx, cy)
		print("Selected: %d,%d" % [cx, cy])
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
	for x in range(COLS + 1):
		var px := x * CELL_SIZE
		draw_line(Vector2(px, 0), Vector2(px, grid_height), grid_color, 1.0)
	for y in range(ROWS + 1):
		var py := y * CELL_SIZE
		draw_line(Vector2(0, py), Vector2(grid_width, py), grid_color, 1.0)
