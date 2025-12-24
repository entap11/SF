extends Node2D

const COLS := 12
const ROWS := 8
const CELL_SIZE := 64
const UNIT_SPEED_PX := 160.0
const DASH_GAP_PX := 6.0
const BASE_MS := 1000.0
const PER_POWER_MS := 2.0
const BONUS_10_MS := 2.0
const BONUS_25_MS := 2.0
const DRAG_DEADZONE_PX := 8.0

var selected_cell := Vector2i(-1, -1)
var selected_hive_id := -1
var selected_lane_id := -1
var hives: Array = []
var lanes: Array = []
var tap_first_id := -1
var drag_active := false
var drag_start_hive_id := -1
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_current_pos: Vector2 = Vector2.ZERO
var drag_hover_hive_id := -1
var drag_moved := false
var last_vibe_target_id := -1

func _ready() -> void:
	_init_hives()
	_init_lanes()

func _process(delta: float) -> void:
	_update_lanes(delta)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_press(to_local(event.position))
		else:
			_handle_release(to_local(event.position))
	if event is InputEventMouseMotion:
		_handle_drag(to_local(event.position))
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_press(to_local(event.position))
		else:
			_handle_release(to_local(event.position))
	if event is InputEventScreenDrag:
		_handle_drag(to_local(event.position))

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
		_draw_lane(lane)
	_draw_drag_preview()
	for hive in hives:
		var center := _cell_center(hive["grid_pos"])
		var fill := _owner_color(hive["owner_id"])
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
		{"id": 1, "grid_pos": Vector2i(1, 2), "owner_id": 1, "power": 8, "kind": "Hive"},
		{"id": 2, "grid_pos": Vector2i(3, 5), "owner_id": 1, "power": 12, "kind": "Hive"},
		{"id": 3, "grid_pos": Vector2i(6, 3), "owner_id": 0, "power": 0, "kind": "Hive"},
		{"id": 4, "grid_pos": Vector2i(8, 1), "owner_id": 2, "power": 15, "kind": "Hive"},
		{"id": 5, "grid_pos": Vector2i(10, 6), "owner_id": 3, "power": 20, "kind": "Hive"},
		{"id": 6, "grid_pos": Vector2i(7, 6), "owner_id": 4, "power": 5, "kind": "Hive"}
	]

func _init_lanes() -> void:
	lanes = [
		{"id": 1, "a_id": 1, "b_id": 2, "dir": 1, "send_a": true, "send_b": false, "a_pressure": 0.0, "b_pressure": 0.0, "a_stream_len": 0.0, "b_stream_len": 0.0},
		{"id": 2, "a_id": 2, "b_id": 3, "dir": 1, "send_a": true, "send_b": false, "a_pressure": 0.0, "b_pressure": 0.0, "a_stream_len": 0.0, "b_stream_len": 0.0},
		{"id": 3, "a_id": 3, "b_id": 4, "dir": -1, "send_a": false, "send_b": true, "a_pressure": 0.0, "b_pressure": 0.0, "a_stream_len": 0.0, "b_stream_len": 0.0},
		{"id": 4, "a_id": 2, "b_id": 4, "dir": 1, "send_a": true, "send_b": true, "a_pressure": 0.0, "b_pressure": 0.0, "a_stream_len": 0.0, "b_stream_len": 0.0},
		{"id": 5, "a_id": 4, "b_id": 5, "dir": 1, "send_a": true, "send_b": true, "a_pressure": 0.0, "b_pressure": 0.0, "a_stream_len": 0.0, "b_stream_len": 0.0},
		{"id": 6, "a_id": 5, "b_id": 6, "dir": 1, "send_a": true, "send_b": true, "a_pressure": 0.0, "b_pressure": 0.0, "a_stream_len": 0.0, "b_stream_len": 0.0},
		{"id": 7, "a_id": 1, "b_id": 6, "dir": -1, "send_a": false, "send_b": true, "a_pressure": 0.0, "b_pressure": 0.0, "a_stream_len": 0.0, "b_stream_len": 0.0},
		{"id": 8, "a_id": 4, "b_id": 6, "dir": 1, "send_a": true, "send_b": false, "a_pressure": 0.0, "b_pressure": 0.0, "a_stream_len": 0.0, "b_stream_len": 0.0}
	]

func _find_hive_at_cell(cell: Vector2i) -> Dictionary:
	for hive in hives:
		if hive["grid_pos"] == cell:
			return hive
	return {}

func _find_hive_by_id(hive_id: int) -> Dictionary:
	for hive in hives:
		if hive["id"] == hive_id:
			return hive
	return {}

func _pick_lane(local_pos: Vector2) -> Dictionary:
	var best_lane: Dictionary = {}
	var best_dist := INF
	for lane in lanes:
		var a: Dictionary = _find_hive_by_id(lane["a_id"])
		var b: Dictionary = _find_hive_by_id(lane["b_id"])
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

func _owner_color(owner_id: int) -> Color:
	match owner_id:
		0:
			return Color(0.6, 0.6, 0.6)
		1:
			return Color(0.95, 0.85, 0.2)
		2:
			return Color(0.12, 0.12, 0.12)
		3:
			return Color(0.9, 0.2, 0.2)
		4:
			return Color(0.2, 0.5, 0.95)
		_:
			return Color(0.8, 0.8, 0.8)

func _update_lanes(delta: float) -> void:
	for lane in lanes:
		var a := _find_hive_by_id(lane["a_id"])
		var b := _find_hive_by_id(lane["b_id"])
		if a.is_empty() or b.is_empty():
			continue
		if a["owner_id"] == 0:
			lane["send_a"] = false
		if b["owner_id"] == 0:
			lane["send_b"] = false
		var mode := _lane_mode(a, b)
		if mode == "friendly" and lane["send_a"] and lane["send_b"]:
			lane["send_b"] = false
		var rate_a := _send_rate(a, lane["send_a"])
		var rate_b := _send_rate(b, lane["send_b"])
		if rate_a > 0.0:
			lane["a_pressure"] += rate_a * delta
			lane["a_stream_len"] = min(_lane_length_px(a, b), lane["a_stream_len"] + UNIT_SPEED_PX * delta)
		if rate_b > 0.0:
			lane["b_pressure"] += rate_b * delta
			lane["b_stream_len"] = min(_lane_length_px(a, b), lane["b_stream_len"] + UNIT_SPEED_PX * delta)

func _lane_mode(a: Dictionary, b: Dictionary) -> String:
	if a["owner_id"] == 0 or b["owner_id"] == 0:
		return "neutral"
	if a["owner_id"] == b["owner_id"]:
		return "friendly"
	return "opposing"

func _send_rate(hive: Dictionary, is_sending: bool) -> float:
	if not is_sending:
		return 0.0
	if hive["owner_id"] == 0:
		return 0.0
	var interval_ms := _interval_ms(hive["power"])
	var interval_sec := interval_ms / 1000.0
	if interval_sec <= 0.0:
		return 0.0
	return 1.0 / interval_sec

func _interval_ms(power: int) -> float:
	var bonus := 0.0
	if power >= 10:
		bonus += BONUS_10_MS
	if power >= 25:
		bonus += BONUS_25_MS
	var value := BASE_MS - (power * PER_POWER_MS) - bonus
	return max(200.0, value)

func _lane_length_px(a: Dictionary, b: Dictionary) -> float:
	return _cell_center(a["grid_pos"]).distance_to(_cell_center(b["grid_pos"]))

func _draw_lane(lane: Dictionary) -> void:
	var a := _find_hive_by_id(lane["a_id"])
	var b := _find_hive_by_id(lane["b_id"])
	if a.is_empty() or b.is_empty():
		return
	var a_pos := _cell_center(a["grid_pos"])
	var b_pos := _cell_center(b["grid_pos"])
	if lane["id"] == selected_lane_id:
		draw_line(a_pos, b_pos, Color(0.9, 0.9, 0.2), 4.0)
	var mode := _lane_mode(a, b)
	var send_a: bool = lane["send_a"]
	var send_b: bool = lane["send_b"]
	if mode == "opposing" and send_a and send_b:
		_draw_opposing_lane(lane, a, b, a_pos, b_pos)
		return
	if send_a:
		_draw_one_way_lane(a, b, a_pos, b_pos, lane["a_stream_len"])
	elif send_b:
		_draw_one_way_lane(b, a, b_pos, a_pos, lane["b_stream_len"])

func _handle_press(local_pos: Vector2) -> void:
	var hive_id := _hive_id_at_point(local_pos)
	if hive_id == -1:
		var lane_hit: Dictionary = _pick_lane(local_pos)
		if not lane_hit.is_empty():
			selected_hive_id = -1
			selected_lane_id = lane_hit["id"]
			selected_cell = _cell_from_point(local_pos)
			print("SF: Lane selected id=%d a=%d b=%d dir=%d" % [lane_hit["id"], lane_hit["a_id"], lane_hit["b_id"], lane_hit["dir"]])
			return
		selected_hive_id = -1
		selected_lane_id = -1
		selected_cell = _cell_from_point(local_pos)
		print("SF: Cell selected %d,%d" % [selected_cell.x, selected_cell.y])
		return
	var hive := _find_hive_by_id(hive_id)
	if hive.is_empty() or hive["owner_id"] == 0:
		if tap_first_id != -1:
			_handle_tap(hive_id)
		else:
			_clear_tap_state()
			_clear_selection()
		return
	drag_active = true
	drag_moved = false
	drag_start_hive_id = hive_id
	drag_start_pos = local_pos
	drag_current_pos = local_pos
	drag_hover_hive_id = -1
	last_vibe_target_id = -1
	selected_hive_id = hive_id
	selected_lane_id = -1
	selected_cell = _cell_from_point(local_pos)

func _handle_release(local_pos: Vector2) -> void:
	if not drag_active:
		return
	drag_current_pos = local_pos
	var end_hive_id := _hive_id_at_point(local_pos)
	if not drag_moved:
		if drag_start_hive_id != -1:
			_handle_tap(drag_start_hive_id)
		_reset_drag()
		return
	if end_hive_id != -1 and end_hive_id != drag_start_hive_id:
		if _lane_exists_between(drag_start_hive_id, end_hive_id):
			_apply_intent_pair(drag_start_hive_id, end_hive_id)
	_reset_drag()

func _handle_drag(local_pos: Vector2) -> void:
	if not drag_active:
		return
	drag_current_pos = local_pos
	if drag_current_pos.distance_to(drag_start_pos) >= DRAG_DEADZONE_PX:
		drag_moved = true
	var hover_id := _hive_id_at_point(local_pos)
	if hover_id != -1 and hover_id != drag_start_hive_id and _lane_exists_between(drag_start_hive_id, hover_id):
		if hover_id != last_vibe_target_id:
			Input.vibrate_handheld(30)
			last_vibe_target_id = hover_id
		drag_hover_hive_id = hover_id
	else:
		drag_hover_hive_id = -1
		last_vibe_target_id = -1

func _handle_tap(hive_id: int) -> void:
	var hive := _find_hive_by_id(hive_id)
	if hive.is_empty():
		_clear_tap_state()
		return
	if hive["owner_id"] == 0 and tap_first_id == -1:
		_clear_tap_state()
		return
	if tap_first_id == -1:
		tap_first_id = hive_id
		selected_hive_id = hive_id
		return
	if tap_first_id == hive_id:
		_clear_tap_state()
		return
	if _lane_exists_between(tap_first_id, hive_id):
		_apply_intent_pair(tap_first_id, hive_id)
	_clear_tap_state()

func _apply_intent_pair(start_id: int, end_id: int) -> void:
	var lane_index := _lane_index_between(start_id, end_id)
	if lane_index == -1:
		return
	var lane: Dictionary = lanes[lane_index]
	var reverse_on := _intent_is_on(end_id, start_id)
	if reverse_on:
		_set_intent(end_id, start_id, false)
		print("SF: Intent OFF %d->%d" % [end_id, start_id])
	else:
		_set_intent(start_id, end_id, true)
		print("SF: Intent ON %d->%d" % [start_id, end_id])

func _set_intent(from_id: int, to_id: int, enable: bool) -> void:
	var lane_index := _lane_index_between(from_id, to_id)
	if lane_index == -1:
		return
	var lane: Dictionary = lanes[lane_index]
	var a_id: int = lane["a_id"]
	var b_id: int = lane["b_id"]
	var a := _find_hive_by_id(a_id)
	var b := _find_hive_by_id(b_id)
	var mode := _lane_mode(a, b)
	if from_id == a_id and to_id == b_id:
		lane["send_a"] = enable
		if mode == "friendly" and enable:
			lane["send_b"] = false
			lane["dir"] = 1
	elif from_id == b_id and to_id == a_id:
		lane["send_b"] = enable
		if mode == "friendly" and enable:
			lane["send_a"] = false
			lane["dir"] = -1
	lanes[lane_index] = lane

func _intent_is_on(from_id: int, to_id: int) -> bool:
	var lane_index := _lane_index_between(from_id, to_id)
	if lane_index == -1:
		return false
	var lane: Dictionary = lanes[lane_index]
	if from_id == lane["a_id"] and to_id == lane["b_id"]:
		return lane["send_a"]
	if from_id == lane["b_id"] and to_id == lane["a_id"]:
		return lane["send_b"]
	return false

func _lane_exists_between(a_id: int, b_id: int) -> bool:
	return _lane_index_between(a_id, b_id) != -1

func _lane_index_between(a_id: int, b_id: int) -> int:
	for i in range(lanes.size()):
		var lane: Dictionary = lanes[i]
		if (lane["a_id"] == a_id and lane["b_id"] == b_id) or (lane["a_id"] == b_id and lane["b_id"] == a_id):
			return i
	return -1

func _hive_id_at_point(local_pos: Vector2) -> int:
	var cx := int(local_pos.x / CELL_SIZE)
	var cy := int(local_pos.y / CELL_SIZE)
	cx = max(0, min(COLS - 1, cx))
	cy = max(0, min(ROWS - 1, cy))
	var hive := _find_hive_at_cell(Vector2i(cx, cy))
	if hive.is_empty():
		return -1
	return hive["id"]

func _cell_from_point(local_pos: Vector2) -> Vector2i:
	var cx := int(local_pos.x / CELL_SIZE)
	var cy := int(local_pos.y / CELL_SIZE)
	cx = max(0, min(COLS - 1, cx))
	cy = max(0, min(ROWS - 1, cy))
	return Vector2i(cx, cy)

func _draw_drag_preview() -> void:
	if not drag_active or drag_start_hive_id == -1:
		return
	var start_hive := _find_hive_by_id(drag_start_hive_id)
	if start_hive.is_empty():
		return
	var start_pos := _cell_center(start_hive["grid_pos"])
	var color := Color(0.4, 0.4, 0.4)
	if drag_hover_hive_id != -1:
		color = _owner_color(start_hive["owner_id"])
	draw_line(start_pos, drag_current_pos, color, 2.0)
	if drag_hover_hive_id != -1:
		var hover_hive := _find_hive_by_id(drag_hover_hive_id)
		if not hover_hive.is_empty():
			var hover_pos := _cell_center(hover_hive["grid_pos"])
			draw_arc(hover_pos, CELL_SIZE * 0.34, 0.0, TAU, 28, color, 2.0)

func _clear_tap_state() -> void:
	tap_first_id = -1

func _clear_selection() -> void:
	selected_hive_id = -1
	selected_lane_id = -1

func _reset_drag() -> void:
	drag_active = false
	drag_start_hive_id = -1
	drag_hover_hive_id = -1
	drag_moved = false
	last_vibe_target_id = -1

func _draw_opposing_lane(lane: Dictionary, a: Dictionary, b: Dictionary, a_pos: Vector2, b_pos: Vector2) -> void:
	var total: float = lane["a_pressure"] + lane["b_pressure"]
	if total <= 0.0:
		return
	var f: float = lane["a_pressure"] / total
	var impact := a_pos.lerp(b_pos, f)
	_draw_segmented_clamped(a, a_pos, impact, lane["a_stream_len"])
	_draw_segmented_clamped(b, b_pos, impact, lane["b_stream_len"])

func _draw_one_way_lane(src: Dictionary, _dst: Dictionary, src_pos: Vector2, dst_pos: Vector2, stream_len: float) -> void:
	var max_len: float = src_pos.distance_to(dst_pos)
	var dir: Vector2 = (dst_pos - src_pos).normalized()
	var visible_len: float = min(stream_len, max_len)
	var end_pos := src_pos + dir * visible_len
	_draw_segmented(src, src_pos, end_pos)
	if visible_len >= max_len:
		_draw_arrowhead(src_pos, dst_pos, _owner_color(src["owner_id"]))

func _draw_segmented_clamped(src: Dictionary, src_pos: Vector2, dst_pos: Vector2, stream_len: float) -> void:
	var max_len: float = src_pos.distance_to(dst_pos)
	var dir: Vector2 = (dst_pos - src_pos).normalized()
	var visible_len: float = min(stream_len, max_len)
	var end_pos := src_pos + dir * visible_len
	_draw_segmented(src, src_pos, end_pos)

func _draw_segmented(src: Dictionary, from_pos: Vector2, to_pos: Vector2) -> void:
	var interval_ms: float = _interval_ms(src["power"])
	var segment_len: float = UNIT_SPEED_PX * (interval_ms / 1000.0)
	var color: Color = _owner_color(src["owner_id"])
	var total_len: float = from_pos.distance_to(to_pos)
	if total_len <= 0.0:
		return
	var dir: Vector2 = (to_pos - from_pos).normalized()
	var traveled: float = 0.0
	while traveled < total_len:
		var seg_start: Vector2 = from_pos + dir * traveled
		var seg_end: Vector2 = from_pos + dir * min(traveled + segment_len, total_len)
		draw_line(seg_start, seg_end, color, 2.0)
		traveled += segment_len + DASH_GAP_PX
