class_name BuffHiveTargetingController
extends Node2D

signal selection_changed(pointer_session_id: int, hive_id: int, reason: String)

const ACQUISITION_RADIUS_SCREEN_PX: float = 52.0
const RETENTION_RADIUS_SCREEN_PX: float = 72.0
const TARGET_SWITCH_MARGIN_SCREEN_PX: float = 14.0
const VISIBLE_FOOTPRINT_PADDING_SCREEN_PX: float = 18.0
const RETENTION_EXTRA_SCREEN_PX: float = 20.0
const ELIGIBLE_RING_PAD_SCREEN_PX: float = 10.0
const PREVIEW_RING_PAD_SCREEN_PX: float = 18.0
const PULSE_HZ: float = 1.6
const DISTANCE_EPSILON_PX: float = 0.001

var _arena: Node = null
var _hive_renderer: Node = null
var _active: bool = false
var _pointer_session_id: int = 0
var _eligible_hive_ids: Array[int] = []
var _selected_hive_id: int = -1
var _finger_root_screen_pos: Vector2 = Vector2.ZERO
var _inside_arena: bool = false
var _pulse_phase: float = 0.0
var _phase_override: float = -1.0
var _draw_probes_by_id: Dictionary = {}
var _movement_event_count: int = 0
var _recompute_count: int = 0


func _ready() -> void:
	z_index = 30
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _active:
		clear(_pointer_session_id, true, "presentation_paused")


func setup(arena_ref: Node, hive_renderer_ref: Node) -> void:
	_arena = arena_ref
	_hive_renderer = hive_renderer_ref


func begin_or_update(
	pointer_session_id: int,
	eligible_hive_ids: Array,
	selected_hive_id: int,
	finger_root_screen_pos: Vector2
) -> bool:
	if pointer_session_id <= 0:
		return false
	if _active and pointer_session_id < _pointer_session_id:
		return false
	if not _active or pointer_session_id != _pointer_session_id:
		_reset_state(false, "session_replaced")
		_pointer_session_id = pointer_session_id
		_active = true
		set_process(true)
	_eligible_hive_ids = _normalized_hive_ids(eligible_hive_ids)
	_selected_hive_id = selected_hive_id if _eligible_hive_ids.has(selected_hive_id) else -1
	_finger_root_screen_pos = finger_root_screen_pos
	_movement_event_count += 1
	_recompute_selection("pointer_update")
	queue_redraw()
	return true


func update_finger(pointer_session_id: int, finger_root_screen_pos: Vector2) -> bool:
	if not _active or pointer_session_id != _pointer_session_id:
		return false
	_finger_root_screen_pos = finger_root_screen_pos
	_movement_event_count += 1
	_recompute_selection("pointer_update")
	queue_redraw()
	return true


func clear(pointer_session_id: int = -1, notify_shell: bool = true, reason: String = "cleared") -> bool:
	if not _active:
		return false
	if pointer_session_id >= 0 and pointer_session_id != _pointer_session_id:
		return false
	_reset_state(notify_shell, reason)
	return true


func notify_render_nodes_changed() -> void:
	if not _active:
		return
	_recompute_selection("render_nodes_changed")
	queue_redraw()


func force_recompute(reason: String = "forced") -> void:
	if not _active:
		return
	_recompute_selection(reason)
	queue_redraw()


func set_phase_override(phase: float) -> void:
	_phase_override = clampf(phase, 0.0, 1.0)
	_pulse_phase = _phase_override
	queue_redraw()


func clear_phase_override() -> void:
	_phase_override = -1.0


func get_snapshot() -> Dictionary:
	return {
		"active": _active,
		"pointer_session_id": _pointer_session_id,
		"eligible_hive_ids": _eligible_hive_ids.duplicate(),
		"selected_hive_id": _selected_hive_id,
		"inside_arena": _inside_arena,
		"pulse_phase": _pulse_phase,
		"renderable_hive_count": _draw_probes_by_id.size(),
		"movement_event_count": _movement_event_count,
		"recompute_count": _recompute_count,
		"acquisition_radius_screen_px": ACQUISITION_RADIUS_SCREEN_PX,
		"retention_radius_screen_px": RETENTION_RADIUS_SCREEN_PX,
		"target_switch_margin_screen_px": TARGET_SWITCH_MARGIN_SCREEN_PX
	}


func get_visual_state_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for hive_id: int in _eligible_hive_ids:
		if not _draw_probes_by_id.has(hive_id):
			continue
		var probe: Dictionary = _draw_probes_by_id[hive_id] as Dictionary
		var local_per_screen_px: float = maxf(0.001, float(probe.get("local_per_screen_px", 1.0)))
		var base_radius: float = float(probe.get("base_radius_local", 0.0))
		out[hive_id] = {
			"eligible": _inside_arena,
			"previewed": _inside_arena and hive_id == _selected_hive_id,
			"pulse_phase": _pulse_phase,
			"eligible_ring_radius_local": base_radius * 1.10 + ELIGIBLE_RING_PAD_SCREEN_PX * local_per_screen_px,
			"preview_ring_radius_local": base_radius * 1.10 + PREVIEW_RING_PAD_SCREEN_PX * local_per_screen_px,
			"render_instance_id": int(probe.get("render_instance_id", 0))
		}
	return out


func _process(_delta: float) -> void:
	if not _active:
		return
	_update_pulse_phase()
	# This bounded cached-ID pass also handles camera/canvas motion, hidden or
	# freed nodes, and stationary fingers without polling gameplay eligibility.
	_recompute_selection("presentation_tick")
	queue_redraw()


func _update_pulse_phase() -> void:
	if _phase_override >= 0.0:
		_pulse_phase = _phase_override
		return
	var seconds: float = float(Time.get_ticks_msec()) / 1000.0
	_pulse_phase = 0.5 + 0.5 * sin(seconds * TAU * PULSE_HZ)


func _recompute_selection(reason: String) -> void:
	_recompute_count += 1
	_draw_probes_by_id.clear()
	if _arena == null or _hive_renderer == null:
		_set_selected_hive(-1, "presentation_dependencies_missing")
		_inside_arena = false
		return
	if not _arena.has_method("root_screen_to_buff_arena_local"):
		_set_selected_hive(-1, "coordinate_converter_missing")
		_inside_arena = false
		return
	var conversion_any: Variant = _arena.call("root_screen_to_buff_arena_local", _finger_root_screen_pos)
	var conversion: Dictionary = conversion_any as Dictionary if typeof(conversion_any) == TYPE_DICTIONARY else {}
	_inside_arena = bool(conversion.get("ok", false))
	if not _inside_arena:
		_set_selected_hive(-1, str(conversion.get("reason", "outside_arena")))
		return

	var candidates: Array[Dictionary] = []
	for hive_id: int in _eligible_hive_ids:
		var candidate: Dictionary = _candidate_for_hive(hive_id)
		if candidate.is_empty():
			continue
		candidates.append(candidate)
		_draw_probes_by_id[hive_id] = candidate

	var selected_candidate: Dictionary = _candidate_by_id(candidates, _selected_hive_id)
	var next_selected_id: int = -1
	if not selected_candidate.is_empty():
		var selected_distance: float = float(selected_candidate.get("distance_screen_px", INF))
		var selected_retention: float = float(selected_candidate.get("retention_radius_screen_px", RETENTION_RADIUS_SCREEN_PX))
		if selected_distance <= selected_retention + DISTANCE_EPSILON_PX:
			next_selected_id = _selected_hive_id
			var challenger: Dictionary = _nearest_acquirable(candidates, _selected_hive_id)
			if not challenger.is_empty():
				var challenger_distance: float = float(challenger.get("distance_screen_px", INF))
				if challenger_distance + TARGET_SWITCH_MARGIN_SCREEN_PX < selected_distance - DISTANCE_EPSILON_PX:
					next_selected_id = int(challenger.get("hive_id", -1))
	if next_selected_id <= 0:
		var nearest: Dictionary = _nearest_acquirable(candidates, -1)
		if not nearest.is_empty():
			next_selected_id = int(nearest.get("hive_id", -1))
	_set_selected_hive(next_selected_id, reason)


func _candidate_for_hive(hive_id: int) -> Dictionary:
	if not _hive_renderer.has_method("get_buff_target_probe"):
		return {}
	var probe_any: Variant = _hive_renderer.call("get_buff_target_probe", hive_id)
	var probe: Dictionary = probe_any as Dictionary if typeof(probe_any) == TYPE_DICTIONARY else {}
	if not bool(probe.get("ok", false)):
		return {}
	var center_local: Vector2 = probe.get("center_arena_local", Vector2.INF) as Vector2
	var edge_local: Vector2 = probe.get("radius_edge_arena_local", Vector2.INF) as Vector2
	var ring_center_local: Vector2 = probe.get("ring_center_arena_local", center_local) as Vector2
	var center_projection: Dictionary = _project_to_root(center_local)
	var edge_projection: Dictionary = _project_to_root(edge_local)
	if not bool(center_projection.get("ok", false)) or not bool(edge_projection.get("ok", false)):
		return {}
	var center_root: Vector2 = center_projection.get("root_screen_pos", Vector2.INF) as Vector2
	var edge_root: Vector2 = edge_projection.get("root_screen_pos", Vector2.INF) as Vector2
	var visible_radius_screen_px: float = center_root.distance_to(edge_root)
	if not is_finite(visible_radius_screen_px) or visible_radius_screen_px <= 0.0:
		return {}
	var acquisition_radius: float = maxf(
		ACQUISITION_RADIUS_SCREEN_PX,
		visible_radius_screen_px + VISIBLE_FOOTPRINT_PADDING_SCREEN_PX
	)
	var retention_radius: float = maxf(
		RETENTION_RADIUS_SCREEN_PX,
		acquisition_radius + RETENTION_EXTRA_SCREEN_PX
	)
	var base_radius_local: float = float(probe.get("base_radius_arena_local", 0.0))
	var local_per_screen_px: float = base_radius_local / visible_radius_screen_px
	return {
		"hive_id": hive_id,
		"distance_screen_px": _finger_root_screen_pos.distance_to(center_root),
		"acquisition_radius_screen_px": acquisition_radius,
		"retention_radius_screen_px": retention_radius,
		"center_controller_local": to_local(_arena_local_to_world(center_local)),
		"ring_center_controller_local": to_local(_arena_local_to_world(ring_center_local)),
		"base_radius_local": base_radius_local,
		"local_per_screen_px": local_per_screen_px,
		"render_instance_id": int(probe.get("render_instance_id", 0))
	}


func _project_to_root(arena_local_pos: Vector2) -> Dictionary:
	if _arena == null or not _arena.has_method("buff_arena_local_to_root_screen"):
		return {"ok": false, "reason": "projection_missing"}
	var projected_any: Variant = _arena.call("buff_arena_local_to_root_screen", arena_local_pos)
	return projected_any as Dictionary if typeof(projected_any) == TYPE_DICTIONARY else {}


func _arena_local_to_world(arena_local_pos: Vector2) -> Vector2:
	if _arena != null and _arena.has_method("buff_arena_local_to_world"):
		var world_any: Variant = _arena.call("buff_arena_local_to_world", arena_local_pos)
		if world_any is Vector2:
			return world_any as Vector2
	return arena_local_pos


func _nearest_acquirable(candidates: Array[Dictionary], excluded_hive_id: int) -> Dictionary:
	var best: Dictionary = {}
	for candidate: Dictionary in candidates:
		var hive_id: int = int(candidate.get("hive_id", -1))
		if hive_id == excluded_hive_id:
			continue
		var distance: float = float(candidate.get("distance_screen_px", INF))
		var acquisition_radius: float = float(candidate.get("acquisition_radius_screen_px", ACQUISITION_RADIUS_SCREEN_PX))
		if distance > acquisition_radius + DISTANCE_EPSILON_PX:
			continue
		if best.is_empty() or _candidate_precedes(candidate, best):
			best = candidate
	return best


func _candidate_precedes(candidate: Dictionary, current: Dictionary) -> bool:
	var candidate_distance: float = float(candidate.get("distance_screen_px", INF))
	var current_distance: float = float(current.get("distance_screen_px", INF))
	if candidate_distance < current_distance - DISTANCE_EPSILON_PX:
		return true
	if absf(candidate_distance - current_distance) <= DISTANCE_EPSILON_PX:
		return int(candidate.get("hive_id", 0)) < int(current.get("hive_id", 0))
	return false


func _candidate_by_id(candidates: Array[Dictionary], hive_id: int) -> Dictionary:
	if hive_id <= 0:
		return {}
	for candidate: Dictionary in candidates:
		if int(candidate.get("hive_id", -1)) == hive_id:
			return candidate
	return {}


func _set_selected_hive(hive_id: int, reason: String) -> void:
	if hive_id == _selected_hive_id:
		return
	_selected_hive_id = hive_id
	selection_changed.emit(_pointer_session_id, _selected_hive_id, reason)


func _reset_state(notify_shell: bool, reason: String) -> void:
	var previous_session_id: int = _pointer_session_id
	var previous_selected_id: int = _selected_hive_id
	_active = false
	_pointer_session_id = 0
	_eligible_hive_ids.clear()
	_selected_hive_id = -1
	_inside_arena = false
	_draw_probes_by_id.clear()
	set_process(false)
	queue_redraw()
	if notify_shell and previous_session_id > 0 and previous_selected_id > 0:
		selection_changed.emit(previous_session_id, -1, reason)


func _normalized_hive_ids(raw_ids: Array) -> Array[int]:
	var seen: Dictionary = {}
	var out: Array[int] = []
	for raw_id: Variant in raw_ids:
		var hive_id: int = int(raw_id)
		if hive_id <= 0 or seen.has(hive_id):
			continue
		seen[hive_id] = true
		out.append(hive_id)
	out.sort()
	return out


func _draw() -> void:
	if not _active or not _inside_arena:
		return
	for hive_id: int in _eligible_hive_ids:
		if not _draw_probes_by_id.has(hive_id):
			continue
		var probe: Dictionary = _draw_probes_by_id[hive_id] as Dictionary
		_draw_eligible_ring(probe, hive_id == _selected_hive_id)


func _draw_eligible_ring(probe: Dictionary, previewed: bool) -> void:
	var center: Vector2 = probe.get("ring_center_controller_local", Vector2.ZERO) as Vector2
	var base_radius: float = float(probe.get("base_radius_local", 0.0))
	var local_per_screen_px: float = maxf(0.001, float(probe.get("local_per_screen_px", 1.0)))
	var pulse: float = clampf(_pulse_phase, 0.0, 1.0)
	var eligible_radius: float = base_radius * 1.10 + ELIGIBLE_RING_PAD_SCREEN_PX * local_per_screen_px
	var eligible_width: float = maxf(1.5 * local_per_screen_px, 3.0 * local_per_screen_px)
	var eligible_color := Color(1.0, 1.0, 1.0, 0.22 + 0.36 * pulse)
	draw_arc(center, eligible_radius, 0.0, TAU, 72, eligible_color, eligible_width, true)
	if not previewed:
		return
	var preview_radius: float = base_radius * 1.10 + PREVIEW_RING_PAD_SCREEN_PX * local_per_screen_px
	var preview_width: float = maxf(4.5 * local_per_screen_px, eligible_width * 1.7)
	var preview_color := Color(1.0, 1.0, 1.0, 0.72 + 0.26 * pulse)
	draw_arc(center, preview_radius, 0.0, TAU, 84, preview_color, preview_width, true)
	var outer_color := Color(1.0, 1.0, 1.0, 0.26 + 0.32 * pulse)
	draw_arc(center, preview_radius + 7.0 * local_per_screen_px, 0.0, TAU, 84, outer_color, 2.0 * local_per_screen_px, true)
