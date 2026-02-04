# NOTE: Gate/rate-limit lane debug logs to prevent per-frame spam.
# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.

class_name LaneRenderer
extends Node2D

const SFLog := preload("res://scripts/util/sf_log.gd")
const SpriteRegistry := preload("res://scripts/renderers/sprite_registry.gd")
const EdgeGeometry := preload("res://scripts/geo/edge_geometry.gd")
const EdgeVisual := preload("res://scripts/renderers/edge_visual.gd")
const EdgeEndpoints := preload("res://scripts/renderers/edge_endpoints.gd")
const COLORKEY_SHADER := preload("res://shaders/sf_colorkey_alpha.gdshader")
const LANE_BAND_SHADER := preload("res://shaders/lane_band.gdshader")
const HiveNodeScript := preload("res://scripts/hive/hive_node.gd")

@export var debug_lane_seg_overlay: bool = false
@export var debug_draw_magenta_x: bool = false
@export var debug_lane_metrics: bool = false
@export var show_lane_candidates_pre_game: bool = true
@export var show_lane_candidates_while_running: bool = false
@export var show_lane_sprites: bool = true
@export var debug_draw_endpoints: bool = false
@export var lane_thickness_mode: int = 0
@export var lane_thickness_px: float = 80.0
@export var lane_vs_unit_ratio: float = 0.85
@export var lane_start_cap_trim_px: float = 18.0
@export var lane_end_cap_trim_px: float = 18.0

const DEBUG_LANES := false
const USE_LANE_SPRITES := true
const AUDIT_RENDER: bool = true

const LANE_LOG_INTERVAL_MS := 1000
const LANE_FLASH_DEFAULT_MS := 250
const LANE_FLASH_WIDTH := 4.5
const LANE_FLASH_COLOR := Color(1.0, 0.9, 0.35, 0.9)
const LANE_INACTIVE_COLOR := Color(1.0, 1.0, 1.0, 0.18)
const LANE_CONTESTED_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const LANE_ACTIVE_ALPHA := 0.9
const LANE_SEGMENT_KEY := "lane.segment"
const LANE_CONNECTOR_KEY := "lane.connector"
const LANE_TEX_KEY := "lane.mvp"
const LANE_FALLBACK_PATH := "res://assets/sprites/sf_skin_v1/lane_mvp.png"
const LANE_SEGMENT_TARGET_PX := 40.0
const LANE_SEGMENT_SCALE := 1.0
const LANE_CONNECTOR_SCALE := 0.75
const LANE_MAX_SEGMENTS := 64
const LANE_Z_INDEX := -5
const LANE_CONNECTOR_AT_ENDPOINTS := false
# --- Lane sprite sizing ---
const LANE_THICKNESS_PX := 2.0
const LANE_WIDTH_PX := 14.0
const LANE_MIN_LEN_PX := 6.0
const LANE_SCALE_CLAMP := Vector2(10.0, 10.0)
const LANE_GROW_TIME_MS: float = 260.0
# Anchors are already lane-edge-biased; extra tuck visually shortens lanes too much.
const LANE_TUCK_IN_PX: float = 0.0
const LANE_THICKNESS_MODE_MANUAL: int = 0
const LANE_THICKNESS_MODE_MATCH_UNIT_RATIO: int = 1
const UNIT_RENDER_SCALE_MATCH: float = 3.0
const UNIT_RENDER_BASE_DIAMETER_PX: float = 20.0
const UNIT_THICKNESS_KEY: String = "unit.p1"
const DEBUG_PICK_DOT_MS := 200
const DEBUG_PICK_DOT_RADIUS := 3.5
const DEBUG_PICK_DOT_COLOR := Color(1.0, 0.2, 0.9, 0.9)

var state: GameState = null
var sel: Object = null
var arena: Node2D = null

var model: Dictionary = {}
var hive_nodes_by_id: Dictionary = {}
var _bootstrap_next_ms: int = 0
var _bootstrapped := false
var _last_changed_lane_id: int = -1
var _last_lane_log_ms: int = 0
var _sim_running: bool = false
var _lane_candidates_visible: bool = false
var _lane_flash_expire_by_id: Dictionary = {}
var _lane_tex: Texture2D = null
var _lane_connector_tex: Texture2D = null
var _lane_tex_has_alpha: bool = false
var _lane_connector_tex_has_alpha: bool = false
var _lane_nodes_by_key: Dictionary = {}
var _lane_key_by_id: Dictionary = {}
var _lane_sprite_root: Node2D = null
var _lane_colorkey_material: ShaderMaterial = null
var _lane_band_material: ShaderMaterial = null
var _rebuild_pending: bool = false
var _last_sig: String = ""
var _rebuild_req_reason: String = ""
var _debug_pick_dots: Array = []
var _lane_xform_logged: bool = false
var _lane_tex_logged: bool = false
var _lane_map_sig: String = ""
var _lane_scale_logged: Dictionary = {}
var _lane_endpoint_logged: Dictionary = {}
var _lane_align_logged: bool = false
var _lane_endpoints_audit_last_ms: int = 0
var _lane_endpoints_logged_this_rebuild: bool = false
var _anchor_proof_logged_this_rebuild: bool = false
var _lane_sprite_coverage_last_ms: int = 0
var _hive_cache_dirty: bool = true
var _hive_cache_map_sig: String = ""
var _hive_lane_anchor_local_by_id: Dictionary = {}
var _hive_meta_by_id: Dictionary = {}
var _anchor_world_by_hive_id: Dictionary = {}
var _hive_nodes_sig: int = 0
var _anchor_snapshot_sig: int = 0
var _anchor_snapshot_ready: bool = false
var _pending_snapshot_rebuild: bool = false
var _audit_last_ms: int = 0
var _audit_draw_ops: int = 0
var _audit_mat_sets: int = 0
var _audit_rebuilds: int = 0

func _lane_color_for_hive(hive_id: int) -> Color:
	var owner_id: int = 0
	if state != null:
		var hive: HiveData = state.find_hive_by_id(hive_id)
		if hive != null:
			owner_id = int(hive.owner_id)
	return _owner_color(owner_id)

func _owner_color(owner_id: int) -> Color:
	return HiveRenderer._owner_color(owner_id)

func _hive_world_pos(hive_id: int) -> Variant:
	var anchor_local_any: Variant = _hive_local_pos_for_lane(hive_id)
	if anchor_local_any is Vector2:
		return to_global(anchor_local_any as Vector2)
	return null

func _lane_anchor_world_from_center(center_world: Vector2) -> Vector2:
	return HiveNodeScript.lane_anchor_world_from_center(center_world)

func _hive_render_anchor_world_from_node(node: Node2D) -> Vector2:
	if node == null:
		return Vector2.ZERO

	# Debug visibility: if someone adds a generic child named "Anchor", it is NOT authoritative for lanes.
	# Log once per rebuild so it doesn't spam.
	if not _anchor_proof_logged_this_rebuild:
		var maybe_anchor: Node = node.get_node_or_null("Anchor")
		if maybe_anchor != null:
			SFLog.warn("LANE_NONAUTHORITATIVE_CHILD_ANCHOR_PRESENT", {
				"path": str(node.get_path()),
				"child": "Anchor"
			})

	# Authoritative hooks (explicit only)
	if node.has_method("get_lane_anchor_world"):
		var a_any: Variant = node.call("get_lane_anchor_world")
		if a_any is Vector2:
			return a_any as Vector2

	if node.has_method("get_hive_render_anchor_world"):
		var r_any: Variant = node.call("get_hive_render_anchor_world")
		if r_any is Vector2:
			return r_any as Vector2

	# Final fallback: node origin
	return node.global_position

func _maybe_log_anchor_proof(a_id: int, b_id: int, raw_a_local: Vector2, raw_b_local: Vector2, start_local: Vector2, end_local: Vector2) -> void:
	if _anchor_proof_logged_this_rebuild:
		return
	_anchor_proof_logged_this_rebuild = true
	SFLog.info("LANE_ANCHOR_PROOF", {
		"edge": "%d->%d" % [a_id, b_id],
		"raw_a": raw_a_local,
		"raw_b": raw_b_local,
		"start": start_local,
		"end": end_local,
		"hive_a_local": get_hive_render_anchor_local(a_id),
		"hive_b_local": get_hive_render_anchor_local(b_id)
	})

func _edge_geo_from_cache(lane_id: int, a_id: int, b_id: int) -> Variant:
	var edge_any: Variant = null
	if lane_id > 0:
		edge_any = OpsState.get_edge_for_lane_key(lane_id)
		if edge_any == null:
			edge_any = OpsState.get_edge_for_lane_key(str(lane_id))
	if edge_any == null and a_id > 0 and b_id > 0:
		edge_any = OpsState.get_edge_for_lane_key("%d->%d" % [a_id, b_id])
	return edge_any

func _edge_geo_to_endpoints_local(edge_any: Variant, a_center_local: Vector2, b_center_local: Vector2, a_id: int = -1, b_id: int = -1) -> Dictionary:
	var from_anchor_world: Vector2 = Vector2.ZERO
	var to_anchor_world: Vector2 = Vector2.ZERO
	var dir_world: Vector2 = Vector2.ZERO
	var src_id: int = -1
	var dst_id: int = -1
	if edge_any is EdgeGeometry:
		var edge: EdgeGeometry = edge_any as EdgeGeometry
		from_anchor_world = edge.a
		to_anchor_world = edge.b
		dir_world = edge.dir
		src_id = edge.src_id
		dst_id = edge.dst_id
	elif typeof(edge_any) == TYPE_DICTIONARY:
		var d: Dictionary = edge_any as Dictionary
		from_anchor_world = d.get("a", d.get("start", Vector2.ZERO))
		to_anchor_world = d.get("b", d.get("end", Vector2.ZERO))
		dir_world = d.get("dir", Vector2.ZERO)
		src_id = int(d.get("src_id", -1))
		dst_id = int(d.get("dst_id", -1))
	else:
		return {"ok": false}
	if a_id > 0 and b_id > 0 and src_id == b_id and dst_id == a_id:
		var swap: Vector2 = from_anchor_world
		from_anchor_world = to_anchor_world
		to_anchor_world = swap
		dir_world = -dir_world
	var trimmed: Dictionary = EdgeEndpoints.compute(from_anchor_world, to_anchor_world, EdgeEndpoints.EDGE_TUCK_PX)
	var start_world: Vector2 = trimmed.get("start", from_anchor_world)
	var end_world: Vector2 = trimmed.get("end", to_anchor_world)
	var a_local: Vector2 = to_local(start_world)
	var b_local: Vector2 = to_local(end_world)
	var lane_vec: Vector2 = b_local - a_local
	var lane_len: float = lane_vec.length()
	var lane_dir: Vector2 = Vector2.ZERO
	if lane_len > 0.000001:
		lane_dir = lane_vec / lane_len
	elif dir_world.length_squared() > 0.000001:
		lane_dir = (to_local(start_world + dir_world) - a_local).normalized()
	var lane_normal: Vector2 = Vector2.ZERO
	if lane_dir.length_squared() > 0.000001:
		lane_normal = Vector2(-lane_dir.y, lane_dir.x)
	a_local = EdgeVisual.lane_point(a_local, lane_normal)
	b_local = EdgeVisual.lane_point(b_local, lane_normal)
	var visual_vec: Vector2 = b_local - a_local
	var visual_len: float = visual_vec.length()
	if visual_len > 0.000001:
		lane_dir = visual_vec / visual_len
	return {
		"ok": true,
		"a_center": a_center_local,
		"b_center": b_center_local,
		"a_anchor": a_local,
		"b_anchor": b_local,
		"a": a_local,
		"b": b_local,
		"dir": lane_dir,
		"len": visual_len
	}

func _compute_lane_endpoints_world(a_anchor_world: Vector2, b_anchor_world: Vector2) -> Dictionary:
	var lane_vec: Vector2 = b_anchor_world - a_anchor_world
	var lane_len: float = lane_vec.length()
	var start_world: Vector2 = a_anchor_world
	var end_world: Vector2 = b_anchor_world
	var dir: Vector2 = Vector2.ZERO
	if lane_len > 0.000001:
		dir = lane_vec / lane_len
		var tuck: float = minf(LANE_TUCK_IN_PX, lane_len * 0.5)
		start_world = a_anchor_world + (dir * tuck)
		end_world = b_anchor_world - (dir * tuck)
	return {
		"a_anchor": a_anchor_world,
		"b_anchor": b_anchor_world,
		"a": start_world,
		"b": end_world,
		"dir": dir,
		"len": start_world.distance_to(end_world)
	}

func _maybe_log_lane_endpoints(a_anchor_world: Vector2, b_anchor_world: Vector2, start_world: Vector2, end_world: Vector2) -> void:
	if _lane_endpoints_logged_this_rebuild:
		return
	_lane_endpoints_logged_this_rebuild = true
	SFLog.info("LANE_ENDPOINTS", {
		"a": a_anchor_world,
		"b": b_anchor_world,
		"start": start_world,
		"end": end_world,
		"tuck": EdgeEndpoints.EDGE_TUCK_PX
	})

func _compute_lane_endpoints_from_centers_local(a_center_local: Vector2, b_center_local: Vector2, _a_id: int = -1, _b_id: int = -1, _lane_id: int = -1) -> Dictionary:
	var a_anchor_world: Vector2 = to_global(a_center_local)
	var b_anchor_world: Vector2 = to_global(b_center_local)
	var ep_world: Dictionary = _compute_lane_endpoints_world(a_anchor_world, b_anchor_world)
	var from_anchor_world: Vector2 = ep_world.get("a", a_anchor_world)
	var to_anchor_world: Vector2 = ep_world.get("b", b_anchor_world)
	var geo: EdgeGeometry = EdgeGeometry.build(
		_a_id,
		_b_id,
		from_anchor_world,
		to_anchor_world,
		lane_start_cap_trim_px,
		lane_end_cap_trim_px
	)
	var trimmed: Dictionary = EdgeEndpoints.compute(geo.a, geo.b, EdgeEndpoints.EDGE_TUCK_PX)
	var start_world: Vector2 = trimmed.get("start", geo.a)
	var end_world: Vector2 = trimmed.get("end", geo.b)
	var a_local: Vector2 = to_local(start_world)
	var b_local: Vector2 = to_local(end_world)
	var lane_vec: Vector2 = b_local - a_local
	var lane_len: float = lane_vec.length()
	var lane_dir: Vector2 = Vector2.ZERO
	if lane_len > 0.000001:
		lane_dir = lane_vec / lane_len
	var lane_normal: Vector2 = Vector2.ZERO
	if lane_dir.length_squared() > 0.000001:
		lane_normal = Vector2(-lane_dir.y, lane_dir.x)
	a_local = EdgeVisual.lane_point(a_local, lane_normal)
	b_local = EdgeVisual.lane_point(b_local, lane_normal)
	var visual_start_world: Vector2 = to_global(a_local)
	var visual_end_world: Vector2 = to_global(b_local)
	_maybe_log_lane_endpoints(a_anchor_world, b_anchor_world, visual_start_world, visual_end_world)
	if _a_id > 0 and _b_id > 0:
		_maybe_log_anchor_proof(_a_id, _b_id, a_center_local, b_center_local, a_local, b_local)
	var visual_vec: Vector2 = b_local - a_local
	var visual_len: float = visual_vec.length()
	if visual_len > 0.000001:
		lane_dir = visual_vec / visual_len
	return {
		"ok": true,
		"a_center": a_center_local,
		"b_center": b_center_local,
		"a_anchor": a_local,
		"b_anchor": b_local,
		"a": a_local,
		"b": b_local,
		"dir": lane_dir,
		"len": visual_len
	}

func compute_lane_endpoints_map_local(hive_a: Node2D, hive_b: Node2D) -> Dictionary:
	if hive_a == null or hive_b == null:
		return {}
	var a_anchor_world: Vector2 = _hive_render_anchor_world_from_node(hive_a)
	var b_anchor_world: Vector2 = _hive_render_anchor_world_from_node(hive_b)
	var a_center_local: Vector2 = to_local(a_anchor_world)
	var b_center_local: Vector2 = to_local(b_anchor_world)
	var a_id: int = int(hive_a.get("hive_id"))
	var b_id: int = int(hive_b.get("hive_id"))
	return _compute_lane_endpoints_from_centers_local(a_center_local, b_center_local, a_id, b_id)

func _build_lane_segments(rm: Dictionary) -> Array:
	# Returns array of {p0:Vector2, p1:Vector2, color:Color}
	var segs: Array = []

	var a_id: int = int(rm.get("a_id", -1))
	var b_id: int = int(rm.get("b_id", -1))
	if a_id < 0 or b_id < 0:
		return segs

	# Get hive world positions from your existing hive lookup.
	var a_pos: Variant = _hive_world_pos(a_id)
	var b_pos: Variant = _hive_world_pos(b_id)
	if a_pos == null or b_pos == null:
		return segs

	var p0: Vector2 = a_pos
	var p1: Vector2 = b_pos

	var send_a: bool = bool(rm.get("send_a", false))
	var send_b: bool = bool(rm.get("send_b", false))
	var color_a: Color = _lane_color_for_hive(a_id)
	var color_b: Color = _lane_color_for_hive(b_id)

	# If neither side active, render nothing (or keep your current idle render if desired).
	if not send_a and not send_b:
		return segs

	# Single-direction lane: full line in that team's color.
	if send_a and not send_b:
		segs.append({"p0": p0, "p1": p1, "color": color_a})
		return segs
	if send_b and not send_a:
		segs.append({"p0": p0, "p1": p1, "color": color_b})
		return segs

	# Contested: split at front_t.
	var t: float = clamp(float(rm.get("front_t", 0.5)), 0.0, 1.0)
	var impact: Vector2 = p0.lerp(p1, t)

	segs.append({"p0": p0, "p1": impact, "color": color_a})
	segs.append({"p0": p1, "p1": impact, "color": color_b})
	return segs

func _lane_color_for_t(send_a: bool, send_b: bool, color_a: Color, color_b: Color, t: float, front_t: float) -> Color:
	if send_a and send_b:
		return color_a if t <= front_t else color_b
	if send_a:
		return color_a
	if send_b:
		return color_b
	return LANE_INACTIVE_COLOR

func _make_lane_segment_sprite(from: Vector2, to: Vector2, tex: Texture2D) -> Sprite2D:
	if tex == null:
		return null
	var seg_len: float = from.distance_to(to)
	if seg_len < LANE_MIN_LEN_PX:
		return null
	var tex_w: float = float(tex.get_width())
	var tex_h: float = float(tex.get_height())
	if tex_w <= 0.0 or tex_h <= 0.0:
		return null

	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	sprite.centered = true
	sprite.rotation = (to - from).angle()
	sprite.position = (from + to) * 0.5
	sprite.material = _get_lane_band_material()

	var scale_x: float = seg_len / tex_w
	var scale_y: float = LANE_THICKNESS_PX / tex_h
	scale_x = clampf(scale_x, 0.0, LANE_SCALE_CLAMP.x)
	scale_y = clampf(scale_y, 0.0, LANE_SCALE_CLAMP.y)
	sprite.scale = Vector2(scale_x, scale_y)
	if DEBUG_LANES and debug_lane_metrics and not _lane_xform_logged:
		_lane_xform_logged = true
		SFLog.info("LANE_XFORM_DEBUG", {
			"sprite_scale": sprite.scale,
			"sprite_global_scale": sprite.global_scale,
			"lane_renderer_scale": global_scale
		})
	if false:
		SFLog.info("LANE_THICKNESS_DEBUG", {
			"tex_h": tex_h,
			"scale_y": scale_y,
			"thickness_px": scale_y * tex_h,
			"scale_x": scale_x
		})
	return sprite

func _ready() -> void:
	SFLog.allow_tag("RENDER_AUDIT_LANES")
	SFLog.allow_tag("LANE_ENDPOINTS")
	SFLog.allow_tag("LANE_EDGE_BIND")
	SFLog.allow_tag("LANE_ANCHOR_PROOF")
	SFLog.allow_tag("LANE_NONAUTHORITATIVE_CHILD_ANCHOR_PRESENT")
	SFLog.allow_tag("EDGE_VISUAL_OFFSETS")
	SFLog.allow_tag("LANE_SPRITE_COVERAGE")
	SFLog.allow_tag("LANE_ANCHOR_CACHE")
	SFLog.allow_tag("LANE_RENDER_REBUILD")
	SFLog.allow_tag("LANE_ANCHOR_SNAPSHOT_BUILT")
	SFLog.allow_tag("HIVE_NODES_SET_SKIPPED")
	_load_lane_textures()
	_ensure_lane_sprite_root()
	set_process(USE_LANE_SPRITES and show_lane_sprites)
	_lane_candidates_visible = false
	_request_rebuild("ready")

func _process(delta: float) -> void:
	if USE_LANE_SPRITES and show_lane_sprites:
		_update_lane_visuals(delta)
	if not _debug_pick_dots.is_empty():
		queue_redraw()
	_audit_render_maybe_flush()

func _audit_render_maybe_flush() -> void:
	if not AUDIT_RENDER:
		return
	var now_ms: int = Time.get_ticks_msec()
	if _audit_last_ms <= 0:
		_audit_last_ms = now_ms
		return
	if now_ms - _audit_last_ms < 1000:
		return
	SFLog.info("RENDER_AUDIT_LANES", {
		"lanes": _lane_nodes_by_key.size(),
		"draw_ops": _audit_draw_ops,
		"mat_sets": _audit_mat_sets,
		"rebuilds": _audit_rebuilds
	})
	_audit_last_ms = now_ms
	_audit_draw_ops = 0
	_audit_mat_sets = 0
	_audit_rebuilds = 0

# Arena expects this signature.
func setup(state_ref: GameState, selection_ref: Object, arena_ref: Node2D) -> void:
	state = state_ref
	sel = selection_ref
	arena = arena_ref
	_hive_cache_dirty = true
	queue_redraw()

func bind_state(state_ref: GameState) -> void:
	state = state_ref
	_hive_cache_dirty = true
	queue_redraw()

func set_model(rm: Dictionary) -> void:
	model = rm
	var map_id_for_cache: String = str(rm.get("map_id", rm.get("id", "")))
	var hives_count_for_cache: int = 0
	var hives_v_for_cache: Variant = rm.get("hives", [])
	if typeof(hives_v_for_cache) == TYPE_ARRAY:
		hives_count_for_cache = (hives_v_for_cache as Array).size()
	elif typeof(rm.get("hives_by_id", {})) == TYPE_DICTIONARY:
		hives_count_for_cache = (rm.get("hives_by_id", {}) as Dictionary).size()
	var cache_sig: String = "%s:%d" % [map_id_for_cache, hives_count_for_cache]
	if cache_sig != _hive_cache_map_sig:
		_hive_cache_map_sig = cache_sig
		_hive_cache_dirty = true
		if not hive_nodes_by_id.is_empty():
			_anchor_snapshot_ready = false
			_schedule_anchor_snapshot_rebuild("map_sig_changed")
	var lanes_total := 0
	var lanes_active := 0
	var lanes_v: Variant = model.get("lanes", [])
	if typeof(lanes_v) == TYPE_ARRAY:
		var lanes: Array = lanes_v as Array
		lanes_total = lanes.size()
		for lane_v in lanes:
			if typeof(lane_v) != TYPE_DICTIONARY:
				continue
			var d := lane_v as Dictionary
			if bool(d.get("send_a", false)) or bool(d.get("send_b", false)):
				lanes_active += 1
	var map_id := str(model.get("map_id", model.get("id", "")))
	var sig := "%s:%d:%d" % [map_id, lanes_total, lanes_active]
	if sig != _lane_map_sig:
		_lane_map_sig = sig
		SFLog.info("LANE_MAP_APPLY", {
			"map_id": map_id,
			"lanes_total": lanes_total,
			"lanes_active": lanes_active
		})
	var running: bool = bool(model.get("sim_running", false))
	_update_lane_candidates_visibility(running)
	queue_redraw()
	var active_sig: String = _compute_active_lane_signature()
	if active_sig != _last_sig:
		_request_rebuild("state_changed")

func set_hive_nodes(dict: Dictionary) -> void:
	var next_sig: int = _compute_hive_nodes_sig(dict)
	if next_sig == _hive_nodes_sig:
		SFLog.info("HIVE_NODES_SET_SKIPPED", {
			"renderer": "lane",
			"reason": "sig_unchanged",
			"count": dict.size()
		}, "", 1000)
		return
	_hive_nodes_sig = next_sig
	hive_nodes_by_id = dict
	_hive_cache_dirty = true
	_anchor_snapshot_ready = false
	_schedule_anchor_snapshot_rebuild("hive_nodes_changed")
	if DEBUG_LANES:
		SFLog.info("LANE_RENDERER_HIVES_SET", {"count": hive_nodes_by_id.size()})
	queue_redraw()
	_request_rebuild("hives_set")

func _compute_hive_nodes_sig(dict: Dictionary) -> int:
	var sig: int = dict.size()
	var sum_ids: int = 0
	var sum_nodes: int = 0
	var xor_mix: int = 0
	for key_any in dict.keys():
		var hive_id: int = int(key_any)
		var node_any: Variant = dict.get(key_any, null)
		var node_iid: int = 0
		if node_any is Object:
			var node_obj: Object = node_any as Object
			node_iid = int(node_obj.get_instance_id())
		sum_ids = (sum_ids + hive_id) & 0x7fffffff
		sum_nodes = (sum_nodes + node_iid) & 0x7fffffff
		xor_mix = xor_mix ^ int((hive_id * 1315423911) ^ node_iid)
	sig = (sig * 31 + sum_ids) & 0x7fffffff
	sig = (sig * 31 + sum_nodes) & 0x7fffffff
	sig = (sig * 31 + xor_mix) & 0x7fffffff
	return sig

func _schedule_anchor_snapshot_rebuild(reason: String) -> void:
	if _pending_snapshot_rebuild:
		return
	_pending_snapshot_rebuild = true
	call_deferred("_rebuild_anchor_snapshot_deferred", reason)

func _rebuild_anchor_snapshot_deferred(reason: String) -> void:
	_pending_snapshot_rebuild = false
	_anchor_world_by_hive_id.clear()
	for key_any in hive_nodes_by_id.keys():
		var hive_id: int = int(key_any)
		var node_any: Variant = hive_nodes_by_id.get(key_any, null)
		if not (node_any is Node2D):
			continue
		var node: Node2D = node_any as Node2D
		_anchor_world_by_hive_id[hive_id] = _hive_render_anchor_world_from_node(node)
	_anchor_snapshot_sig = _hive_nodes_sig
	_anchor_snapshot_ready = true
	_hive_cache_dirty = true
	queue_redraw()
	_request_rebuild("anchor_snapshot_ready")
	SFLog.info("LANE_ANCHOR_SNAPSHOT_BUILT", {
		"count": _anchor_world_by_hive_id.size(),
		"reason": reason
	})

func mark_lane_changed(lane_id: int) -> void:
	_last_changed_lane_id = lane_id
	queue_redraw()
	_update_lane_sprite_tints()

func flash_lane(lane_id: int, duration_ms: int = LANE_FLASH_DEFAULT_MS) -> void:
	if lane_id <= 0:
		return
	var now_ms := Time.get_ticks_msec()
	_lane_flash_expire_by_id[lane_id] = now_ms + maxi(1, duration_ms)
	queue_redraw()

func _draw() -> void:
	if debug_draw_magenta_x:
		# Big obvious diagnostic: if you see this, LaneRenderer is drawing.
		var w := 512.0
		var h := 768.0
		draw_line(Vector2(0, 0), Vector2(w, h), Color(1, 0, 1, 1), 6.0)
		draw_line(Vector2(w, 0), Vector2(0, h), Color(1, 0, 1, 1), 6.0)
	_draw_pick_debug()
	if debug_draw_endpoints:
		_draw_endpoint_debug()
	if USE_LANE_SPRITES and show_lane_sprites:
		return

	_draw_intended_lanes()

	# Need hive nodes to draw anything.
	if hive_nodes_by_id.is_empty():
		return

	var has_model_lanes := false
	if not model.is_empty():
		var lanes_v: Variant = model.get("lanes", [])
		if typeof(lanes_v) == TYPE_ARRAY:
			has_model_lanes = (lanes_v as Array).size() > 0

	if has_model_lanes:
		_draw_model_lanes(model)
	else:
		_draw_state_lanes()

func _draw_endpoint_debug() -> void:
	var lanes: Array = _lane_entries_from_model()
	if lanes.is_empty():
		lanes = _lane_entries_from_state()
	for lane_any in lanes:
		if typeof(lane_any) != TYPE_DICTIONARY:
			continue
		var lane: Dictionary = lane_any as Dictionary
		var a_id: int = int(lane.get("a_id", lane.get("from", 0)))
		var b_id: int = int(lane.get("b_id", lane.get("to", 0)))
		if a_id <= 0 or b_id <= 0:
			continue
		var a_any: Variant = _hive_local_pos_for_lane(a_id)
		var b_any: Variant = _hive_local_pos_for_lane(b_id)
		if not (a_any is Vector2 and b_any is Vector2):
			continue
		var a_pos: Vector2 = a_any as Vector2
		var b_pos: Vector2 = b_any as Vector2
		draw_line(a_pos, b_pos, Color(1.0, 0.0, 1.0, 1.0), 2.0)
		draw_circle(a_pos, 4.0, Color(0.0, 1.0, 1.0, 1.0))
		draw_circle(b_pos, 4.0, Color(0.0, 1.0, 1.0, 1.0))

func _draw_intended_lanes() -> void:
	if model.is_empty():
		return

	var hive_anchor_local_by_id: Dictionary = _collect_hive_positions()

	var lanes_v: Variant = model.get("lanes", [])
	if typeof(lanes_v) != TYPE_ARRAY:
		return
	var lanes: Array = lanes_v as Array
	for l_v in lanes:
		if typeof(l_v) != TYPE_DICTIONARY:
			continue
		var l: Dictionary = l_v as Dictionary
		var a_id: int = int(l.get("a_id", l.get("from", -1)))
		var b_id: int = int(l.get("b_id", l.get("to", -1)))
		var lane_id: int = int(l.get("lane_id", l.get("id", -1)))
		if not (hive_anchor_local_by_id.has(a_id) and hive_anchor_local_by_id.has(b_id)):
			continue
		if bool(l.get("send_a", false)) or bool(l.get("send_b", false)):
			var a_pos_any: Variant = hive_anchor_local_by_id.get(a_id, null)
			var b_pos_any: Variant = hive_anchor_local_by_id.get(b_id, null)
			if not (a_pos_any is Vector2 and b_pos_any is Vector2):
				continue
			var a_pos: Vector2 = a_pos_any as Vector2
			var b_pos: Vector2 = b_pos_any as Vector2
			var ep: Dictionary = _compute_lane_endpoints_from_centers_local(a_pos, b_pos, a_id, b_id, lane_id)
			if not bool(ep.get("ok", false)):
				continue
			var p0: Vector2 = ep.get("a", a_pos)
			var p1: Vector2 = ep.get("b", b_pos)
			var send_a: bool = bool(l.get("send_a", false))
			var send_b: bool = bool(l.get("send_b", false))
			_draw_lane_colored(p0, p1, a_id, b_id, send_a, send_b, model, 3.0, l)

# Returns true if it drew at least one lane.
func _draw_state_lanes() -> bool:
	if state == null:
		return false

	var drew_any := false
	var now_ms := Time.get_ticks_msec()
	_prune_lane_flashes(now_ms)

	for lane_any in state.lanes:
		var a_id := 0
		var b_id := 0
		var lane_id := -1
		var send_a := false
		var send_b := false

		# Support BOTH LaneData and Dictionary lane shapes.
		if lane_any is LaneData:
			var l := lane_any as LaneData
			a_id = int(l.a_id)
			b_id = int(l.b_id)
			lane_id = int(l.id)
			send_a = bool(l.send_a)
			send_b = bool(l.send_b)
		elif lane_any is Dictionary:
			var d := lane_any as Dictionary
			# tolerate either a_id/b_id or from/to naming
			a_id = int(d.get("a_id", d.get("from", 0)))
			b_id = int(d.get("b_id", d.get("to", 0)))
			lane_id = int(d.get("lane_id", d.get("id", -1)))
			send_a = bool(d.get("send_a", false))
			send_b = bool(d.get("send_b", false))
		else:
			continue

		if a_id <= 0 or b_id <= 0:
			continue
		if not hive_nodes_by_id.has(a_id) or not hive_nodes_by_id.has(b_id):
			continue

		var a_node := hive_nodes_by_id[a_id] as Node2D
		var b_node := hive_nodes_by_id[b_id] as Node2D
		if a_node == null or b_node == null:
			continue

		var a_pos_any: Variant = _hive_local_pos_for_lane(a_id)
		var b_pos_any: Variant = _hive_local_pos_for_lane(b_id)
		if not (a_pos_any is Vector2 and b_pos_any is Vector2):
			continue
		var a_pos: Vector2 = a_pos_any as Vector2
		var b_pos: Vector2 = b_pos_any as Vector2

		var seg := _edge_to_edge_segment(a_id, b_id, a_pos, b_pos, lane_id)
		if seg.size() != 2:
			continue

		var start: Vector2 = seg[0]
		var end: Vector2 = seg[1]

		if DEBUG_LANES and debug_lane_metrics and lane_id == 1:
			now_ms = Time.get_ticks_msec()
			if now_ms - _last_lane_log_ms >= LANE_LOG_INTERVAL_MS:
				_last_lane_log_ms = now_ms
				var center_dist := a_pos.distance_to(b_pos)
				var edge_dist := start.distance_to(end)
				SFLog.info("LANE_EDGE_DEBUG", {
					"lane_id": lane_id,
					"center_dist": center_dist,
					"edge_dist": edge_dist,
					"lane_r": float(GameState.HIVE_LANE_RADIUS_PX)
				})

		var is_candidate: bool = not send_a and not send_b
		if is_candidate and not _lane_candidates_visible:
			continue
		var width := 2.0
		if send_a or send_b:
			width = 3.0
		var build_t := 1.0
		if lane_any is LaneData:
			build_t = float((lane_any as LaneData).build_t)
		var lane_meta := {
			"front_t": float(OpsState.lane_front_by_lane_id.get(lane_id, 0.5)),
			"build_t": build_t
		}
		_draw_lane_colored(start, end, a_id, b_id, send_a, send_b, {}, width, lane_meta)
		var flash_until: int = int(_lane_flash_expire_by_id.get(lane_id, 0))
		if flash_until > now_ms:
			draw_line(start, end, LANE_FLASH_COLOR, LANE_FLASH_WIDTH)
		if debug_lane_seg_overlay:
			draw_circle(start, 3.0, Color(0, 1, 0, 1))
			draw_circle(end, 3.0, Color(0, 1, 0, 1))
		drew_any = true

		if send_a != send_b:
			var dir := (end - start).normalized()
			if send_b:
				dir = -dir
			var p := (start + end) * 0.5
			var tick := Vector2(-dir.y, dir.x) * 8.0
			draw_line(p - tick, p + tick, Color(0.9, 0.9, 0.2, 0.9), 3.0)

		# Optional highlight changed lane
		if lane_id == _last_changed_lane_id and lane_id != -1:
			draw_line(start, end, Color(0.2, 0.9, 0.9, 0.9), 3.0)

	return drew_any

func _prune_lane_flashes(now_ms: int) -> void:
	if _lane_flash_expire_by_id.is_empty():
		return
	var to_remove: Array = []
	for lane_id in _lane_flash_expire_by_id:
		if int(_lane_flash_expire_by_id[lane_id]) <= now_ms:
			to_remove.append(lane_id)
	for lane_id in to_remove:
		_lane_flash_expire_by_id.erase(lane_id)

func _grid_to_world(x: int, y: int, cell_size: float) -> Vector2:
	if arena != null:
		var spec: Variant = arena.get("grid_spec")
		if spec != null:
			return spec.grid_to_world(Vector2i(x, y))
	return Vector2((float(x) + 0.5) * cell_size, (float(y) + 0.5) * cell_size)

func _grid_to_world_center(x: int, y: int, cell_size: float) -> Vector2:
	return Vector2((float(x) + 0.5) * cell_size, (float(y) + 0.5) * cell_size)

func _load_lane_textures() -> void:
	var tex: Texture2D = null
	var tex_path: String = ""
	if ResourceLoader.exists(LANE_FALLBACK_PATH):
		tex = ResourceLoader.load(LANE_FALLBACK_PATH) as Texture2D
		tex_path = LANE_FALLBACK_PATH
	if tex == null:
		var registry := SpriteRegistry.get_instance()
		if registry != null:
			tex = _unwrap_atlas(registry.get_tex(LANE_TEX_KEY))
			tex_path = registry.get_tex_path(LANE_TEX_KEY)
	if tex != null and not _lane_tex_logged:
		_lane_tex_logged = true
		SFLog.info("LANE_TEX_RESOLVE_OK", {
			"key": LANE_TEX_KEY,
			"path": tex_path if tex_path != "" else tex.resource_path,
			"w": tex.get_width(),
			"h": tex.get_height(),
			"class": tex.get_class()
		})
	_lane_tex = tex
	_lane_connector_tex = tex
	_lane_tex_has_alpha = _texture_has_alpha(_lane_tex)
	_lane_connector_tex_has_alpha = _lane_tex_has_alpha

func _unwrap_atlas(tex: Texture2D) -> Texture2D:
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		if at.atlas is Texture2D:
			return at.atlas as Texture2D
		return null
	return tex

func _ensure_lane_sprite_root() -> void:
	if _lane_sprite_root != null and is_instance_valid(_lane_sprite_root):
		return
	var existing := get_node_or_null("LaneSprites")
	if existing is Node2D:
		_lane_sprite_root = existing as Node2D
		return
	var root := Node2D.new()
	root.name = "LaneSprites"
	add_child(root)
	_lane_sprite_root = root

func _lane_key(a_id: int, b_id: int, lane_id: int) -> String:
	if lane_id > 0:
		return str(lane_id)
	return "%s_%s" % [str(a_id), str(b_id)]

func _lane_segment_len() -> float:
	# We want enough segments to visualize a moving front_t (impact point).
	# Using texture width makes n collapse to 1 when the lane texture is large.
	return LANE_SEGMENT_TARGET_PX

func _texture_has_alpha(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var img := tex.get_image()
	if img == null:
		return false
	var fmt := img.get_format()
	return fmt in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH]

func _trim_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return tex

	var used := img.get_used_rect()
	# If the image is basically empty or already tight, bail.
	if used.size.x <= 0 or used.size.y <= 0:
		return tex
	if used.size == img.get_size():
		return tex

	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = used
	return atlas

func _get_lane_colorkey_material() -> ShaderMaterial:
	if _lane_colorkey_material != null:
		return _lane_colorkey_material
	var mat := ShaderMaterial.new()
	mat.shader = COLORKEY_SHADER
	mat.set_shader_parameter("key_color", Color(1, 1, 1, 1))
	mat.set_shader_parameter("threshold", 0.12)
	mat.set_shader_parameter("softness", 0.06)
	if AUDIT_RENDER:
		_audit_mat_sets += 3
	_lane_colorkey_material = mat
	return mat

func _get_lane_band_material() -> ShaderMaterial:
	if _lane_band_material != null:
		return _lane_band_material
	var mat := ShaderMaterial.new()
	mat.shader = LANE_BAND_SHADER
	mat.set_shader_parameter("band", 0.18)
	mat.set_shader_parameter("feather", 0.10)
	if AUDIT_RENDER:
		_audit_mat_sets += 2
	_lane_band_material = mat
	return mat

func _clear_lane_sprites() -> void:
	if _lane_sprite_root == null:
		return
	var kids := _lane_sprite_root.get_children()
	for child in kids:
		_lane_sprite_root.remove_child(child)
		child.free()
	_lane_nodes_by_key.clear()
	_lane_key_by_id.clear()
	_lane_scale_logged.clear()
	_lane_endpoint_logged.clear()

func _ensure_hive_lane_anchor_cache() -> void:
	if not _hive_cache_dirty and not _hive_lane_anchor_local_by_id.is_empty():
		return
	_rebuild_hive_lane_anchor_cache()

func _rebuild_hive_lane_anchor_cache() -> void:
	_hive_lane_anchor_local_by_id.clear()
	_hive_meta_by_id.clear()
	var cell_size: float = float(model.get("cell_size", 64))
	if not hive_nodes_by_id.is_empty():
		if not _anchor_snapshot_ready:
			_hive_cache_dirty = false
			return
		for hid_any in _anchor_world_by_hive_id.keys():
			var hid: int = int(hid_any)
			var anchor_any: Variant = _anchor_world_by_hive_id.get(hid_any, null)
			if not (anchor_any is Vector2):
				continue
			var anchor_world: Vector2 = anchor_any as Vector2
			_hive_lane_anchor_local_by_id[hid] = to_local(anchor_world)
	else:
		var hives_v: Variant = model.get("hives", [])
		if typeof(hives_v) == TYPE_ARRAY:
			var hives: Array = hives_v as Array
			for h_v in hives:
				if typeof(h_v) != TYPE_DICTIONARY:
					continue
				var hive_data: Dictionary = h_v as Dictionary
				var hid: int = int(hive_data.get("id", -1))
				if hid <= 0:
					continue
				_hive_meta_by_id[hid] = hive_data
				var pos_v: Variant = hive_data.get("pos", null)
				var center_world: Vector2
				if pos_v is Vector2:
					var center_local: Vector2 = pos_v as Vector2
					center_world = to_global(center_local)
				else:
					var x: int = int(hive_data.get("x", 0))
					var y: int = int(hive_data.get("y", 0))
					center_world = _grid_to_world_center(x, y, cell_size)
				var anchor_world: Vector2 = center_world
				_hive_lane_anchor_local_by_id[hid] = to_local(anchor_world)

	var rm_hives_by_id_any: Variant = model.get("hives_by_id", {})
	if typeof(rm_hives_by_id_any) == TYPE_DICTIONARY:
		var rm_hives_by_id: Dictionary = rm_hives_by_id_any as Dictionary
		for hid_any in rm_hives_by_id.keys():
			var hid: int = int(hid_any)
			var hive_any: Variant = rm_hives_by_id.get(hid_any, null)
			if typeof(hive_any) != TYPE_DICTIONARY:
				continue
			var hive_dict: Dictionary = hive_any as Dictionary
			_hive_meta_by_id[hid] = hive_dict
			if _hive_lane_anchor_local_by_id.has(hid):
				continue
			var pos_any: Variant = hive_dict.get("pos", null)
			if pos_any is Vector2:
				var center_local: Vector2 = pos_any as Vector2
				var center_world: Vector2 = to_global(center_local)
				_hive_lane_anchor_local_by_id[hid] = to_local(center_world)

	_hive_cache_dirty = false
	SFLog.throttled_info("LANE_ANCHOR_CACHE", {
		"count": _hive_lane_anchor_local_by_id.size()
	}, 1000)

func _collect_hive_positions() -> Dictionary:
	_ensure_hive_lane_anchor_cache()
	return _hive_lane_anchor_local_by_id

func get_hive_render_anchor_local(hive_id: int) -> Vector2:
	_ensure_hive_lane_anchor_cache()
	var v_any: Variant = _hive_lane_anchor_local_by_id.get(hive_id, null)
	if v_any is Vector2:
		return v_any as Vector2
	return Vector2.INF

func get_edge_geo(lane_id: int, a_id: int, b_id: int) -> Dictionary:
	var lane_key: String = "%s|%d>%d" % [str(lane_id), a_id, b_id]
	if not _anchor_snapshot_ready and not hive_nodes_by_id.is_empty():
		return {
			"ok": false,
			"lane_key": lane_key,
			"source": "snapshot_not_ready"
		}
	if a_id <= 0 or b_id <= 0:
		return {
			"ok": false,
			"lane_key": lane_key,
			"source": "fail"
		}
	var a_any: Variant = _hive_local_pos_for_lane(a_id)
	var b_any: Variant = _hive_local_pos_for_lane(b_id)
	if not (a_any is Vector2 and b_any is Vector2):
		return {
			"ok": false,
			"lane_key": lane_key,
			"source": "fail"
		}
	var a_local: Vector2 = a_any as Vector2
	var b_local: Vector2 = b_any as Vector2
	var ep: Dictionary = {}
	var source: String = "compute"
	var edge_any: Variant = _edge_geo_from_cache(lane_id, a_id, b_id)
	if edge_any != null:
		source = "cache"
		ep = _edge_geo_to_endpoints_local(edge_any, a_local, b_local, a_id, b_id)
	else:
		ep = _compute_lane_endpoints_from_centers_local(a_local, b_local, a_id, b_id, lane_id)
	if not bool(ep.get("ok", false)):
		return {
			"ok": false,
			"lane_key": lane_key,
			"source": "fail"
		}
	var start_local: Vector2 = ep.get("a", a_local)
	var end_local: Vector2 = ep.get("b", b_local)
	var start_world: Vector2 = to_global(start_local)
	var end_world: Vector2 = to_global(end_local)
	var axis: Vector2 = end_local - start_local
	var normal: Vector2 = Vector2.ZERO
	if axis.length_squared() > 0.000001:
		var dir: Vector2 = axis.normalized()
		normal = Vector2(-dir.y, dir.x)
	return {
		"ok": true,
		"start_local": start_local,
		"end_local": end_local,
		"start_world": start_world,
		"end_world": end_world,
		"normal": normal,
		"lane_key": lane_key,
		"source": source
	}

func get_lane_endpoints_world(lane_id: int, from_id: int, to_id: int) -> Dictionary:
	var lane_key: String = "%s|%d>%d" % [str(lane_id), from_id, to_id]
	if not _anchor_snapshot_ready and not hive_nodes_by_id.is_empty():
		return {
			"ok": false,
			"lane_key": lane_key,
			"source": "snapshot_not_ready"
		}
	var edge_geo: Dictionary = get_edge_geo(lane_id, from_id, to_id)
	if not bool(edge_geo.get("ok", false)):
		return {
			"ok": false,
			"lane_key": lane_key,
			"source": str(edge_geo.get("source", "fail"))
		}
	return {
		"ok": true,
		"lane_key": str(edge_geo.get("lane_key", lane_key)),
		"start_world": edge_geo.get("start_world", Vector2.ZERO),
		"end_world": edge_geo.get("end_world", Vector2.ZERO),
		"normal": edge_geo.get("normal", Vector2.ZERO),
		"source": str(edge_geo.get("source", "compute"))
	}

func get_hive_lane_anchor_local(hive_id: int, fallback_local: Vector2) -> Vector2:
	var anchor_local: Vector2 = get_hive_render_anchor_local(hive_id)
	if anchor_local != Vector2.INF:
		return anchor_local
	return fallback_local

func _lane_entries_from_model() -> Array:
	var lanes_v: Variant = model.get("lanes", [])
	if typeof(lanes_v) != TYPE_ARRAY:
		return []
	return lanes_v as Array

func _lane_entries_from_state() -> Array:
	if state == null:
		return []
	var out: Array = []
	for lane_any in state.lanes:
		if lane_any is LaneData:
			var l := lane_any as LaneData
			out.append({
				"a_id": int(l.a_id),
				"b_id": int(l.b_id),
				"lane_id": int(l.id),
				"send_a": bool(l.send_a),
				"send_b": bool(l.send_b)
			})
		elif lane_any is Dictionary:
			var d := lane_any as Dictionary
			out.append({
				"a_id": int(d.get("a_id", d.get("from", 0))),
				"b_id": int(d.get("b_id", d.get("to", 0))),
				"lane_id": int(d.get("lane_id", d.get("id", -1))),
				"send_a": bool(d.get("send_a", false)),
				"send_b": bool(d.get("send_b", false))
			})
	return out

func _request_rebuild(reason: String) -> void:
	if AUDIT_RENDER:
		_audit_rebuilds += 1
	_rebuild_req_reason = reason
	if _rebuild_pending:
		return
	_rebuild_pending = true
	call_deferred("_flush_rebuild")

func _flush_rebuild() -> void:
	_rebuild_pending = false
	_lane_endpoints_logged_this_rebuild = false
	_anchor_proof_logged_this_rebuild = false
	var sig := _compute_active_lane_signature()
	if sig == _last_sig:
		return
	_last_sig = sig
	SFLog.info("LANE_RENDER_REBUILD", {
		"reason": _rebuild_req_reason,
		"lanes": _lane_nodes_by_key.size()
	})
	SFLog.info("EDGE_VISUAL_OFFSETS", {
		"lane_normal_px": EdgeVisual.LANE_NORMAL_OFFSET_PX,
		"unit_normal_px": EdgeVisual.UNIT_NORMAL_OFFSET_PX,
		"unit_lift_y_px": EdgeVisual.UNIT_LIFT_Y_PX
	}, "", 250)
	_rebuild_lane_sprites_now()

func _compute_active_lane_signature() -> String:
	var parts: Array[String] = []
	var lanes: Array = _lane_entries_from_model()
	if lanes.is_empty():
		lanes = _lane_entries_from_state()
	for lane in lanes:
		if typeof(lane) != TYPE_DICTIONARY:
			continue
		var d := lane as Dictionary
		var send_a: bool = bool(d.get("send_a", false))
		var send_b: bool = bool(d.get("send_b", false))
		if not (send_a or send_b):
			continue
		var lane_id: int = int(d.get("lane_id", d.get("id", -1)))
		var intent: String = str(d.get("intent", ""))
		parts.append("%s:%s%s:%s" % [
			str(lane_id),
			"A" if send_a else "",
			"B" if send_b else "",
			str(intent)
		])
	parts.sort()
	var lanes_sig: String = "|".join(parts)
	var snapshot_state: String = "%d:%d" % [_anchor_snapshot_sig, 1 if _anchor_snapshot_ready else 0]
	return "%s#%s" % [lanes_sig, snapshot_state]

func get_lane_signature() -> int:
	var sig: String = _compute_active_lane_signature()
	return int(hash(sig))

func _rebuild_lane_sprites_now() -> void:
	if not USE_LANE_SPRITES or not show_lane_sprites:
		_clear_lane_sprites()
		return
	if _lane_tex == null:
		_load_lane_textures()
	if _lane_tex == null:
		return
	_ensure_lane_sprite_root()
	var lanes: Array = _lane_entries_from_model()
	if lanes.is_empty():
		lanes = _lane_entries_from_state()
	var seen: Dictionary = {}
	for lane_any in lanes:
		if typeof(lane_any) != TYPE_DICTIONARY:
			continue
		var lane: Dictionary = lane_any as Dictionary
		var a_id: int = int(lane.get("a_id", lane.get("from", 0)))
		var b_id: int = int(lane.get("b_id", lane.get("to", 0)))
		if a_id <= 0 or b_id <= 0:
			continue
		var send_a: bool = bool(lane.get("send_a", false))
		var send_b: bool = bool(lane.get("send_b", false))
		if not send_a and not send_b:
			continue
		var lane_id: int = int(lane.get("lane_id", lane.get("id", -1)))
		var key: String = _lane_key(a_id, b_id, lane_id)
		seen[key] = true
		if lane_id > 0:
			_lane_key_by_id[lane_id] = key
		var entry: Dictionary = {}
		var existing_any: Variant = _lane_nodes_by_key.get(key, null)
		if typeof(existing_any) == TYPE_DICTIONARY:
			entry = existing_any as Dictionary
		if entry.is_empty() or not entry.has("sprite_a") or not entry.has("sprite_b"):
			var sprite_a: Sprite2D = _create_lane_sprite_node()
			var sprite_b: Sprite2D = _create_lane_sprite_node()
			_lane_sprite_root.add_child(sprite_a)
			_lane_sprite_root.add_child(sprite_b)
			entry = {
				"sprite_a": sprite_a,
				"sprite_b": sprite_b,
				"visual_t": 0.0
			}
		var prev_send_a: bool = bool(entry.get("send_a", false))
		var prev_send_b: bool = bool(entry.get("send_b", false))
		if prev_send_a != send_a or prev_send_b != send_b:
			entry["visual_t"] = 0.0
		entry["a_id"] = a_id
		entry["b_id"] = b_id
		entry["lane_id"] = lane_id
		entry["send_a"] = send_a
		entry["send_b"] = send_b
		_lane_nodes_by_key[key] = entry
	var keys: Array = _lane_nodes_by_key.keys()
	for key_any in keys:
		var key: String = str(key_any)
		if seen.has(key):
			continue
		var old_any: Variant = _lane_nodes_by_key.get(key, null)
		if typeof(old_any) == TYPE_DICTIONARY:
			var old_entry: Dictionary = old_any as Dictionary
			var sprite_a_old: Sprite2D = old_entry.get("sprite_a", null) as Sprite2D
			var sprite_b_old: Sprite2D = old_entry.get("sprite_b", null) as Sprite2D
			if sprite_a_old != null:
				sprite_a_old.queue_free()
			if sprite_b_old != null:
				sprite_b_old.queue_free()
		_lane_nodes_by_key.erase(key)
	var lane_ids: Array = _lane_key_by_id.keys()
	for lane_id_any in lane_ids:
		var key_ref: String = str(_lane_key_by_id.get(lane_id_any, ""))
		if key_ref.is_empty() or not seen.has(key_ref):
			_lane_key_by_id.erase(lane_id_any)

func _create_lane_sprite_node() -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = _lane_tex
	sprite.centered = true
	sprite.z_index = LANE_Z_INDEX
	sprite.material = _get_lane_band_material()
	sprite.visible = false
	return sprite

func _update_lane_visuals(delta: float) -> void:
	if _lane_nodes_by_key.is_empty():
		return
	var thickness_info: Dictionary = _resolve_lane_thickness_info()
	var target_px: float = float(thickness_info.get("target_px", lane_thickness_px))
	var unit_body_px: float = float(thickness_info.get("unit_body_px", -1.0))
	var grow_time_s: float = maxf(0.001, LANE_GROW_TIME_MS / 1000.0)
	var step: float = delta / grow_time_s
	var keys: Array = _lane_nodes_by_key.keys()
	if AUDIT_RENDER:
		_audit_draw_ops += keys.size()
	for key_any in keys:
		var entry_any: Variant = _lane_nodes_by_key.get(key_any, null)
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var sprite_a: Sprite2D = entry.get("sprite_a", null) as Sprite2D
		var sprite_b: Sprite2D = entry.get("sprite_b", null) as Sprite2D
		if sprite_a == null or sprite_b == null:
			continue
		var send_a: bool = bool(entry.get("send_a", false))
		var send_b: bool = bool(entry.get("send_b", false))
		var a_id: int = int(entry.get("a_id", 0))
		var b_id: int = int(entry.get("b_id", 0))
		var lane_id: int = int(entry.get("lane_id", -1))
		var visual_t: float = clampf(float(entry.get("visual_t", 0.0)) + step, 0.0, 1.0)
		entry["visual_t"] = visual_t
		_lane_nodes_by_key[key_any] = entry
		var a_anchor_v: Variant = _hive_local_pos_for_lane(a_id)
		var b_anchor_v: Variant = _hive_local_pos_for_lane(b_id)
		if not (a_anchor_v is Vector2 and b_anchor_v is Vector2):
			sprite_a.visible = false
			sprite_b.visible = false
			continue
		var a_anchor: Vector2 = a_anchor_v as Vector2
		var b_anchor: Vector2 = b_anchor_v as Vector2
		var ep: Dictionary = _compute_lane_endpoints_from_centers_local(a_anchor, b_anchor, a_id, b_id, lane_id)
		if not bool(ep.get("ok", false)):
			sprite_a.visible = false
			sprite_b.visible = false
			continue
		var a_pos: Vector2 = ep.get("a", a_anchor)
		var b_pos: Vector2 = ep.get("b", b_anchor)
		_log_lane_endpoints_once(lane_id, ep)
		var color_a: Color = _with_alpha(_lane_color_for_hive(a_id), LANE_ACTIVE_ALPHA)
		var color_b: Color = _with_alpha(_lane_color_for_hive(b_id), LANE_ACTIVE_ALPHA)
		var lane_basis_dir: Vector2 = b_pos - a_pos
		if send_a and send_b:
			var mid: Vector2 = a_pos.lerp(b_pos, 0.5)
			_apply_lane_sprite_visual(sprite_a, a_pos, a_pos.lerp(mid, visual_t), color_a, lane_id, target_px, unit_body_px, lane_basis_dir)
			_apply_lane_sprite_visual(sprite_b, b_pos, b_pos.lerp(mid, visual_t), color_b, lane_id, target_px, unit_body_px, lane_basis_dir)
		elif send_a:
			_apply_lane_sprite_visual(sprite_a, a_pos, a_pos.lerp(b_pos, visual_t), color_a, lane_id, target_px, unit_body_px, lane_basis_dir)
			sprite_b.visible = false
		elif send_b:
			_apply_lane_sprite_visual(sprite_b, b_pos, b_pos.lerp(a_pos, visual_t), color_b, lane_id, target_px, unit_body_px, lane_basis_dir)
			sprite_a.visible = false
		else:
			sprite_a.visible = false
			sprite_b.visible = false

func _resolve_lane_thickness_info() -> Dictionary:
	var target_px: float = lane_thickness_px
	var unit_body_px: float = -1.0
	if lane_thickness_mode == LANE_THICKNESS_MODE_MATCH_UNIT_RATIO:
		unit_body_px = _resolve_unit_body_width_px()
		if unit_body_px > 0.0:
			target_px = unit_body_px * lane_vs_unit_ratio
	target_px = clampf(target_px, 18.0, 120.0)
	return {
		"target_px": target_px,
		"unit_body_px": unit_body_px
	}

func _resolve_unit_body_width_px() -> float:
	var registry: SpriteRegistry = SpriteRegistry.get_instance()
	if registry == null:
		return -1.0
	var unit_scale: float = float(registry.get_scale(UNIT_THICKNESS_KEY))
	if unit_scale <= 0.0:
		unit_scale = 1.0
	var unit_body_px: float = UNIT_RENDER_BASE_DIAMETER_PX * unit_scale * UNIT_RENDER_SCALE_MATCH
	return unit_body_px

func _hive_center_local_for_lane(hive_id: int) -> Variant:
	var anchor_local: Vector2 = get_hive_render_anchor_local(hive_id)
	if anchor_local != Vector2.INF:
		return anchor_local
	return null

func _hive_local_pos_for_lane(hive_id: int) -> Variant:
	return _hive_center_local_for_lane(hive_id)

func _maybe_log_lane_sprite_coverage(length_px: float, segment_count: int, effective_seg_len: float) -> void:
	if length_px <= LANE_SEGMENT_TARGET_PX:
		return
	var now_ms: int = Time.get_ticks_msec()
	if _lane_sprite_coverage_last_ms > 0 and now_ms - _lane_sprite_coverage_last_ms < 1000:
		return
	_lane_sprite_coverage_last_ms = now_ms
	SFLog.info("LANE_SPRITE_COVERAGE", {
		"len": snapped(length_px, 0.1),
		"seg_count": segment_count,
		"eff_seg_len": snapped(effective_seg_len, 0.1),
		"max": LANE_MAX_SEGMENTS,
		"target": LANE_SEGMENT_TARGET_PX
	})

func _apply_lane_sprite_visual(
	sprite: Sprite2D,
	start_pos: Vector2,
	end_pos: Vector2,
	color: Color,
	lane_id: int,
	target_thickness_px: float,
	unit_body_px: float,
	lane_basis_dir: Vector2 = Vector2.ZERO
) -> void:
	if sprite == null or sprite.texture == null:
		return
	var dir: Vector2 = end_pos - start_pos
	var length_px: float = dir.length()
	if length_px <= LANE_MIN_LEN_PX:
		sprite.visible = false
		return
	var desired_seg_len: float = LANE_SEGMENT_TARGET_PX
	var min_segments: int = 1
	var max_segments: int = LANE_MAX_SEGMENTS
	var segment_count: int = int(ceil(length_px / desired_seg_len))
	segment_count = clampi(segment_count, min_segments, max_segments)
	var effective_seg_len: float = length_px / float(segment_count)
	_maybe_log_lane_sprite_coverage(length_px, segment_count, effective_seg_len)
	var tex_w: float = maxf(1.0, float(sprite.texture.get_width()))
	var tex_h: float = maxf(1.0, float(sprite.texture.get_height()))
	# Keep visual coverage full length while preserving per-segment texture density.
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0.0, 0.0, tex_w * float(segment_count), tex_h)
	var scale_x: float = maxf(0.0, effective_seg_len / tex_w)
	var scale_y: float = clampf(target_thickness_px / tex_h, 0.0, LANE_SCALE_CLAMP.y)
	var normal_basis: Vector2 = lane_basis_dir
	if normal_basis.length_squared() <= 0.000001:
		normal_basis = dir
	var normal_dir: Vector2 = Vector2.ZERO
	if normal_basis.length_squared() > 0.000001:
		var unit_dir: Vector2 = normal_basis.normalized()
		normal_dir = Vector2(-unit_dir.y, unit_dir.x)
	var start_visual: Vector2 = EdgeVisual.lane_point(start_pos, normal_dir)
	var end_visual: Vector2 = EdgeVisual.lane_point(end_pos, normal_dir)
	var visual_dir: Vector2 = end_visual - start_visual
	var mid_pos: Vector2 = (start_visual + end_visual) * 0.5
	sprite.visible = true
	sprite.position = mid_pos
	sprite.rotation = visual_dir.angle()
	sprite.scale = Vector2(scale_x, scale_y)
	sprite.modulate = color
	if lane_id == 9 and not _lane_align_logged:
		_lane_align_logged = true
		var dir_norm: Vector2 = Vector2.ZERO
		if normal_basis.length_squared() > 0.000001:
			dir_norm = normal_basis.normalized()
		SFLog.info("LANE_ALIGN_DEBUG", {
			"lane_id": lane_id,
			"p0": start_visual,
			"p1": end_visual,
			"mid": mid_pos,
			"dir": dir_norm,
			"normal": normal_dir,
			"offset_px": EdgeVisual.LANE_NORMAL_OFFSET_PX,
			"final_pos": mid_pos
		})
	if lane_id > 0 and not _lane_scale_logged.has(lane_id):
		_lane_scale_logged[lane_id] = true
		SFLog.info("LANE_VISUAL_THICKNESS", {
			"lane_id": lane_id,
			"mode": lane_thickness_mode,
			"target_px": target_thickness_px,
			"base_h": tex_h,
			"unit_body_px": unit_body_px,
			"x_scale": scale_x,
			"y_scale": scale_y,
			"tex_size": [sprite.texture.get_width(), sprite.texture.get_height()]
		})

func _log_lane_endpoints_once(lane_id: int, ep: Dictionary) -> void:
	if lane_id <= 0:
		return
	if _lane_endpoint_logged.has(lane_id):
		return
	var a_pos: Vector2 = ep.get("a", Vector2.ZERO)
	var b_pos: Vector2 = ep.get("b", Vector2.ZERO)
	var a_center: Vector2 = ep.get("a_center", Vector2.ZERO)
	var b_center: Vector2 = ep.get("b_center", Vector2.ZERO)
	var a_anchor: Vector2 = ep.get("a_anchor", a_pos)
	var b_anchor: Vector2 = ep.get("b_anchor", b_pos)
	var lane_vec: Vector2 = b_pos - a_pos
	var lane_len: float = lane_vec.length()
	var lane_deg: float = rad_to_deg(lane_vec.angle()) if lane_len > 0.000001 else 0.0
	_lane_endpoint_logged[lane_id] = true
	SFLog.info("LANE_ENDPOINTS_UNIFIED", {
		"lane_id": lane_id,
		"a_center": a_center,
		"b_center": b_center,
		"a_anchor": a_anchor,
		"b_anchor": b_anchor,
		"a": a_pos,
		"b": b_pos,
		"len": lane_len,
		"deg": lane_deg
	})

func _update_lane_sprite_tints() -> void:
	if not USE_LANE_SPRITES:
		return
	if _lane_nodes_by_key.is_empty():
		return
	var rm: Dictionary = model
	var lanes: Array = _lane_entries_from_model()
	if lanes.is_empty():
		lanes = _lane_entries_from_state()
		rm = {}
	var hive_anchor_local_by_id: Dictionary = _collect_hive_positions()
	for lane in lanes:
		if typeof(lane) != TYPE_DICTIONARY:
			continue
		var d := lane as Dictionary
		var a_id: int = int(d.get("a_id", d.get("from", 0)))
		var b_id: int = int(d.get("b_id", d.get("to", 0)))
		if not (hive_anchor_local_by_id.has(a_id) and hive_anchor_local_by_id.has(b_id)):
			continue
		var lane_id: int = int(d.get("lane_id", d.get("id", -1)))
		var key := _lane_key(a_id, b_id, lane_id)
		if not _lane_nodes_by_key.has(key):
			continue
		var send_a: bool = bool(d.get("send_a", false))
		var send_b: bool = bool(d.get("send_b", false))
		var color_a: Color = _lane_color_for_hive(a_id)
		var color_b: Color = _lane_color_for_hive(b_id)
		var front_t: float = float(d.get("front_t", d.get("split_t", 0.5)))
		var p0_any: Variant = hive_anchor_local_by_id.get(a_id, null)
		var p1_any: Variant = hive_anchor_local_by_id.get(b_id, null)
		if not (p0_any is Vector2 and p1_any is Vector2):
			continue
		var p0_local: Vector2 = p0_any as Vector2
		var p1_local: Vector2 = p1_any as Vector2
		var p0: Vector2 = to_global(p0_local)
		var p1: Vector2 = to_global(p1_local)
		var dir: Vector2 = p1 - p0
		var len_sq: float = dir.length_squared()
		var entry: Dictionary = _lane_nodes_by_key[key]
		var segments: Array = entry.get("segments", [])
		for s in segments:
			if s is Sprite2D:
				var spr: Sprite2D = s as Sprite2D
				var t: float = 0.0
				if len_sq > 0.0:
					var rel: Vector2 = spr.global_position - p0
					t = clamp(rel.dot(dir) / len_sq, 0.0, 1.0)
				var seg_color: Color = _lane_color_for_t(send_a, send_b, color_a, color_b, t, front_t)
				spr.modulate = seg_color
		var connectors: Array = entry.get("connectors", [])
		for c in connectors:
			if c is Sprite2D:
				var conn: Sprite2D = c as Sprite2D
				var t_c: float = 0.0
				if len_sq > 0.0:
					var rel_c: Vector2 = conn.global_position - p0
					t_c = clamp(rel_c.dot(dir) / len_sq, 0.0, 1.0)
				var conn_color: Color = _lane_color_for_t(send_a, send_b, color_a, color_b, t_c, front_t)
				conn.modulate = conn_color

func _draw_model_lanes(rm: Dictionary) -> void:
	var lanes_v: Variant = rm.get("lanes", [])
	var lanes: Array = lanes_v as Array
	if lanes == null:
		return

	for lane_v in lanes:
		var d: Dictionary = lane_v as Dictionary
		if d.is_empty():
			continue
		var send_a: bool = bool(d.get("send_a", false))
		var send_b: bool = bool(d.get("send_b", false))
		var is_candidate: bool = not send_a and not send_b
		if is_candidate and not _lane_candidates_visible:
			continue

		var a_id: int = int(d.get("a_id", d.get("from", 0)))
		var b_id: int = int(d.get("b_id", d.get("to", 0)))
		if a_id <= 0 or b_id <= 0:
			continue
		var lane_id: int = int(d.get("lane_id", d.get("id", -1)))
		var build_t: float = float(d.get("build_t", -1.0))
		if build_t < 0.0 and state != null and lane_id > 0:
			var lane: LaneData = state.find_lane_by_id(lane_id) as LaneData
			if lane != null:
				build_t = float(lane.build_t)
		if build_t < 0.0:
			build_t = 1.0
		if not hive_nodes_by_id.has(a_id) or not hive_nodes_by_id.has(b_id):
			continue

		var a_node := hive_nodes_by_id[a_id] as Node2D
		var b_node := hive_nodes_by_id[b_id] as Node2D
		if a_node == null or b_node == null:
			continue

		var a_pos_any: Variant = _hive_local_pos_for_lane(a_id)
		var b_pos_any: Variant = _hive_local_pos_for_lane(b_id)
		if not (a_pos_any is Vector2 and b_pos_any is Vector2):
			continue
		var a_pos: Vector2 = a_pos_any as Vector2
		var b_pos: Vector2 = b_pos_any as Vector2

		var seg := _edge_to_edge_segment(a_id, b_id, a_pos, b_pos, lane_id)
		if seg.size() != 2:
			continue
		var width := 2.0
		if send_a or send_b:
			width = 3.0
		var lane_meta := d.duplicate()
		lane_meta["build_t"] = build_t
		_draw_lane_colored(seg[0], seg[1], a_id, b_id, send_a, send_b, rm, width, lane_meta)

func _edge_to_edge_segment(a_id: int, b_id: int, a_pos: Vector2, b_pos: Vector2, lane_id: int = -1) -> PackedVector2Array:
	var ep: Dictionary = _compute_lane_endpoints_from_centers_local(a_pos, b_pos, a_id, b_id, lane_id)
	if not bool(ep.get("ok", false)):
		return PackedVector2Array()
	var a_edge: Vector2 = ep.get("a", a_pos)
	var b_edge: Vector2 = ep.get("b", b_pos)
	return PackedVector2Array([a_edge, b_edge])

func pick_lane_at_world_pos(world_pos: Vector2, max_dist: float) -> Dictionary:
	if max_dist <= 0.0:
		return {"hit": false}
	var lanes: Array = _lane_entries_from_model()
	if lanes.is_empty():
		lanes = _lane_entries_from_state()
	if lanes.is_empty():
		return {"hit": false}
	var hive_anchor_local_by_id: Dictionary = _collect_hive_positions()
	if hive_anchor_local_by_id.is_empty():
		return {"hit": false}
	var local_pos: Vector2 = to_local(world_pos)
	var best_dist: float = max_dist
	var best: Dictionary = {"hit": false}
	for lane_any in lanes:
		if typeof(lane_any) != TYPE_DICTIONARY:
			continue
		var d := lane_any as Dictionary
		var send_a: bool = bool(d.get("send_a", false))
		var send_b: bool = bool(d.get("send_b", false))
		if not send_a and not send_b:
			continue
		var a_id: int = int(d.get("a_id", d.get("from", 0)))
		var b_id: int = int(d.get("b_id", d.get("to", 0)))
		if a_id <= 0 or b_id <= 0:
			continue
		if not hive_anchor_local_by_id.has(a_id) or not hive_anchor_local_by_id.has(b_id):
			continue
		var a_pos_any: Variant = hive_anchor_local_by_id.get(a_id, null)
		var b_pos_any: Variant = hive_anchor_local_by_id.get(b_id, null)
		if not (a_pos_any is Vector2 and b_pos_any is Vector2):
			continue
		var a_pos: Vector2 = a_pos_any as Vector2
		var b_pos: Vector2 = b_pos_any as Vector2
		var hit := _project_point_to_segment(local_pos, a_pos, b_pos)
		var dist: float = float(hit.get("dist", INF))
		if dist <= best_dist:
			best_dist = dist
			best = {
				"hit": true,
				"lane_id": int(d.get("lane_id", d.get("id", -1))),
				"t": float(hit.get("t", 0.0)),
				"dist": dist,
				"a_id": a_id,
				"b_id": b_id,
				"a_pos": to_global(a_pos),
				"b_pos": to_global(b_pos)
			}
	return best

func debug_pick_dot(world_pos: Vector2, duration_ms: int = DEBUG_PICK_DOT_MS) -> void:
	var expires := Time.get_ticks_msec() + maxi(1, duration_ms)
	_debug_pick_dots.append({"pos": to_local(world_pos), "expires": expires})
	queue_redraw()

func _draw_pick_debug() -> void:
	if _debug_pick_dots.is_empty():
		return
	var now_ms := Time.get_ticks_msec()
	var keep: Array = []
	for d in _debug_pick_dots:
		var exp := int(d.get("expires", 0))
		if exp <= now_ms:
			continue
		var pos: Vector2 = d.get("pos", Vector2.ZERO)
		draw_circle(pos, DEBUG_PICK_DOT_RADIUS, DEBUG_PICK_DOT_COLOR)
		keep.append(d)
	_debug_pick_dots = keep

func _project_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> Dictionary:
	var ab: Vector2 = b - a
	if ab.length_squared() == 0.0:
		return {"t": 0.0, "dist": p.distance_to(a)}
	var t: float = (p - a).dot(ab) / ab.length_squared()
	t = clampf(t, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return {"t": t, "dist": p.distance_to(proj)}

func _draw_lane_colored(start: Vector2, end: Vector2, a_id: int, b_id: int, send_a: bool, send_b: bool, rm: Dictionary, width: float, lane: Dictionary) -> void:
	if _lane_tex == null:
		_load_lane_textures()
	if _lane_tex == null:
		return
	var build_t: float = clampf(float(lane.get("build_t", 1.0)), 0.0, 1.0)
	if build_t < 1.0:
		if send_a and not send_b:
			end = start.lerp(end, build_t)
		elif send_b and not send_a:
			start = end.lerp(start, build_t)
	if send_a and send_b:
		var t_front: float = clamp(float(lane.get("front_t", 0.5)), 0.0, 1.0)
		var mid := start.lerp(end, t_front)
		var color_a := _resolve_lane_color(a_id, b_id, true, false, rm, lane)
		var color_b := _resolve_lane_color(a_id, b_id, false, true, rm, lane)
		_draw_lane_textured_segment(start, mid, color_a)
		_draw_lane_textured_segment(mid, end, color_b)
		return
	var color := _resolve_lane_color(a_id, b_id, send_a, send_b, rm, lane)
	_draw_lane_textured_segment(start, end, color)

func _draw_lane_textured_segment(start: Vector2, end: Vector2, color: Color) -> void:
	var dir: Vector2 = end - start
	var len := dir.length()
	if len <= 0.01:
		return
	var mid := (start + end) * 0.5
	var ang := dir.angle()
	var lane_width := LANE_WIDTH_PX
	draw_set_transform(mid, ang, Vector2.ONE)
	draw_texture_rect(
		_lane_tex,
		Rect2(Vector2(-len * 0.5, -lane_width * 0.5), Vector2(len, lane_width)),
		false,
		color
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _resolve_lane_color(a_id: int, b_id: int, send_a: bool, send_b: bool, rm: Dictionary, lane: Dictionary = {}) -> Color:
	var owner_a: int = _owner_id_for_lane(a_id, rm)
	var owner_b: int = _owner_id_for_lane(b_id, rm)
	if not lane.is_empty():
		# Prefer explicit from/to hive ownership when available.
		var from_hive_ref: Variant = lane.get("from_hive", null)
		if from_hive_ref != null:
			owner_a = _owner_id_from_hive_ref(from_hive_ref)
		var to_hive_ref: Variant = lane.get("to_hive", null)
		if to_hive_ref != null:
			owner_b = _owner_id_from_hive_ref(to_hive_ref)
	if send_a and not send_b:
		return _with_alpha(HiveRenderer._owner_color(owner_a), LANE_ACTIVE_ALPHA)
	if send_b and not send_a:
		return _with_alpha(HiveRenderer._owner_color(owner_b), LANE_ACTIVE_ALPHA)
	if send_a and send_b:
		return LANE_CONTESTED_COLOR
	return LANE_INACTIVE_COLOR

func _owner_id_from_hive_ref(hive_ref: Variant) -> int:
	if hive_ref == null:
		return 0
	if hive_ref is HiveData:
		var hive: HiveData = hive_ref as HiveData
		return int(hive.owner_id)
	if typeof(hive_ref) == TYPE_DICTIONARY:
		var h: Dictionary = hive_ref as Dictionary
		if h.has("owner_player_id"):
			return int(h.get("owner_player_id", 0))
		return int(h.get("owner_id", 0))
	if hive_ref is Object:
		var obj: Object = hive_ref as Object
		var owner_v: Variant = obj.get("owner_player_id")
		if owner_v != null:
			return int(owner_v)
		owner_v = obj.get("owner_id")
		if owner_v != null:
			return int(owner_v)
	return 0

func _owner_id_for_lane(hive_id: int, rm: Dictionary) -> int:
	if state != null:
		var hive: HiveData = state.find_hive_by_id(hive_id)
		if hive != null:
			return int(hive.owner_id)
	if not rm.is_empty():
		var rm_hives_by_id: Dictionary = rm.get("hives_by_id", {})
		if rm_hives_by_id.has(hive_id):
			var hive_data: Variant = rm_hives_by_id.get(hive_id, null)
			return _owner_id_from_hive_ref(hive_data)
	return 0

func _with_alpha(color: Color, a: float) -> Color:
	return Color(color.r, color.g, color.b, a)

func _update_lane_candidates_visibility(running: bool) -> void:
	var prev_running: bool = _sim_running
	var prev_visible: bool = _lane_candidates_visible
	_sim_running = running
	var enabled: bool = _should_show_candidates()
	# Never show candidates by default (only via explicit debug action later)
	enabled = false
	if enabled != prev_visible:
		_lane_candidates_visible = enabled
		if DEBUG_LANES:
			SFLog.info("LANE_CANDIDATES_VIS", {"running": _sim_running, "enabled": enabled})
		_request_rebuild("lane_candidates_visibility")
		return
	if prev_running != _sim_running:
		_lane_candidates_visible = enabled
	queue_redraw()

func _should_show_candidates() -> bool:
	if not _sim_running:
		return show_lane_candidates_pre_game
	return show_lane_candidates_while_running
