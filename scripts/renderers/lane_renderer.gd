# NOTE: Gate/rate-limit lane debug logs to prevent per-frame spam.
# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.

class_name LaneRenderer
extends Node2D

const SFLog := preload("res://scripts/util/sf_log.gd")
const SpriteRegistry := preload("res://scripts/renderers/sprite_registry.gd")
const COLORKEY_SHADER := preload("res://shaders/sf_colorkey_alpha.gdshader")
const LANE_BAND_SHADER := preload("res://shaders/lane_band.gdshader")

@export var debug_lane_seg_overlay: bool = false
@export var debug_draw_magenta_x: bool = false
@export var debug_lane_metrics: bool = false
@export var show_lane_candidates_pre_game: bool = true
@export var show_lane_candidates_while_running: bool = false
@export var show_lane_sprites: bool = true

const DEBUG_LANES := false
const USE_LANE_SPRITES := false

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
const LANE_MAX_SEGMENTS := 8
const LANE_Z_INDEX := -5
const LANE_CONNECTOR_AT_ENDPOINTS := false
# --- Lane sprite sizing ---
const LANE_THICKNESS_PX := 2.0
const LANE_WIDTH_PX := 14.0
const LANE_MIN_LEN_PX := 6.0
const LANE_SCALE_CLAMP := Vector2(10.0, 10.0)
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
	var hives_by_id: Dictionary = _collect_hive_positions()
	if not hives_by_id.has(hive_id):
		return null
	var local_pos: Vector2 = hives_by_id[hive_id]
	return to_global(local_pos)

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
	_load_lane_textures()
	_ensure_lane_sprite_root()
	set_process(false)
	_lane_candidates_visible = false
	_request_rebuild("ready")

# Arena expects this signature.
func setup(state_ref: GameState, selection_ref: Object, arena_ref: Node2D) -> void:
	state = state_ref
	sel = selection_ref
	arena = arena_ref
	queue_redraw()

func bind_state(state_ref: GameState) -> void:
	state = state_ref
	queue_redraw()

func set_model(rm: Dictionary) -> void:
	model = rm
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
	_request_rebuild("state_changed")

func set_hive_nodes(dict: Dictionary) -> void:
	if dict == hive_nodes_by_id:
		return
	hive_nodes_by_id = dict
	if DEBUG_LANES:
		SFLog.info("LANE_RENDERER_HIVES_SET", {"count": hive_nodes_by_id.size()})
	queue_redraw()
	_request_rebuild("hives_set")

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

func _draw_intended_lanes() -> void:
	if model.is_empty():
		return

	var hives_by_id: Dictionary = {}
	var cell_size: float = float(model.get("cell_size", 64))
	if not hive_nodes_by_id.is_empty():
		for hid in hive_nodes_by_id.keys():
			var node := hive_nodes_by_id[hid] as Node2D
			if node == null:
				continue
			hives_by_id[int(hid)] = to_local(node.global_position)
	else:
		var hives_v: Variant = model.get("hives", [])
		if typeof(hives_v) == TYPE_ARRAY:
			var hives: Array = hives_v as Array
			for h_v in hives:
				if typeof(h_v) != TYPE_DICTIONARY:
					continue
				var h: Dictionary = h_v as Dictionary
				var hid: int = int(h.get("id", -1))
				if hid <= 0:
					continue
				var pos_v: Variant = h.get("pos")
				var pos: Vector2
				if typeof(pos_v) == TYPE_VECTOR2:
					pos = pos_v as Vector2
				else:
					var x: int = int(h.get("x", 0))
					var y: int = int(h.get("y", 0))
					pos = _grid_to_world_center(x, y, cell_size)
				hives_by_id[hid] = to_local(pos)

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
		if not (hives_by_id.has(a_id) and hives_by_id.has(b_id)):
			continue
		if bool(l.get("send_a", false)) or bool(l.get("send_b", false)):
			var a_pos: Vector2 = hives_by_id[a_id]
			var b_pos: Vector2 = hives_by_id[b_id]
			var pts: Dictionary = GameState.lane_edge_points(a_pos, b_pos)
			var p0: Vector2 = pts.get("a_edge", a_pos)
			var p1: Vector2 = pts.get("b_edge", b_pos)
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

		var a_pos := to_local(a_node.global_position)
		var b_pos := to_local(b_node.global_position)

		var seg := _edge_to_edge_segment(a_pos, b_pos)
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
	var registry := SpriteRegistry.get_instance()
	var tex: Texture2D = null
	var tex_path := ""
	if registry != null:
		tex = _unwrap_atlas(registry.get_tex(LANE_TEX_KEY))
		tex_path = registry.get_tex_path(LANE_TEX_KEY)
	if tex == null and ResourceLoader.exists(LANE_FALLBACK_PATH):
		tex = ResourceLoader.load(LANE_FALLBACK_PATH) as Texture2D
		tex_path = LANE_FALLBACK_PATH
		if not _lane_tex_logged:
			_lane_tex_logged = true
			SFLog.warn("LANE_TEX_RESOLVE_FALLBACK", {
				"key": LANE_TEX_KEY,
				"fallback_path": LANE_FALLBACK_PATH
			})
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
	_lane_colorkey_material = mat
	return mat

func _get_lane_band_material() -> ShaderMaterial:
	if _lane_band_material != null:
		return _lane_band_material
	var mat := ShaderMaterial.new()
	mat.shader = LANE_BAND_SHADER
	mat.set_shader_parameter("band", 0.18)
	mat.set_shader_parameter("feather", 0.10)
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

func _collect_hive_positions() -> Dictionary:
	var hives_by_id: Dictionary = {}
	var cell_size: float = float(model.get("cell_size", 64))
	if not hive_nodes_by_id.is_empty():
		for hid in hive_nodes_by_id.keys():
			var node := hive_nodes_by_id[hid] as Node2D
			if node == null:
				continue
			hives_by_id[int(hid)] = to_local(node.global_position)
	else:
		var hives_v: Variant = model.get("hives", [])
		if typeof(hives_v) == TYPE_ARRAY:
			var hives: Array = hives_v as Array
			for h_v in hives:
				if typeof(h_v) != TYPE_DICTIONARY:
					continue
				var h: Dictionary = h_v as Dictionary
				var hid: int = int(h.get("id", -1))
				if hid <= 0:
					continue
				var pos_v: Variant = h.get("pos")
				var pos: Vector2
				if typeof(pos_v) == TYPE_VECTOR2:
					pos = pos_v as Vector2
				else:
					var x: int = int(h.get("x", 0))
					var y: int = int(h.get("y", 0))
					pos = _grid_to_world_center(x, y, cell_size)
				hives_by_id[hid] = to_local(pos)
	return hives_by_id

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
	_rebuild_req_reason = reason
	if _rebuild_pending:
		return
	_rebuild_pending = true
	call_deferred("_flush_rebuild")

func _flush_rebuild() -> void:
	_rebuild_pending = false
	var sig := _compute_active_lane_signature()
	if sig == _last_sig:
		return
	_last_sig = sig
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
	return "|".join(parts)

func _rebuild_lane_sprites_now() -> void:
	if not USE_LANE_SPRITES:
		return
	if not show_lane_sprites:
		return
	# HARD GUARD: never draw candidate lanes unless explicitly enabled.
	if not _lane_candidates_visible:
		# We still allow ACTIVE lanes (send_a/send_b true) to render.
		# But we do NOT want “all possible lanes” ever.
		pass
	_ensure_lane_sprite_root()
	# Hard clear before any rebuild to avoid double-draw/accumulation.
	_clear_lane_sprites()
	if _lane_tex == null:
		_load_lane_textures()
	if _lane_tex == null:
		return
	if hive_nodes_by_id.is_empty() and model.is_empty():
		return
	var hives_by_id := _collect_hive_positions()
	if hives_by_id.is_empty():
		return
	var lanes: Array = _lane_entries_from_model()
	var rm: Dictionary = model
	if lanes.is_empty():
		lanes = _lane_entries_from_state()
		rm = {}
	var total_rm_lanes := lanes.size()
	if not _lane_candidates_visible:
		var active: Array = []
		for lane in lanes:
			if typeof(lane) != TYPE_DICTIONARY:
				continue
			var d := lane as Dictionary
			var send_a: bool = bool(d.get("send_a", false))
			var send_b: bool = bool(d.get("send_b", false))
			var intent: String = str(d.get("intent", ""))
			if send_a or send_b or intent != "":
				active.append(d)
		lanes = active
	if lanes.is_empty():
		return
	var lane_count := 0
	var seg_total := 0
	var sample_seg_len: float = -1.0
	var sample_scale: Vector2 = Vector2.ZERO
	for lane in lanes:
		if typeof(lane) != TYPE_DICTIONARY:
			continue
		var d := lane as Dictionary
		var a_id: int = int(d.get("a_id", d.get("from", 0)))
		var b_id: int = int(d.get("b_id", d.get("to", 0)))
		if a_id <= 0 or b_id <= 0:
			continue
		var send_a: bool = bool(d.get("send_a", false))
		var send_b: bool = bool(d.get("send_b", false))
		var intent: String = str(d.get("intent", ""))
		var is_candidate: bool = (not send_a and not send_b and intent == "")
		if is_candidate and not _lane_candidates_visible:
			continue
		if not (hives_by_id.has(a_id) and hives_by_id.has(b_id)):
			continue
		var lane_id: int = int(d.get("lane_id", d.get("id", -1)))
		var key := _lane_key(a_id, b_id, lane_id)
		if lane_id > 0:
			_lane_key_by_id[lane_id] = key
		var p0: Vector2 = hives_by_id[a_id]
		var p1: Vector2 = hives_by_id[b_id]
		var dist := p0.distance_to(p1)
		if dist <= 0.01:
			continue
		var seg_len := maxf(_lane_segment_len(), 1.0)
		var n: int = int(clamp(round(dist / seg_len), 1, LANE_MAX_SEGMENTS))
		lane_count += 1
		seg_total += n
		var color_a: Color = _lane_color_for_hive(a_id)
		var color_b: Color = _lane_color_for_hive(b_id)
		var front_t: float = float(d.get("front_t", d.get("split_t", 0.5)))
		var segments: Array = []
		for i in range(n):
			var t0: float = float(i) / float(n)
			var t1: float = float(i + 1) / float(n)
			var t_mid: float = (t0 + t1) * 0.5
			var a_seg: Vector2 = p0.lerp(p1, t0)
			var b_seg: Vector2 = p0.lerp(p1, t1)
			var lane_tex: Texture2D = _lane_tex
			var sprite := _make_lane_segment_sprite(a_seg, b_seg, lane_tex)
			if sprite == null:
				continue
			if sample_seg_len < 0.0:
				sample_seg_len = a_seg.distance_to(b_seg)
				sample_scale = sprite.scale
			var seg_color: Color = _lane_color_for_t(send_a, send_b, color_a, color_b, t_mid, front_t)
			sprite.modulate = seg_color
			sprite.modulate.a = 0.0
			sprite.z_index = LANE_Z_INDEX
			_lane_sprite_root.add_child(sprite)
			segments.append(sprite)
		var connectors: Array = []
		var connector_tex := _lane_connector_tex if _lane_connector_tex != null else _lane_tex
		if connector_tex != null:
			var start_j := 1
			var end_j := n - 1
			if LANE_CONNECTOR_AT_ENDPOINTS:
				start_j = 0
				end_j = n
			for j in range(start_j, end_j + 1):
				if j <= 0 or j >= n:
					if not LANE_CONNECTOR_AT_ENDPOINTS:
						continue
				var t_j: float = float(j) / float(n)
				var pos_j: Vector2 = p0.lerp(p1, t_j)
				var conn := Sprite2D.new()
				conn.texture = connector_tex
				conn.material = null
				if not _lane_connector_tex_has_alpha:
					var lane_mat := _get_lane_colorkey_material()
					if lane_mat != null:
						conn.material = lane_mat
				conn.position = pos_j
				conn.rotation = 0.0
				conn.scale = Vector2.ONE * LANE_CONNECTOR_SCALE
				var conn_color: Color = _lane_color_for_t(send_a, send_b, color_a, color_b, t_j, front_t)
				conn.modulate = conn_color
				conn.modulate.a = 0.0
				conn.centered = true
				conn.z_index = LANE_Z_INDEX
				_lane_sprite_root.add_child(conn)
				connectors.append(conn)
		_lane_nodes_by_key[key] = {
			"segments": segments,
			"connectors": connectors,
			"a_id": a_id,
			"b_id": b_id,
			"lane_id": lane_id
		}
	var sprite_children := _lane_sprite_root.get_child_count() if _lane_sprite_root != null else 0
	if DEBUG_LANES and debug_lane_metrics:
		SFLog.info("LANE_SPRITE_FILTER", {
			"total_rm_lanes": total_rm_lanes,
			"visible_lane_count": lane_count,
			"segments_created_total": seg_total,
			"sprite_children": sprite_children
		})
	if OS.is_debug_build():
		assert(seg_total <= lane_count * 32)
	if lane_count > 0:
		var avg := float(seg_total) / float(lane_count)
		var tex_size := _lane_tex.get_size() if _lane_tex != null else Vector2.ZERO
		if DEBUG_LANES and debug_lane_metrics:
			SFLog.info("LANE_SPRITE_SIZE", {
				"tex_size": tex_size,
				"seg_len": sample_seg_len,
				"scale": sample_scale,
				"lane_count": lane_count,
				"seg_per_lane": avg
			})
			SFLog.info("LANE_SPRITE_BUILD", {
				"lane_count": lane_count,
				"seg_per_lane_avg": avg
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
	var hives_by_id: Dictionary = _collect_hive_positions()
	for lane in lanes:
		if typeof(lane) != TYPE_DICTIONARY:
			continue
		var d := lane as Dictionary
		var a_id: int = int(d.get("a_id", d.get("from", 0)))
		var b_id: int = int(d.get("b_id", d.get("to", 0)))
		if not (hives_by_id.has(a_id) and hives_by_id.has(b_id)):
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
		var p0_local: Vector2 = hives_by_id[a_id]
		var p1_local: Vector2 = hives_by_id[b_id]
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

		var a_pos := to_local(a_node.global_position)
		var b_pos := to_local(b_node.global_position)

		var seg := _edge_to_edge_segment(a_pos, b_pos)
		if seg.size() != 2:
			continue
		var width := 2.0
		if send_a or send_b:
			width = 3.0
		var lane_meta := d.duplicate()
		lane_meta["build_t"] = build_t
		_draw_lane_colored(seg[0], seg[1], a_id, b_id, send_a, send_b, rm, width, lane_meta)

func _edge_to_edge_segment(a_pos: Vector2, b_pos: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a_pos, b_pos])

func pick_lane_at_world_pos(world_pos: Vector2, max_dist: float) -> Dictionary:
	if max_dist <= 0.0:
		return {"hit": false}
	var lanes := _lane_entries_from_model()
	if lanes.is_empty():
		lanes = _lane_entries_from_state()
	if lanes.is_empty():
		return {"hit": false}
	var hives_by_id := _collect_hive_positions()
	if hives_by_id.is_empty():
		return {"hit": false}
	var local_pos := to_local(world_pos)
	var best_dist := max_dist
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
		if not hives_by_id.has(a_id) or not hives_by_id.has(b_id):
			continue
		var a_pos: Vector2 = hives_by_id[a_id]
		var b_pos: Vector2 = hives_by_id[b_id]
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
		var hives_by_id: Dictionary = rm.get("hives_by_id", {})
		if hives_by_id.has(hive_id):
			var h: Dictionary = hives_by_id[hive_id]
			return _owner_id_from_hive_ref(h)
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
