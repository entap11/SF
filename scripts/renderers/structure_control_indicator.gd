class_name StructureControlIndicator
extends RefCounted

const TeamVisuals := preload("res://scripts/renderers/team_visuals.gd")
const NPC_CIRCUIT_COLOR: Color = Color(0.55, 0.50, 0.70, 1.0)
const METAL_DARK: Color = Color(0.025, 0.028, 0.034, 0.76)
const METAL_MID: Color = Color(0.42, 0.45, 0.50, 0.78)
const METAL_EDGE: Color = Color(0.84, 0.88, 0.92, 0.56)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.58)

const TOWER_RADIUS_PX: float = 22.0
const BARRACKS_RADIUS_PX: float = 17.0
const BACK_WIDTH_PX: float = 7.5
const FACE_WIDTH_PX: float = 4.2
const ACCENT_WIDTH_PX: float = 2.3
const LOCK_WIDTH_PX: float = 1.8
const TICK_LEN_PX: float = 9.0
const TICK_BACK_WIDTH_PX: float = 4.0
const TICK_FACE_WIDTH_PX: float = 2.0
const GUIDE_START_PAD_PX: float = 11.0
const GUIDE_END_PAD_PX: float = 20.0
const GUIDE_START_WIDTH_PX: float = 15.0
const GUIDE_END_WIDTH_PX: float = 8.0
const GUIDE_CORE_WIDTH_PX: float = 1.3
const REQUIRED_HIVE_RING_EXTRA_PX: float = 5.0
const REQUIRED_HIVE_RING_WIDTH_PX: float = 1.7
const ARC_POINTS: int = 16
const FULL_ARC_POINTS: int = 72

static func draw_control_collar(
	drawer: CanvasItem,
	structure_pos: Vector2,
	structure: Dictionary,
	hives_by_id: Dictionary,
	structure_type: String
) -> int:
	var control_ids: Array = _control_ids_for(structure)
	if control_ids.is_empty():
		return 0

	var radius: float = TOWER_RADIUS_PX if structure_type == "tower" else BARRACKS_RADIUS_PX
	var entries: Array = _control_entries(structure_pos, control_ids, hives_by_id)
	if entries.is_empty():
		return 0

	_draw_backing(drawer, structure_pos, radius)
	var span: float = _segment_span(entries.size())
	var drawn: int = 0
	for entry_any in entries:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		_draw_control_guide(drawer, structure_pos, radius, entry)
		_draw_control_segment(drawer, structure_pos, radius, span, entry)
		drawn += 1

	if _structure_locked(structure, entries):
		var lock_owner: int = int(structure.get("owner_id", int(entries[0].get("owner_id", 0))))
		_draw_lock(drawer, structure_pos, radius, lock_owner)
	return drawn

static func _control_ids_for(structure: Dictionary) -> Array:
	var out: Array = []
	var control_v: Variant = structure.get("control_hive_ids", structure.get("required_hive_ids", []))
	if typeof(control_v) == TYPE_ARRAY:
		for id_v in control_v as Array:
			var id: int = int(id_v)
			if id > 0 and not out.has(id):
				out.append(id)
	if out.is_empty():
		var required_v: Variant = structure.get("required_hive_ids", [])
		if typeof(required_v) == TYPE_ARRAY:
			for id_v in required_v as Array:
				var id: int = int(id_v)
				if id > 0 and not out.has(id):
					out.append(id)
	return out

static func _control_entries(structure_pos: Vector2, control_ids: Array, hives_by_id: Dictionary) -> Array:
	var entries: Array = []
	for hive_id_v in control_ids:
		var hive_id: int = int(hive_id_v)
		var hive_any: Variant = hives_by_id.get(hive_id, {})
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		if hive.is_empty():
			continue
		var hive_pos_v: Variant = hive.get("world_pos", hive.get("pos", Vector2.ZERO))
		if not (hive_pos_v is Vector2):
			continue
		var hive_pos: Vector2 = hive_pos_v as Vector2
		var dir: Vector2 = hive_pos - structure_pos
		if dir.length_squared() <= 0.001:
			dir = Vector2.RIGHT
		var angle: float = dir.angle()
		entries.append({
			"hive_id": hive_id,
			"owner_id": int(hive.get("owner_id", 0)),
			"hive_pos": hive_pos,
			"hive_radius": float(hive.get("radius_px", 18.0)),
			"angle": angle,
			"dir": dir.normalized()
		})
	_sort_entries(entries)
	return entries

static func _sort_entries(entries: Array) -> void:
	for i in range(1, entries.size()):
		var current: Variant = entries[i]
		var j: int = i - 1
		while j >= 0 and _entry_angle_less(current, entries[j]):
			entries[j + 1] = entries[j]
			j -= 1
		entries[j + 1] = current

static func _entry_angle_less(a: Variant, b: Variant) -> bool:
	if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
		return false
	var ad: Dictionary = a as Dictionary
	var bd: Dictionary = b as Dictionary
	var aa: float = float(ad.get("angle", 0.0))
	var ba: float = float(bd.get("angle", 0.0))
	if not is_equal_approx(aa, ba):
		return aa < ba
	return int(ad.get("hive_id", 0)) < int(bd.get("hive_id", 0))

static func _segment_span(count: int) -> float:
	var denom: float = maxf(float(count), 5.0)
	return clampf((TAU / denom) * 0.56, 0.42, 0.78)

static func _draw_backing(drawer: CanvasItem, center: Vector2, radius: float) -> void:
	drawer.draw_arc(center, radius + 3.0, 0.0, TAU, FULL_ARC_POINTS, SHADOW, BACK_WIDTH_PX + 2.0)
	drawer.draw_arc(center, radius + 3.0, 0.0, TAU, FULL_ARC_POINTS, METAL_DARK, BACK_WIDTH_PX)
	drawer.draw_arc(center, radius + 3.0, 0.0, TAU, FULL_ARC_POINTS, METAL_MID, FACE_WIDTH_PX)
	drawer.draw_arc(center, radius + 3.0, 0.0, TAU, FULL_ARC_POINTS, METAL_EDGE, 0.75)

static func _draw_control_guide(
	drawer: CanvasItem,
	center: Vector2,
	radius: float,
	entry: Dictionary
) -> void:
	var dir_v: Variant = entry.get("dir", Vector2.RIGHT)
	var dir: Vector2 = dir_v as Vector2 if dir_v is Vector2 else Vector2.RIGHT
	if dir.length_squared() <= 0.001:
		return
	dir = dir.normalized()
	var hive_pos_v: Variant = entry.get("hive_pos", Vector2.ZERO)
	if not (hive_pos_v is Vector2):
		return
	var hive_pos: Vector2 = hive_pos_v as Vector2
	var hive_radius: float = maxf(8.0, float(entry.get("hive_radius", 18.0)))
	var guide_len: float = center.distance_to(hive_pos)
	if guide_len <= radius + hive_radius + GUIDE_START_PAD_PX:
		return
	var owner_id: int = int(entry.get("owner_id", 0))
	var base: Color = _owner_color(owner_id)
	var normal: Vector2 = Vector2(-dir.y, dir.x)
	var start: Vector2 = center + dir * (radius + GUIDE_START_PAD_PX)
	var end: Vector2 = hive_pos - dir * (hive_radius + GUIDE_END_PAD_PX)
	var fill: Color = base
	fill.a = 0.16 if owner_id > 0 else 0.12
	var edge: Color = base.lightened(0.15)
	edge.a = 0.34 if owner_id > 0 else 0.24
	var core: Color = base.lightened(0.28)
	core.a = 0.56 if owner_id > 0 else 0.38
	var p0: Vector2 = start + normal * (GUIDE_START_WIDTH_PX * 0.5)
	var p1: Vector2 = end + normal * (GUIDE_END_WIDTH_PX * 0.5)
	var p2: Vector2 = end - normal * (GUIDE_END_WIDTH_PX * 0.5)
	var p3: Vector2 = start - normal * (GUIDE_START_WIDTH_PX * 0.5)
	drawer.draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), fill)
	drawer.draw_line(p0, p1, edge, 0.85)
	drawer.draw_line(p3, p2, edge, 0.85)
	drawer.draw_line(start, end, core, GUIDE_CORE_WIDTH_PX)
	drawer.draw_arc(hive_pos, hive_radius + REQUIRED_HIVE_RING_EXTRA_PX, 0.0, TAU, FULL_ARC_POINTS, edge, REQUIRED_HIVE_RING_WIDTH_PX)

static func _draw_control_segment(
	drawer: CanvasItem,
	center: Vector2,
	radius: float,
	span: float,
	entry: Dictionary
) -> void:
	var angle: float = float(entry.get("angle", 0.0))
	var owner_id: int = int(entry.get("owner_id", 0))
	var dir_v: Variant = entry.get("dir", Vector2.RIGHT)
	var dir: Vector2 = dir_v as Vector2 if dir_v is Vector2 else Vector2.RIGHT
	var accent: Color = _owner_color(owner_id)
	var glow: Color = accent
	glow.a = 0.42 if owner_id > 0 else 0.34
	var core: Color = accent.lightened(0.18)
	core.a = 0.82 if owner_id > 0 else 0.66
	var a0: float = angle - span * 0.5
	var a1: float = angle + span * 0.5

	drawer.draw_arc(center, radius + 3.0, a0, a1, ARC_POINTS, glow, FACE_WIDTH_PX + 1.5)
	drawer.draw_arc(center, radius + 3.0, a0, a1, ARC_POINTS, core, ACCENT_WIDTH_PX)

	var tick_start: Vector2 = center + dir * (radius + 5.5)
	var tick_end: Vector2 = center + dir * (radius + 5.5 + TICK_LEN_PX)
	drawer.draw_line(tick_start, tick_end, SHADOW, TICK_BACK_WIDTH_PX)
	drawer.draw_line(tick_start, tick_end, core, TICK_FACE_WIDTH_PX)
	drawer.draw_circle(tick_start, 2.3, METAL_EDGE)
	drawer.draw_circle(tick_start, 1.25, core)

	var normal: Vector2 = Vector2(-dir.y, dir.x)
	var tip: Vector2 = tick_end + dir * 3.2
	var wing_a: Vector2 = tick_end - dir * 2.0 + normal * 2.4
	var wing_b: Vector2 = tick_end - dir * 2.0 - normal * 2.4
	drawer.draw_colored_polygon(PackedVector2Array([tip, wing_a, wing_b]), core)

static func _draw_lock(drawer: CanvasItem, center: Vector2, radius: float, owner_id: int) -> void:
	var lock_color: Color = _owner_color(owner_id)
	lock_color.a = 0.78 if owner_id > 0 else 0.54
	var inner: Color = lock_color.lightened(0.20)
	inner.a = lock_color.a
	drawer.draw_arc(center, radius - 2.0, 0.0, TAU, FULL_ARC_POINTS, lock_color, LOCK_WIDTH_PX + 1.2)
	drawer.draw_arc(center, radius - 4.2, 0.0, TAU, FULL_ARC_POINTS, inner, LOCK_WIDTH_PX)
	drawer.draw_circle(center, 2.2, inner)

static func _structure_locked(structure: Dictionary, entries: Array) -> bool:
	if entries.is_empty():
		return false
	var controlled: bool = bool(structure.get("is_controlled", false))
	var active: bool = bool(structure.get("active", controlled))
	if not controlled and not active:
		return false
	var owner_id: int = int(entries[0].get("owner_id", 0))
	for entry_any in entries:
		if typeof(entry_any) != TYPE_DICTIONARY:
			return false
		var entry: Dictionary = entry_any as Dictionary
		if int(entry.get("owner_id", 0)) != owner_id:
			return false
	return int(structure.get("owner_id", owner_id)) == owner_id

static func _owner_color(owner_id: int) -> Color:
	if owner_id <= 0:
		return NPC_CIRCUIT_COLOR
	return TeamVisuals.owner_color(owner_id)
