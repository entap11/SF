class_name BuffFreezeLanePresentation
extends Node2D

# A read-only projection of the authoritative buff snapshot. The simulation
# decides activation, remaining time, target loss and expiry. Animation never
# submits commands or changes lane/unit state.
const TICK_SECONDS: float = 0.1
const BURST_SECONDS: float = 0.65
const THAW_TICKS: int = 6
const MAX_CRYSTALS: int = 48
const ICE: Color = Color(0.62, 0.91, 1.0)
const WHITE_ICE: Color = Color(0.91, 0.99, 1.0)

var _lane_renderer: Node2D
var _arena: Node
var _match_id: String = ""
var _tick: int = -1
var _subtick: float = 0.0
var _motion: String = "full"
var _active: Dictionary = {}
var _thaws: Dictionary = {}
var _marker_styles: Dictionary = {}

func _ready() -> void:
	z_as_relative = false
	z_index = -2 # Above lane art, below ordinary units and hives.
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)

func setup(arena_ref: Node, lane_renderer_ref: Node2D) -> void:
	_arena = arena_ref
	_lane_renderer = lane_renderer_ref
	clear_presentation()

func apply_authoritative_snapshot(snapshot: Dictionary, motion_mode: String = "full") -> void:
	var match_id: String = str(snapshot.get("match_id", ""))
	var tick: int = int(snapshot.get("tick", 0))
	if match_id != _match_id or tick < _tick:
		clear_presentation()
	_match_id = match_id
	if tick != _tick:
		_subtick = 0.0
	_tick = tick
	_motion = motion_mode if motion_mode in ["full", "reduced", "none"] else "full"
	var next: Dictionary = {}
	var effects: Variant = snapshot.get("effects", [])
	if effects is Array:
		for value: Variant in effects:
			if not value is Dictionary:
				continue
			var effect: Dictionary = value
			var id: String = str(effect.get("activation_id", ""))
			if str(effect.get("match_id", match_id)) != match_id:
				continue
			if str(effect.get("buff_id", "")) != "FREEZE_LANE" or id.is_empty():
				continue
			if str(effect.get("status", "active")) != "active" or str(effect.get("target_type", "")) != "lane":
				continue
			if int(effect.get("target_id", -1)) <= 0 or int(effect.get("expires_tick", 0)) <= tick:
				continue
			if int(effect.get("started_tick", tick)) > tick:
				continue
			next[id] = effect.duplicate(true)
			_thaws.erase(id)
	for id: String in _active:
		if next.has(id):
			continue
		var old: Dictionary = _active[id]
		var expiry: int = int(old.get("expires_tick", 0))
		# Target loss/replacement clears immediately. Only a just-expired effect
		# gets a cosmetic thaw; reconnects must not replay an old ending.
		if _motion == "full" and tick >= expiry and tick < expiry + THAW_TICKS:
			_thaws[id] = old.duplicate(true)
	_active = next
	for id: String in _thaws.keys():
		if _motion != "full" or tick >= int((_thaws[id] as Dictionary).get("expires_tick", 0)) + THAW_TICKS:
			_thaws.erase(id)
	set_process(not _active.is_empty() or not _thaws.is_empty())
	queue_redraw()

func clear_presentation() -> void:
	_active.clear()
	_thaws.clear()
	_match_id = ""
	_tick = -1
	_subtick = 0.0
	set_process(false)
	queue_redraw()

func get_snapshot() -> Dictionary:
	var markers: Array = []
	for id: String in _active:
		var effect: Dictionary = _active[id]
		markers.append({
			"activation_id": id,
			"lane_id": int(effect.get("target_id", -1)),
			"remaining_ms": maxi(0, int(effect.get("expires_tick", _tick)) - _tick) * 100,
			"renderable": _lane_points(int(effect.get("target_id", -1))).size() >= 2
		})
	return {"active_count": _active.size(), "thaw_count": _thaws.size(), "tick": _tick,
		"motion_mode": _motion, "markers": markers, "processing": is_processing()}

func _process(delta: float) -> void:
	# Interpolate decoration by at most one tick. A stalled/paused simulation
	# cannot expire an effect or run its countdown from wall-clock time.
	_subtick = minf(TICK_SECONDS, _subtick + maxf(0.0, delta))
	queue_redraw()

func _draw() -> void:
	var lane_marker_counts: Dictionary = {}
	for id: String in _active:
		var effect: Dictionary = _active[id]
		var lane_id: int = int(effect.get("target_id", -1))
		var marker_index: int = int(lane_marker_counts.get(lane_id, 0))
		_draw_effect(effect, false, marker_index)
		lane_marker_counts[lane_id] = marker_index + 1
	for id: String in _thaws:
		_draw_effect(_thaws[id], true, 0)

func _draw_effect(effect: Dictionary, thawing: bool, marker_index: int) -> void:
	var points: PackedVector2Array = _lane_points(int(effect.get("target_id", -1)))
	if points.size() < 2:
		return
	var full_motion: bool = _motion == "full"
	var elapsed: float = float(_tick - int(effect.get("started_tick", _tick))) * TICK_SECONDS + (_subtick if full_motion else 0.0)
	var thaw: float = clampf((float(_tick - int(effect.get("expires_tick", _tick))) + _subtick / TICK_SECONDS) / float(THAW_TICKS), 0.0, 1.0) if thawing else 0.0
	var opacity: float = 1.0 - thaw
	var burst: float = maxf(0.0, 1.0 - elapsed / BURST_SECONDS) if full_motion and not thawing else 0.0
	var length: float = 0.0
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])
	if length < 1.0:
		return
	# Soft halo and translucent ice retain lane direction and moving units.
	draw_polyline(points, Color(0.18, 0.65, 1.0, 0.12 * opacity), 34.0 + burst * 24.0, true)
	draw_polyline(points, Color(0.37, 0.80, 1.0, 0.24 * opacity), 20.0, true)
	draw_polyline(points, Color(0.86, 0.98, 1.0, (0.30 + burst * 0.35) * opacity), 7.0, true)
	var count: int = clampi(int(length / 19.0), 4, MAX_CRYSTALS)
	for i in range(count):
		var sample: Dictionary = _sample_path(points, length * (float(i) + 0.5) / float(count))
		var center: Vector2 = sample["point"]
		var tangent: Vector2 = sample["tangent"]
		var normal: Vector2 = tangent.orthogonal()
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var size: float = 7.0 + float((i * 7) % 5) * 2.0 + burst * 9.0
		var drift: float = thaw * (16.0 + float(i % 4) * 7.0)
		var base: Vector2 = center + normal * side * (7.0 + drift)
		var shard := PackedVector2Array([base - tangent * 4.5, base + normal * side * size + tangent * 2.0, base + tangent * 6.0])
		draw_colored_polygon(shard, Color(0.56, 0.89, 1.0, 0.48 * opacity))
		draw_line(shard[0], shard[1], Color(0.91, 0.99, 1.0, 0.80 * opacity), 1.7, true)
		if full_motion and i % 3 == 0:
			var sparkle: float = 0.5 + 0.5 * sin(elapsed * 2.2 + float(i) * 1.7)
			draw_circle(shard[1], 1.4 + burst * 1.5, Color(0.92, 0.99, 1.0, sparkle * opacity))
	var middle: Dictionary = _sample_path(points, length * 0.5)
	var midpoint: Vector2 = middle["point"]
	if burst > 0.0:
		draw_arc(midpoint, 15.0 + (1.0 - burst) * 58.0, 0.0, TAU, 48, Color(0.73, 0.96, 1.0, burst * 0.8), 3.0, true)
	if not thawing:
		var normal: Vector2 = (middle["tangent"] as Vector2).orthogonal()
		var marker: Vector2 = midpoint + normal * (37.0 + float(marker_index) * 37.0)
		_draw_marker(marker, effect)

func _draw_marker(center: Vector2, effect: Dictionary) -> void:
	var owner_color := Color(0.65, 0.85, 1.0)
	if is_instance_valid(_arena) and _arena.has_method("get_buff_presentation_owner_color"):
		owner_color = _arena.call("get_buff_presentation_owner_color", int(effect.get("owner_id", 0))) as Color
	var panel := Rect2(center - Vector2(43, 16), Vector2(86, 32))
	draw_style_box(_marker_style(owner_color), panel)
	var snow_center: Vector2 = center - Vector2(27, 0)
	for arm in range(6):
		var dir := Vector2.from_angle(float(arm) * TAU / 6.0)
		var tip: Vector2 = snow_center + dir * 10.0
		draw_line(snow_center, tip, WHITE_ICE, 2.0, true)
		for side in [-1.0, 1.0]:
			draw_line(snow_center + dir * 6.0, snow_center + dir * 3.0 + dir.orthogonal() * float(side) * 3.0, ICE, 1.5, true)
	var remaining: float = float(maxi(0, int(effect.get("expires_tick", _tick)) - _tick)) * TICK_SECONDS
	draw_string(ThemeDB.fallback_font, center + Vector2(-11, 6), "%.1fs" % remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, WHITE_ICE)
	var duration: int = maxi(1, int(effect.get("duration_ticks", 1)))
	var fraction: float = clampf(float(int(effect.get("expires_tick", _tick)) - _tick) / float(duration), 0.0, 1.0)
	draw_line(panel.position + Vector2(5, 29), panel.position + Vector2(5 + 76.0 * fraction, 29), ICE, 2.0, true)

func _marker_style(color: Color) -> StyleBoxFlat:
	if not _marker_styles.has(color):
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.08, 0.13, 0.96)
		style.border_color = color
		style.set_border_width_all(2)
		style.set_corner_radius_all(9)
		_marker_styles[color] = style
	return _marker_styles[color]

func _lane_points(lane_id: int) -> PackedVector2Array:
	if not is_instance_valid(_lane_renderer) or not _lane_renderer.has_method("get_buff_target_lane_probe"):
		return PackedVector2Array()
	var probe: Dictionary = _lane_renderer.call("get_buff_target_lane_probe", lane_id) as Dictionary
	if not bool(probe.get("valid", false)):
		return PackedVector2Array()
	var result := PackedVector2Array()
	for point: Vector2 in probe.get("points", PackedVector2Array()):
		result.append(to_local(_lane_renderer.to_global(point)))
	return result

static func _sample_path(points: PackedVector2Array, distance: float) -> Dictionary:
	var left: float = maxf(0.0, distance)
	for i in range(1, points.size()):
		var delta: Vector2 = points[i] - points[i - 1]
		var length: float = delta.length()
		if length <= 0.0001:
			continue
		if left <= length or i == points.size() - 1:
			return {"point": points[i - 1] + delta * clampf(left / length, 0.0, 1.0), "tangent": delta / length}
		left -= length
	return {"point": points[0], "tangent": Vector2.RIGHT}
