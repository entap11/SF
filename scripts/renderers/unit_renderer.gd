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
const HiveNodeScript := preload("res://scripts/hive/hive_node.gd")
const UNIT_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const DEBUG_HIVE1_CROSS := false
const UNIT_LOG_INTERVAL_MS := 1000
const UNIT_BOUNDS_LOG_INTERVAL_MS := 1000
const UNIT_REDRAW_INTERVAL_MS := 30
const UNIT_BASELINE_AUDIT_INTERVAL_MS: int = 1000
const UNIT_RECONCILE_LOG_INTERVAL_MS: int = 1000
const UNIT_RECONCILE_SLOW_MS: float = 2.0
const SWARM_SCALE_MULT: float = 15.0
const SWARM_LABEL_FONT_SIZE: int = 12
const SWARM_LABEL_SIZE: Vector2 = Vector2(48.0, 20.0)
const SWARM_TEXTURE_SIZE: int = 32
const SWARM_TEXTURE_PATH: String = "res://assets/sprites/sf_skin_v1/swarm.png"
const BOBBLE_AMP_MIN_PX: float = 2.0
const BOBBLE_AMP_MAX_PX: float = 6.0
const BOBBLE_OMEGA: float = 8.0
const BOBBLE_Y_CLAMP_PX: float = 6.0
const SIM_DT_SEC_DEFAULT: float = 0.1
const BUTTER_INTERP_DELAY_TICKS: float = 1.0
const SAMPLE_T_EPS: float = 0.001
const BUTTER_MAX_EXTRAP_SEC: float = 0.05
const DBG_BUTTER: bool = false
const DBG_BUTTER_LOG_INTERVAL_MS: int = 1000
const DBG_FORCE_CONSTANT_VISUAL_MOTION: bool = false
const DBG_VISUAL_SPEED: float = 0.35
const AUDIT_RENDER: bool = true
const USE_UNIT_POOL: bool = true
const UNIT_POOL_SIZE_PER_TEAM: int = 64
const UNIT_POOL_OFFSCREEN_POS: Vector2 = Vector2(-99999.0, -99999.0)
const PRUNE_AFTER_TICKS: int = 2

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
var _audit_last_ms: int = 0
var _audit_draw_ops: int = 0
var _audit_mat_sets: int = 0
var _audit_rebuilds: int = 0
var _audit_units_peak: int = 0
var _audit_frames: int = 0
var _audit_material_assigns: int = 0
var _audit_modulate_sets: int = 0
var _audit_mat_key_counts: Dictionary = {}
var _audit_rebuild_counts: Dictionary = {}
var _last_units_snapshot: Array = []
var _last_units_snapshot_size: int = -1
var _last_units_snapshot_sig: int = 0
var _bound_units_version: int = -1
var _bound_hives_version: int = -1
var _hive_by_id_cache: Dictionary = {}
var _hive_cache_count: int = 0
var _hive_bind_version: int = 0
var _hive_key_sig: int = 0
var _unit_missing_ticks: Dictionary = {}
var _last_baseline_audit_ms: int = 0
var _lane_renderer: Object = null
var _reconcile_last_log_ms: int = 0
var _death_reconcile_last_log_ms: int = 0
var _reconcile_baseline_ms: float = 0.0
var _reconcile_baseline_samples: int = 0
var _last_bound_units_count: int = 0
var _hive_lookup_last_log_ms: int = 0
var _cached_hive_anchor_info: Dictionary = {}
var _cached_lane_endpoints: Dictionary = {}

func _ready() -> void:
	SFLog.allow_tag("RENDER_AUDIT_UNITS")
	SFLog.allow_tag("RENDER_AUDIT_UNITS_TOP_MAT_KEYS")
	SFLog.allow_tag("RENDER_AUDIT_UNITS_REBUILDS")
	SFLog.allow_tag("UNIT_RENDER_REBUILD")
	SFLog.allow_tag("UNIT_BASELINE_AUDIT")
	SFLog.allow_tag("UNIT_DEATH_FRAME_MS")
	SFLog.allow_tag("UNIT_RECONCILE_SLOW")
	SFLog.allow_tag("UNIT_HIVE_LOOKUP_BUILD_MS")
	_pool_build()
	_apply_debug_force_top_z()
	_request_redraw()

func setup_renderer_refs(lane_renderer_ref: Object) -> void:
	if _lane_renderer != lane_renderer_ref:
		_invalidate_endpoint_caches()
	_lane_renderer = lane_renderer_ref

func _invalidate_endpoint_caches() -> void:
	_cached_hive_anchor_info.clear()
	_cached_lane_endpoints.clear()

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
	node.visible = false
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
		_unit_missing_ticks.erase(unit_id)
		_unit_data_by_id.erase(unit_id)
		_unit_in_use.erase(unit_id)
		_unit_visual_by_id.erase(unit_id)
		_unit_samples_by_id.erase(unit_id)
		_diag_visual_phase_by_id.erase(unit_id)
	node.set_meta("unit_id", -1)
	var sprite: Sprite2D = node.get_node_or_null("UnitSprite") as Sprite2D
	if sprite != null:
		sprite.texture = null
		if AUDIT_RENDER and sprite.material != null:
			_audit_material_assigns += 1
		sprite.material = null
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE
		sprite.rotation = 0.0
		if AUDIT_RENDER:
			_audit_modulate_sets += 1
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
	var units_version: int = int(model.get("units_set_version", -1))
	var hives_version: int = int(model.get("hives_set_version", -1))
	if units_version >= 0 or hives_version >= 0:
		return
	var units_v: Variant = model.get("units", [])
	var units_arr: Array = []
	if typeof(units_v) == TYPE_ARRAY:
		units_arr = units_v as Array
	var hives_v: Variant = model.get("hives", [])
	var hives_arr: Array = []
	if typeof(hives_v) == TYPE_ARRAY:
		hives_arr = hives_v as Array
	if not hives_arr.is_empty():
		set_hive_snapshot(hives_arr)
	set_units_snapshot(units_arr, Time.get_ticks_usec())

func bind_hives(hives: Array, hives_version: int) -> void:
	if hives_version >= 0:
		if hives_version == _bound_hives_version:
			return
		_bound_hives_version = hives_version
		set_hive_snapshot(hives, true)
		return
	set_hive_snapshot(hives, false)

func bind_units(snapshot: Array, units_version: int, sim_time_us: int) -> void:
	if units_version < 0:
		set_units_snapshot(snapshot, sim_time_us)
		return
	_units = snapshot
	model["units"] = snapshot
	model["sim_time_s"] = float(sim_time_us) / 1000000.0
	var structure_changed: bool = units_version != _bound_units_version
	_bound_units_version = units_version
	_last_units_snapshot = snapshot
	_last_units_snapshot_size = snapshot.size()
	_last_units_snapshot_sig = _units_snapshot_signature(snapshot)
	if structure_changed:
		SFLog.throttled_info("UNIT_RENDER_REBUILD", {
			"reason": "units_version_changed",
			"units": snapshot.size()
		}, 250)
	var reconcile_t0_us: int = Time.get_ticks_usec()
	var sync_profile: Dictionary = _sync_unit_nodes(snapshot)
	var update_profile: Dictionary = _update_unit_nodes_positions(snapshot)
	var reconcile_total_us: int = int(Time.get_ticks_usec() - reconcile_t0_us)
	_log_reconcile_profile(snapshot, sync_profile, update_profile, reconcile_total_us, "bind_units")
	_sync_swarm_nodes()
	_request_redraw()

func set_units(units: Array) -> void:
	set_units_snapshot(units, Time.get_ticks_usec())
	var c := units.size()
	if debug_unit_logs and c != _last_set_count:
		_last_set_count = c
		var now_ms := Time.get_ticks_msec()
		if now_ms - _last_set_log_ms >= UNIT_LOG_INTERVAL_MS:
			_last_set_log_ms = now_ms
			SFLog.info("UNIT_RENDERER_SET", {"count": c})

func set_units_snapshot(snapshot: Array, sim_time_us: int) -> void:
	_units = snapshot
	model["units"] = snapshot
	model["sim_time_s"] = float(sim_time_us) / 1000000.0
	var structure_changed: bool = _consume_units_snapshot_signature(snapshot)
	if structure_changed:
		SFLog.throttled_info("UNIT_RENDER_REBUILD", {
			"reason": "units_signature_changed",
			"units": snapshot.size()
		}, 250)
	var reconcile_t0_us: int = Time.get_ticks_usec()
	var sync_profile: Dictionary = _sync_unit_nodes(snapshot)
	var update_profile: Dictionary = _update_unit_nodes_positions(snapshot)
	var reconcile_total_us: int = int(Time.get_ticks_usec() - reconcile_t0_us)
	_log_reconcile_profile(snapshot, sync_profile, update_profile, reconcile_total_us, "set_units_snapshot")
	_sync_swarm_nodes()
	_request_redraw()

func _consume_units_snapshot_signature(snapshot: Array) -> bool:
	var size_now: int = snapshot.size()
	var sig_now: int = _units_snapshot_signature(snapshot)
	var size_changed: bool = size_now != _last_units_snapshot_size
	var sig_changed: bool = sig_now != _last_units_snapshot_sig
	_last_units_snapshot = snapshot
	_last_units_snapshot_size = size_now
	_last_units_snapshot_sig = sig_now
	return size_changed or sig_changed

func _units_snapshot_signature(snapshot: Array) -> int:
	var count: int = snapshot.size()
	var all_xor: int = 0
	var sum_ids: int = 0
	var mix_sum: int = 0
	for i in range(count):
		var unit_any: Variant = snapshot[i]
		var unit_id: int = -1
		if typeof(unit_any) == TYPE_DICTIONARY:
			var ud: Dictionary = unit_any as Dictionary
			unit_id = int(ud.get("id", -1))
		all_xor = all_xor ^ unit_id
		sum_ids = (sum_ids + unit_id) & 0x7fffffff
		var unit_mix: int = int((int(unit_id) * 2654435761) & 0x7fffffff)
		mix_sum = (mix_sum + unit_mix) & 0x7fffffff
	var sig: int = count
	sig = (sig * 31 + all_xor) & 0x7fffffff
	sig = (sig * 31 + sum_ids) & 0x7fffffff
	sig = (sig * 31 + mix_sum) & 0x7fffffff
	return sig

func _us_to_ms(us: int) -> float:
	return float(us) / 1000.0

func _max_reconcile_step(step_ms: Dictionary) -> Dictionary:
	var best_name: String = "none"
	var best_ms: float = 0.0
	for key_any in step_ms.keys():
		var key: String = str(key_any)
		var val: float = float(step_ms.get(key, 0.0))
		if val > best_ms:
			best_ms = val
			best_name = key
	return {
		"name": best_name,
		"ms": best_ms
	}

func _log_reconcile_profile(
	snapshot: Array,
	sync_profile: Dictionary,
	update_profile: Dictionary,
	reconcile_total_us: int,
	source: String
) -> void:
	var current_count: int = snapshot.size()
	var deaths_this_bind: int = maxi(0, _last_bound_units_count - current_count)
	var total_ms: float = _us_to_ms(reconcile_total_us)
	var step_ms: Dictionary = {
		"scan": _us_to_ms(int(sync_profile.get("scan_us", 0))),
		"stale": _us_to_ms(int(sync_profile.get("stale_us", 0))),
		"create": _us_to_ms(int(sync_profile.get("create_us", 0))),
		"prune": _us_to_ms(int(sync_profile.get("prune_us", 0))),
		"hive_lookup": _us_to_ms(int(update_profile.get("hive_lookup_us", 0))),
		"endpoint_eval": _us_to_ms(int(update_profile.get("endpoint_eval_us", 0))),
		"group_scan": _us_to_ms(int(sync_profile.get("group_scan_us", 0))) + _us_to_ms(int(update_profile.get("group_scan_us", 0)))
	}
	if deaths_this_bind <= 0:
		if _reconcile_baseline_samples <= 0:
			_reconcile_baseline_ms = total_ms
		else:
			_reconcile_baseline_ms = lerpf(_reconcile_baseline_ms, total_ms, 0.10)
		_reconcile_baseline_samples += 1
	var max_step: Dictionary = _max_reconcile_step(step_ms)
	var culprit_name: String = str(max_step.get("name", "none"))
	var culprit_ms: float = float(max_step.get("ms", 0.0))
	var now_ms: int = Time.get_ticks_msec()
	if deaths_this_bind > 0:
		if now_ms - _death_reconcile_last_log_ms >= UNIT_RECONCILE_LOG_INTERVAL_MS:
			_death_reconcile_last_log_ms = now_ms
			var baseline_ms: float = _reconcile_baseline_ms if _reconcile_baseline_samples > 0 else total_ms
			var extra_ms: float = maxf(0.0, total_ms - baseline_ms)
			SFLog.warn("UNIT_DEATH_FRAME_MS", {
				"source": source,
				"deaths": deaths_this_bind,
				"units_now": current_count,
				"extra_ms": snapped(extra_ms, 0.01),
				"total_ms": snapped(total_ms, 0.01),
				"baseline_ms": snapped(baseline_ms, 0.01),
				"culprit": culprit_name,
				"culprit_ms": snapped(culprit_ms, 0.01),
				"scan_ms": snapped(float(step_ms.get("scan", 0.0)), 0.01),
				"stale_ms": snapped(float(step_ms.get("stale", 0.0)), 0.01),
				"create_ms": snapped(float(step_ms.get("create", 0.0)), 0.01),
				"prune_ms": snapped(float(step_ms.get("prune", 0.0)), 0.01),
				"hive_lookup_ms": snapped(float(step_ms.get("hive_lookup", 0.0)), 0.01),
				"endpoint_eval_ms": snapped(float(step_ms.get("endpoint_eval", 0.0)), 0.01),
				"group_scan_ms": snapped(float(step_ms.get("group_scan", 0.0)), 0.01),
				"group_scans": int(sync_profile.get("group_scan_n", 0)) + int(update_profile.get("group_scan_n", 0)),
				"create_count": int(sync_profile.get("create_n", 0)),
				"prune_count": int(sync_profile.get("prune_n", 0))
			})
	elif total_ms >= UNIT_RECONCILE_SLOW_MS and now_ms - _reconcile_last_log_ms >= UNIT_RECONCILE_LOG_INTERVAL_MS:
		_reconcile_last_log_ms = now_ms
		SFLog.warn("UNIT_RECONCILE_SLOW", {
			"source": source,
			"units_now": current_count,
			"total_ms": snapped(total_ms, 0.01),
			"culprit": culprit_name,
			"culprit_ms": snapped(culprit_ms, 0.01),
			"scan_ms": snapped(float(step_ms.get("scan", 0.0)), 0.01),
			"stale_ms": snapped(float(step_ms.get("stale", 0.0)), 0.01),
			"create_ms": snapped(float(step_ms.get("create", 0.0)), 0.01),
			"prune_ms": snapped(float(step_ms.get("prune", 0.0)), 0.01),
			"hive_lookup_ms": snapped(float(step_ms.get("hive_lookup", 0.0)), 0.01),
			"endpoint_eval_ms": snapped(float(step_ms.get("endpoint_eval", 0.0)), 0.01),
			"group_scan_ms": snapped(float(step_ms.get("group_scan", 0.0)), 0.01),
			"group_scans": int(sync_profile.get("group_scan_n", 0)) + int(update_profile.get("group_scan_n", 0)),
			"create_count": int(sync_profile.get("create_n", 0)),
			"prune_count": int(sync_profile.get("prune_n", 0))
		})
	_last_bound_units_count = current_count

func set_hive_snapshot(hives: Array, force_rebuild: bool = false) -> void:
	var t0_us: int = Time.get_ticks_usec()
	var count: int = hives.size()
	var sig: int = _hive_snapshot_signature(hives)
	if not force_rebuild and count == _hive_cache_count and sig == _hive_key_sig:
		return
	_hive_by_id_cache.clear()
	for h in hives:
		if typeof(h) != TYPE_DICTIONARY:
			continue
		var hd: Dictionary = h as Dictionary
		var id_str: String = str(hd.get("id", ""))
		if id_str.is_valid_int():
			_hive_by_id_cache[int(id_str)] = hd
	_hive_cache_count = count
	_hive_key_sig = sig
	_hive_bind_version += 1
	_invalidate_endpoint_caches()
	_audit_mark_rebuild("hive_lookup_build")
	var dt_ms: float = _us_to_ms(int(Time.get_ticks_usec() - t0_us))
	var now_ms: int = Time.get_ticks_msec()
	if dt_ms >= 1.0 and now_ms - _hive_lookup_last_log_ms >= UNIT_RECONCILE_LOG_INTERVAL_MS:
		_hive_lookup_last_log_ms = now_ms
		SFLog.warn("UNIT_HIVE_LOOKUP_BUILD_MS", {
			"hives": count,
			"force_rebuild": force_rebuild,
			"dt_ms": snapped(dt_ms, 0.01)
		})

func _hive_snapshot_signature(hives: Array) -> int:
	var sig: int = hives.size()
	var xor_ids: int = 0
	var sample_n: int = mini(8, hives.size())
	var edge_xor: int = 0
	for i in range(hives.size()):
		var hive_any: Variant = hives[i]
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hd: Dictionary = hive_any as Dictionary
		var hive_id: int = int(hd.get("id", -1))
		xor_ids = xor_ids ^ hive_id
		if i < sample_n or i >= hives.size() - sample_n:
			edge_xor = edge_xor ^ hive_id
	sig = (sig * 31 + xor_ids) & 0x7fffffff
	sig = (sig * 31 + edge_xor) & 0x7fffffff
	return sig

func set_hive_nodes(dict: Dictionary) -> void:
	hive_nodes_by_id = dict
	_invalidate_endpoint_caches()
	_sync_swarm_nodes()
	_request_redraw()

func clear_all() -> void:
	model = {}
	_last_units_snapshot = []
	_last_units_snapshot_size = -1
	_last_units_snapshot_sig = 0
	_bound_units_version = -1
	_bound_hives_version = -1
	_hive_by_id_cache.clear()
	_hive_cache_count = 0
	_hive_bind_version = 0
	_hive_key_sig = 0
	_reconcile_baseline_ms = 0.0
	_reconcile_baseline_samples = 0
	_last_bound_units_count = 0
	_reconcile_last_log_ms = 0
	_death_reconcile_last_log_ms = 0
	_invalidate_endpoint_caches()
	_unit_missing_ticks.clear()
	_unit_data_by_id.clear()
	_unit_visual_by_id.clear()
	_unit_samples_by_id.clear()
	_diag_visual_phase_by_id.clear()
	_clear_swarm_nodes()
	_clear_unit_nodes()
	_request_redraw()

func _sync_unit_nodes(units: Array) -> Dictionary:
	var profile: Dictionary = {
		"scan_us": 0,
		"create_us": 0,
		"create_n": 0,
		"stale_us": 0,
		"prune_us": 0,
		"prune_n": 0,
		"group_scan_us": 0,
		"group_scan_n": 0,
		"total_us": 0
	}
	var total_t0_us: int = Time.get_ticks_usec()
	if not units.is_empty():
		_log_unit_space_once()
	var seen_ids: Dictionary = {}
	var scan_t0_us: int = Time.get_ticks_usec()
	for unit_any in units:
		if typeof(unit_any) != TYPE_DICTIONARY:
			continue
		var ud: Dictionary = unit_any as Dictionary
		var unit_id: int = int(ud.get("id", -1))
		if unit_id <= 0:
			continue
		seen_ids[unit_id] = true
		_unit_missing_ticks.erase(unit_id)
		_unit_data_by_id[unit_id] = ud
		if not unit_nodes_by_id.has(unit_id):
			var create_t0_us: int = Time.get_ticks_usec()
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
			_audit_mark_rebuild("unit_node_create")
			_ensure_unit_sprite(node)
			_log_unit_sprite_tree(node, unit_id)
			if debug_unit_logs and SFLog.verbose_sim:
				SFLog.info("UNIT_RENDER_CREATE", {
					"unit_id": unit_id,
					"owner_id": int(ud.get("owner_id", 0))
				})
			profile["create_n"] = int(profile.get("create_n", 0)) + 1
			profile["create_us"] = int(profile.get("create_us", 0)) + int(Time.get_ticks_usec() - create_t0_us)
	profile["scan_us"] = int(Time.get_ticks_usec() - scan_t0_us)
	var stale_t0_us: int = Time.get_ticks_usec()
	for existing_id_any in unit_nodes_by_id.keys():
		var existing_id: int = int(existing_id_any)
		if seen_ids.has(existing_id):
			continue
		_unit_missing_ticks[existing_id] = int(_unit_missing_ticks.get(existing_id, 0)) + 1
		_unit_data_by_id.erase(existing_id)
	profile["stale_us"] = int(Time.get_ticks_usec() - stale_t0_us)
	var missing_ids: Array = _unit_missing_ticks.keys()
	var prune_t0_us: int = Time.get_ticks_usec()
	for existing_id_any in missing_ids:
		var existing_id: int = int(existing_id_any)
		if seen_ids.has(existing_id):
			continue
		var missing_ticks: int = int(_unit_missing_ticks.get(existing_id, 0))
		if missing_ticks < PRUNE_AFTER_TICKS:
			continue
		var node: Node2D = unit_nodes_by_id.get(existing_id, null)
		if node != null:
			if not _assert_not_freed(node):
				continue
			_audit_mark_rebuild("unit_node_prune")
			_pool_release(node)
			if debug_unit_logs and SFLog.verbose_sim:
				SFLog.info("UNIT_RENDER_PRUNE", {"unit_id": int(existing_id)})
			profile["prune_n"] = int(profile.get("prune_n", 0)) + 1
		_unit_missing_ticks.erase(existing_id)
		_unit_data_by_id.erase(existing_id)
	profile["prune_us"] = int(Time.get_ticks_usec() - prune_t0_us)
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
	profile["total_us"] = int(Time.get_ticks_usec() - total_t0_us)
	return profile

func _rebuild_unit_data_index(units: Array) -> void:
	SFLog.info("UNIT_RENDER_REBUILD", {
		"reason": "unit_data_index",
		"units": units.size()
	})
	_audit_mark_rebuild("unit_data_index")
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
	if not existing_ids.is_empty():
		_audit_mark_rebuild("unit_nodes_clear", existing_ids.size())
	for existing_id in existing_ids:
		var node: Node2D = unit_nodes_by_id.get(existing_id, null)
		if node != null:
			if not _assert_not_freed(node):
				continue
			_pool_release(node)
	unit_nodes_by_id.clear()
	_unit_missing_ticks.clear()
	_unit_in_use.clear()
	_unit_visual_by_id.clear()
	_unit_samples_by_id.clear()

func _update_unit_nodes_positions(units: Array) -> Dictionary:
	var profile: Dictionary = {
		"hive_lookup_us": 0,
		"endpoint_eval_us": 0,
		"group_scan_us": 0,
		"group_scan_n": 0,
		"total_us": 0
	}
	var total_t0_us: int = Time.get_ticks_usec()
	if units.is_empty():
		profile["total_us"] = int(Time.get_ticks_usec() - total_t0_us)
		return profile
	var hive_lookup_t0_us: int = Time.get_ticks_usec()
	var hive_by_id: Dictionary = _build_hive_by_id()
	profile["hive_lookup_us"] = int(Time.get_ticks_usec() - hive_lookup_t0_us)
	var registry: SpriteRegistry = _get_sprite_registry()
	var endpoint_cache: Dictionary = _cached_lane_endpoints
	var hive_anchor_cache: Dictionary = _cached_hive_anchor_info
	var endpoint_t0_us: int = Time.get_ticks_usec()
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
		_ingest_unit_sample(ud, hive_by_id, unit_id, endpoint_cache, hive_anchor_cache)
		var state_any: Variant = _unit_visual_by_id.get(unit_id, null)
		if typeof(state_any) == TYPE_DICTIONARY:
			var state: Dictionary = state_any as Dictionary
			if bool(state.get("just_spawned", false)):
				var curr_pos_v: Variant = state.get("curr_pos", null)
				if curr_pos_v is Vector2:
					node.position = curr_pos_v as Vector2
				node.rotation = float(state.get("curr_rot", node.rotation))
	profile["endpoint_eval_us"] = int(Time.get_ticks_usec() - endpoint_t0_us)
	profile["total_us"] = int(Time.get_ticks_usec() - total_t0_us)
	return profile

func _update_unit_visual_target(_node: Node2D, ud: Dictionary, hive_by_id: Dictionary, unit_id: int) -> void:
	_ingest_unit_sample(ud, hive_by_id, unit_id)

func _ingest_unit_sample(
	ud: Dictionary,
	hive_by_id: Dictionary,
	unit_id: int,
	endpoint_cache: Variant = null,
	hive_anchor_cache: Variant = null
) -> void:
	var lane_id: int = int(ud.get("lane_id", 0))
	var endpoints: Dictionary = _unit_path_endpoints_map_local(ud, hive_by_id, endpoint_cache, hive_anchor_cache)
	var sample_pos: Vector2 = _sample_unit_pos_from_endpoints(ud, endpoints)
	var sample_dir: Vector2 = _sample_unit_dir_from_endpoints(ud, endpoints)
	var target_t: float = clampf(float(ud.get("t", 0.0)), 0.0, 1.0)
	var a_pos: Vector2 = sample_pos
	var b_pos: Vector2 = sample_pos
	if bool(endpoints.get("ok", false)):
		a_pos = endpoints.get("a", sample_pos)
		b_pos = endpoints.get("b", sample_pos)
	var sample_time_us: int = Time.get_ticks_usec()
	var sample_time_s: float = float(sample_time_us) / 1000000.0
	var sample_dir_norm: Vector2 = sample_dir
	if sample_dir_norm.length_squared() <= 0.000001:
		sample_dir_norm = Vector2.RIGHT
	else:
		sample_dir_norm = sample_dir_norm.normalized()
	var sample_rot: float = sample_dir_norm.angle() + deg_to_rad(UNIT_SPRITE_FORWARD_DEG)
	var s_new: Dictionary = {
		"t": target_t,
		"a": a_pos,
		"b": b_pos,
		"ts": sample_time_s,
		"ts_us": sample_time_us
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
		entry["prev_time_us"] = sample_time_us
		entry["curr_time_us"] = sample_time_us
		entry["prev_rot"] = sample_rot
		entry["curr_rot"] = sample_rot
		entry["render_pos"] = sample_pos
		entry["just_spawned"] = true
	else:
		var curr_pos: Vector2 = entry.get("curr_pos", sample_pos)
		entry["prev_pos"] = curr_pos
		entry["curr_pos"] = sample_pos
		var curr_time_us: int = int(entry.get("curr_time_us", sample_time_us))
		entry["prev_time_us"] = curr_time_us
		entry["curr_time_us"] = sample_time_us
		var curr_rot: float = float(entry.get("curr_rot", sample_rot))
		entry["prev_rot"] = curr_rot
		entry["curr_rot"] = sample_rot
	entry["lane_id"] = lane_id
	entry["dir"] = sample_dir_norm
	_unit_visual_by_id[unit_id] = entry

func _sample_unit_pos_map_local(ud: Dictionary, hive_by_id: Dictionary) -> Vector2:
	var endpoints: Dictionary = _unit_path_endpoints_map_local(ud, hive_by_id)
	return _sample_unit_pos_from_endpoints(ud, endpoints)

func _sample_unit_pos_from_endpoints(ud: Dictionary, endpoints: Dictionary) -> Vector2:
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
	return _sample_unit_dir_from_endpoints(ud, endpoints)

func _sample_unit_dir_from_endpoints(ud: Dictionary, endpoints: Dictionary) -> Vector2:
	if bool(endpoints.get("ok", false)):
		var a_pos: Vector2 = endpoints.get("a", Vector2.ZERO)
		var b_pos: Vector2 = endpoints.get("b", Vector2.ZERO)
		var axis: Vector2 = b_pos - a_pos
		if axis.length_squared() > 0.000001:
			var sign: int = _unit_travel_sign(ud)
			return axis.normalized() * float(sign)
	return Vector2.RIGHT

func _unit_path_endpoints_map_local(
	ud: Dictionary,
	hive_by_id: Dictionary,
	endpoint_cache: Variant = null,
	hive_anchor_cache: Variant = null
) -> Dictionary:
	var from_pos_v: Variant = ud.get("from_pos", null)
	var to_pos_v: Variant = ud.get("to_pos", null)
	if from_pos_v is Vector2 and to_pos_v is Vector2:
		return {"ok": true, "a": from_pos_v as Vector2, "b": to_pos_v as Vector2}
	var unit_id: int = int(ud.get("id", -1))
	var a_id: int = _resolve_id(ud.get("a_id", 0))
	var b_id: int = _resolve_id(ud.get("b_id", 0))
	if a_id > 0 and b_id > 0:
		var ab_endpoints: Dictionary = _lane_endpoints_map_local_from_hive_ids(a_id, b_id, hive_by_id, unit_id, endpoint_cache, hive_anchor_cache)
		if bool(ab_endpoints.get("ok", false)):
			return ab_endpoints
	var from_id: int = _resolve_id(ud.get("from_id", ud.get("from", 0)))
	var to_id: int = _resolve_id(ud.get("to_id", ud.get("to", 0)))
	if from_id > 0 and to_id > 0:
		var ft_endpoints: Dictionary = _lane_endpoints_map_local_from_hive_ids(from_id, to_id, hive_by_id, unit_id, endpoint_cache, hive_anchor_cache)
		if bool(ft_endpoints.get("ok", false)):
			return ft_endpoints
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

func _hive_center_world_pos(hive_id: int, hive_by_id: Dictionary) -> Variant:
	if hive_nodes_by_id.has(hive_id):
		var node: Node2D = hive_nodes_by_id[hive_id]
		if node != null:
			return node.global_position
	var center_local_v: Variant = _hive_center_map_local(hive_id, hive_by_id)
	if center_local_v is Vector2:
		return to_global(center_local_v as Vector2)
	return null

func _lane_anchor_local_from_center_world(hive_center_world: Vector2) -> Vector2:
	var anchor_world: Vector2 = HiveNodeScript.lane_anchor_world_from_center(hive_center_world)
	return to_local(anchor_world)

func _maybe_log_unit_baseline_audit(
	unit_id: int,
	from_id: int,
	to_id: int,
	from_anchor_lane_local: Vector2,
	to_anchor_lane_local: Vector2,
	from_anchor_unit_local: Vector2,
	to_anchor_unit_local: Vector2
) -> void:
	if unit_id <= 0:
		return
	var now_ms: int = Time.get_ticks_msec()
	if _last_baseline_audit_ms > 0 and now_ms - _last_baseline_audit_ms < UNIT_BASELINE_AUDIT_INTERVAL_MS:
		return
	_last_baseline_audit_ms = now_ms
	SFLog.info("UNIT_BASELINE_AUDIT", {
		"unit_id": unit_id,
		"from_id": from_id,
		"to_id": to_id,
		"from_anchor_lane_local": from_anchor_lane_local,
		"to_anchor_lane_local": to_anchor_lane_local,
		"from_anchor_unit_local": from_anchor_unit_local,
		"to_anchor_unit_local": to_anchor_unit_local
	})

func _resolve_hive_lane_anchor_info(hive_id: int, hive_by_id: Dictionary, hive_anchor_cache: Variant = null) -> Dictionary:
	var cache: Dictionary = _cached_hive_anchor_info
	if typeof(hive_anchor_cache) == TYPE_DICTIONARY:
		cache = hive_anchor_cache as Dictionary
	if cache.has(hive_id):
		var cached_any: Variant = cache.get(hive_id, null)
		if typeof(cached_any) == TYPE_DICTIONARY:
			return cached_any as Dictionary
	var fallback_unit_local: Vector2 = Vector2.ZERO
	var has_anchor: bool = false
	var center_world_v: Variant = _hive_center_world_pos(hive_id, hive_by_id)
	if center_world_v is Vector2:
		var center_world: Vector2 = center_world_v as Vector2
		fallback_unit_local = _lane_anchor_local_from_center_world(center_world)
		has_anchor = true
	else:
		var center_local_v: Variant = _hive_center_map_local(hive_id, hive_by_id)
		if center_local_v is Vector2:
			fallback_unit_local = center_local_v as Vector2
			has_anchor = true
	var lane_anchor_local: Vector2 = fallback_unit_local
	var unit_anchor_local: Vector2 = fallback_unit_local
	var lane_node: Node2D = null
	if _lane_renderer != null and is_instance_valid(_lane_renderer):
		if _lane_renderer is Node2D:
			lane_node = _lane_renderer as Node2D
	if lane_node != null:
		var fallback_global: Vector2 = to_global(fallback_unit_local)
		lane_anchor_local = lane_node.to_local(fallback_global)
		unit_anchor_local = fallback_unit_local
	var out: Dictionary = {
		"ok": has_anchor,
		"lane_local": lane_anchor_local,
		"unit_local": unit_anchor_local
	}
	cache[hive_id] = out
	return out

func _lane_endpoints_map_local_from_hive_ids(
	from_id: int,
	to_id: int,
	hive_by_id: Dictionary,
	unit_id: int = -1,
	endpoint_cache: Variant = null,
	hive_anchor_cache: Variant = null
) -> Dictionary:
	var endpoint_cache_dict: Dictionary = _cached_lane_endpoints
	if typeof(endpoint_cache) == TYPE_DICTIONARY:
		endpoint_cache_dict = endpoint_cache as Dictionary
	var key: String = "%d>%d" % [from_id, to_id]
	if endpoint_cache_dict.has(key):
		var cached_any: Variant = endpoint_cache_dict.get(key, null)
		if typeof(cached_any) == TYPE_DICTIONARY:
			var cached: Dictionary = cached_any as Dictionary
			if bool(cached.get("ok", false)):
				_maybe_log_unit_baseline_audit(
					unit_id,
					from_id,
					to_id,
					cached.get("from_lane_local", Vector2.ZERO),
					cached.get("to_lane_local", Vector2.ZERO),
					cached.get("a", Vector2.ZERO),
					cached.get("b", Vector2.ZERO)
				)
			return cached
	var from_info: Dictionary = _resolve_hive_lane_anchor_info(from_id, hive_by_id, hive_anchor_cache)
	var to_info: Dictionary = _resolve_hive_lane_anchor_info(to_id, hive_by_id, hive_anchor_cache)
	var from_ok: bool = bool(from_info.get("ok", false))
	var to_ok: bool = bool(to_info.get("ok", false))
	if not from_ok or not to_ok:
		var miss: Dictionary = {"ok": false, "a": Vector2.ZERO, "b": Vector2.ZERO}
		endpoint_cache_dict[key] = miss
		return miss
	var from_lane_local: Vector2 = from_info.get("lane_local", Vector2.ZERO)
	var to_lane_local: Vector2 = to_info.get("lane_local", Vector2.ZERO)
	var from_unit_local: Vector2 = from_info.get("unit_local", Vector2.ZERO)
	var to_unit_local: Vector2 = to_info.get("unit_local", Vector2.ZERO)
	var out: Dictionary = {
		"ok": true,
		"a": from_unit_local,
		"b": to_unit_local,
		"from_lane_local": from_lane_local,
		"to_lane_local": to_lane_local
	}
	endpoint_cache_dict[key] = out
	_maybe_log_unit_baseline_audit(
		unit_id,
		from_id,
		to_id,
		from_lane_local,
		to_lane_local,
		from_unit_local,
		to_unit_local
	)
	return out

func _to_render_local(pos: Vector2) -> Vector2:
	if _unit_space == "global":
		return to_local(pos)
	return pos

func _build_hive_by_id() -> Dictionary:
	if _hive_bind_version == 0:
		var hives_v: Variant = model.get("hives", [])
		if typeof(hives_v) == TYPE_ARRAY:
			set_hive_snapshot(hives_v as Array)
	return _hive_by_id_cache

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
		node.visible = false
		sprite.visible = false
		return
	var resolved_path := tex.resource_path
	if resolved_path.is_empty():
		resolved_path = tex_path
	# Order: texture -> material -> self_modulate
	if sprite.texture == null or sprite.texture != tex:
		sprite.texture = tex
	var team_color: Color = _owner_color(owner_id)
	team_color.a = UNIT_COLOR.a
	if _color_changed(sprite.self_modulate, team_color):
		if AUDIT_RENDER:
			_audit_modulate_sets += 1
		sprite.self_modulate = team_color
	var has_resource_path: bool = not tex.resource_path.is_empty()
	if has_resource_path:
		var mat: ShaderMaterial = _ensure_unit_colorkey_material(sprite, sprite_key, registry, owner_id, unit_id)
		if mat != null and sprite.material != mat:
			if AUDIT_RENDER:
				_audit_material_assigns += 1
			sprite.material = mat
	else:
		if sprite.material != null:
			if AUDIT_RENDER:
				_audit_material_assigns += 1
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
			"ok": sprite.material != null,
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
	node.visible = true
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
	_audit_render_maybe_flush()

func _audit_render_maybe_flush() -> void:
	if not AUDIT_RENDER:
		return
	var now_ms: int = Time.get_ticks_msec()
	if _audit_last_ms <= 0:
		_audit_last_ms = now_ms
		return
	_audit_frames += 1
	var active_units: int = unit_nodes_by_id.size()
	if active_units > _audit_units_peak:
		_audit_units_peak = active_units
	if now_ms - _audit_last_ms < 1000:
		return
	SFLog.info("RENDER_AUDIT_UNITS", {
		"units": _audit_units_peak,
		"draw_ops": _audit_draw_ops,
		"mat_sets": _audit_mat_sets,
		"rebuilds": _audit_rebuilds,
		"material_sets": _audit_material_assigns,
		"modulate_sets": _audit_modulate_sets
	})
	var top_mat_entries: Array = _audit_top_entries(_audit_mat_key_counts, 5)
	SFLog.info("RENDER_AUDIT_UNITS_TOP_MAT_KEYS", {
		"total_mat_sets": _audit_mat_sets,
		"top": top_mat_entries
	})
	var rebuild_entries: Array = _audit_top_entries(_audit_rebuild_counts, 5)
	SFLog.info("RENDER_AUDIT_UNITS_REBUILDS", {
		"total_rebuilds": _audit_rebuilds,
		"rebuilds": rebuild_entries
	})
	_audit_last_ms = now_ms
	_audit_draw_ops = 0
	_audit_mat_sets = 0
	_audit_rebuilds = 0
	_audit_units_peak = 0
	_audit_frames = 0
	_audit_material_assigns = 0
	_audit_modulate_sets = 0
	_audit_mat_key_counts.clear()
	_audit_rebuild_counts.clear()

func _audit_inc_count(bucket: Dictionary, key: String, amount: int = 1) -> void:
	if not AUDIT_RENDER:
		return
	if key.is_empty() or amount <= 0:
		return
	bucket[key] = int(bucket.get(key, 0)) + amount

func _audit_mark_rebuild(reason: String, amount: int = 1) -> void:
	if not AUDIT_RENDER:
		return
	if reason.is_empty() or amount <= 0:
		return
	_audit_rebuilds += amount
	_audit_inc_count(_audit_rebuild_counts, reason, amount)

func _audit_top_entries(bucket: Dictionary, max_items: int) -> Array:
	var result: Array = []
	if bucket.is_empty() or max_items <= 0:
		return result
	var top_keys: Array = []
	var top_values: Array = []
	for key_any in bucket.keys():
		var key: String = str(key_any)
		var value: int = int(bucket.get(key, 0))
		if value <= 0:
			continue
		var inserted: bool = false
		var idx: int = 0
		while idx < top_values.size():
			if value > int(top_values[idx]):
				top_values.insert(idx, value)
				top_keys.insert(idx, key)
				inserted = true
				break
			idx += 1
		if not inserted and top_values.size() < max_items:
			top_values.append(value)
			top_keys.append(key)
		if top_values.size() > max_items:
			top_values.resize(max_items)
			top_keys.resize(max_items)
	for i in range(top_keys.size()):
		result.append({"k": str(top_keys[i]), "n": int(top_values[i])})
	return result

func _mat_set(mat: ShaderMaterial, key: StringName, value: Variant) -> void:
	if mat == null:
		return
	mat.set_shader_parameter(key, value)
	if not AUDIT_RENDER:
		return
	_audit_mat_sets += 1
	_audit_inc_count(_audit_mat_key_counts, str(key), 1)

func _color_changed(a: Color, b: Color) -> bool:
	var eps: float = 0.0001
	if absf(a.r - b.r) > eps:
		return true
	if absf(a.g - b.g) > eps:
		return true
	if absf(a.b - b.b) > eps:
		return true
	if absf(a.a - b.a) > eps:
		return true
	return false

func _sample_float(sample: Dictionary, key: String, fallback: float) -> float:
	return float(sample.get(key, fallback))

func _sample_vec2(sample: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = sample.get(key, fallback)
	if value is Vector2:
		return value as Vector2
	return fallback

func _update_unit_visual_smoothing(_delta: float) -> void:
	var alpha: float = clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	_render_units(alpha)

func _render_units_constant_speed(delta: float) -> void:
	if unit_nodes_by_id.is_empty():
		return
	var safe_delta: float = maxf(delta, 0.0)
	var hive_by_id: Dictionary = _build_hive_by_id()
	var ids: Array = unit_nodes_by_id.keys()
	if AUDIT_RENDER:
		_audit_draw_ops += ids.size()
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

func _render_units(alpha: float) -> void:
	if _unit_visual_by_id.is_empty():
		return
	var ids: Array = unit_nodes_by_id.keys()
	if AUDIT_RENDER:
		_audit_draw_ops += ids.size()
	for id_any in ids:
		var unit_id: int = int(id_any)
		var node: Node2D = unit_nodes_by_id.get(unit_id, null)
		if node == null:
			continue
		if not _assert_not_freed(node):
			continue
		var state_any: Variant = _unit_visual_by_id.get(unit_id, null)
		if typeof(state_any) == TYPE_DICTIONARY:
			var state: Dictionary = state_any as Dictionary
			if bool(state.get("just_spawned", false)):
				var spawn_pos: Vector2 = state.get("curr_pos", node.position)
				node.position = spawn_pos
				node.rotation = float(state.get("curr_rot", node.rotation))
				state["render_pos"] = spawn_pos
				state["just_spawned"] = false
				_unit_visual_by_id[unit_id] = state
				continue
			var prev_pos: Vector2 = state.get("prev_pos", node.position)
			var curr_pos: Vector2 = state.get("curr_pos", prev_pos)
			var render_pos: Vector2 = prev_pos.lerp(curr_pos, alpha)
			node.position = render_pos
			var prev_rot: float = float(state.get("prev_rot", node.rotation))
			var curr_rot: float = float(state.get("curr_rot", prev_rot))
			node.rotation = lerp_angle(prev_rot, curr_rot, alpha)
			state["render_pos"] = render_pos
			_unit_visual_by_id[unit_id] = state

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
	_audit_mark_rebuild("colorkey_material_cache_miss")
	var mat := ShaderMaterial.new()
	mat.shader = COLORKEY_SHADER
	_mat_set(mat, "key_color", color)
	_mat_set(mat, "threshold", threshold)
	_mat_set(mat, "softness", softness)
	_colorkey_materials[key] = mat
	return mat

func _get_unit_colorkey_material(sprite_key: String, owner_id: int, registry: SpriteRegistry) -> ShaderMaterial:
	var key := "%s|%d" % [sprite_key, owner_id]
	if _unit_material_by_sprite.has(key):
		return _unit_material_by_sprite[key]
	_audit_mark_rebuild("unit_colorkey_lookup")
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
	unit_id: int
) -> ShaderMaterial:
	if sprite == null:
		return null
	var mat: ShaderMaterial = _get_unit_colorkey_material(sprite_key, owner_id, registry)
	if mat == null:
		return null
	if unit_id > 0:
		var last_owner: int = int(_unit_team_color_logged.get(unit_id, -1))
		if last_owner != owner_id:
			_unit_team_color_logged[unit_id] = owner_id
			var team_color_dbg: Color = _owner_color(owner_id)
			SFLog.info("UNIT_TEAM_COLOR", {
				"unit_id": unit_id,
				"owner_id": owner_id,
				"team_color": team_color_dbg
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

	var hive_by_id: Dictionary = _build_hive_by_id()

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
			var endpoints: Dictionary = _lane_endpoints_map_local_from_hive_ids(a_id, b_id, hive_by_id)
			if bool(endpoints.get("ok", false)):
				var a_pos: Vector2 = endpoints.get("a", Vector2.ZERO)
				var b_pos: Vector2 = endpoints.get("b", Vector2.ZERO)
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
	var dir: Vector2 = _unit_lane_dir(ud, hive_by_id)
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	var normal: Vector2 = Vector2(-dir.y, dir.x)
	var phase: float = _unit_phase(unit_id)
	var amp: float = _unit_amp(unit_id)
	var offset: float = sin(BOBBLE_OMEGA * sim_time_s + phase) * amp
	var off: Vector2 = normal * offset
	off.y = clampf(off.y, -BOBBLE_Y_CLAMP_PX, BOBBLE_Y_CLAMP_PX)
	return off

func _unit_lane_dir(ud: Dictionary, hive_by_id: Dictionary) -> Vector2:
	var endpoints: Dictionary = _unit_path_endpoints_map_local(ud, hive_by_id)
	if not bool(endpoints.get("ok", false)):
		return Vector2.ZERO
	var from_pos: Vector2 = endpoints.get("a", Vector2.ZERO)
	var to_pos: Vector2 = endpoints.get("b", Vector2.ZERO)
	var delta: Vector2 = to_pos - from_pos
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
	var unit_id: int = int(ud.get("id", -1))
	var a_id: int = _resolve_id(ud.get("a_id", 0))
	var b_id: int = _resolve_id(ud.get("b_id", 0))
	if a_id > 0 and b_id > 0:
		var ab_local: Dictionary = _lane_endpoints_map_local_from_hive_ids(a_id, b_id, hive_by_id, unit_id)
		if bool(ab_local.get("ok", false)):
			var a_world_local: Vector2 = ab_local.get("a", Vector2.ZERO)
			var b_world_local: Vector2 = ab_local.get("b", Vector2.ZERO)
			return {
				"ok": true,
				"a": _to_world_pos(a_world_local),
				"b": _to_world_pos(b_world_local)
			}
	var from_id: int = _resolve_id(ud.get("from_id", ud.get("from", 0)))
	var to_id: int = _resolve_id(ud.get("to_id", ud.get("to", 0)))
	if from_id > 0 and to_id > 0:
		var ft_local: Dictionary = _lane_endpoints_map_local_from_hive_ids(from_id, to_id, hive_by_id, unit_id)
		if bool(ft_local.get("ok", false)):
			var from_local: Vector2 = ft_local.get("a", Vector2.ZERO)
			var to_local_v: Vector2 = ft_local.get("b", Vector2.ZERO)
			return {
				"ok": true,
				"a": _to_world_pos(from_local),
				"b": _to_world_pos(to_local_v)
			}
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
