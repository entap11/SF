class_name MatchReplayMapView
extends Control

const PLAYER_COLORS: Dictionary = {
	0: Color(0.46, 0.50, 0.56, 1.0),
	1: Color(0.95, 0.73, 0.25, 1.0),
	2: Color(0.34, 0.63, 1.0, 1.0),
	3: Color(0.96, 0.34, 0.42, 1.0),
	4: Color(0.47, 0.86, 0.48, 1.0)
}

var _replay: Dictionary = {}
var _frame_index: int = 0
var _hive_pos_by_id: Dictionary = {}

func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(320.0, 190.0)

func set_replay_data(replay_data: Dictionary) -> void:
	_replay = replay_data.duplicate(true) if replay_data != null else {}
	_frame_index = 0
	_rebuild_hive_index()
	queue_redraw()

func set_frame_index(index: int) -> void:
	var frames: Array = _frames()
	if frames.is_empty():
		_frame_index = 0
	else:
		_frame_index = clampi(index, 0, frames.size() - 1)
	queue_redraw()

func frame_count() -> int:
	return _frames().size()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.035, 0.040, 0.050, 1.0), true)
	_draw_grid(rect)
	var frames: Array = _frames()
	if _replay.is_empty() or frames.is_empty() or _hive_pos_by_id.is_empty():
		_draw_empty_state(rect)
		return
	var frame: Dictionary = frames[clampi(_frame_index, 0, frames.size() - 1)] as Dictionary
	_draw_lane_candidates()
	_draw_active_lanes(frame)
	_draw_structures()
	_draw_units(frame)
	_draw_hives(frame)

func _draw_empty_state(rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 18
	var text := "Play a match to save a map replay"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := rect.get_center() - (text_size * 0.5)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.78, 0.82, 0.88, 0.82))

func _draw_grid(rect: Rect2) -> void:
	var step := 42.0
	var line_color := Color(1.0, 1.0, 1.0, 0.035)
	var x := fmod(rect.position.x, step)
	while x < rect.size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, rect.size.y), line_color, 1.0)
		x += step
	var y := fmod(rect.position.y, step)
	while y < rect.size.y:
		draw_line(Vector2(0.0, y), Vector2(rect.size.x, y), line_color, 1.0)
		y += step

func _draw_lane_candidates() -> void:
	var map_data: Dictionary = _map_data()
	var candidates: Array = map_data.get("lane_candidates", [])
	for candidate_any in candidates:
		if typeof(candidate_any) != TYPE_ARRAY:
			continue
		var row: Array = candidate_any as Array
		if row.size() < 2:
			continue
		var a_id: int = int(row[0])
		var b_id: int = int(row[1])
		if not _hive_pos_by_id.has(a_id) or not _hive_pos_by_id.has(b_id):
			continue
		draw_line(_screen_pos(_hive_pos_by_id[a_id]), _screen_pos(_hive_pos_by_id[b_id]), Color(0.60, 0.64, 0.72, 0.18), 2.0)

func _draw_active_lanes(frame: Dictionary) -> void:
	for lane_any in frame.get("l", []):
		if typeof(lane_any) != TYPE_ARRAY:
			continue
		var lane: Array = lane_any as Array
		if lane.size() < 5:
			continue
		var a_id: int = int(lane[1])
		var b_id: int = int(lane[2])
		if not _hive_pos_by_id.has(a_id) or not _hive_pos_by_id.has(b_id):
			continue
		var send_a: bool = int(lane[3]) != 0
		var send_b: bool = int(lane[4]) != 0
		var a_pos: Vector2 = _screen_pos(_hive_pos_by_id[a_id])
		var b_pos: Vector2 = _screen_pos(_hive_pos_by_id[b_id])
		if send_a or send_b:
			draw_line(a_pos, b_pos, Color(0.96, 0.77, 0.25, 0.70), 4.0)
		if send_a:
			_draw_lane_arrow(a_pos, b_pos, _owner_for_hive(frame, a_id))
		if send_b:
			_draw_lane_arrow(b_pos, a_pos, _owner_for_hive(frame, b_id))

func _draw_lane_arrow(from_pos: Vector2, to_pos: Vector2, owner_id: int) -> void:
	var dir := to_pos - from_pos
	if dir.length_squared() < 1.0:
		return
	dir = dir.normalized()
	var mid := from_pos.lerp(to_pos, 0.58)
	var side := Vector2(-dir.y, dir.x)
	var color := _player_color(owner_id)
	draw_polygon(
		PackedVector2Array([mid + dir * 9.0, mid - dir * 7.0 + side * 6.0, mid - dir * 7.0 - side * 6.0]),
		PackedColorArray([color, color, color])
	)

func _draw_structures() -> void:
	var map_data: Dictionary = _map_data()
	for tower_any in map_data.get("towers", []):
		if typeof(tower_any) != TYPE_ARRAY:
			continue
		var row: Array = tower_any as Array
		if row.size() < 4:
			continue
		var pos := _screen_pos(Vector2(float(row[1]), float(row[2])))
		draw_rect(Rect2(pos - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), _player_color(int(row[3])).darkened(0.15), true)
	for barracks_any in map_data.get("barracks", []):
		if typeof(barracks_any) != TYPE_ARRAY:
			continue
		var row_b: Array = barracks_any as Array
		if row_b.size() < 4:
			continue
		var pos_b := _screen_pos(Vector2(float(row_b[1]), float(row_b[2])))
		draw_circle(pos_b, 8.0, _player_color(int(row_b[3])).darkened(0.20))

func _draw_units(frame: Dictionary) -> void:
	var lane_lookup := _lane_lookup(frame)
	for unit_any in frame.get("u", []):
		if typeof(unit_any) != TYPE_ARRAY:
			continue
		var unit: Array = unit_any as Array
		if unit.size() < 4:
			continue
		var lane_id: int = int(unit[0])
		if not lane_lookup.has(lane_id):
			continue
		var lane: Array = lane_lookup[lane_id]
		var a_id: int = int(lane[1])
		var b_id: int = int(lane[2])
		if not _hive_pos_by_id.has(a_id) or not _hive_pos_by_id.has(b_id):
			continue
		var t: float = clampf(float(unit[2]), 0.0, 1.0)
		var a_pos: Vector2 = _screen_pos(_hive_pos_by_id[a_id])
		var b_pos: Vector2 = _screen_pos(_hive_pos_by_id[b_id])
		var pos := a_pos.lerp(b_pos, t)
		var amount: int = maxi(1, int(unit[3]))
		draw_circle(pos, clampf(3.5 + float(amount) * 0.7, 4.0, 10.0), _player_color(int(unit[1])))

func _draw_hives(frame: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 14
	for hive_any in frame.get("h", []):
		if typeof(hive_any) != TYPE_ARRAY:
			continue
		var row: Array = hive_any as Array
		if row.size() < 3:
			continue
		var hive_id: int = int(row[0])
		if not _hive_pos_by_id.has(hive_id):
			continue
		var owner_id: int = int(row[1])
		var power: int = int(row[2])
		var pos: Vector2 = _screen_pos(_hive_pos_by_id[hive_id])
		var radius := 18.0
		draw_circle(pos, radius + 3.0, Color(0.02, 0.02, 0.03, 0.95))
		draw_circle(pos, radius, _player_color(owner_id))
		draw_arc(pos, radius + 1.5, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.34), 2.0)
		var text := str(power)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, pos + Vector2(-text_size.x * 0.5, text_size.y * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.02, 0.025, 0.03, 1.0))

func _frames() -> Array:
	var frames_any: Variant = _replay.get("frames", [])
	if typeof(frames_any) != TYPE_ARRAY:
		return []
	return frames_any as Array

func _map_data() -> Dictionary:
	var map_any: Variant = _replay.get("map", {})
	if typeof(map_any) != TYPE_DICTIONARY:
		return {}
	return map_any as Dictionary

func _rebuild_hive_index() -> void:
	_hive_pos_by_id.clear()
	var map_data: Dictionary = _map_data()
	for hive_any in map_data.get("hives", []):
		if typeof(hive_any) != TYPE_ARRAY:
			continue
		var row: Array = hive_any as Array
		if row.size() < 3:
			continue
		_hive_pos_by_id[int(row[0])] = Vector2(float(row[1]), float(row[2]))

func _screen_pos(map_pos: Vector2) -> Vector2:
	var bounds := _map_bounds()
	var inner := Rect2(Vector2(30.0, 24.0), Vector2(maxf(1.0, size.x - 60.0), maxf(1.0, size.y - 48.0)))
	var span_x: float = maxf(1.0, bounds.size.x)
	var span_y: float = maxf(1.0, bounds.size.y)
	var scale: float = minf(inner.size.x / span_x, inner.size.y / span_y)
	var used := Vector2(span_x * scale, span_y * scale)
	var origin := inner.position + (inner.size - used) * 0.5
	return origin + Vector2((map_pos.x - bounds.position.x) * scale, (map_pos.y - bounds.position.y) * scale)

func _map_bounds() -> Rect2:
	if _hive_pos_by_id.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ONE)
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for pos_any in _hive_pos_by_id.values():
		var pos: Vector2 = pos_any as Vector2
		min_pos.x = minf(min_pos.x, pos.x)
		min_pos.y = minf(min_pos.y, pos.y)
		max_pos.x = maxf(max_pos.x, pos.x)
		max_pos.y = maxf(max_pos.y, pos.y)
	var pad := Vector2(0.7, 0.7)
	return Rect2(min_pos - pad, (max_pos - min_pos) + pad * 2.0)

func _lane_lookup(frame: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for lane_any in frame.get("l", []):
		if typeof(lane_any) != TYPE_ARRAY:
			continue
		var lane: Array = lane_any as Array
		if lane.size() < 3:
			continue
		out[int(lane[0])] = lane
	return out

func _owner_for_hive(frame: Dictionary, hive_id: int) -> int:
	for hive_any in frame.get("h", []):
		if typeof(hive_any) != TYPE_ARRAY:
			continue
		var row: Array = hive_any as Array
		if row.size() >= 2 and int(row[0]) == hive_id:
			return int(row[1])
	return 0

func _player_color(owner_id: int) -> Color:
	return PLAYER_COLORS.get(owner_id, PLAYER_COLORS[0]) as Color
