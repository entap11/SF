class_name BuffEffectPresentation
extends Node2D

# Disposable visual projection. Only snapshots establish active effects; only
# simulation events establish an ending or a successful Supercharge release.
const Definitions := preload("res://scripts/state/buff_definitions.gd")
const PathSampler := preload("res://scripts/renderers/buff_freeze_lane_presentation.gd")
const TICK_SECONDS: float = 0.1
const END_TICKS: int = 7
const MAX_ENDINGS: int = 24
const COLORS: Dictionary = {
	"shield": Color(0.40, 0.83, 1.0), "shock": Color(0.80, 0.64, 1.0),
	"production": Color(0.39, 1.0, 0.70), "speed": Color(0.63, 0.96, 1.0),
	"swarm": Color(1.0, 0.55, 0.28), "impact": Color(1.0, 0.79, 0.30),
	"queue": Color(1.0, 0.77, 0.30), "turn": Color(0.92, 0.54, 1.0)
}

var _arena: Node
var _hives: Node2D
var _lanes: Node2D
var _match_id: String = ""
var _tick: int = -1
var _subtick: float = 0.0
var _motion: String = "full"
var _active: Dictionary = {}
var _endings: Dictionary = {}
var _styles: Dictionary = {}

func _ready() -> void:
	z_as_relative = false
	z_index = -1 # Lane decoration remains behind bees, hive art and power labels.
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)

func setup(arena: Node, hives: Node2D, lanes: Node2D) -> void:
	_arena = arena
	_hives = hives
	_lanes = lanes
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
	_active.clear()
	for value: Variant in snapshot.get("effects", []):
		if not value is Dictionary:
			continue
		var effect: Dictionary = value
		var id: String = str(effect.get("activation_id", ""))
		if id.is_empty() or str(effect.get("match_id", match_id)) != match_id or match_id.is_empty():
			continue
		if motif(str(effect.get("buff_id", ""))).is_empty() or str(effect.get("status", "")) != "active":
			continue
		if int(effect.get("started_tick", tick)) > tick or int(effect.get("expires_tick", 0)) <= tick:
			continue
		_active[id] = effect.duplicate(true)
	for id: String in _endings.keys():
		var ending: Dictionary = _endings[id]
		if _motion != "full" or tick >= int(ending.get("tick", 0)) + END_TICKS:
			_endings.erase(id)
	_update_processing()
	queue_redraw()

func handle_lifecycle_event(event: Dictionary) -> void:
	var effect: Dictionary = event.get("effect", {})
	var id: String = str(effect.get("activation_id", ""))
	# Never replay terminal events for an effect this view has not observed.
	if not _active.has(id) or str(effect.get("match_id", "")) != _match_id:
		return
	_active.erase(id)
	if _motion == "full" and str(event.get("reason", "")) == "timer_expired":
		var ending: Dictionary = event.duplicate(true)
		ending["released"] = str(event.get("event", "")) == "supercharge_released" and int(event.get("released_units", 0)) > 0
		_endings[id] = ending
		while _endings.size() > MAX_ENDINGS:
			_endings.erase(_endings.keys()[0])
	_update_processing()
	queue_redraw()

func clear_presentation() -> void:
	_active.clear()
	_endings.clear()
	_match_id = ""
	_tick = -1
	_subtick = 0.0
	set_process(false)
	queue_redraw()

func _update_processing() -> void:
	set_process(_motion == "full" and (not _active.is_empty() or not _endings.is_empty()))

func _process(delta: float) -> void:
	_subtick = minf(TICK_SECONDS, _subtick + maxf(0.0, delta))
	queue_redraw()

func get_snapshot() -> Dictionary:
	var markers: Array = []
	for id: String in _active:
		var effect: Dictionary = _active[id]
		markers.append({"activation_id": id, "motif": motif(str(effect.get("buff_id", ""))),
			"remaining_ms": maxi(0, int(effect.get("expires_tick", _tick)) - _tick) * 100,
			"hive_ids": _hive_ids(effect), "queued_units": int(effect.get("queued_units", 0)),
			"target_type": effect.get("target_type", ""), "target_id": effect.get("target_id", null)})
	var releases: int = 0
	for ending: Dictionary in _endings.values():
		if bool(ending.get("released", false)):
			releases += 1
	return {"active_count": _active.size(), "ending_count": _endings.size(), "release_count": releases,
		"markers": markers, "tick": _tick, "motion_mode": _motion, "processing": is_processing()}

static func motif(buff_id: String) -> String:
	match buff_id:
		Definitions.HIVE_SHIELD_SINGLE, Definitions.HIVE_SHIELD_GLOBAL: return "shield"
		Definitions.HIVE_SHOCK_IMMUNITY, Definitions.HIVE_GLOBAL_SHOCK_IMMUNITY: return "shock"
		Definitions.HIVE_SINGLE_PRODUCTION_BOOST, Definitions.HIVE_GLOBAL_PRODUCTION_BOOST: return "production"
		Definitions.UNIT_SPEED: return "speed"
		Definitions.UNIT_SWARM_DAMAGE: return "swarm"
		Definitions.UNIT_HIVE_IMPACT_DAMAGE: return "impact"
		Definitions.HIVE_SUPERCHARGE_QUEUE: return "queue"
		Definitions.LANE_TREACHEROUS: return "turn"
	return "" # Freeze retains its approved renderer.

func _hive_ids(effect: Dictionary) -> Array:
	if str(effect.get("target_type", "")) == "hive":
		return [int(effect.get("target_id", -1))]
	if str(effect.get("buff_id", "")) in [Definitions.HIVE_SHIELD_GLOBAL, Definitions.HIVE_GLOBAL_SHOCK_IMMUNITY, Definitions.HIVE_GLOBAL_PRODUCTION_BOOST]:
		# Use the simulation's pruned activation scope. New or recaptured hives
		# must not acquire decoration by inspecting current visual ownership.
		return (effect.get("scoped_hive_ids", []) as Array).duplicate()
	return []

func _draw() -> void:
	var stacks: Dictionary = {}
	for id: String in _active:
		_draw_effect(_active[id], {}, stacks)
	for id: String in _endings:
		var ending: Dictionary = _endings[id]
		_draw_effect(ending.get("effect", {}), ending, stacks)

func _draw_effect(effect: Dictionary, ending: Dictionary, stacks: Dictionary) -> void:
	var kind: String = motif(str(effect.get("buff_id", "")))
	var elapsed: float = float(_tick - int(effect.get("started_tick", _tick))) * TICK_SECONDS + (_subtick if _motion == "full" else 0.0)
	var fade: float = 0.0 if ending.is_empty() else clampf((float(_tick - int(ending.get("tick", _tick))) + _subtick / TICK_SECONDS) / END_TICKS, 0.0, 1.0)
	var burst: float = maxf(0.0, 1.0 - elapsed / 0.6) if _motion == "full" and ending.is_empty() else 0.0
	var color: Color = COLORS.get(kind, Color.WHITE)
	color.a = 1.0 - fade
	var target_type: String = str(effect.get("target_type", ""))
	if target_type == "lane":
		_draw_lane(effect, ending, kind, color, elapsed, burst, fade, stacks)
		return
	var ids: Array = _hive_ids(effect)
	for hive_id: int in ids:
		var geometry: Dictionary = _hive_geometry(hive_id)
		if geometry.is_empty():
			continue
		var center: Vector2 = geometry["center"]
		var stack_key: String = "hive:%d" % hive_id
		var stack: int = int(stacks.get(stack_key, 0))
		stacks[stack_key] = stack + 1
		var radius: float = float(geometry["radius"]) + 12.0 + stack * 12.0
		_draw_hive_aura(center, radius, kind, color, elapsed, burst, fade)
		if ending.is_empty():
			_draw_badge(center + Vector2(0, radius + 22.0 + stack * 24.0), effect, kind, color, target_type == "global")
	if ids.is_empty() and kind in ["swarm", "impact"]:
		_draw_global(effect, kind, color, burst, ending.is_empty(), stacks)

func _draw_hive_aura(center: Vector2, radius: float, kind: String, color: Color, elapsed: float, burst: float, fade: float) -> void:
	var phase: float = elapsed if _motion == "full" else 0.0
	var r: float = radius + fade * 14.0
	draw_arc(center, r, 0.0, TAU, 48, Color(color, color.a * 0.14), 12.0 + burst * 16.0, true)
	match kind:
		"shield":
			var shell := PackedVector2Array()
			for i in range(7):
				shell.append(center + Vector2.from_angle(-PI / 2.0 + float(i) * TAU / 6.0) * r)
			draw_colored_polygon(shell, Color(color, color.a * 0.08))
			draw_polyline(shell, Color(color, color.a * 0.86), 2.5 + burst * 2.0, true)
			draw_arc(center, r + 6.0, -PI * 0.85, -PI * 0.15, 30, Color(color, color.a * 0.5), 2.0, true)
		"shock":
			for i in range(6):
				var angle: float = float(i) * TAU / 6.0
				draw_arc(center, r, angle + 0.1, angle + 0.75, 10, color, 3.0, true)
				var p: Vector2 = center + Vector2.from_angle(angle) * (r + 4.0)
				_draw_glyph(p, "shock", color, 0.65)
		"production":
			for i in range(3):
				var angle: float = float(i) * TAU / 3.0 + phase * 0.65
				draw_arc(center, r, angle, angle + 1.1, 16, color, 3.5, true)
				var p: Vector2 = center + Vector2.from_angle(angle + 1.1) * r
				draw_circle(p, 3.0 + burst * 3.0, Color(color, color.a * 0.9))
		"speed":
			for side in [-1.0, 1.0]:
				for i in range(3):
					var p: Vector2 = center + Vector2(float(side) * (r + 4.0 + i * 8.0), -float(i) * 3.0)
					draw_polyline(PackedVector2Array([p + Vector2(-4, 9), p + Vector2(4, 0), p + Vector2(-4, -9)]), Color(color, color.a * (1.0 - i * 0.2)), 2.5, true)
	if burst > 0.0:
		draw_arc(center, r + (1.0 - burst) * 26.0, 0.0, TAU, 48, Color(color, burst * 0.75), 3.0, true)

func _draw_lane(effect: Dictionary, ending: Dictionary, kind: String, color: Color, elapsed: float, burst: float, fade: float, stacks: Dictionary) -> void:
	var points: PackedVector2Array = _lane_points(int(effect.get("target_id", -1)))
	if points.size() < 2:
		return
	var length: float = 0.0
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])
	if length < 1.0:
		return
	var middle: Dictionary = PathSampler._sample_path(points, length * 0.5)
	var center: Vector2 = middle["point"]
	var normal: Vector2 = (middle["tangent"] as Vector2).orthogonal()
	draw_polyline(points, Color(color, color.a * 0.12), 24.0 + burst * 16.0, true)
	if kind == "turn":
		# Paired U-turns carry no guessed source direction or ownership change.
		for i in range(clampi(int(length / 100.0), 2, 10)):
			var p: Dictionary = PathSampler._sample_path(points, length * (float(i) + 0.5) / float(clampi(int(length / 100.0), 2, 10)))
			_draw_glyph(p["point"], "turn", Color(color, color.a * 0.75), 0.8)
	else:
		var target: Dictionary = effect.get("target", {})
		var source_a: bool = bool(target.get("source_is_a", true))
		var source: Dictionary = PathSampler._sample_path(points, minf(45.0, length * 0.15) if source_a else maxf(0.0, length - 45.0))
		var count: int = maxi(0, int(effect.get("queued_units", 0)))
		for i in range(mini(count, 8)):
			var angle: float = float(i) * TAU / 8.0 + (elapsed * 0.5 if _motion == "full" else 0.0)
			draw_circle((source["point"] as Vector2) + Vector2.from_angle(angle) * 20.0, 3.2, color)
		if bool(ending.get("released", false)):
			var distance: float = length * fade if source_a else length * (1.0 - fade)
			var front: Dictionary = PathSampler._sample_path(points, distance)
			draw_circle(front["point"], 12.0, Color(color, color.a * 0.25))
			_draw_glyph(front["point"], "queue", color, 1.1)
	if burst > 0.0:
		draw_arc(center, 12.0 + (1.0 - burst) * 42.0, 0, TAU, 40, Color(color, burst), 3.0, true)
	if ending.is_empty():
		var key: String = "lane:%s" % str(effect.get("target_id", -1))
		var stack: int = int(stacks.get(key, 0))
		stacks[key] = stack + 1
		# Opposite side from the approved Freeze marker to support overlap.
		_draw_badge(center - normal * (38.0 + stack * 40.0), effect, kind, color, false)

func _draw_global(effect: Dictionary, kind: String, color: Color, burst: float, active: bool, stacks: Dictionary) -> void:
	if not is_instance_valid(_arena) or not _arena.has_method("get_buff_global_presentation_boundary"):
		return
	var probe: Dictionary = _arena.call("get_buff_global_presentation_boundary")
	if not bool(probe.get("valid", false)):
		return
	var points := PackedVector2Array()
	for p: Vector2 in probe.get("boundary_arena_local_points", PackedVector2Array()):
		points.append(to_local((get_parent() as Node2D).to_global(p)))
	if points.size() < 4:
		return
	var start: Vector2 = points[0]
	var end: Vector2 = points[1]
	if points[0] != points[-1]:
		points.append(points[0])
	draw_polyline(points, Color(color, color.a * (0.22 + burst * 0.4)), 3.0 + burst * 6.0, true)
	if active:
		var stack: int = int(stacks.get("global", 0))
		stacks["global"] = stack + 1
		_draw_badge(start.lerp(end, 0.5) + Vector2(0, 24 + stack * 40), effect, kind, color, true)

func _draw_badge(center: Vector2, effect: Dictionary, kind: String, color: Color, global_scope: bool) -> void:
	var remaining: float = maxi(0, int(effect.get("expires_tick", _tick)) - _tick) * TICK_SECONDS
	var text: String = "%.1fs" % remaining
	if kind == "queue":
		text = "+%d  %s" % [int(effect.get("queued_units", 0)), text]
	var width: float = 144.0 if kind == "queue" else 108.0
	var panel := Rect2(center - Vector2(width * 0.5, 17), Vector2(width, 34))
	var owner: Color = Color.WHITE
	if is_instance_valid(_arena) and _arena.has_method("get_buff_presentation_owner_color"):
		owner = _arena.call("get_buff_presentation_owner_color", int(effect.get("owner_id", 0)))
	if not _styles.has(owner):
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.04, 0.065, 0.96)
		style.border_color = owner
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		_styles[owner] = style
	draw_style_box(_styles[owner], panel)
	_draw_glyph(panel.position + Vector2(18, 16), kind, color, 0.8)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(35, 23), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.98, 1.0))
	var fraction: float = clampf(float(int(effect.get("expires_tick", _tick)) - _tick) / float(maxi(1, int(effect.get("duration_ticks", 1)))), 0.0, 1.0)
	draw_line(panel.position + Vector2(5, 31), panel.position + Vector2(5 + (width - 10) * fraction, 31), color, 2.0, true)
	if global_scope:
		for i in range(3):
			draw_circle(panel.position + Vector2(width - 8 + i * 4, -3), 2.3, color)

func _draw_glyph(center: Vector2, kind: String, color: Color, scale: float = 1.0) -> void:
	var points := PackedVector2Array()
	match kind:
		"shield": points = PackedVector2Array([Vector2(-9,-9), Vector2(9,-9), Vector2(8,3), Vector2(0,11), Vector2(-8,3), Vector2(-9,-9)])
		"shock": points = PackedVector2Array([Vector2(4,-11), Vector2(-6,1), Vector2(2,1), Vector2(-4,11), Vector2(7,-2), Vector2(0,-2), Vector2(4,-11)])
		"production": points = PackedVector2Array([Vector2(-8,3), Vector2(0,-7), Vector2(8,3), Vector2(0,11), Vector2(-8,3)])
		"turn": points = PackedVector2Array([Vector2(-8,9), Vector2(-8,-5), Vector2(-3,-10), Vector2(4,-10), Vector2(9,-5), Vector2(9,5), Vector2(3,-1), Vector2(9,5), Vector2(15,-1)])
		"speed", "queue": points = PackedVector2Array([Vector2(-10,-8), Vector2(-2,0), Vector2(-10,8), Vector2(-2,0), Vector2(-10,-8)])
		"swarm": points = PackedVector2Array([Vector2(-9,-9), Vector2(9,9), Vector2(0,0), Vector2(9,-9), Vector2(-9,9)])
		"impact": points = PackedVector2Array([Vector2(0,-12), Vector2(3,-4), Vector2(11,-6), Vector2(5,1), Vector2(11,8), Vector2(2,5), Vector2(-3,12), Vector2(-4,3), Vector2(-12,1), Vector2(-4,-3), Vector2(0,-12)])
	for i in range(points.size()):
		points[i] = center + points[i] * scale
	if points.size() > 1:
		draw_polyline(points, color, 2.2, true)
	if kind in ["speed", "queue"]:
		draw_polyline(PackedVector2Array([center + Vector2(0,-8) * scale, center + Vector2(8,0) * scale, center + Vector2(0,8) * scale]), color, 2.2, true)

func _hive_geometry(id: int) -> Dictionary:
	if not is_instance_valid(_hives) or not _hives.has_method("get_buff_target_probe") or not get_parent() is Node2D:
		return {}
	var probe: Dictionary = _hives.call("get_buff_target_probe", id)
	if not bool(probe.get("ok", false)):
		return {}
	var parent_2d: Node2D = get_parent()
	var center: Vector2 = to_local(parent_2d.to_global(probe.get("center_arena_local", Vector2.ZERO)))
	var edge: Vector2 = to_local(parent_2d.to_global(probe.get("radius_edge_arena_local", Vector2.ZERO)))
	return {"center": center, "radius": center.distance_to(edge)}

func _lane_points(id: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	if not is_instance_valid(_lanes) or not _lanes.has_method("get_buff_target_lane_probe"):
		return points
	var probe: Dictionary = _lanes.call("get_buff_target_lane_probe", id)
	if bool(probe.get("valid", false)):
		for p: Vector2 in probe.get("points", PackedVector2Array()):
			points.append(to_local(_lanes.to_global(p)))
	return points
