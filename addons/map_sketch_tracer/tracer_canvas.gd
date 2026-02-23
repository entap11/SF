@tool
extends Control
class_name MapSketchCanvas

signal status_changed(message: String)
signal hover_changed(message: String)

const COLS := 12
const ROWS := 8
const CELL_SIZE := 64.0
const GRID_COLOR := Color(0.32, 0.32, 0.32)
const GRID_BORDER := Color(0.18, 0.18, 0.18)
const LANE_COLOR := Color(0.15, 0.15, 0.15, 0.6)
const LANE_SELECTED_COLOR := Color(1.0, 0.8, 0.2, 0.9)
const NODE_OUTLINE_COLOR := Color(0.1, 0.1, 0.1)
const SNAP_COLOR := Color(0.2, 0.6, 1.0, 0.25)

var sketch_texture: Texture2D
var sketch_opacity: float = 0.35

var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO
var min_zoom: float = 0.2
var max_zoom: float = 4.0
var user_panned := false

var mode: String = "select"
var place_type: String = "player_hive"
var place_owner: String = "P1"

var nodes: Array = []
var lanes: Array = []

var selected_node_id: String = ""
var selected_lane_index: int = -1
var pending_lane_start: String = ""

var hover_cell: Vector2i = Vector2i(-1, -1)
var hover_valid := false

var dragging_node_id: String = ""
var dragging := false
var panning := false
var pan_start: Vector2 = Vector2.ZERO
var pan_origin: Vector2 = Vector2.ZERO

var id_counts: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_focus_mode(Control.FOCUS_ALL)
	_center_grid()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not user_panned:
		_center_grid()

func set_mode(value: String) -> void:
	mode = value
	pending_lane_start = ""
	queue_redraw()

func set_place_type(value: String) -> void:
	place_type = value

func set_place_owner(value: String) -> void:
	place_owner = value

func set_sketch_opacity(value: float) -> void:
	sketch_opacity = clamp(value, 0.0, 1.0)
	queue_redraw()

func clear_sketch() -> void:
	sketch_texture = null
	queue_redraw()

func load_sketch(path: String) -> bool:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		_emit_status("Failed to load image: %s" % path)
		return false
	sketch_texture = ImageTexture.create_from_image(img)
	_emit_status("Loaded sketch: %s" % path)
	queue_redraw()
	return true

func clear_all() -> void:
	nodes.clear()
	lanes.clear()
	selected_node_id = ""
	selected_lane_index = -1
	pending_lane_start = ""
	id_counts.clear()
	queue_redraw()

func export_json(map_name: String, description: String) -> String:
	var data := _build_export_dict(map_name, description)
	return JSON.stringify(data, "\t")

func export_json_to_path(path: String, map_name: String, description: String) -> bool:
	var file_path := path
	if not file_path.ends_with(".json"):
		file_path += ".json"
	var json_text := export_json(map_name, description)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		_emit_status("Failed to open: %s" % file_path)
		return false
	file.store_string(json_text)
	_emit_status("Exported: %s" % file_path)
	return true

func validate_map(map_name: String, description: String) -> Dictionary:
	var errors: Array = []
	var data := _build_export_dict(map_name, description)
	if data.keys().is_empty() or str(data.keys()[0]) != "_schema":
		errors.append("_schema must be first key")
	if nodes.is_empty():
		errors.append("No nodes placed")
	var seen_cells: Dictionary = {}
	var seen_ids: Dictionary = {}
	for node in nodes:
		var pos: Vector2i = node.get("grid", Vector2i(-1, -1))
		if pos.x < 0 or pos.x >= COLS or pos.y < 0 or pos.y >= ROWS:
			errors.append("Node out of bounds: %s" % node.get("id", ""))
		var cell_key := "%d,%d" % [pos.x, pos.y]
		if seen_cells.has(cell_key):
			errors.append("Duplicate node cell %s" % cell_key)
		else:
			seen_cells[cell_key] = true
		var id_str := str(node.get("id", ""))
		if id_str.is_empty():
			errors.append("Node missing id")
		elif seen_ids.has(id_str):
			errors.append("Duplicate node id %s" % id_str)
		else:
			seen_ids[id_str] = true
	var lane_keys: Dictionary = {}
	for lane in lanes:
		var a_id := str(lane.get("from_id", ""))
		var b_id := str(lane.get("to_id", ""))
		if not seen_ids.has(a_id) or not seen_ids.has(b_id):
			errors.append("Lane endpoint missing: %s-%s" % [a_id, b_id])
			continue
		if a_id == b_id:
			errors.append("Lane self-link: %s" % a_id)
			continue
		var key := _lane_key(a_id, b_id)
		if lane_keys.has(key):
			errors.append("Duplicate lane: %s" % key)
		else:
			lane_keys[key] = true
	var ok := errors.is_empty()
	return {"ok": ok, "errors": errors}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.1)
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 0.9)
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				panning = true
				pan_start = mb.position
				pan_origin = pan
				user_panned = true
			else:
				panning = false
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			pending_lane_start = ""
			queue_redraw()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			if mb.pressed:
				_handle_left_press(mb.position)
			else:
				_drag_end()
			return
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_update_hover(mm.position)
		if panning:
			pan = pan_origin + (mm.position - pan_start)
			queue_redraw()
			return
		if dragging:
			_drag_move(mm.position)
			return

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_DELETE or key == KEY_BACKSPACE:
			_delete_selected()

func _handle_left_press(pos: Vector2) -> void:
	_update_hover(pos)
	if mode == "place":
		_place_node_at_hover()
		return
	if mode == "connect":
		_handle_connect_click(pos)
		return
	_select_at_point(pos)

func _select_at_point(pos: Vector2) -> void:
	selected_lane_index = -1
	var node: Dictionary = _node_at_point(pos)
	if not node.is_empty():
		selected_node_id = str(node.get("id", ""))
		dragging_node_id = selected_node_id
		dragging = true
		return
	selected_node_id = ""
	var lane_idx := _lane_at_point(pos)
	if lane_idx != -1:
		selected_lane_index = lane_idx
	queue_redraw()

func _handle_connect_click(pos: Vector2) -> void:
	var node: Dictionary = _node_at_point(pos)
	if node.is_empty():
		return
	if not _is_hive_node(node):
		_emit_status("Only hives can be lane endpoints")
		return
	var node_id := str(node.get("id", ""))
	if pending_lane_start.is_empty():
		pending_lane_start = node_id
		queue_redraw()
		return
	if pending_lane_start == node_id:
		pending_lane_start = ""
		queue_redraw()
		return
	_add_lane(pending_lane_start, node_id)
	pending_lane_start = ""
	queue_redraw()

func _place_node_at_hover() -> void:
	if not hover_valid:
		_emit_status("Click inside the grid")
		return
	if not _node_at_cell(hover_cell, "").is_empty():
		_emit_status("Cell already occupied")
		return
	var node: Dictionary = _create_node(hover_cell)
	nodes.append(node)
	queue_redraw()

func _drag_move(pos: Vector2) -> void:
	if dragging_node_id.is_empty():
		return
	if not hover_valid:
		return
	var node: Dictionary = _node_by_id(dragging_node_id)
	if node.is_empty():
		return
	if not _node_at_cell(hover_cell, dragging_node_id).is_empty():
		return
	node["grid"] = hover_cell
	queue_redraw()

func _drag_end() -> void:
	dragging = false
	dragging_node_id = ""

func _delete_selected() -> void:
	if not selected_node_id.is_empty():
		_delete_node(selected_node_id)
		selected_node_id = ""
		queue_redraw()
		return
	if selected_lane_index != -1:
		lanes.remove_at(selected_lane_index)
		selected_lane_index = -1
		queue_redraw()

func _delete_node(node_id: String) -> void:
	for i in range(nodes.size() - 1, -1, -1):
		if str(nodes[i].get("id", "")) == node_id:
			nodes.remove_at(i)
			break
	for i in range(lanes.size() - 1, -1, -1):
		var lane: Dictionary = lanes[i]
		if str(lane.get("from_id", "")) == node_id or str(lane.get("to_id", "")) == node_id:
			lanes.remove_at(i)

func _update_hover(pos: Vector2) -> void:
	var cell: Vector2i = _screen_to_grid(pos)
	if cell.x < 0 or cell.x >= COLS or cell.y < 0 or cell.y >= ROWS:
		hover_valid = false
		hover_cell = Vector2i(-1, -1)
		hover_changed.emit("Hover: --")
		return
	hover_valid = true
	hover_cell = cell
	hover_changed.emit("Hover: %d,%d" % [cell.x, cell.y])
	queue_redraw()

func _node_at_point(pos: Vector2) -> Dictionary:
	var hit_radius := CELL_SIZE * 0.25 * zoom
	for node in nodes:
		var center := _grid_to_screen(node.get("grid", Vector2i.ZERO))
		if center.distance_to(pos) <= hit_radius:
			return node
	return {}

func _node_at_cell(cell: Vector2i, ignore_id: String) -> Dictionary:
	for node in nodes:
		if ignore_id != "" and str(node.get("id", "")) == ignore_id:
			continue
		if node.get("grid", Vector2i(-1, -1)) == cell:
			return node
	return {}

func _node_by_id(node_id: String) -> Dictionary:
	for node in nodes:
		if str(node.get("id", "")) == node_id:
			return node
	return {}

func _lane_at_point(pos: Vector2) -> int:
	var threshold := max(6.0, 6.0 * zoom)
	for i in range(lanes.size()):
		var lane: Dictionary = lanes[i]
		var a_node: Dictionary = _node_by_id(str(lane.get("from_id", "")))
		var b_node: Dictionary = _node_by_id(str(lane.get("to_id", "")))
		if a_node.is_empty() or b_node.is_empty():
			continue
		var a_pos := _grid_to_screen(a_node.get("grid", Vector2i.ZERO))
		var b_pos := _grid_to_screen(b_node.get("grid", Vector2i.ZERO))
		var dist_t := _segment_distance_t(pos, a_pos, b_pos)
		if dist_t.x <= threshold and dist_t.y > 0.0 and dist_t.y < 1.0:
			return i
	return -1

func _add_lane(a_id: String, b_id: String) -> void:
	if a_id == b_id:
		return
	var key := _lane_key(a_id, b_id)
	for lane in lanes:
		if _lane_key(str(lane.get("from_id", "")), str(lane.get("to_id", ""))) == key:
			_emit_status("Lane already exists")
			return
	lanes.append({"from_id": a_id, "to_id": b_id})
	_emit_status("Lane added %s" % key)

func _is_hive_node(node: Dictionary) -> bool:
	var t := str(node.get("type", ""))
	return t == "player_hive" or t == "npc_hive"

func _create_node(cell: Vector2i) -> Dictionary:
	var node_type := place_type
	var owner := ""
	if node_type == "player_hive":
		owner = place_owner
	elif node_type == "npc_hive":
		owner = "NPC"
	var node_id := _next_node_id(node_type, owner)
	return {
		"id": node_id,
		"type": node_type,
		"owner": owner,
		"grid": cell
	}

func _next_node_id(node_type: String, owner: String) -> String:
	var key := node_type
	if node_type == "player_hive":
		key = owner
	if node_type == "npc_hive":
		key = "NPC"
	if not id_counts.has(key):
		id_counts[key] = 0
	var count := int(id_counts[key]) + 1
	id_counts[key] = count
	var base := "N"
	match node_type:
		"player_hive":
			base = "%s_H" % owner
		"npc_hive":
			base = "NPC_H"
		"tower":
			base = "T"
		"barracks":
			base = "B"
	return "%s%d" % [base, count]

func _build_export_dict(map_name: String, description: String) -> Dictionary:
	var entities: Array = []
	var sorted_nodes := nodes.duplicate()
	sorted_nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_id := str(a.get("id", ""))
		var b_id := str(b.get("id", ""))
		return a_id < b_id
	)
	for node in sorted_nodes:
		var pos: Vector2i = node.get("grid", Vector2i.ZERO)
		var entry: Dictionary = {
			"id": str(node.get("id", "")),
			"type": str(node.get("type", "")),
			"x": pos.x,
			"y": pos.y,
			"grid_x": pos.x,
			"grid_y": pos.y
		}
		var owner := str(node.get("owner", ""))
		if not owner.is_empty():
			entry["owner"] = owner
		entities.append(entry)
	var lanes_out: Array = []
	var lane_sorted := lanes.duplicate()
	lane_sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _lane_key(str(a.get("from_id", "")), str(a.get("to_id", ""))) < _lane_key(str(b.get("from_id", "")), str(b.get("to_id", "")))
	)
	for lane in lane_sorted:
		lanes_out.append({
			"from_id": str(lane.get("from_id", "")),
			"to_id": str(lane.get("to_id", ""))
		})
	var data: Dictionary = {}
	data["_schema"] = "swarmfront.map.v1.xy"
	data["width"] = COLS
	data["height"] = ROWS
	if not map_name.strip_edges().is_empty():
		data["name"] = map_name.strip_edges()
	if not description.strip_edges().is_empty():
		data["description"] = description.strip_edges()
	data["entities"] = entities
	data["lanes"] = lanes_out
	return data

func _lane_key(a_id: String, b_id: String) -> String:
	if a_id < b_id:
		return "%s:%s" % [a_id, b_id]
	return "%s:%s" % [b_id, a_id]

func _segment_distance_t(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq <= 0.000001:
		return Vector2(p.distance_to(a), 0.0)
	var t: float = ((p - a).dot(ab)) / ab_len_sq
	var t_clamped: float = clamp(t, 0.0, 1.0)
	var closest: Vector2 = a + ab * t_clamped
	return Vector2(p.distance_to(closest), t)

func _grid_to_screen(cell: Vector2i) -> Vector2:
	return pan + Vector2((cell.x + 0.5) * CELL_SIZE * zoom, (cell.y + 0.5) * CELL_SIZE * zoom)

func _screen_to_grid(pos: Vector2) -> Vector2i:
	var grid_pos: Vector2 = (pos - pan) / (CELL_SIZE * zoom)
	var gx := int(round(grid_pos.x - 0.5))
	var gy := int(round(grid_pos.y - 0.5))
	return Vector2i(gx, gy)

func _center_grid() -> void:
	var grid_size := Vector2(COLS * CELL_SIZE, ROWS * CELL_SIZE) * zoom
	pan = (size - grid_size) * 0.5
	queue_redraw()

func _zoom_at(pos: Vector2, factor: float) -> void:
	var old_zoom := zoom
	zoom = clamp(zoom * factor, min_zoom, max_zoom)
	var world_before := (pos - pan) / old_zoom
	pan = pos - world_before * zoom
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.1), true)
	var grid_rect := Rect2(pan, Vector2(COLS * CELL_SIZE, ROWS * CELL_SIZE) * zoom)
	if sketch_texture != null:
		draw_texture_rect(sketch_texture, grid_rect, false, Color(1.0, 1.0, 1.0, sketch_opacity))
	_draw_grid(grid_rect)
	_draw_lanes()
	_draw_nodes()
	_draw_selection()
	_draw_pending_lane()
	_draw_hover_cell()

func _draw_grid(grid_rect: Rect2) -> void:
	var width := COLS * CELL_SIZE * zoom
	var height := ROWS * CELL_SIZE * zoom
	for x in range(COLS + 1):
		var px := pan.x + x * CELL_SIZE * zoom
		var color := GRID_BORDER if x == 0 or x == COLS else GRID_COLOR
		draw_line(Vector2(px, pan.y), Vector2(px, pan.y + height), color, 1.0)
	for y in range(ROWS + 1):
		var py := pan.y + y * CELL_SIZE * zoom
		var color := GRID_BORDER if y == 0 or y == ROWS else GRID_COLOR
		draw_line(Vector2(pan.x, py), Vector2(pan.x + width, py), color, 1.0)

func _draw_nodes() -> void:
	for node in nodes:
		var pos: Vector2i = node.get("grid", Vector2i.ZERO)
		var center := _grid_to_screen(pos)
		var radius := CELL_SIZE * 0.25 * zoom
		var color := _node_color(node)
		var t := str(node.get("type", ""))
		if t == "tower" or t == "barracks":
			var size := radius * 1.6
			var rect := Rect2(center.x - size * 0.5, center.y - size * 0.5, size, size)
			draw_rect(rect, color, true)
			draw_rect(rect, NODE_OUTLINE_COLOR, false, 1.0)
		else:
			draw_circle(center, radius, color)
			draw_arc(center, radius, 0.0, TAU, 24, NODE_OUTLINE_COLOR, 1.0)
		var label := str(node.get("id", ""))
		if not label.is_empty():
			draw_string(ThemeDB.fallback_font, center + Vector2(-radius, radius * 0.2), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 10, Color(1, 1, 1))

func _draw_lanes() -> void:
	var width := max(1.0, 2.0 * zoom)
	for i in range(lanes.size()):
		var lane: Dictionary = lanes[i]
		var a_node: Dictionary = _node_by_id(str(lane.get("from_id", "")))
		var b_node: Dictionary = _node_by_id(str(lane.get("to_id", "")))
		if a_node.is_empty() or b_node.is_empty():
			continue
		var a_pos := _grid_to_screen(a_node.get("grid", Vector2i.ZERO))
		var b_pos := _grid_to_screen(b_node.get("grid", Vector2i.ZERO))
		var color := LANE_SELECTED_COLOR if i == selected_lane_index else LANE_COLOR
		draw_line(a_pos, b_pos, color, width)

func _draw_selection() -> void:
	if selected_node_id.is_empty():
		return
	var node: Dictionary = _node_by_id(selected_node_id)
	if node.is_empty():
		return
	var center := _grid_to_screen(node.get("grid", Vector2i.ZERO))
	var radius := CELL_SIZE * 0.32 * zoom
	draw_arc(center, radius, 0.0, TAU, 28, Color(1.0, 1.0, 1.0), 2.0)

func _draw_pending_lane() -> void:
	if pending_lane_start.is_empty():
		return
	var node: Dictionary = _node_by_id(pending_lane_start)
	if node.is_empty():
		return
	var start := _grid_to_screen(node.get("grid", Vector2i.ZERO))
	var end := start
	if hover_valid:
		end = _grid_to_screen(hover_cell)
	var color := Color(0.2, 0.7, 1.0, 0.8)
	draw_line(start, end, color, max(1.0, 1.5 * zoom))

func _draw_hover_cell() -> void:
	if not hover_valid:
		return
	var cell_rect := Rect2(
		pan + Vector2(hover_cell.x * CELL_SIZE * zoom, hover_cell.y * CELL_SIZE * zoom),
		Vector2(CELL_SIZE * zoom, CELL_SIZE * zoom)
	)
	draw_rect(cell_rect, SNAP_COLOR, true)

func _node_color(node: Dictionary) -> Color:
	var t := str(node.get("type", ""))
	if t == "tower":
		return Color(0.45, 0.3, 0.7)
	if t == "barracks":
		return Color(0.3, 0.6, 0.4)
	if t == "npc_hive":
		return Color(0.55, 0.65, 0.75)
	var owner := str(node.get("owner", ""))
	match owner:
		"P1":
			return Color(0.2, 0.2, 0.2)
		"P2":
			return Color(0.85, 0.2, 0.2)
		"P3":
			return Color(0.2, 0.4, 0.9)
		"P4":
			return Color(0.95, 0.85, 0.2)
	return Color(0.6, 0.6, 0.6)

func _emit_status(message: String) -> void:
	status_changed.emit(message)
