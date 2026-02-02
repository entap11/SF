# NOTE: Add debug gating/rate limits for logs to prevent per-frame spam.
extends Node2D

const SFLog := preload("res://scripts/util/sf_log.gd")
const SpriteRegistry := preload("res://scripts/renderers/sprite_registry.gd")
const COLORKEY_SHADER := preload("res://shaders/sf_colorkey_alpha.gdshader")

var model: Dictionary = {}
var hive_nodes_by_id: Dictionary = {}
var _units: Array = []
var _last_set_count: int = -1
var _last_set_log_ms: int = 0
var _last_model_units_count: int = -1
var _last_live_nodes_count: int = -1
var swarm_nodes_by_id: Dictionary = {}
var unit_nodes_by_id: Dictionary = {}
var _swarm_texture: Texture2D = null
var _sprite_registry: SpriteRegistry = null
var _colorkey_materials: Dictionary = {}
var _unit_material_by_sprite: Dictionary = {}
var _unit_material_by_instance: Dictionary = {}
var _unit_team_color_logged: Dictionary = {}
var _unit_tint_target_logged: Dictionary = {}
var _unit_material_cleared_logged: Dictionary = {}
var _unit_visual_by_id: Dictionary = {}
var _unit_samples_by_id: Dictionary = {}
var _unit_data_by_id: Dictionary = {}
var _unit_colorkey_logged := false
var _unit_sprite_logged := false

const UNIT_RADIUS_PX := 3.5
const UNIT_DRAW_RADIUS_PX: float = 4.0
const UNIT_RENDER_SCALE: float = 3.0
const UNIT_SPRITE_FORWARD_DEG: float = 45.0
const UNIT_TRAVEL_T_EPS: float = 0.02
const DBG_UNITS: bool = false
const HiveRenderer := preload("res://scripts/renderers/hive_renderer.gd")
const UNIT_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const DEBUG_HIVE1_CROSS := false
const UNIT_LOG_INTERVAL_MS := 1000
const UNIT_BOUNDS_LOG_INTERVAL_MS := 1000
const UNIT_REDRAW_INTERVAL_MS := 30
const SWARM_SCALE_MULT: float = 15.0
const SWARM_LABEL_FONT_SIZE: int = 12
const SWARM_LABEL_SIZE: Vector2 = Vector2(48.0, 20.0)
const SWARM_TEXTURE_SIZE: int = 32
const SWARM_TEXTURE_PATH: String = "res://assets/sprites/sf_skin_v1/swarm.png"
const BOBBLE_AMP_MIN_PX: float = 2.0
const BOBBLE_AMP_MAX_PX: float = 6.0
const BOBBLE_OMEGA: float = 8.0
const SIM_DT_SEC_DEFAULT: float = 0.1
const BUTTER_INTERP_DELAY_TICKS: float = 1.0
const SAMPLE_T_EPS: float = 0.001
const BUTTER_MAX_EXTRAP_SEC: float = 0.05
const DBG_BUTTER: bool = false
const DBG_BUTTER_LOG_INTERVAL_MS: int = 1000
const DBG_FORCE_CONSTANT_VISUAL_MOTION: bool = false
const DBG_VISUAL_SPEED: float = 0.35
const USE_UNIT_POOL: bool = true
const UNIT_POOL_SIZE_PER_TEAM: int = 64
const UNIT_POOL_OFFSCREEN_POS: Vector2 = Vector2(-99999.0, -99999.0)

@export var debug_unit_logs: bool = false
@export var debug_unit_owner_labels: bool = false
@export var debug_draw_units: bool = false
@export var debug_force_top_z: bool = true
@export var debug_force_big_radius_px: float = 10.0
@export var sim_dt_sec: float = SIM_DT_SEC_DEFAULT

var _unit_space: String = "local"
var _unit_space_logged: bool = false
var _pending_redraw: bool = false
var _last_redraw_ms: int = 0
var _last_bounds_log_ms: int = 0
var _last_force_top_z: bool = false
var _bobble_logged: bool = false
var _dbg_butter_last_ms: int = 0
var _diag_visual_phase_by_id: Dictionary = {}
var _unit_pool: Array[Node2D] = []
var _unit_in_use: Dictionary = {}
var _pooled_nodes: Dictionary = {}

func _ready() -> void:
	_pool_build()
	_apply_debug_force_top_z()
	_request_redraw()

func _now_sec() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0

func _assert_not_freed(n: Node) -> bool:
	if n == null:
		push_error("UnitRenderer: NULL node passed")
		return false
	elif not is_instance_valid(n):
		push_error("UnitRenderer: FREED node detected — pooling violation")
		return false
	return true

func _tracked_unit_id_for_node(node: Node2D) -> int:
	if node == null:
		return -1
	var meta_id: int = int(node.get_meta("unit_id", -1))
	if meta_id > 0 and unit_nodes_by_id.get(meta_id, null) == node:
		return meta_id
	var ids: Array = unit_nodes_by_id.keys()
	for id_any in ids:
		var unit_id: int = int(id_any)
		var candidate: Node2D = unit_nodes_by_id.get(unit_id, null)
		if candidate == node:
			return unit_id
	return -1

func _create_unit_render_node() -> Node2D:
	var node: Node2D = Node2D.new()
	node.z_index = 0
	_ensure_unit_sprite(node)
	return node

func _pool_build() -> void:
	if not USE_UNIT_POOL:
		return
	if not _unit_pool.is_empty():
		return
	var total_nodes: int = UNIT_POOL_SIZE_PER_TEAM * 4
	for i in range(total_nodes):
		var node: Node2D = _create_unit_render_node()
		node.name = "UnitPool_%d" % i
		node.visible = false
		node.position = UNIT_POOL_OFFSCREEN_POS
		node.rotation = 0.0
		node.scale = Vector2.ONE
		node.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(node)
		_unit_pool.append(node)
		_pooled_nodes[node] = true

func _pool_acquire() -> Node2D:
	if not USE_UNIT_POOL:
		var direct_node: Node2D = _create_unit_render_node()
		add_child(direct_node)
		if not _assert_not_freed(direct_node):
			return null
		return direct_node
	_pool_build()
	if _unit_pool.is_empty():
		var node_extra: Node2D = _create_unit_render_node()
		node_extra.name = "UnitPool_Extra"
		add_child(node_extra)
		if not _assert_not_freed(node_extra):
			return null
		_pool_release(node_extra)
	var node: Node2D = _unit_pool.pop_back()
	if not _assert_not_freed(node):
		return null
	if not _pooled_nodes.has(node):
		push_error("UnitRenderer: acquired node missing from pool tracking")
	_pooled_nodes.erase(node)
	if not _assert_not_freed(node):
		return null
	node.visible = true
	if not _assert_not_freed(node):
		return null
	node.process_mode = Node.PROCESS_MODE_INHERIT
	return node

func _pool_release(node: Node2D) -> void:
	if not _assert_not_freed(node):
		return
	if node == null:
		return
	if _pooled_nodes.has(node):
		push_error("UnitRenderer: double-release detected")
		return
	var unit_id: int = _tracked_unit_id_for_node(node)
	if unit_id > 0:
		unit_nodes_by_id.erase(unit_id)
		_unit_in_use.erase(unit_id)
		_unit_visual_by_id.erase(unit_id)
		_unit_samples_by_id.erase(unit_id)
		_diag_visual_phase_by_id.erase(unit_id)
	node.set_meta("unit_id", -1)
	var sprite: Sprite2D = node.get_node_or_null("UnitSprite") as Sprite2D
	if sprite != null:
		sprite.texture = null
		sprite.material = null
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE
		sprite.rotation = 0.0
		sprite.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		sprite.visible = false
	if not _assert_not_freed(node):
		return
	node.visible = false
	if not _assert_not_freed(node):
		return
	node.position = Vector2.ZERO
	if not _assert_not_freed(node):
		return
	node.rotation = 0.0
	if not _assert_not_freed(node):
		return
	node.global_rotation = 0.0
	if not _assert_not_freed(node):
		return
	node.scale = Vector2.ONE
	if not _assert_not_freed(node):
		return
	node.process_mode = Node.PROCESS_MODE_DISABLED
	_pooled_nodes[node] = true
	if USE_UNIT_POOL:
		if not _unit_pool.has(node):
			_unit_pool.append(node)
	else:
		push_error("UnitRenderer: queue_free forbidden for unit render nodes")

func prewarm_pool() -> void:
	_pool_build()
	if not USE_UNIT_POOL:
		return
	var node: Node2D = _pool_acquire()
	if node == null:
		return
	if not _assert_not_freed(node):
		return
	node.position = UNIT_POOL_OFFSCREEN_POS
	var sprite: Sprite2D = _ensure_unit_sprite(node)
	if sprite != null:
		var registry: SpriteRegistry = _get_sprite_registry()
		if registry != null:
			var key: String = "unit.neutral"
			var tex: Texture2D = registry.get_tex(key)
			if tex == null:
				var tex_path: String = registry.get_tex_path(key)
				if not tex_path.is_empty():
					var res: Resource = ResourceLoader.load(tex_path)
					if res is Texture2D:
						tex = res as Texture2D
			sprite.texture = tex
		sprite.visible = true
	call_deferred("_release_prewarm_unit_next_frame", node)

func _release_prewarm_unit_next_frame(node: Node2D) -> void:
	await get_tree().process_frame
	if not _assert_not_freed(node):
		return
	_pool_release(node)

func set_model(m: Dictionary) -> void:
	model = m
	var units_v: Variant = model.get("units", [])
	var units_arr: Array = []
	if typeof(units_v) == TYPE_ARRAY:
		units_arr = units_v as Array
	_units = units_arr
	_rebuild_unit_data_index(units_arr)
	_sync_unit_nodes(units_arr)
	_update_unit_nodes_positions(units_arr)
	_sync_swarm_nodes()
	_request_redraw()

func set_units(units: Array) -> void:
	_units = units
	model["units"] = units
	_rebuild_unit_data_index(units)
	_sync_unit_nodes(units)
	_update_unit_nodes_positions(units)
	var c := units.size()
	if debug_unit_logs and c != _last_set_count:
		_last_set_count = c
		var now_ms := Time.get_ticks_msec()
		if now_ms - _last_set_log_ms >= UNIT_LOG_INTERVAL_MS:
			_last_set_log_ms = now_ms
			SFLog.info("UNIT_RENDERER_SET", {"count": c})
	_request_redraw()

func set_hive_nodes(dict: Dictionary) -> void:
	hive_nodes_by_id = dict
	_sync_swarm_nodes()
	_request_redraw()

func clear_all() -> void:
	model = {}
	_unit_data_by_id.clear()
	_unit_visual_by_id.clear()
	_unit_samples_by_id.clear()
	_diag_visual_phase_by_id.clear()
	_clear_swarm_nodes()
	_clear_unit_nodes()
	_request_redraw()

func _sync_unit_nodes(units: Array) -> void:
	var present: Dictionary = {}
	if not units.is_empty():
		_log_unit_space_once()
	for unit_any in units:
		if typeof(unit_any) != TYPE_DICTIONARY:
			continue
		var ud: Dictionary = unit_any as Dictionary
		var unit_id: int = int(ud.get("id", -1))
		if unit_id <= 0:
			continue
		present[unit_id] = true
		if not unit_nodes_by_id.has(unit_id):
			var node: Node2D = _pool_acquire()
			if node == null:
				continue
			if not _assert_not_freed(node):
				continue
			node.name = "Unit_%d" % unit_id
			node.set_meta("unit_id", unit_id)
			node.z_index = 0
			unit_nodes_by_id[unit_id] = node
			_unit_in_use[unit_id] = node
			_ensure_unit_sprite(node)
			_log_unit_sprite_tree(node, unit_id)
			SFLog.info("UNIT_RENDER_CREATE", {
				"unit_id": unit_id,
				"owner_id": int(ud.get("owner_id", 0))
			})
	var existing_ids: Array = unit_nodes_by_id.keys()
	for existing_id in existing_ids:
		if present.has(existing_id):
			continue
		var node: Node2D = unit_nodes_by_id.get(existing_id, null)
		if node != null:
			if not _assert_not_freed(node):
				continue
			_pool_release(node)
			SFLog.info("UNIT_RENDER_PRUNE", {"unit_id": int(existing_id)})
	var model_count: int = units.size()
	var live_count: int = unit_nodes_by_id.size()
	if model_count != _last_model_units_count or live_count != _last_live_nodes_count:
		_last_model_units_count = model_count
		_last_live_nodes_count = live_count
		if SFLog.verbose_sim:
			SFLog.throttled_info("UNIT_RENDER_COUNTS", {
				"model_units": units.size(),
				"live_nodes": unit_nodes_by_id.size()
			}, 500)

func _rebuild_unit_data_index(units: Array) -> void:
	_unit_data_by_id.clear()
	for unit_any in units:
		if typeof(unit_any) != TYPE_DICTIONARY:
			continue
		var ud: Dictionary = unit_any as Dictionary
		var unit_id: int = int(ud.get("id", -1))
		if unit_id <= 0:
			continue
		_unit_data_by_id[unit_id] = ud

func _clear_unit_nodes() -> void:
	var existing_ids: Array = unit_nodes_by_id.keys()
	for existing_id in existing_ids:
		var node: Node2D = unit_nodes_by_id.get(existing_id, null)
		if node != null:
			if not _assert_not_freed(node):
				continue
			_pool_release(node)
	unit_nodes_by_id.clear()
	_unit_in_use.clear()
	_unit_visual_by_id.clear()
	_unit_samples_by_id.clear()

func _update_unit_nodes_positions(units: Array) -> void:
	if units.is_empty():
		return
	var hive_by_id: Dictionary = _build_hive_by_id()
	var registry: SpriteRegistry = _get_sprite_registry()
	for unit_any in units:
		if typeof(unit_any) != TYPE_DICTIONARY:
			continue
		var ud: Dictionary = unit_any as Dictionary
		var unit_id: int = int(ud.get("id", -1))
		if unit_id <= 0:
			continue
		var node: Node2D = unit_nodes_by_id.get(unit_id, null)
		if node == null:
			continue
		var sprite: Sprite2D = _ensure_unit_sprite(node)
		if sprite == null:
			continue
		_update_unit_sprite(node, ud, hive_by_id, registry, false)
		_ingest_unit_sample(ud, hive_by_id, unit_id)

func _update_unit_visual_target(_node: Node2D, ud: Dictionary, hive_by_id: Dictionary, unit_id: int) -> void:
	_ingest_unit_sample(ud, hive_by_id, unit_id)

func _ingest_unit_sample(ud: Dictionary, hive_by_id: Dictionary, unit_id: int) -> void:
	var lane_id: int = int(ud.get("lane_id", 0))
	var sample_pos: Vector2 = _sample_unit_pos_map_local(ud, hive_by_id)
	var sample_dir: Vector2 = _sample_unit_dir_map_local(ud, hive_by_id)
	var endpoints: Dictionary = _unit_path_endpoints_map_local(ud, hive_by_id)
	var target_t: float = clampf(float(ud.get("t", 0.0)), 0.0, 1.0)
	var a_pos: Vector2 = sample_pos
	var b_pos: Vector2 = sample_pos
	if bool(endpoints.get("ok", false)):
		a_pos = endpoints.get("a", sample_pos)
		b_pos = endpoints.get("b", sample_pos)
	var s_new: Dictionary = {
		"t": target_t,
		"a": a_pos,
		"b": b_pos,
		"ts": _now_sec()
	}
	var buf_any: Variant = _unit_samples_by_id.get(unit_id, null)
	var buf: Dictionary = {}
	if typeof(buf_any) == TYPE_DICTIONARY:
		buf = buf_any as Dictionary
	if not buf.has("s0"):
		buf["s0"] = s_new
		buf["s1"] = s_new
	else:
		var prev_any: Variant = buf.get("s1", s_new)
		var prev: Dictionary = s_new
		if typeof(prev_any) == TYPE_DICTIONARY:
			prev = prev_any as Dictionary
		buf["s0"] = prev
		buf["s1"] = s_new
	_unit_samples_by_id[unit_id] = buf
	var entry: Dictionary = {}
	var existing_any: Variant = _unit_visual_by_id.get(unit_id, null)
	if typeof(existing_any) == TYPE_DICTIONARY:
		entry = existing_any as Dictionary
	if entry.is_empty():
		entry["prev_pos"] = sample_pos
		entry["curr_pos"] = sample_pos
	else:
		var curr_pos: Vector2 = entry.get("curr_pos", sample_pos)
		entry["prev_pos"] = curr_pos
		entry["curr_pos"] = sample_pos
	entry["lane_id"] = lane_id
	entry["dir"] = sample_dir
	_unit_visual_by_id[unit_id] = entry

func _sample_unit_pos_map_local(ud: Dictionary, hive_by_id: Dictionary) -> Vector2:
	var endpoints: Dictionary = _unit_path_endpoints_map_local(ud, hive_by_id)
	if bool(endpoints.get("ok", false)):
		var a_pos: Vector2 = endpoints.get("a", Vector2.ZERO)
		var b_pos: Vector2 = endpoints.get("b", Vector2.ZERO)
		var t: float = clampf(float(ud.get("t", 0.0)), 0.0, 1.0)
		return a_pos.lerp(b_pos, t)
	var pos_v: Variant = ud.get("pos", null)
	if pos_v is Vector2:
		return pos_v as Vector2
	var wp_v: Variant = ud.get("wp", null)
	if wp_v is Vector2:
		return wp_v as Vector2
	var p_v: Variant = ud.get("position", null)
	if p_v is Vector2:
		return p_v as Vector2
	return Vector2.ZERO

func _sample_unit_dir_map_local(ud: Dictionary, hive_by_id: Dictionary) -> Vector2:
	var endpoints: Dictionary = _unit_path_endpoints_map_local(ud, hive_by_id)
	if bool(endpoints.get("ok", false)):
		var a_pos: Vector2 = endpoints.get("a", Vector2.ZERO)
		var b_pos: Vector2 = endpoints.get("b", Vector2.ZERO)
		var axis: Vector2 = b_pos - a_pos
		if axis.length_squared() > 0.000001:
			var sign: int = _unit_travel_sign(ud)
			return axis.normalized() * float(sign)
	return Vector2.RIGHT

func _unit_path_endpoints_map_local(ud: Dictionary, hive_by_id: Dictionary) -> Dictionary:
	var from_pos_v: Variant = ud.get("from_pos", null)
	var to_pos_v: Variant = ud.get("to_pos", null)
	if from_pos_v is Vector2 and to_pos_v is Vector2:
		return {"ok": true, "a": from_pos_v as Vector2, "b": to_pos_v as Vector2}
	var a_id: int = _resolve_id(ud.get("a_id", 0))
	var b_id: int = _resolve_id(ud.get("b_id", 0))
	if a_id > 0 and b_id > 0:
		var a_center_v: Variant = _hive_center_map_local(a_id, hive_by_id)
		var b_center_v: Variant = _hive_center_map_local(b_id, hive_by_id)
		if a_center_v is Vector2 and b_center_v is Vector2:
			var a_center: Vector2 = a_center_v as Vector2
			var b_center: Vector2 = b_center_v as Vector2
			var edge: Dictionary = GameState.lane_edge_points(a_center, b_center)
			var a_edge: Vector2 = edge.get("a_edge", a_center)
			var b_edge: Vector2 = edge.get("b_edge", b_center)
			return {"ok": true, "a": a_edge, "b": b_edge}
	var from_id: int = _resolve_id(ud.get("from_id", ud.get("from", 0)))
	var to_id: int = _resolve_id(ud.get("to_id", ud.get("to", 0)))
	if from_id > 0 and to_id > 0:
		var from_center_v: Variant = _hive_center_map_local(from_id, hive_by_id)
		var to_center_v: Variant = _hive_center_map_local(to_id, hive_by_id)
		if from_center_v is Vector2 and to_center_v is Vector2:
			var from_center: Vector2 = from_center_v as Vector2
			var to_center: Vector2 = to_center_v as Vector2
			var edge_ft: Dictionary = GameState.lane_edge_points(from_center, to_center)
			var from_edge: Vector2 = edge_ft.get("a_edge", from_center)
			var to_edge: Vector2 = edge_ft.get("b_edge", to_center)
			return {"ok": true, "a": from_edge, "b": to_edge}
	return {"ok": false, "a": Vector2.ZERO, "b": Vector2.ZERO}

func _hive_center_map_local(hive_id: int, hive_by_id: Dictionary) -> Variant:
	if hive_nodes_by_id.has(hive_id):
		var node: Node2D = hive_nodes_by_id[hive_id]
		if node != null:
			return node.position
	if hive_by_id.has(hive_id):
		var hd: Dictionary = hive_by_id[hive_id]
		var cell_size: float = float(model.get("cell_size", 64))
		var gx: float = float(hd.get("x", 0.0))
		var gy: float = float(hd.get("y", 0.0))
		return Vector2((gx + 0.5) * cell_size, (gy + 0.5) * cell_size)
	return null

func _to_render_local(pos: Vector2) -> Vector2:
	if _unit_space == "global":
		return to_local(pos)
	return pos

func _build_hive_by_id() -> Dictionary:
	var hive_by_id: Dictionary = {}
	var hives_v: Variant = model.get("hives", [])
	if typeof(hives_v) == TYPE_ARRAY:
		for h in hives_v as Array:
			if typeof(h) != TYPE_DICTIONARY:
				continue
			var hd: Dictionary = h as Dictionary
			var id_str := str(hd.get("id", ""))
			if id_str.is_valid_int():
				hive_by_id[int(id_str)] = hd
	return hive_by_id

func _unit_pos_in_space(u: Variant, hive_by_id: Dictionary) -> Variant:
	var pos_result: Array = _unit_pos(u, hive_by_id)
	if pos_result.is_empty() or not bool(pos_result[0]):
		return null
	var pos: Vector2 = pos_result[1]
	return pos

func _unit_pos_local(u: Variant, hive_by_id: Dictionary) -> Variant:
	var pos: Variant = _unit_pos_in_space(u, hive_by_id)
	if not (pos is Vector2):
		return null
	if _unit_space == "global":
		return to_local(pos as Vector2)
	return pos

func _log_unit_space_once() -> void:
	if _unit_space_logged:
		return
	_unit_space_logged = true
	SFLog.info("UNIT_SPACE", {"space": _unit_space})

func _collect_sprite_descendants(root: Node) -> Array:
	var sprites: Array = []
	if root == null:
		return sprites
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Sprite2D:
			sprites.append(n)
		for child in n.get_children():
			if child is Node:
				stack.append(child)
	return sprites

func _find_unit_tint_target(root: Node) -> Sprite2D:
	var sprite: Sprite2D = root.get_node_or_null("UnitSprite") as Sprite2D
	return sprite

func _log_unit_sprite_tree(node: Node, unit_id: int) -> void:
	if not DBG_UNITS:
		return
	var sprites := _collect_sprite_descendants(node)
	if sprites.is_empty():
		SFLog.info("UNIT_SPRITE_DESC", {
			"unit_id": unit_id,
			"count": 0
		})
		return
	for s_any in sprites:
		var s := s_any as Sprite2D
		if s == null:
			continue
		var tex := s.texture
		var tex_path := ""
		if tex != null:
			tex_path = tex.resource_path
		var mat := s.material
		var mat_class := "null"
		if mat != null:
			mat_class = mat.get_class()
		SFLog.info("UNIT_SPRITE_DESC", {
			"unit_id": unit_id,
			"path": str(s.get_path()),
			"tex_path": tex_path,
			"has_tex": tex != null,
			"material": mat_class
		})

func _ensure_unit_sprite(node: Node2D) -> Sprite2D:
	var sprite := node.get_node_or_null("UnitSprite") as Sprite2D
	if sprite != null:
		return sprite
	sprite = Sprite2D.new()
	sprite.name = "UnitSprite"
	sprite.centered = true
	node.add_child(sprite)
	return sprite

func _apply_unit_orientation(
	unit_root: Node2D,
	sprite: Sprite2D,
	ud: Dictionary,
	hive_by_id: Dictionary,
	unit_id: int,
	owner_id: int,
	lane_id: int
) -> void:
	var p_now: Vector2 = unit_root.global_position
	var heading: Dictionary = _unit_travel_heading(ud, hive_by_id, p_now)
	var dir_v: Variant = heading.get("dir", Vector2.RIGHT)
	var dir: Vector2 = dir_v as Vector2 if dir_v is Vector2 else Vector2.RIGHT
	if dir.length_squared() < 0.000001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var ang: float = dir.angle()
	var final_ang: float = ang + deg_to_rad(UNIT_SPRITE_FORWARD_DEG)
	unit_root.global_rotation = final_ang
	sprite.rotation = 0.0

func _apply_unit_orientation_from_dir(unit_root: Node2D, sprite: Sprite2D, dir: Vector2) -> void:
	var safe_dir: Vector2 = dir
	if safe_dir.length_squared() < 0.000001:
		safe_dir = Vector2.RIGHT
	else:
		safe_dir = safe_dir.normalized()
	var ang: float = safe_dir.angle()
	var final_ang: float = ang + deg_to_rad(UNIT_SPRITE_FORWARD_DEG)
	unit_root.global_rotation = final_ang
	sprite.rotation = 0.0

func _update_unit_sprite(
	node: Node2D,
	ud: Dictionary,
	hive_by_id: Dictionary,
	registry: SpriteRegistry,
	apply_orientation: bool = true
) -> void:
	var owner_id: int = _unit_owner_id(ud, hive_by_id)
	var unit_id := int(node.get_meta("unit_id", -1))
	var sprite := _ensure_unit_sprite(node)
	if sprite == null:
		return
	var tex: Texture2D = null
	var tex_path := ""
	var scale := 1.0
	var offset := Vector2.ZERO
	var sprite_key := ""
	if registry != null:
		sprite_key = "unit.%s" % SpriteRegistry.owner_key(owner_id)
		tex = registry.get_tex(sprite_key)
		tex_path = registry.get_tex_path(sprite_key)
		scale = registry.get_scale(sprite_key)
		offset = registry.get_offset(sprite_key)
	if tex == null and not tex_path.is_empty():
		var fallback_res := ResourceLoader.load(tex_path)
		if fallback_res is Texture2D:
			tex = fallback_res as Texture2D
			SFLog.warn("UNIT_SPRITE_FALLBACK", {
				"unit_id": unit_id,
				"owner_id": owner_id,
				"key": sprite_key,
				"fallback_path": tex_path
			})
	if tex == null and registry != null and sprite_key != "unit.neutral":
		var neutral_key := "unit.neutral"
		var neutral_path := registry.get_tex_path(neutral_key)
		if not neutral_path.is_empty():
			var neutral_res := ResourceLoader.load(neutral_path)
			if neutral_res is Texture2D:
				tex = neutral_res as Texture2D
				tex_path = neutral_path
				SFLog.warn("UNIT_SPRITE_FALLBACK", {
					"unit_id": unit_id,
					"owner_id": owner_id,
					"key": neutral_key,
					"fallback_path": neutral_path
				})
	if tex == null:
		return
	var resolved_path := tex.resource_path
	if resolved_path.is_empty():
		resolved_path = tex_path
	# Order: texture -> material -> self_modulate
	if sprite.texture == null or sprite.texture != tex:
		sprite.texture = tex
	var team_color: Color = _owner_color(owner_id)
	team_color.a = UNIT_COLOR.a
	sprite.self_modulate = team_color
	var mat := _ensure_unit_colorkey_material(sprite, sprite_key, registry, owner_id, unit_id, team_color)
	if mat != null:
		sprite.material = mat
	if sprite.material is ShaderMaterial and sprite.material.shader == COLORKEY_SHADER and tex.resource_path.is_empty():
		sprite.material = null
		if debug_unit_logs and unit_id > 0 and not _unit_material_cleared_logged.has(unit_id):
			_unit_material_cleared_logged[unit_id] = true
			SFLog.info("UNIT_MATERIAL_CLEARED_FOR_TINT", {
				"unit_id": unit_id,
				"owner_id": owner_id,
				"path": str(sprite.get_path())
			})
	if debug_unit_logs and unit_id > 0 and not _unit_tint_target_logged.has(unit_id):
		_unit_tint_target_logged[unit_id] = true
		SFLog.info("UNIT_TINT_APPLIED", {
			"unit_id": unit_id,
			"owner_id": owner_id,
			"modulate": team_color,
			"texture_path": resolved_path
		})
		var mat_class := "null"
		var mat_set := sprite.material != null
		if mat_set:
			mat_class = sprite.material.get_class()
		SFLog.info("UNIT_TINT_DEBUG", {
			"unit_id": unit_id,
			"owner_id": owner_id,
			"node": str(sprite.get_path()),
			"modulate": sprite.modulate,
			"material_set": mat_set,
			"material_class": mat_class,
			"texture_path": resolved_path
		})
		SFLog.info("UNIT_COLKEY_APPLIED", {
			"node": str(sprite.get_path()),
			"node_class": sprite.get_class(),
			"ok": mat != null,
			"key": sprite_key
		})
		SFLog.info("UNIT_TINT_TARGET", {
			"unit_id": unit_id,
			"owner_id": owner_id,
			"target_path": str(sprite.get_path()),
			"tex_path": resolved_path,
			"is_sprite2d": sprite is Sprite2D
		})
	sprite.position = offset
	var tex_size := tex.get_size()
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		var size_px := debug_force_big_radius_px * 2.0 * scale * UNIT_RENDER_SCALE
		sprite.scale = Vector2(size_px / tex_size.x, size_px / tex_size.y)
	if apply_orientation:
		var lane_id: int = int(ud.get("lane_id", 0))
		_apply_unit_orientation(node, sprite, ud, hive_by_id, unit_id, owner_id, lane_id)
	sprite.visible = not debug_draw_units

func _apply_debug_force_top_z() -> void:
	if debug_force_top_z == _last_force_top_z:
		return
	_last_force_top_z = debug_force_top_z
	if debug_force_top_z:
		z_as_relative = false
		z_index = 9999
		for node in unit_nodes_by_id.values():
			if node is Node2D:
				(node as Node2D).z_index = 0
	else:
		z_as_relative = true
		z_index = 0

func _request_redraw() -> void:
	_pending_redraw = true

func _maybe_log_unit_bounds() -> void:
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_bounds_log_ms < UNIT_BOUNDS_LOG_INTERVAL_MS:
		return
	if _units.is_empty():
		return
	var hive_by_id := _build_hive_by_id()
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	var count := 0
	var any_in_view := false
	var cam_rect := _camera_rect_in_unit_space()
	for u in _units:
		if typeof(u) != TYPE_DICTIONARY:
			continue
		var pos: Variant = _unit_pos_in_space(u, hive_by_id)
		if not (pos is Vector2):
			continue
		var pos_v: Vector2 = pos as Vector2
		if _unit_space == "global":
			min_pos.x = minf(min_pos.x, pos_v.x)
			min_pos.y = minf(min_pos.y, pos_v.y)
			max_pos.x = maxf(max_pos.x, pos_v.x)
			max_pos.y = maxf(max_pos.y, pos_v.y)
			if cam_rect.has_point(pos_v):
				any_in_view = true
		else:
			var local_pos := pos_v
			min_pos.x = minf(min_pos.x, local_pos.x)
			min_pos.y = minf(min_pos.y, local_pos.y)
			max_pos.x = maxf(max_pos.x, local_pos.x)
			max_pos.y = maxf(max_pos.y, local_pos.y)
			if cam_rect.has_point(local_pos):
				any_in_view = true
		count += 1
	if count > 0 and not any_in_view:
		_last_bounds_log_ms = now_ms
		SFLog.info("UNIT_BOUNDS", {
			"count": count,
			"min": min_pos,
			"max": max_pos,
			"camera": cam_rect,
			"space": _unit_space
		})
	elif count > 0 and any_in_view:
		_last_bounds_log_ms = now_ms

func _camera_rect_in_unit_space() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2()
	var vp_size := get_viewport().get_visible_rect().size
	var zoom := cam.zoom
	var view_size := Vector2(
		vp_size.x / maxf(zoom.x, 0.001),
		vp_size.y / maxf(zoom.y, 0.001)
	)
	var center := cam.get_screen_center_position()
	var rect_global := Rect2(center - view_size * 0.5, view_size)
	if _unit_space == "global":
		return rect_global
	var tl := to_local(rect_global.position)
	var tr := to_local(rect_global.position + Vector2(rect_global.size.x, 0.0))
	var bl := to_local(rect_global.position + Vector2(0.0, rect_global.size.y))
	var br := to_local(rect_global.position + rect_global.size)
	var min_x := minf(tl.x, minf(tr.x, minf(bl.x, br.x)))
	var min_y := minf(tl.y, minf(tr.y, minf(bl.y, br.y)))
	var max_x := maxf(tl.x, maxf(tr.x, maxf(bl.x, br.x)))
	var max_y := maxf(tl.y, maxf(tr.y, maxf(bl.y, br.y)))
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _process(delta: float) -> void:
	_apply_debug_force_top_z()
	if DBG_FORCE_CONSTANT_VISUAL_MOTION:
		_render_units_constant_speed(delta)
	else:
		_update_unit_visual_smoothing(delta)
	_maybe_log_unit_bounds()
	var now_ms := Time.get_ticks_msec()
	if _pending_redraw and now_ms - _last_redraw_ms >= UNIT_REDRAW_INTERVAL_MS:
		_last_redraw_ms = now_ms
		_pending_redraw = false
		queue_redraw()

func _sample_float(sample: Dictionary, key: String, fallback: float) -> float:
	return float(sample.get(key, fallback))

func _sample_vec2(sample: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = sample.get(key, fallback)
	if value is Vector2:
		return value as Vector2
	return fallback

func _update_unit_visual_smoothing(_delta: float) -> void:
	var step_sec: float = maxf(sim_dt_sec, 0.000001)
	var interp_delay: float = step_sec * BUTTER_INTERP_DELAY_TICKS
	var render_time: float = _now_sec() - interp_delay
	_render_units(render_time, step_sec)

func _render_units_constant_speed(delta: float) -> void:
	if unit_nodes_by_id.is_empty():
		return
	var safe_delta: float = maxf(delta, 0.0)
	var hive_by_id: Dictionary = _build_hive_by_id()
	var ids: Array = unit_nodes_by_id.keys()
	for id_any in ids:
		var unit_id: int = int(id_any)
		var node: Node2D = unit_nodes_by_id.get(unit_id, null)
		if node == null:
			continue
		if not _assert_not_freed(node):
			continue
		var phase: float = float(_diag_visual_phase_by_id.get(unit_id, 0.0))
		phase = fposmod(phase + safe_delta * DBG_VISUAL_SPEED, 1.0)
		_diag_visual_phase_by_id[unit_id] = phase
		var start_pos: Vector2 = Vector2.ZERO
		var end_pos: Vector2 = Vector2.ZERO
		var has_endpoints: bool = false
		var unit_any: Variant = _unit_data_by_id.get(unit_id, null)
		if typeof(unit_any) == TYPE_DICTIONARY:
			var ud: Dictionary = unit_any as Dictionary
			var endpoints: Dictionary = _unit_path_endpoints_map_local(ud, hive_by_id)
			has_endpoints = bool(endpoints.get("ok", false))
			if has_endpoints:
				start_pos = endpoints.get("a", Vector2.ZERO)
				end_pos = endpoints.get("b", Vector2.ZERO)
		if not has_endpoints:
			var state_any: Variant = _unit_visual_by_id.get(unit_id, null)
			if typeof(state_any) == TYPE_DICTIONARY:
				var state: Dictionary = state_any as Dictionary
				start_pos = state.get("prev_pos", Vector2.ZERO)
				end_pos = state.get("curr_pos", start_pos)
			else:
				start_pos = node.position
				end_pos = node.position
		if not _assert_not_freed(node):
			continue
		node.position = start_pos.lerp(end_pos, phase)
		var dir_vec: Vector2 = end_pos - start_pos
		if dir_vec.length_squared() <= 0.000001:
			var fallback_any: Variant = _unit_visual_by_id.get(unit_id, null)
			if typeof(fallback_any) == TYPE_DICTIONARY:
				var fallback_state: Dictionary = fallback_any as Dictionary
				dir_vec = fallback_state.get("dir", Vector2.RIGHT)
		if dir_vec.length_squared() <= 0.000001:
			dir_vec = Vector2.RIGHT
		var sprite: Sprite2D = _ensure_unit_sprite(node)
		if sprite != null:
			_apply_unit_orientation_from_dir(node, sprite, dir_vec)

func _render_units(render_time: float, step_sec: float) -> void:
	if _unit_samples_by_id.is_empty():
		return
	var ids: Array = unit_nodes_by_id.keys()
	for id_any in ids:
		var unit_id: int = int(id_any)
		var node: Node2D = unit_nodes_by_id.get(unit_id, null)
		if node == null:
			continue
		if not _assert_not_freed(node):
			continue
		var buf_any: Variant = _unit_samples_by_id.get(unit_id, null)
		if typeof(buf_any) != TYPE_DICTIONARY:
			continue
		var buf: Dictionary = buf_any as Dictionary
		var s0_any: Variant = buf.get("s0", null)
		var s1_any: Variant = buf.get("s1", s0_any)
		if typeof(s0_any) != TYPE_DICTIONARY and typeof(s1_any) != TYPE_DICTIONARY:
			continue
		var s0: Dictionary = {}
		var s1: Dictionary = {}
		if typeof(s0_any) == TYPE_DICTIONARY:
			s0 = s0_any as Dictionary
		if typeof(s1_any) == TYPE_DICTIONARY:
			s1 = s1_any as Dictionary
		if s0.is_empty() and s1.is_empty():
			continue
		if s0.is_empty():
			s0 = s1
		if s1.is_empty():
			s1 = s0
		var t0: float = _sample_float(s0, "ts", 0.0)
		var t1: float = _sample_float(s1, "ts", t0)
		var denom: float = maxf(t1 - t0, 0.000001)
		var alpha: float = clampf((render_time - t0) / denom, 0.0, 1.0)
		var tt0: float = clampf(_sample_float(s0, "t", 0.0), 0.0, 1.0)
		var tt1: float = clampf(_sample_float(s1, "t", tt0), 0.0, 1.0)
		var t_render: float = lerpf(tt0, tt1, alpha)
		if render_time > t1 and step_sec > 0.0:
			var late: float = minf(render_time - t1, BUTTER_MAX_EXTRAP_SEC)
			if late > 0.0:
				var extra_alpha: float = clampf(late / step_sec, 0.0, 1.0)
				var extrap_t: float = tt1 + (tt1 - tt0) * extra_alpha
				t_render = clampf(extrap_t, 0.0, 1.0)
		var a_pos: Vector2 = _sample_vec2(s1, "a", Vector2.ZERO)
		var b_pos: Vector2 = _sample_vec2(s1, "b", a_pos)
		var render_pos: Vector2 = a_pos.lerp(b_pos, t_render)
		if not _assert_not_freed(node):
			continue
		node.position = render_pos
		var t_next: float = clampf(t_render + SAMPLE_T_EPS, 0.0, 1.0)
		var p_next: Vector2 = a_pos.lerp(b_pos, t_next)
		var dir_vec: Vector2 = p_next - render_pos
		if dir_vec.length_squared() <= 0.000001:
			dir_vec = b_pos - a_pos
		if dir_vec.length_squared() <= 0.000001:
			var state_any: Variant = _unit_visual_by_id.get(unit_id, null)
			if typeof(state_any) == TYPE_DICTIONARY:
				var state: Dictionary = state_any as Dictionary
				dir_vec = _sample_vec2(state, "dir", Vector2.RIGHT)
		if dir_vec.length_squared() <= 0.000001:
			dir_vec = Vector2.RIGHT
		var sprite: Sprite2D = _ensure_unit_sprite(node)
		if sprite != null:
			_apply_unit_orientation_from_dir(node, sprite, dir_vec)

func _draw() -> void:
	if not debug_draw_units:
		return
	if _units.is_empty():
		return
	if not _bobble_logged:
		_bobble_logged = true
		SFLog.info("UNIT_BOBBLE_ENABLED", {
			"amp_min_px": BOBBLE_AMP_MIN_PX,
			"amp_max_px": BOBBLE_AMP_MAX_PX,
			"omega": BOBBLE_OMEGA
		})
	var hive_by_id := _build_hive_by_id()
	var sim_time_s: float = float(model.get("sim_time_s", 0.0))
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 10
	var registry := _get_sprite_registry()
	for u in _units:
		if typeof(u) != TYPE_DICTIONARY:
			continue
		var pos: Variant = _unit_pos_local(u, hive_by_id)
		if not (pos is Vector2):
			continue
		var pos_v: Vector2 = pos as Vector2
		var ud: Dictionary = u as Dictionary
		pos_v += _unit_bobble_offset(ud, hive_by_id, sim_time_s)
		var owner_id: int = _unit_owner_id(u, hive_by_id)
		var tex: Texture2D = null
		var scale: float = 1.0
		var offset: Vector2 = Vector2.ZERO
		if registry != null:
			var key := "unit.%s" % SpriteRegistry.owner_key(owner_id)
			tex = registry.get_tex(key)
			scale = registry.get_scale(key)
			offset = registry.get_offset(key)
			if tex != null and not _unit_sprite_logged:
				_unit_sprite_logged = true
				var resolved_path := tex.resource_path
				if resolved_path.is_empty() and registry != null:
					resolved_path = registry.get_tex_path(key)
				SFLog.info("UNIT_SPRITE_RESOLVED", {
					"key": key,
					"path": str(resolved_path)
				})
		if tex != null:
			var size_px := debug_force_big_radius_px * 2.0 * scale * UNIT_RENDER_SCALE
			var size := Vector2(size_px, size_px)
			var rect := Rect2(pos_v - size * 0.5 + offset, size)
			draw_texture_rect(tex, rect, false)
		else:
			draw_circle(pos_v, debug_force_big_radius_px, Color(1, 1, 1, 1))
	if debug_unit_owner_labels and font != null:
		for u in _units:
			if typeof(u) != TYPE_DICTIONARY:
				continue
			var pos2: Variant = _unit_pos_local(u, hive_by_id)
			if not (pos2 is Vector2):
				continue
			var pos2_v: Vector2 = pos2 as Vector2
			var ud2: Dictionary = u as Dictionary
			pos2_v += _unit_bobble_offset(ud2, hive_by_id, sim_time_s)
			var owner2 := _unit_owner_id(u, hive_by_id)
			var label := _unit_debug_label(u, owner2)
			if label.is_empty():
				continue
			var text_pos := pos2_v + Vector2(0.0, -8.0)
			draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, 1))

func _get_colorkey_material(color: Color, threshold: float, softness: float) -> ShaderMaterial:
	var key := "%s|%s|%s|%s" % [
		str(color),
		str(threshold),
		str(softness),
		str(COLORKEY_SHADER)
	]
	if _colorkey_materials.has(key):
		return _colorkey_materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = COLORKEY_SHADER
	mat.set_shader_parameter("key_color", color)
	mat.set_shader_parameter("threshold", threshold)
	mat.set_shader_parameter("softness", softness)
	_colorkey_materials[key] = mat
	return mat

func _get_unit_colorkey_material(sprite_key: String, owner_id: int, registry: SpriteRegistry) -> ShaderMaterial:
	var key := "%s|%d" % [sprite_key, owner_id]
	if _unit_material_by_sprite.has(key):
		return _unit_material_by_sprite[key]
	var ck_color := _owner_color(owner_id)
	var ck_threshold := 0.28
	var ck_softness := 0.10
	if registry != null:
		var ck := registry.get_colorkey(sprite_key)
		if bool(ck.get("enabled", false)):
			ck_threshold = float(ck.get("threshold", ck_threshold))
			ck_softness = float(ck.get("softness", ck_softness))
	SFLog.log_once(
		"UNIT_COLKEY_PARAMS",
		JSON.stringify({
			"key": sprite_key,
			"color": ck_color,
			"threshold": ck_threshold,
			"softness": ck_softness
		}),
		SFLog.Level.INFO
	)
	var mat := _get_colorkey_material(ck_color, ck_threshold, ck_softness)
	_unit_material_by_sprite[key] = mat
	return mat

func _ensure_unit_colorkey_material(
	sprite: Sprite2D,
	sprite_key: String,
	registry: SpriteRegistry,
	owner_id: int,
	unit_id: int,
	team_color: Color
) -> ShaderMaterial:
	if sprite == null:
		return null
	var instance_id := sprite.get_instance_id()
	var mat: ShaderMaterial = null
	if _unit_material_by_instance.has(instance_id):
		mat = _unit_material_by_instance[instance_id]
	else:
		var base := _get_unit_colorkey_material(sprite_key, owner_id, registry)
		if base != null:
			var dup: Variant = base.duplicate()
			if dup is ShaderMaterial:
				mat = dup as ShaderMaterial
			else:
				mat = null
		if mat == null:
			mat = ShaderMaterial.new()
			mat.shader = COLORKEY_SHADER
		_unit_material_by_instance[instance_id] = mat
	var ck_threshold := 0.28
	var ck_softness := 0.10
	if registry != null and sprite_key != "":
		var ck := registry.get_colorkey(sprite_key)
		if bool(ck.get("enabled", false)):
			ck_threshold = float(ck.get("threshold", ck_threshold))
			ck_softness = float(ck.get("softness", ck_softness))
	mat.set_shader_parameter("key_color", team_color)
	mat.set_shader_parameter("threshold", ck_threshold)
	mat.set_shader_parameter("softness", ck_softness)
	if unit_id > 0:
		var last_owner: int = int(_unit_team_color_logged.get(unit_id, -1))
		if last_owner != owner_id:
			_unit_team_color_logged[unit_id] = owner_id
			SFLog.info("UNIT_TEAM_COLOR", {
				"unit_id": unit_id,
				"owner_id": owner_id,
				"team_color": team_color
			})
	return mat

func _sync_swarm_nodes() -> void:
	var swarms_v: Variant = model.get("swarms", [])
	var swarms: Array = []
	if typeof(swarms_v) == TYPE_ARRAY:
		swarms = swarms_v as Array
	if swarms.is_empty():
		if not swarm_nodes_by_id.is_empty():
			_clear_swarm_nodes()
		return

	var hive_by_id: Dictionary = {}
	var hives_v: Variant = model.get("hives", [])
	if typeof(hives_v) == TYPE_ARRAY:
		for h in hives_v as Array:
			if typeof(h) != TYPE_DICTIONARY:
				continue
			var hd: Dictionary = h as Dictionary
			var id_str := str(hd.get("id", ""))
			if id_str.is_valid_int():
				hive_by_id[int(id_str)] = hd

	var lanes_by_id: Dictionary = {}
	var lanes_v: Variant = model.get("lanes", [])
	if typeof(lanes_v) == TYPE_ARRAY:
		for lane_any in lanes_v as Array:
			if typeof(lane_any) != TYPE_DICTIONARY:
				continue
			var ld: Dictionary = lane_any as Dictionary
			var lane_id: int = int(ld.get("lane_id", ld.get("id", -1)))
			if lane_id <= 0:
				continue
			var a_id: int = int(ld.get("a_id", ld.get("from", 0)))
			var b_id: int = int(ld.get("b_id", ld.get("to", 0)))
			if a_id <= 0 or b_id <= 0:
				continue
			lanes_by_id[lane_id] = {"a_id": a_id, "b_id": b_id}

	var swarm_radius: float = UNIT_DRAW_RADIUS_PX
	var seen: Dictionary = {}
	for swarm_any in swarms:
		if typeof(swarm_any) != TYPE_DICTIONARY:
			continue
		var sd: Dictionary = swarm_any as Dictionary
		var swarm_id: int = int(sd.get("swarm_id", sd.get("id", -1)))
		var lane_id: int = int(sd.get("lane_id", -1))
		if swarm_id <= 0 or lane_id <= 0:
			continue
		if not lanes_by_id.has(lane_id):
			continue
		var lane_d: Dictionary = lanes_by_id[lane_id]
		var a_id: int = int(lane_d.get("a_id", 0))
		var b_id: int = int(lane_d.get("b_id", 0))
		if a_id <= 0 or b_id <= 0:
			continue
		var a_pos_v: Variant = _hive_pos(a_id, hive_by_id)
		var b_pos_v: Variant = _hive_pos(b_id, hive_by_id)
		if not (a_pos_v is Vector2 and b_pos_v is Vector2):
			continue
		var a_pos: Vector2 = a_pos_v
		var b_pos: Vector2 = b_pos_v
		var pts: Dictionary = GameState.lane_edge_points(a_pos, b_pos)
		var a_edge: Vector2 = pts.get("a_edge", a_pos)
		var b_edge: Vector2 = pts.get("b_edge", b_pos)
		var side: String = str(sd.get("side", "A"))
		var t: float = clampf(float(sd.get("t", 0.0)), 0.0, 1.0)
		var pos: Vector2 = a_edge.lerp(b_edge, t) if side != "B" else b_edge.lerp(a_edge, t)

		var node: Node2D = swarm_nodes_by_id.get(swarm_id, null)
		if node == null:
			node = _create_swarm_node(swarm_id, swarm_radius)
			swarm_nodes_by_id[swarm_id] = node
			add_child(node)
			var init_count: int = int(sd.get("count", 0))
			node.set_meta("count", init_count)
			SFLog.info("SWARM_VIS_CREATE", {"swarm_id": swarm_id, "count": init_count})
		_update_swarm_node(node, sd, pos, swarm_radius)
		seen[swarm_id] = true

	var existing_ids: Array = swarm_nodes_by_id.keys()
	for existing_id in existing_ids:
		if not seen.has(existing_id):
			var node: Node2D = swarm_nodes_by_id.get(existing_id, null)
			if node != null:
				node.queue_free()
				SFLog.info("SWARM_VIS_FREE", {"swarm_id": int(existing_id)})
			swarm_nodes_by_id.erase(existing_id)

func _create_swarm_node(swarm_id: int, swarm_radius: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Swarm_%d" % swarm_id
	root.z_index = 10
	root.scale = Vector2(SWARM_SCALE_MULT, SWARM_SCALE_MULT)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = true
	sprite.texture = _ensure_swarm_texture()
	var tex: Texture2D = sprite.texture
	if tex != null:
		var tex_w: float = float(tex.get_width())
		if tex_w > 0.0:
			var scale_val: float = (swarm_radius * 2.0) / tex_w
			sprite.scale = Vector2(scale_val, scale_val)
	root.add_child(sprite)
	var label := Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = SWARM_LABEL_SIZE
	label.position = -SWARM_LABEL_SIZE * 0.5
	label.add_theme_font_size_override("font_size", SWARM_LABEL_FONT_SIZE)
	label.z_index = 1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return root

func _update_swarm_node(node: Node2D, sd: Dictionary, pos: Vector2, swarm_radius: float) -> void:
	node.position = pos
	var owner_id: int = int(sd.get("owner_id", 0))
	var color: Color = _owner_color(owner_id)
	color.a = UNIT_COLOR.a
	var sprite := node.get_node_or_null("Sprite") as Sprite2D
	if sprite != null:
		sprite.modulate = color
		var tex: Texture2D = _ensure_swarm_texture()
		if sprite.texture != tex:
			sprite.texture = tex
		if tex != null:
			var tex_w: float = float(tex.get_width())
			if tex_w > 0.0:
				var scale_val: float = (swarm_radius * 2.0) / tex_w
				sprite.scale = Vector2(scale_val, scale_val)
	var label := node.get_node_or_null("Label") as Label
	if label != null:
		var count: int = int(sd.get("count", 0))
		var last_count: int = int(node.get_meta("count", -1))
		if count != last_count:
			node.set_meta("count", count)
			SFLog.info("SWARM_VIS_COUNT", {"swarm_id": int(sd.get("swarm_id", sd.get("id", -1))), "count": count})
		label.text = str(count)

func _clear_swarm_nodes() -> void:
	var ids: Array = swarm_nodes_by_id.keys()
	for swarm_id in ids:
		var node: Node2D = swarm_nodes_by_id.get(swarm_id, null)
		if node != null:
			node.queue_free()
			SFLog.info("SWARM_VIS_FREE", {"swarm_id": int(swarm_id)})
	swarm_nodes_by_id.clear()

func _ensure_swarm_texture() -> Texture2D:
	if _swarm_texture != null:
		return _swarm_texture
	var loaded: Resource = load(SWARM_TEXTURE_PATH)
	if loaded is Texture2D:
		_swarm_texture = loaded as Texture2D
		return _swarm_texture
	SFLog.warn("SWARM_TEXTURE_FALLBACK", {"path": SWARM_TEXTURE_PATH})
	var size: int = SWARM_TEXTURE_SIZE
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var center: Vector2 = Vector2(float(size) * 0.5, float(size) * 0.5)
	var radius: float = float(size) * 0.5
	var radius_sq: float = radius * radius
	for y in range(size):
		var fy: float = float(y) + 0.5 - center.y
		for x in range(size):
			var fx: float = float(x) + 0.5 - center.x
			if (fx * fx + fy * fy) <= radius_sq:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	var tex: Texture2D = ImageTexture.create_from_image(img)
	_swarm_texture = tex
	return _swarm_texture

func _unit_pos(u: Variant, hive_by_id: Dictionary) -> Array:
	if typeof(u) == TYPE_DICTIONARY:
		var ud: Dictionary = u as Dictionary
		var pos_v: Variant = ud.get("pos")
		if typeof(pos_v) == TYPE_VECTOR2:
			return [true, pos_v as Vector2]
		var from_pos_v: Variant = ud.get("from_pos")
		var to_pos_v: Variant = ud.get("to_pos")
		if typeof(from_pos_v) == TYPE_VECTOR2 and typeof(to_pos_v) == TYPE_VECTOR2 and ud.has("t"):
			var from_pos: Vector2 = from_pos_v as Vector2
			var to_pos: Vector2 = to_pos_v as Vector2
			var t: float = clampf(float(ud.get("t", 0.0)), 0.0, 1.0)
			return [true, from_pos.lerp(to_pos, t)]
		var a_id := _resolve_id(ud.get("a_id", 0))
		var b_id := _resolve_id(ud.get("b_id", 0))
		if a_id > 0 and b_id > 0 and ud.has("t"):
			var a_pos_v: Variant = _hive_pos(a_id, hive_by_id)
			var b_pos_v: Variant = _hive_pos(b_id, hive_by_id)
			if typeof(a_pos_v) == TYPE_VECTOR2 and typeof(b_pos_v) == TYPE_VECTOR2:
				var a_pos: Vector2 = a_pos_v as Vector2
				var b_pos: Vector2 = b_pos_v as Vector2
				var t: float = clampf(float(ud.get("t", 0.0)), 0.0, 1.0)
				return [true, a_pos.lerp(b_pos, t)]
		var wp: Variant = ud.get("wp")
		if typeof(wp) == TYPE_VECTOR2:
			return [true, wp as Vector2]
		var position: Variant = ud.get("position")
		if typeof(position) == TYPE_VECTOR2:
			return [true, position as Vector2]
	else:
		if "wp" in u:
			return [true, u.wp]
		if "pos" in u:
			return [true, u.pos]
		if "position" in u:
			return [true, u.position]
	return [false, Vector2.ZERO]

func _unit_bobble_offset(ud: Dictionary, hive_by_id: Dictionary, sim_time_s: float) -> Vector2:
	var unit_id: int = int(ud.get("id", 0))
	if unit_id <= 0:
		return Vector2.ZERO
	var dir := _unit_lane_dir(ud, hive_by_id)
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	var normal := Vector2(-dir.y, dir.x)
	var phase := _unit_phase(unit_id)
	var amp := _unit_amp(unit_id)
	var offset := sin(BOBBLE_OMEGA * sim_time_s + phase) * amp
	return normal * offset

func _unit_lane_dir(ud: Dictionary, hive_by_id: Dictionary) -> Vector2:
	var from_pos: Vector2 = Vector2.ZERO
	var to_pos: Vector2 = Vector2.ZERO
	var from_pos_v: Variant = ud.get("from_pos")
	var to_pos_v: Variant = ud.get("to_pos")
	if from_pos_v is Vector2 and to_pos_v is Vector2:
		from_pos = from_pos_v
		to_pos = to_pos_v
	else:
		var a_id := _resolve_id(ud.get("a_id", 0))
		var b_id := _resolve_id(ud.get("b_id", 0))
		var a_pos_v: Variant = _hive_pos(a_id, hive_by_id)
		var b_pos_v: Variant = _hive_pos(b_id, hive_by_id)
		if a_pos_v is Vector2 and b_pos_v is Vector2:
			from_pos = a_pos_v
			to_pos = b_pos_v
		else:
			return Vector2.ZERO
	var delta := to_pos - from_pos
	if delta.length_squared() <= 0.0001:
		return Vector2.ZERO
	return delta.normalized()

func _unit_travel_heading(ud: Dictionary, hive_by_id: Dictionary, p_now_world: Vector2) -> Dictionary:
	var t_val: float = clampf(float(ud.get("t", 0.0)), 0.0, 1.0)
	var dir_sign: int = _unit_travel_sign(ud)
	var t_next: float = clampf(t_val + float(dir_sign) * UNIT_TRAVEL_T_EPS, 0.0, 1.0)
	var endpoints: Dictionary = _unit_path_endpoints_world(ud, hive_by_id)
	var p_next: Vector2 = p_now_world
	if bool(endpoints.get("ok", false)):
		var a_pos: Vector2 = endpoints.get("a", Vector2.ZERO)
		var b_pos: Vector2 = endpoints.get("b", Vector2.ZERO)
		p_next = a_pos.lerp(b_pos, t_next)
	else:
		var lane_dir: Vector2 = _unit_lane_dir(ud, hive_by_id)
		if lane_dir.length_squared() > 0.000001:
			p_next = p_now_world + lane_dir.normalized() * float(dir_sign)
	return {
		"t": t_val,
		"t_next": t_next,
		"dir": p_next - p_now_world
	}

func _unit_travel_sign(ud: Dictionary) -> int:
	var dir_i: int = int(ud.get("dir", 0))
	if dir_i != 0:
		return 1 if dir_i > 0 else -1
	var from_id: int = _resolve_id(ud.get("from_id", ud.get("from", 0)))
	var to_id: int = _resolve_id(ud.get("to_id", ud.get("to", 0)))
	var a_id: int = _resolve_id(ud.get("a_id", 0))
	var b_id: int = _resolve_id(ud.get("b_id", 0))
	if from_id > 0 and to_id > 0 and a_id > 0 and b_id > 0:
		if from_id == a_id and to_id == b_id:
			return 1
		if from_id == b_id and to_id == a_id:
			return -1
	var side: String = str(ud.get("from_side", ""))
	if side == "B":
		return -1
	if side == "A":
		return 1
	return 1

func _unit_path_endpoints_world(ud: Dictionary, hive_by_id: Dictionary) -> Dictionary:
	var from_pos_v: Variant = ud.get("from_pos")
	var to_pos_v: Variant = ud.get("to_pos")
	if from_pos_v is Vector2 and to_pos_v is Vector2:
		var a_world: Vector2 = _to_world_pos(from_pos_v as Vector2)
		var b_world: Vector2 = _to_world_pos(to_pos_v as Vector2)
		return {"ok": true, "a": a_world, "b": b_world}
	var a_id: int = _resolve_id(ud.get("a_id", 0))
	var b_id: int = _resolve_id(ud.get("b_id", 0))
	if a_id > 0 and b_id > 0:
		var a_pos_v: Variant = _hive_world_pos(a_id, hive_by_id)
		var b_pos_v: Variant = _hive_world_pos(b_id, hive_by_id)
		if a_pos_v is Vector2 and b_pos_v is Vector2:
			return {"ok": true, "a": a_pos_v as Vector2, "b": b_pos_v as Vector2}
	var from_id: int = _resolve_id(ud.get("from_id", ud.get("from", 0)))
	var to_id: int = _resolve_id(ud.get("to_id", ud.get("to", 0)))
	if from_id > 0 and to_id > 0:
		var from_pos_w: Variant = _hive_world_pos(from_id, hive_by_id)
		var to_pos_w: Variant = _hive_world_pos(to_id, hive_by_id)
		if from_pos_w is Vector2 and to_pos_w is Vector2:
			return {"ok": true, "a": from_pos_w as Vector2, "b": to_pos_w as Vector2}
	return {"ok": false, "a": Vector2.ZERO, "b": Vector2.ZERO}

func _unit_phase(unit_id: int) -> float:
	var h := _hash_unit_id(unit_id)
	var frac := float(h % 10000) / 10000.0
	return frac * TAU

func _unit_amp(unit_id: int) -> float:
	var h := _hash_unit_id(unit_id * 31 + 7)
	var frac := float((h >> 8) % 10000) / 10000.0
	return lerpf(BOBBLE_AMP_MIN_PX, BOBBLE_AMP_MAX_PX, frac)

func _hash_unit_id(unit_id: int) -> int:
	var x := int(unit_id)
	x = x ^ (x << 13)
	x = x ^ (x >> 17)
	x = x ^ (x << 5)
	return x & 0x7fffffff

func _owner_color(owner_id: int) -> Color:
	return HiveRenderer._owner_color(owner_id)

func _unit_owner_id(u: Variant, hive_by_id: Dictionary) -> int:
	if typeof(u) != TYPE_DICTIONARY:
		return 0
	var ud: Dictionary = u as Dictionary
	var owner_id := int(ud.get("owner_id", 0))
	if owner_id > 0:
		return owner_id
	var from_id := _resolve_id(ud.get("from_id", ud.get("a_id", 0)))
	if from_id > 0:
		return _hive_owner(from_id, hive_by_id)
	return 0

func _hive_owner(hive_id: int, hive_by_id: Dictionary) -> int:
	if hive_by_id.has(hive_id):
		var hd: Dictionary = hive_by_id[hive_id]
		return int(hd.get("owner_id", 0))
	return 0

func _unit_debug_label(u: Variant, owner_id: int) -> String:
	if typeof(u) != TYPE_DICTIONARY:
		return ""
	var ud: Dictionary = u as Dictionary
	var lane_id := int(ud.get("lane_id", 0))
	var side := ""
	if ud.has("from_side"):
		side = str(ud.get("from_side", ""))
	else:
		var dir := int(ud.get("dir", 0))
		if dir > 0:
			side = "A"
		elif dir < 0:
			side = "B"
	return "o=%d side=%s lane=%d" % [owner_id, side, lane_id]

func _hive_pos(hive_id: int, hive_by_id: Dictionary) -> Variant:
	if hive_nodes_by_id.has(hive_id):
		var node: Node2D = hive_nodes_by_id[hive_id]
		if node != null:
			return node.position
	if hive_by_id.has(hive_id):
		var hd: Dictionary = hive_by_id[hive_id]
		var cell_size := float(model.get("cell_size", 64))
		var gx := float(hd.get("x", 0.0))
		var gy := float(hd.get("y", 0.0))
		return Vector2((gx + 0.5) * cell_size, (gy + 0.5) * cell_size)
	return null

func _hive_world_pos(hive_id: int, hive_by_id: Dictionary) -> Variant:
	if hive_nodes_by_id.has(hive_id):
		var node: Node2D = hive_nodes_by_id[hive_id]
		if node != null:
			return node.global_position
	var local_v: Variant = _hive_pos(hive_id, hive_by_id)
	if local_v is Vector2:
		return to_global(local_v as Vector2)
	return null

func _to_world_pos(pos: Vector2) -> Vector2:
	if _unit_space == "global":
		return pos
	return to_global(pos)

func _resolve_id(raw: Variant) -> int:
	if raw is int:
		return int(raw)
	var s := str(raw)
	if s.is_valid_int():
		return int(s)
	return 0

func _get_sprite_registry() -> SpriteRegistry:
	if _sprite_registry == null:
		_sprite_registry = SpriteRegistry.get_instance()
	return _sprite_registry
