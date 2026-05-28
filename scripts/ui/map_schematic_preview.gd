extends Control
class_name MapSchematicPreview

var _map_data: Dictionary = {}
var _hives: Array[Dictionary] = []
var _hive_pos_by_id: Dictionary = {}
var _grid_size: Vector2 = Vector2(18.0, 28.0)

func set_map_data(map_data: Dictionary) -> void:
	_map_data = map_data.duplicate(true)
	_rebuild_cache()
	queue_redraw()

func clear_map_data() -> void:
	_map_data = {}
	_hives.clear()
	_hive_pos_by_id.clear()
	queue_redraw()

func _rebuild_cache() -> void:
	_hives.clear()
	_hive_pos_by_id.clear()
	_grid_size = _resolve_grid_size(_map_data)
	var hives_v: Variant = _map_data.get("hives", [])
	if typeof(hives_v) != TYPE_ARRAY:
		return
	for hive_any in hives_v as Array:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		var hive_id: int = int(hive.get("id", 0))
		var pos: Vector2 = _entry_pos(hive)
		if hive_id <= 0 or pos.x < 0.0 or pos.y < 0.0:
			continue
		var row: Dictionary = hive.duplicate(true)
		row["preview_pos"] = pos
		_hives.append(row)
		_hive_pos_by_id[hive_id] = pos

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.015, 0.015, 0.012, 1.0), true)
	if _hives.is_empty():
		_draw_empty_state(rect)
		return
	var map_rect: Rect2 = _map_rect(rect)
	_draw_grid(map_rect)
	_draw_walls(map_rect)
	_draw_lanes(map_rect)
	_draw_structure_slots(map_rect)
	_draw_structures(map_rect, "towers", Color(0.98, 0.86, 0.22, 1.0))
	_draw_structures(map_rect, "barracks", Color(0.16, 0.78, 1.0, 1.0))
	_draw_hives(map_rect)

func _draw_empty_state(rect: Rect2) -> void:
	draw_rect(rect.grow(-1.0), Color(0.06, 0.055, 0.045, 1.0), false, 1.0)
	draw_string(
		get_theme_default_font(),
		rect.position + Vector2(18.0, 28.0),
		"MAP SCHEMATIC UNAVAILABLE",
		HORIZONTAL_ALIGNMENT_LEFT,
		rect.size.x - 36.0,
		12,
		Color(0.86, 0.78, 0.54, 0.92)
	)

func _draw_grid(map_rect: Rect2) -> void:
	draw_rect(map_rect, Color(0.025, 0.025, 0.022, 1.0), true)
	draw_rect(map_rect, Color(0.64, 0.50, 0.16, 0.48), false, 1.0)
	for x in range(int(_grid_size.x) + 1):
		if x % 3 != 0:
			continue
		var px: float = lerpf(map_rect.position.x, map_rect.end.x, float(x) / maxf(1.0, _grid_size.x))
		draw_line(Vector2(px, map_rect.position.y), Vector2(px, map_rect.end.y), Color(0.20, 0.17, 0.10, 0.32), 1.0)
	for y in range(int(_grid_size.y) + 1):
		if y % 4 != 0:
			continue
		var py: float = lerpf(map_rect.position.y, map_rect.end.y, float(y) / maxf(1.0, _grid_size.y))
		draw_line(Vector2(map_rect.position.x, py), Vector2(map_rect.end.x, py), Color(0.20, 0.17, 0.10, 0.32), 1.0)

func _draw_lanes(map_rect: Rect2) -> void:
	var lanes_v: Variant = _map_data.get("lane_candidates", _map_data.get("lanes", []))
	if typeof(lanes_v) != TYPE_ARRAY:
		return
	for lane_any in lanes_v as Array:
		if typeof(lane_any) != TYPE_DICTIONARY:
			continue
		var lane: Dictionary = lane_any as Dictionary
		var a_id: int = int(lane.get("a_id", lane.get("from", lane.get("a", 0))))
		var b_id: int = int(lane.get("b_id", lane.get("to", lane.get("b", 0))))
		if not _hive_pos_by_id.has(a_id) or not _hive_pos_by_id.has(b_id):
			continue
		var a: Vector2 = _project(_hive_pos_by_id[a_id] as Vector2, map_rect)
		var b: Vector2 = _project(_hive_pos_by_id[b_id] as Vector2, map_rect)
		draw_line(a, b, Color(0.92, 0.78, 0.32, 0.54), 2.0, true)
		draw_line(a, b, Color(1.0, 0.92, 0.54, 0.22), 5.0, true)

func _draw_hives(map_rect: Rect2) -> void:
	var radius: float = clampf(minf(map_rect.size.x, map_rect.size.y) * 0.035, 5.0, 13.0)
	for hive in _hives:
		var pos: Vector2 = _project(hive.get("preview_pos", Vector2.ZERO) as Vector2, map_rect)
		var color: Color = _owner_color(int(hive.get("owner_id", 0)))
		draw_circle(pos, radius + 3.0, Color(0.0, 0.0, 0.0, 0.72))
		draw_circle(pos, radius + 1.0, Color(1.0, 0.84, 0.25, 0.38))
		draw_circle(pos, radius, color)
		draw_arc(pos, radius + 1.5, 0.0, TAU, 32, Color(1.0, 0.95, 0.70, 0.78), 1.5, true)

func _draw_structure_slots(map_rect: Rect2) -> void:
	var slots_v: Variant = _map_data.get("structure_slots", [])
	if typeof(slots_v) != TYPE_ARRAY:
		return
	var radius: float = clampf(minf(map_rect.size.x, map_rect.size.y) * 0.025, 4.0, 9.0)
	for slot_any in slots_v as Array:
		if typeof(slot_any) != TYPE_DICTIONARY:
			continue
		var slot: Dictionary = slot_any as Dictionary
		var pos: Vector2 = _entry_pos(slot)
		if pos.x < 0.0 or pos.y < 0.0:
			continue
		var p: Vector2 = _project(pos, map_rect)
		draw_circle(p, radius + 4.0, Color(0.02, 0.02, 0.015, 0.88))
		draw_arc(p, radius + 3.0, 0.0, TAU, 32, Color(0.95, 0.78, 0.22, 0.78), 1.5, true)
		draw_line(p + Vector2(-radius, 0.0), p + Vector2(radius, 0.0), Color(0.95, 0.78, 0.22, 0.92), 1.5, true)
		draw_line(p + Vector2(0.0, -radius), p + Vector2(0.0, radius), Color(0.95, 0.78, 0.22, 0.92), 1.5, true)

func _draw_structures(map_rect: Rect2, key: String, color: Color) -> void:
	var structures_v: Variant = _map_data.get(key, [])
	if typeof(structures_v) != TYPE_ARRAY:
		return
	var half: float = clampf(minf(map_rect.size.x, map_rect.size.y) * 0.025, 4.0, 8.0)
	for structure_any in structures_v as Array:
		if typeof(structure_any) != TYPE_DICTIONARY:
			continue
		var structure: Dictionary = structure_any as Dictionary
		var pos: Vector2 = _entry_pos(structure)
		if pos.x < 0.0 or pos.y < 0.0:
			continue
		var p: Vector2 = _project(pos, map_rect)
		draw_rect(Rect2(p - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), Color(0.0, 0.0, 0.0, 0.7), true)
		draw_rect(Rect2(p - Vector2(half - 1.0, half - 1.0), Vector2((half - 1.0) * 2.0, (half - 1.0) * 2.0)), color, true)

func _draw_walls(map_rect: Rect2) -> void:
	var walls_v: Variant = _map_data.get("walls", [])
	if typeof(walls_v) != TYPE_ARRAY:
		return
	for wall_any in walls_v as Array:
		if typeof(wall_any) != TYPE_DICTIONARY:
			continue
		var wall: Dictionary = wall_any as Dictionary
		if wall.has("x1") and wall.has("y1") and wall.has("x2") and wall.has("y2"):
			var a: Vector2 = _project(Vector2(float(wall.get("x1")), float(wall.get("y1"))), map_rect)
			var b: Vector2 = _project(Vector2(float(wall.get("x2")), float(wall.get("y2"))), map_rect)
			draw_line(a, b, Color(0.76, 0.76, 0.82, 0.75), 3.0, true)

func _map_rect(rect: Rect2) -> Rect2:
	var pad: float = 14.0
	var available: Rect2 = rect.grow(-pad)
	var grid_aspect: float = _grid_size.x / maxf(1.0, _grid_size.y)
	var target_w: float = available.size.x
	var target_h: float = target_w / grid_aspect
	if target_h > available.size.y:
		target_h = available.size.y
		target_w = target_h * grid_aspect
	var origin: Vector2 = available.position + (available.size - Vector2(target_w, target_h)) * 0.5
	return Rect2(origin, Vector2(target_w, target_h))

func _project(pos: Vector2, map_rect: Rect2) -> Vector2:
	var gx: float = clampf(pos.x, 0.0, maxf(0.0, _grid_size.x - 1.0))
	var gy: float = clampf(pos.y, 0.0, maxf(0.0, _grid_size.y - 1.0))
	return Vector2(
		map_rect.position.x + (gx / maxf(1.0, _grid_size.x - 1.0)) * map_rect.size.x,
		map_rect.position.y + (gy / maxf(1.0, _grid_size.y - 1.0)) * map_rect.size.y
	)

func _entry_pos(entry: Dictionary) -> Vector2:
	var gp_v: Variant = entry.get("grid_pos", null)
	if typeof(gp_v) == TYPE_ARRAY:
		var gp: Array = gp_v as Array
		if gp.size() >= 2:
			return Vector2(float(gp[0]), float(gp[1]))
	var pos_v: Variant = entry.get("pos", null)
	if typeof(pos_v) == TYPE_DICTIONARY:
		var pos: Dictionary = pos_v as Dictionary
		return Vector2(float(pos.get("x", pos.get("gx", -1))), float(pos.get("y", pos.get("gy", -1))))
	if entry.has("x") and entry.has("y"):
		return Vector2(float(entry.get("x", -1)), float(entry.get("y", -1)))
	return Vector2(-1, -1)

func _resolve_grid_size(map_data: Dictionary) -> Vector2:
	var grid_w: float = float(map_data.get("grid_w", map_data.get("width", 18)))
	var grid_h: float = float(map_data.get("grid_h", map_data.get("height", 28)))
	return Vector2(maxf(1.0, grid_w), maxf(1.0, grid_h))

func _owner_color(owner_id: int) -> Color:
	match owner_id:
		1:
			return Color(0.25, 0.62, 1.0, 1.0)
		2:
			return Color(1.0, 0.26, 0.24, 1.0)
		3:
			return Color(0.22, 0.95, 0.46, 1.0)
		4:
			return Color(0.92, 0.44, 1.0, 1.0)
		_:
			return Color(0.95, 0.78, 0.28, 1.0)
