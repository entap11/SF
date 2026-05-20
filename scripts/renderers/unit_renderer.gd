# NOTE: Add debug gating/rate limits for logs to prevent per-frame spam.
extends Node2D

signal bee_clip_absorb_ready(unit_id: int, to_hive_id: int, lane_id: int, cut_value: float)

const SFLog := preload("res://scripts/util/sf_log.gd")
const SpriteRegistry := preload("res://scripts/renderers/sprite_registry.gd")
const EdgeGeometry := preload("res://scripts/geo/edge_geometry.gd")
const EdgeVisual := preload("res://scripts/renderers/edge_visual.gd")
const EdgeEndpoints := preload("res://scripts/renderers/edge_endpoints.gd")
const TeamVisuals := preload("res://scripts/renderers/team_visuals.gd")
const COLORKEY_SHADER := preload("res://shaders/sf_colorkey_alpha.gdshader")
const TEAM_GLOW_RECOLOR_SHADER := preload("res://shaders/team_glow_recolor.gdshader")
const BeeClipControllerScript := preload("res://scripts/vfx/bee_clip_controller.gd")
const BEE_CLIP_SHADER := preload("res://shaders/BeeClip.gdshader")
const SwarmBeeRenderer := preload("res://scripts/renderers/swarm_bee_renderer.gd")

var model: Dictionary = {}
var hive_nodes_by_id: Dictionary = {}
var _units: Array = []
var _last_set_count: int = -1
var _last_set_log_ms: int = 0
var _last_model_units_count: int = -1
var _last_live_nodes_count: int = -1
var swarm_nodes_by_id: Dictionary = {}
var unit_nodes_by_id: Dictionary = {}
var _unit_multimesh_batches: Dictionary = {}
var _sprite_registry: SpriteRegistry = null
var _colorkey_materials: Dictionary = {}
var _unit_material_by_sprite: Dictionary = {}
var _neutral_unit_material_by_sprite: Dictionary = {}
var _unit_team_color_logged: Dictionary = {}
var _unit_tint_target_logged: Dictionary = {}
var _unit_material_cleared_logged: Dictionary = {}
var _unit_visual_by_id: Dictionary = {}
var _unit_samples_by_id: Dictionary = {}
var _unit_data_by_id: Dictionary = {}
var _unit_style_sig_by_id: Dictionary = {}
var _unit_colorkey_logged := false
var _unit_sprite_logged := false

const UNIT_RADIUS_PX := 3.5
const UNIT_DRAW_RADIUS_PX: float = 4.0
const UNIT_RENDER_SCALE: float = 1.44
const UNIT_VISUAL_SCALE_MULT: float = 0.80
const UNIT_OUTLINE_ENABLED: bool = true
const UNIT_OUTLINE_SCALE_MULT: float = 1.32
const UNIT_OUTLINE_COLOR: Color = Color(0.02, 0.02, 0.03, 0.98)
const UNIT_SPRITE_FORWARD_DEG: float = 90.0
const UNIT_TRAVEL_T_EPS: float = 0.02
const HIVE_REAR_APPROACH_Y_MIN: float = 0.12
const HIVE_REAR_OCCLUSION_ENTRY_PAD_PX: float = 2.0
const HIVE_BACK_SHELL_OCCLUSION_ENTRY_PAD_PX: float = 24.0
const HIVE_SOURCE_OCCLUSION_EXIT_PAD_PX: float = 56.0
const HIVE_REAR_OCCLUSION_Z_INDEX: int = -2
const HIVE_UNIT_DEFAULT_Z_INDEX: int = 0
const DBG_UNITS: bool = false
const HiveNodeScript := preload("res://scripts/hive/hive_node.gd")
const UNIT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const DEBUG_HIVE1_CROSS := false
const UNIT_LOG_INTERVAL_MS := 1000
const UNIT_BOUNDS_LOG_INTERVAL_MS := 1000
const UNIT_REDRAW_INTERVAL_MS := 30
const UNIT_BASELINE_AUDIT_INTERVAL_MS: int = 1000
const UNIT_RECONCILE_LOG_INTERVAL_MS: int = 1000
const UNIT_RECONCILE_SLOW_MS: float = 2.0
const UNIT_DEATH_LOG_MIN_EXTRA_MS: float = 0.50
const UNIT_DEATH_LOG_MIN_TOTAL_MS: float = 1.00
const UNIT_DEATH_LOG_MIN_DEATHS: int = 3
const UNIT_ENDPOINT_SPIKE_LOG_INTERVAL_MS: int = 500
const UNIT_ENDPOINT_PERF_WINDOW_MS: int = 2000
const UNIT_ENDPOINT_PROFILE_CACHE_HITS: bool = false
const SWARM_ABSORB_VISUAL_ENABLED: bool = true
const SWARM_ABSORB_RADIUS_PX: float = 110.0
const SWARM_ABSORB_CORE_RADIUS_PX: float = 24.0
const SWARM_ABSORB_HALO_RADIUS_PX: float = 30.0
const SWARM_ABSORB_MAX_PULL: float = 0.92
const SWARM_ABSORB_MIN_SCALE: float = 0.36
const SWARM_ABSORB_MIN_ALPHA: float = 0.18
const BOBBLE_AMP_MIN_PX: float = 2.0
const BOBBLE_AMP_MAX_PX: float = 6.0
const BOBBLE_OMEGA: float = 8.0
const BOBBLE_Y_CLAMP_PX: float = 6.0
const BOBBLE_RATE_MIN: float = 0.78
const BOBBLE_RATE_MAX: float = 1.28
const BOBBLE_SECONDARY_SCALE_MIN: float = 0.18
const BOBBLE_SECONDARY_SCALE_MAX: float = 0.42
const BOBBLE_SECONDARY_OMEGA_RATIO: float = 0.61
const BOBBLE_ELEVATION_AMP_MIN_PX: float = 0.8
const BOBBLE_ELEVATION_AMP_MAX_PX: float = 2.4
const BOBBLE_ELEVATION_RATE_MIN: float = 0.72
const BOBBLE_ELEVATION_RATE_MAX: float = 1.34
const BOBBLE_ELEVATION_SECONDARY_SCALE_MIN: float = 0.16
const BOBBLE_ELEVATION_SECONDARY_SCALE_MAX: float = 0.36
const BOBBLE_ELEVATION_Y_CLAMP_PX: float = 4.0
const SIM_DT_SEC_DEFAULT: float = 0.1
const BUTTER_INTERP_DELAY_TICKS: float = 0.75
const SAMPLE_T_EPS: float = 0.001
const BUTTER_MAX_EXTRAP_SEC: float = 0.05
const DBG_BUTTER: bool = false
const DBG_BUTTER_LOG_INTERVAL_MS: int = 1000
const DBG_FORCE_CONSTANT_VISUAL_MOTION: bool = false
const DBG_VISUAL_SPEED: float = 0.35
const AUDIT_RENDER: bool = false
const USE_UNIT_POOL: bool = true
const UNIT_POOL_SIZE_PER_TEAM: int = 64
const UNIT_POOL_OFFSCREEN_POS: Vector2 = Vector2(-99999.0, -99999.0)
const PRUNE_AFTER_TICKS: int = 2
const PASS_THROUGH_VISUAL_WARM_PX: float = 7.0
const UNIT_EMERGENCE_DISTANCE_PX: float = 96.0
const UNIT_EMERGENCE_DURATION_US: int = 320000
const UNIT_EMERGENCE_HOLD_US: int = 0
const UNIT_SPAWN_VISUAL_WARM_PX: float = 28.0
const UNIT_EMERGENCE_MIN_AXIS_SCALE: float = 0.16
const UNIT_EMERGENCE_FULL_EPS: float = 0.995
const UNIT_EMERGENCE_REVEAL_SOFTNESS: float = 0.045
const UNIT_BASE_SCALE_META: StringName = &"unit_base_scale"
const UNIT_OUTLINE_BASE_SCALE_META: StringName = &"unit_outline_base_scale"

@export var debug_unit_logs: bool = false
@export var debug_unit_owner_labels: bool = false
@export var debug_draw_units: bool = false
@export var debug_force_top_z: bool = false
@export var debug_force_big_radius_px: float = 10.0
@export var use_multimesh_units: bool = false
@export var sim_dt_sec: float = SIM_DT_SEC_DEFAULT
@export var lane_start_cap_trim_px: float = 18.0
@export var lane_end_cap_trim_px: float = 18.0
@export var bee_clip_enabled: bool = true
@export var bee_clip_visual_length_px_override: float = 0.0
@export var bee_clip_length_scale: float = 0.75
@export var bee_clip_min_visual_length_px: float = 24.0
@export var bee_clip_nose_offset_px: float = 0.0
@export var bee_clip_entrance_plane_offset_px: float = 14.0
@export var bee_clip_collision_lead_px: float = 120.0
@export var bee_clip_collision_snap_on_prime: bool = true
@export var bee_clip_collision_first_contact_cut_max: float = 0.08
@export var bee_clip_collision_length_scale: float = 0.50
@export var bee_clip_collision_plane_offset_px: float = 32.0
@export var bee_clip_collision_prime_nose_bias_px: float = 56.0
@export var bee_clip_collision_missing_speed_cap_px_s: float = 180.0
@export var bee_clip_collision_min_hold_ticks: int = 6
@export var bee_clip_collision_debug_logs: bool = false
@export var bee_clip_collision_debug_throttle_ms: int = 120
@export var bee_clip_flip_forward_axis: bool = false
@export var bee_clip_debug_logs: bool = false
@export var bee_clip_missing_speed_fallback_px_s: float = 220.0
@export var bee_clip_hold_missing_until_clipped: bool = true
@export var bee_clip_missing_hold_max_ticks: int = 14
@export var unit_emergence_enabled: bool = true

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
var _hive_nodes_sig: int = 0
var _unit_missing_ticks: Dictionary = {}
var _last_baseline_audit_ms: int = 0
var _reconcile_last_log_ms: int = 0
var _death_reconcile_last_log_ms: int = 0
var _reconcile_baseline_ms: float = 0.0
var _reconcile_baseline_samples: int = 0
var _last_bound_units_count: int = 0
var _hive_lookup_last_log_ms: int = 0
var _cached_hive_anchor_info: Dictionary = {}
var _cached_lane_endpoints: Dictionary = {}
var _lane_renderer: Object = null
var _last_lane_sig: int = -1
var _endpoint_spike_last_ms: int = 0
var _endpoint_perf_window_start_ms: int = 0
var _endpoint_perf_calls: int = 0
var _endpoint_perf_cache_hits: int = 0
var _endpoint_perf_max_eval_ms: float = 0.0
var _endpoint_perf_spike_count: int = 0
var _last_endpoint_trace: Dictionary = {}
var _unit_assets_prewarmed: bool = false
var _lane_endpoint_prewarm_sig: int = -1
var _post_match_settle_active: bool = false
var _post_match_settle_until_us: int = 0
var _post_match_extrap_sec: float = BUTTER_MAX_EXTRAP_SEC
var _bee_clip_by_unit_id: Dictionary = {}
var _bee_clip_outline_by_unit_id: Dictionary = {}
var _bee_clip_plane_override_by_unit_id: Dictionary = {}
var _bee_clip_last_debug_log_ms: int = 0
var _bee_clip_last_world_pos_by_unit_id: Dictionary = {}
var _bee_clip_last_update_us_by_unit_id: Dictionary = {}
var _bee_clip_travel_dir_world_by_unit_id: Dictionary = {}
var _bee_clip_speed_px_s_by_unit_id: Dictionary = {}
var _bee_clip_entrance_world_by_unit_id: Dictionary = {}
var _bee_clip_visual_len_by_unit_id: Dictionary = {}
var _bee_clip_to_hive_id_by_unit_id: Dictionary = {}
var _bee_clip_lane_id_by_unit_id: Dictionary = {}
var _bee_clip_collision_active_by_unit_id: Dictionary = {}
var _bee_clip_collision_last_log_ms_by_unit_id: Dictionary = {}
var _sim_events: Node = null

func _ready() -> void:
	if _unit_profile_logs_enabled():
		SFLog.allow_tag("RENDER_AUDIT_UNITS")
		SFLog.allow_tag("RENDER_AUDIT_UNITS_TOP_MAT_KEYS")
		SFLog.allow_tag("RENDER_AUDIT_UNITS_REBUILDS")
		SFLog.allow_tag("UNIT_RENDER_REBUILD")
		SFLog.allow_tag("UNIT_BASELINE_AUDIT")
		SFLog.allow_tag("UNIT_DEATH_FRAME_MS")
		SFLog.allow_tag("UNIT_RECONCILE_SLOW")
		SFLog.allow_tag("UNIT_HIVE_LOOKUP_BUILD_MS")
		SFLog.allow_tag("UNIT_EDGE_BIND")
		SFLog.allow_tag("UNIT_ENDPOINT_SPIKE")
		SFLog.allow_tag("UNIT_ENDPOINT_CACHE_INVALIDATE")
		SFLog.allow_tag("UNIT_ENDPOINT_PERF_SUMMARY")
		SFLog.allow_tag("HIVE_NODES_SET_SKIPPED")
	if bee_clip_collision_debug_logs:
		SFLog.allow_tag("BEE_CLIP_COLLISION_DBG")
	if use_multimesh_units:
		_release_unit_pool_nodes()
	else:
		_pool_build()
	_apply_debug_force_top_z()
	_prewarm_unit_assets()
	_try_bind_sim_events()
	_request_redraw()

func _unit_profile_logs_enabled() -> bool:
	return debug_unit_logs or AUDIT_RENDER

func _try_bind_sim_events() -> void:
	if _sim_events == null or not is_instance_valid(_sim_events):
		var tree: SceneTree = get_tree()
		if tree != null:
			_sim_events = tree.get_first_node_in_group("sim_events")
	if _sim_events == null:
		return
	if not _sim_events.is_connected("unit_collision", Callable(self, "_on_sim_unit_collision")):
		_sim_events.connect("unit_collision", Callable(self, "_on_sim_unit_collision"))

func set_sim_events(sim_events: Node) -> void:
	if _sim_events == sim_events:
		_try_bind_sim_events()
		return
	var previous_events: Node = _sim_events
	if previous_events != null and is_instance_valid(previous_events):
		var collision_cb := Callable(self, "_on_sim_unit_collision")
		if previous_events.is_connected("unit_collision", collision_cb):
			previous_events.disconnect("unit_collision", collision_cb)
	_sim_events = sim_events
	_try_bind_sim_events()

func begin_post_match_settle(duration_sec: float = 0.75, extrap_sec: float = 0.40) -> void:
	var safe_duration_sec: float = maxf(0.0, duration_sec)
	var safe_extrap_sec: float = maxf(BUTTER_MAX_EXTRAP_SEC, extrap_sec)
	_post_match_settle_active = safe_duration_sec > 0.0
	_post_match_extrap_sec = safe_extrap_sec
	if _post_match_settle_active:
		_post_match_settle_until_us = Time.get_ticks_usec() + int(round(safe_duration_sec * 1000000.0))
	else:
		_post_match_settle_until_us = 0

func end_post_match_settle() -> void:
	_post_match_settle_active = false
	_post_match_settle_until_us = 0
	_post_match_extrap_sec = BUTTER_MAX_EXTRAP_SEC

func _post_match_settle_is_active(now_us: int) -> bool:
	if not _post_match_settle_active:
		return false
	if _post_match_settle_until_us <= 0:
		return true
	if now_us < _post_match_settle_until_us:
		return true
	_post_match_settle_active = false
	_post_match_settle_until_us = 0
	_post_match_extrap_sec = BUTTER_MAX_EXTRAP_SEC
	return false

func setup_renderer_refs(lane_renderer_ref: Object) -> void:
	if _lane_renderer == lane_renderer_ref:
		return
	_lane_renderer = lane_renderer_ref
	_last_lane_sig = -1
	_invalidate_endpoint_caches("renderer_ref_changed")

func _endpoint_invalidate_caller_hint() -> String:
	var stack: Array = get_stack()
	for i in range(1, stack.size()):
		var frame: Dictionary = stack[i]
		var fn: String = str(frame.get("function", ""))
		if fn != "_invalidate_endpoint_caches" and fn != "":
			return fn
	return ""

func _invalidate_endpoint_caches(reason: String = "unspecified") -> void:
	_cached_hive_anchor_info.clear()
	_cached_lane_endpoints.clear()
	_lane_endpoint_prewarm_sig = -1
	if _unit_profile_logs_enabled():
		SFLog.info("UNIT_ENDPOINT_CACHE_INVALIDATE", {
			"reason": reason,
			"caller": _endpoint_invalidate_caller_hint()
		})

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
	_reset_unit_hive_occlusion_depth(node)
	_ensure_unit_outline_sprite(node)
	_ensure_unit_sprite(node)
	return node

func _pool_build() -> void:
	if use_multimesh_units:
		return
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

func _release_unit_pool_nodes() -> void:
	for node_any in _unit_pool:
		var node: Node = node_any as Node
		if node != null and is_instance_valid(node):
			node.queue_free()
	_unit_pool.clear()
	for node_any in _pooled_nodes.keys():
		var node: Node = node_any as Node
		if node != null and is_instance_valid(node):
			node.queue_free()
	_pooled_nodes.clear()

func _clear_bee_clip_state(unit_id: int) -> void:
	_bee_clip_by_unit_id.erase(unit_id)
	_bee_clip_outline_by_unit_id.erase(unit_id)
	_bee_clip_plane_override_by_unit_id.erase(unit_id)
	_bee_clip_last_world_pos_by_unit_id.erase(unit_id)
	_bee_clip_last_update_us_by_unit_id.erase(unit_id)
	_bee_clip_travel_dir_world_by_unit_id.erase(unit_id)
	_bee_clip_speed_px_s_by_unit_id.erase(unit_id)
	_bee_clip_entrance_world_by_unit_id.erase(unit_id)
	_bee_clip_visual_len_by_unit_id.erase(unit_id)
	_bee_clip_to_hive_id_by_unit_id.erase(unit_id)
	_bee_clip_lane_id_by_unit_id.erase(unit_id)
	_bee_clip_collision_active_by_unit_id.erase(unit_id)
	_bee_clip_collision_last_log_ms_by_unit_id.erase(unit_id)

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
		_unit_style_sig_by_id.erase(unit_id)
		_diag_visual_phase_by_id.erase(unit_id)
		_clear_bee_clip_state(unit_id)
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
		if sprite.has_meta(UNIT_BASE_SCALE_META):
			sprite.remove_meta(UNIT_BASE_SCALE_META)
		if AUDIT_RENDER:
			_audit_modulate_sets += 1
		sprite.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		sprite.visible = false
	var outline_sprite: Sprite2D = node.get_node_or_null("UnitOutlineSprite") as Sprite2D
	if outline_sprite != null:
		outline_sprite.texture = null
		outline_sprite.material = null
		outline_sprite.position = Vector2.ZERO
		outline_sprite.scale = Vector2.ONE
		outline_sprite.rotation = 0.0
		if outline_sprite.has_meta(UNIT_OUTLINE_BASE_SCALE_META):
			outline_sprite.remove_meta(UNIT_OUTLINE_BASE_SCALE_META)
		outline_sprite.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		outline_sprite.visible = false
	if not _assert_not_freed(node):
		return
	node.visible = false
	if not _assert_not_freed(node):
		return
	_reset_unit_hive_occlusion_depth(node)
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
	if use_multimesh_units:
		return
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
	_maybe_invalidate_on_lane_signature()
	_prewarm_active_lane_endpoints()
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
	var sync_profile: Dictionary = _sync_unit_records(snapshot) if use_multimesh_units else _sync_unit_nodes(snapshot)
	var update_profile: Dictionary = _update_unit_records_positions(snapshot) if use_multimesh_units else _update_unit_nodes_positions(snapshot)
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
	_maybe_invalidate_on_lane_signature()
	_prewarm_active_lane_endpoints()
	var structure_changed: bool = _consume_units_snapshot_signature(snapshot)
	if structure_changed:
		SFLog.throttled_info("UNIT_RENDER_REBUILD", {
			"reason": "units_signature_changed",
			"units": snapshot.size()
		}, 250)
	var reconcile_t0_us: int = Time.get_ticks_usec()
	var sync_profile: Dictionary = _sync_unit_records(snapshot) if use_multimesh_units else _sync_unit_nodes(snapshot)
	var update_profile: Dictionary = _update_unit_records_positions(snapshot) if use_multimesh_units else _update_unit_nodes_positions(snapshot)
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

func _lane_renderer_signature() -> int:
	if _lane_renderer == null or not is_instance_valid(_lane_renderer):
		return -1
	if not _lane_renderer.has_method("get_lane_signature"):
		return -1
	var sig_any: Variant = _lane_renderer.call("get_lane_signature")
	if typeof(sig_any) == TYPE_INT:
		return int(sig_any)
	if typeof(sig_any) == TYPE_FLOAT:
		return int(sig_any)
	return -1

func _maybe_invalidate_on_lane_signature() -> void:
	var sig: int = _lane_renderer_signature()
	if sig < 0:
		return
	if _last_lane_sig < 0:
		_last_lane_sig = sig
		return
	if sig == _last_lane_sig:
		return
	_last_lane_sig = sig
	_invalidate_endpoint_caches("lane_sig_changed")

func _owner_id_from_unit_sprite_key(sprite_key: String) -> int:
	if sprite_key == "unit.neutral":
		return 0
	if sprite_key.begins_with("unit.p"):
		var owner_s: String = sprite_key.trim_prefix("unit.p")
		if owner_s.is_valid_int():
			return int(owner_s)
	return 0

func _prewarm_unit_assets() -> void:
	if _unit_assets_prewarmed:
		return
	var registry: SpriteRegistry = _get_sprite_registry()
	if registry == null:
		return
	_pool_build()
	var prewarm_node: Node2D = _pool_acquire()
	var prewarm_sprite: Sprite2D = null
	if prewarm_node != null:
		prewarm_sprite = _ensure_unit_sprite(prewarm_node)
	var keys: Array[String] = ["unit.neutral", "unit.p1", "unit.p2", "unit.p3", "unit.p4"]
	for sprite_key in keys:
		var tex: Texture2D = registry.get_tex(sprite_key)
		if tex == null:
			var tex_path: String = registry.get_tex_path(sprite_key)
			if not tex_path.is_empty():
				var res: Resource = ResourceLoader.load(tex_path)
				if res is Texture2D:
					tex = res as Texture2D
		var owner_id: int = _owner_id_from_unit_sprite_key(sprite_key)
		var mat: ShaderMaterial = _get_unit_material(sprite_key, owner_id, registry)
		if prewarm_sprite != null:
			prewarm_sprite.texture = tex
			prewarm_sprite.material = mat
			prewarm_sprite.visible = true
	if prewarm_node != null:
		_pool_release(prewarm_node)
	_unit_assets_prewarmed = true

func _collect_active_lane_entries() -> Array:
	var lanes_v: Variant = model.get("lanes", [])
	if typeof(lanes_v) != TYPE_ARRAY:
		return []
	var out: Array = []
	var seen: Dictionary = {}
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
		var send_a: bool = bool(ld.get("send_a", false))
		var send_b: bool = bool(ld.get("send_b", false))
		if not send_a and not send_b:
			continue
		if send_a:
			var key_a: String = _lane_cache_key(lane_id, a_id, b_id)
			if not seen.has(key_a):
				seen[key_a] = true
				out.append({"lane_id": lane_id, "from_id": a_id, "to_id": b_id})
		if send_b:
			var key_b: String = _lane_cache_key(lane_id, b_id, a_id)
			if not seen.has(key_b):
				seen[key_b] = true
				out.append({"lane_id": lane_id, "from_id": b_id, "to_id": a_id})
	return out

func _prewarm_active_lane_endpoints() -> void:
	var sig: int = _lane_renderer_signature()
	if sig < 0:
		return
	if sig == _lane_endpoint_prewarm_sig:
		return
	var entries: Array = _collect_active_lane_entries()
	if entries.is_empty():
		_lane_endpoint_prewarm_sig = sig
		return
	var hive_by_id: Dictionary = _build_hive_by_id()
	if hive_by_id.is_empty():
		return
	var endpoint_cache: Dictionary = _cached_lane_endpoints
	var hive_anchor_cache: Dictionary = _cached_hive_anchor_info
	for entry_any in entries:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var lane_id: int = int(entry.get("lane_id", -1))
		var from_id: int = int(entry.get("from_id", 0))
		var to_id: int = int(entry.get("to_id", 0))
		if lane_id <= 0 or from_id <= 0 or to_id <= 0:
			continue
		_lane_endpoints_map_local_from_hive_ids(from_id, to_id, hive_by_id, -1, endpoint_cache, hive_anchor_cache, lane_id)
	_lane_endpoint_prewarm_sig = sig

func _endpoint_perf_maybe_flush(now_ms: int) -> void:
	if not _unit_profile_logs_enabled():
		return
	if _endpoint_perf_window_start_ms <= 0:
		_endpoint_perf_window_start_ms = now_ms
		return
	if now_ms - _endpoint_perf_window_start_ms < UNIT_ENDPOINT_PERF_WINDOW_MS:
		return
	var calls: int = _endpoint_perf_calls
	var hit_rate: float = 0.0
	if calls > 0:
		hit_rate = float(_endpoint_perf_cache_hits) / float(calls)
	SFLog.info("UNIT_ENDPOINT_PERF_SUMMARY", {
		"calls": calls,
		"cache_hits": int(_endpoint_perf_cache_hits),
		"hit_rate": snapped(hit_rate * 100.0, 0.1),
		"max_endpoint_eval_ms": snapped(_endpoint_perf_max_eval_ms, 0.01),
		"spikes": int(_endpoint_perf_spike_count)
	})
	_endpoint_perf_window_start_ms = now_ms
	_endpoint_perf_calls = 0
	_endpoint_perf_cache_hits = 0
	_endpoint_perf_max_eval_ms = 0.0
	_endpoint_perf_spike_count = 0

func _endpoint_perf_record(eval_ms: float, cache_hit: bool, spike: bool) -> void:
	if not _unit_profile_logs_enabled():
		return
	var now_ms: int = Time.get_ticks_msec()
	if _endpoint_perf_window_start_ms <= 0:
		_endpoint_perf_window_start_ms = now_ms
	_endpoint_perf_calls += 1
	if cache_hit:
		_endpoint_perf_cache_hits += 1
	if eval_ms > _endpoint_perf_max_eval_ms:
		_endpoint_perf_max_eval_ms = eval_ms
	if spike:
		_endpoint_perf_spike_count += 1
	_endpoint_perf_maybe_flush(now_ms)

func _maybe_log_endpoint_spike(trace: Dictionary, endpoint_eval_ms: float, total_ms: float) -> void:
	if not _unit_profile_logs_enabled():
		return
	var now_ms: int = Time.get_ticks_msec()
	if _endpoint_spike_last_ms > 0 and now_ms - _endpoint_spike_last_ms < UNIT_ENDPOINT_SPIKE_LOG_INTERVAL_MS:
		return
	_endpoint_spike_last_ms = now_ms
	var out: Dictionary = trace.duplicate()
	out["endpoint_eval_ms"] = snapped(endpoint_eval_ms, 0.01)
	out["total_ms"] = snapped(total_ms, 0.01)
	SFLog.warn("UNIT_ENDPOINT_SPIKE", out)

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
	var endpoint_eval_ms: float = float(step_ms.get("endpoint_eval", 0.0))
	var should_log_profile: bool = _unit_profile_logs_enabled()
	if should_log_profile and (endpoint_eval_ms > 10.0 or total_ms > 16.0):
		var spike_trace: Dictionary = _last_endpoint_trace.duplicate()
		if spike_trace.is_empty():
			spike_trace = {
				"unit_id": -1,
				"lane_id": -1,
				"from_id": -1,
				"to_id": -1,
				"branch": "unknown",
				"edge_geo_cache": "unknown",
				"cache_hit": false,
				"lane_renderer_valid": _lane_renderer != null and is_instance_valid(_lane_renderer),
				"lane_renderer_has_get_lane_endpoints_world": _lane_renderer != null and is_instance_valid(_lane_renderer) and _lane_renderer.has_method("get_lane_endpoints_world"),
				"lane_renderer_has_get_edge_geo": _lane_renderer != null and is_instance_valid(_lane_renderer) and _lane_renderer.has_method("get_edge_geo"),
				"shared_anchor_used": false,
				"fallback_used": false,
				"fallback_path": "",
				"scene_scan_count": 0,
				"scene_scan_ms": 0.0
			}
		spike_trace["group_scans"] = int(sync_profile.get("group_scan_n", 0)) + int(update_profile.get("group_scan_n", 0))
		spike_trace["group_scan_ms"] = snapped(float(step_ms.get("group_scan", 0.0)), 0.01)
		spike_trace["culprit"] = culprit_name
		_maybe_log_endpoint_spike(spike_trace, endpoint_eval_ms, total_ms)
	if deaths_this_bind > 0:
		var baseline_ms: float = _reconcile_baseline_ms if _reconcile_baseline_samples > 0 else total_ms
		var extra_ms: float = maxf(0.0, total_ms - baseline_ms)
		var should_log_death_frame: bool = (
			deaths_this_bind >= UNIT_DEATH_LOG_MIN_DEATHS
			or extra_ms >= UNIT_DEATH_LOG_MIN_EXTRA_MS
			or total_ms >= UNIT_DEATH_LOG_MIN_TOTAL_MS
		)
		if should_log_profile and should_log_death_frame and now_ms - _death_reconcile_last_log_ms >= UNIT_RECONCILE_LOG_INTERVAL_MS:
			_death_reconcile_last_log_ms = now_ms
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
	elif should_log_profile and total_ms >= UNIT_RECONCILE_SLOW_MS and now_ms - _reconcile_last_log_ms >= UNIT_RECONCILE_LOG_INTERVAL_MS:
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
	_invalidate_endpoint_caches("hive_snapshot_changed")
	_audit_mark_rebuild("hive_lookup_build")
	var dt_ms: float = _us_to_ms(int(Time.get_ticks_usec() - t0_us))
	var now_ms: int = Time.get_ticks_msec()
	if _unit_profile_logs_enabled() and dt_ms >= 1.0 and now_ms - _hive_lookup_last_log_ms >= UNIT_RECONCILE_LOG_INTERVAL_MS:
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

func set_hive_nodes(dict: Dictionary) -> void:
	var next_sig: int = _compute_hive_nodes_sig(dict)
	if next_sig == _hive_nodes_sig:
		SFLog.info("HIVE_NODES_SET_SKIPPED", {
			"renderer": "unit",
			"reason": "sig_unchanged",
			"count": dict.size()
		}, "", 1000)
		return
	_hive_nodes_sig = next_sig
	hive_nodes_by_id = dict
	_invalidate_endpoint_caches("hive_nodes_set")
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
	_hive_nodes_sig = 0
	_reconcile_baseline_ms = 0.0
	_reconcile_baseline_samples = 0
	_last_bound_units_count = 0
	_reconcile_last_log_ms = 0
	_death_reconcile_last_log_ms = 0
	_endpoint_spike_last_ms = 0
	_endpoint_perf_window_start_ms = 0
	_endpoint_perf_calls = 0
	_endpoint_perf_cache_hits = 0
	_endpoint_perf_max_eval_ms = 0.0
	_endpoint_perf_spike_count = 0
	_last_endpoint_trace.clear()
	_last_lane_sig = -1
	end_post_match_settle()
	_invalidate_endpoint_caches("clear_all")
	_unit_missing_ticks.clear()
	_unit_data_by_id.clear()
	_unit_visual_by_id.clear()
	_unit_samples_by_id.clear()
	_unit_style_sig_by_id.clear()
	_diag_visual_phase_by_id.clear()
	_bee_clip_by_unit_id.clear()
	_bee_clip_plane_override_by_unit_id.clear()
	_bee_clip_last_world_pos_by_unit_id.clear()
	_bee_clip_last_update_us_by_unit_id.clear()
	_bee_clip_travel_dir_world_by_unit_id.clear()
	_bee_clip_speed_px_s_by_unit_id.clear()
	_bee_clip_entrance_world_by_unit_id.clear()
	_bee_clip_visual_len_by_unit_id.clear()
	_bee_clip_to_hive_id_by_unit_id.clear()
	_bee_clip_lane_id_by_unit_id.clear()
	_bee_clip_collision_active_by_unit_id.clear()
	_bee_clip_collision_last_log_ms_by_unit_id.clear()
	_clear_swarm_nodes()
	_clear_unit_nodes()
	_clear_unit_multimesh_batches()
	_request_redraw()

func set_bee_clip_plane_override(unit_id: int, entrance_point_world: Vector2, travel_dir_world: Vector2) -> void:
	if unit_id <= 0:
		return
	var safe_dir: Vector2 = travel_dir_world
	if safe_dir.length_squared() <= 0.000001:
		safe_dir = Vector2.RIGHT
	else:
		safe_dir = safe_dir.normalized()
	_bee_clip_plane_override_by_unit_id[unit_id] = {
		"point": entrance_point_world,
		"dir": safe_dir
	}
	_bee_clip_entrance_world_by_unit_id[unit_id] = entrance_point_world
	_bee_clip_travel_dir_world_by_unit_id[unit_id] = safe_dir

func clear_bee_clip_plane_override(unit_id: int) -> void:
	if unit_id <= 0:
		return
	_bee_clip_plane_override_by_unit_id.erase(unit_id)
	_bee_clip_collision_active_by_unit_id.erase(unit_id)
	_bee_clip_collision_last_log_ms_by_unit_id.erase(unit_id)

func _bee_clip_plane_offset_for_unit(unit_id: int) -> float:
	if bool(_bee_clip_collision_active_by_unit_id.get(unit_id, false)):
		return bee_clip_collision_plane_offset_px
	return bee_clip_entrance_plane_offset_px

func _log_collision_clip_state(unit_id: int, stage: String, controller: RefCounted, node: Node2D, extra: Dictionary = {}) -> void:
	if not bee_clip_collision_debug_logs:
		return
	if unit_id <= 0 or controller == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	var throttle_ms: int = maxi(1, bee_clip_collision_debug_throttle_ms)
	var last_ms: int = int(_bee_clip_collision_last_log_ms_by_unit_id.get(unit_id, 0))
	if stage != "prime" and now_ms - last_ms < throttle_ms:
		return
	_bee_clip_collision_last_log_ms_by_unit_id[unit_id] = now_ms
	var payload: Dictionary = {
		"unit_id": unit_id,
		"stage": stage,
		"lane_id": int(_bee_clip_lane_id_by_unit_id.get(unit_id, -1)),
		"cut": float(controller.get("cut_value")),
		"distance_to_plane_px": float(controller.get("distance_to_plane_px")),
		"penetration_px": float(controller.get("penetration_px")),
		"lead_px": bee_clip_collision_lead_px,
		"plane_offset_px": _bee_clip_plane_offset_for_unit(unit_id),
		"first_contact_snap": bee_clip_collision_snap_on_prime,
		"first_contact_cut_max": bee_clip_collision_first_contact_cut_max,
		"prime_nose_bias_px": bee_clip_collision_prime_nose_bias_px,
		"collision_active": bool(_bee_clip_collision_active_by_unit_id.get(unit_id, false)),
		"speed_px_s": float(_bee_clip_speed_px_s_by_unit_id.get(unit_id, 0.0)),
		"speed_cap_px_s": bee_clip_collision_missing_speed_cap_px_s
	}
	if node != null and is_instance_valid(node):
		payload["node_world"] = node.global_position
	for key_any in extra.keys():
		payload[key_any] = extra[key_any]
	SFLog.info("BEE_CLIP_COLLISION_DBG", payload)

func _on_sim_unit_collision(
	world_pos: Vector2,
	lane_dir: Vector2,
	_owner_a: int,
	_owner_b: int,
	lane_id: int,
	_intensity: float,
	unit_a_id: int = -1,
	unit_b_id: int = -1,
	unit_a_travel_dir: Vector2 = Vector2.ZERO,
	unit_b_travel_dir: Vector2 = Vector2.ZERO
) -> void:
	if not bee_clip_enabled:
		return
	var lane_norm: Vector2 = lane_dir
	if lane_norm.length_squared() <= 0.000001:
		lane_norm = Vector2.RIGHT
	else:
		lane_norm = lane_norm.normalized()
	var a_dir: Vector2 = unit_a_travel_dir if unit_a_travel_dir.length_squared() > 0.000001 else lane_norm
	var b_dir: Vector2 = unit_b_travel_dir if unit_b_travel_dir.length_squared() > 0.000001 else -lane_norm
	_prime_bee_collision_clip_override(unit_a_id, world_pos, a_dir, lane_id)
	_prime_bee_collision_clip_override(unit_b_id, world_pos, b_dir, lane_id)

func _prime_bee_collision_clip_override(unit_id: int, impact_world: Vector2, travel_dir_world: Vector2, lane_id: int) -> void:
	if unit_id <= 0:
		return
	var safe_dir: Vector2 = travel_dir_world
	if safe_dir.length_squared() <= 0.000001:
		safe_dir = Vector2.RIGHT
	else:
		safe_dir = safe_dir.normalized()
	var state_any: Variant = _unit_visual_by_id.get(unit_id, null)
	if typeof(state_any) == TYPE_DICTIONARY:
		var state: Dictionary = state_any as Dictionary
		var prev_pos_any: Variant = state.get("prev_pos", null)
		var curr_pos_any: Variant = state.get("curr_pos", null)
		if prev_pos_any is Vector2 and curr_pos_any is Vector2:
			var motion_local: Vector2 = (curr_pos_any as Vector2) - (prev_pos_any as Vector2)
			if motion_local.length_squared() > 0.000001:
				var motion_world: Vector2 = _to_world_dir(motion_local)
				if motion_world.length_squared() > 0.000001:
					safe_dir = motion_world.normalized()
	var node: Node2D = unit_nodes_by_id.get(unit_id, null)
	if node != null and is_instance_valid(node):
		var to_impact: Vector2 = impact_world - node.global_position
		if to_impact.length_squared() > 0.000001:
			var impact_dir: Vector2 = to_impact.normalized()
			var impact_ahead_px: float = to_impact.dot(safe_dir)
			# If impact is ahead and direction is badly off, retarget toward impact.
			# If impact is behind, keep motion-aligned direction to avoid late flips.
			if impact_ahead_px > 0.0 and safe_dir.dot(impact_dir) < 0.25:
				safe_dir = impact_dir
	var collision_plane_world: Vector2 = impact_world - (safe_dir * bee_clip_collision_lead_px)
	_bee_clip_collision_active_by_unit_id[unit_id] = true
	_bee_clip_lane_id_by_unit_id[unit_id] = lane_id
	_bee_clip_last_update_us_by_unit_id[unit_id] = Time.get_ticks_usec()
	if node == null or not is_instance_valid(node):
		return
	_bee_clip_last_world_pos_by_unit_id[unit_id] = node.global_position
	var sprite: Sprite2D = _ensure_unit_sprite(node)
	var controller: RefCounted = _ensure_bee_clip_controller(unit_id, sprite)
	if controller == null:
		return
	if controller.has_method("reset"):
		controller.call("reset")
	if controller.has_method("set_first_contact_snap"):
		controller.call("set_first_contact_snap", bee_clip_collision_snap_on_prime, bee_clip_collision_first_contact_cut_max)
	var visual_len_px: float = _compute_bee_visual_length_px_scaled(sprite, bee_clip_collision_length_scale)
	var nose_contact_offset_px: float = bee_clip_nose_offset_px + (visual_len_px * 0.5)
	if bee_clip_collision_prime_nose_bias_px > 0.0:
		var prime_nose_world: Vector2 = node.global_position + (safe_dir * nose_contact_offset_px)
		var min_plane_world: Vector2 = prime_nose_world - (safe_dir * bee_clip_collision_prime_nose_bias_px)
		if collision_plane_world.dot(safe_dir) > min_plane_world.dot(safe_dir):
			collision_plane_world = min_plane_world
	set_bee_clip_plane_override(unit_id, collision_plane_world, safe_dir)
	_bee_clip_visual_len_by_unit_id[unit_id] = visual_len_px
	var speed_px_s: float = _estimate_unit_visual_speed_px_s(unit_id)
	if speed_px_s <= 0.0:
		speed_px_s = bee_clip_missing_speed_fallback_px_s
	if bee_clip_collision_missing_speed_cap_px_s > 0.0:
		speed_px_s = minf(speed_px_s, bee_clip_collision_missing_speed_cap_px_s)
	_bee_clip_speed_px_s_by_unit_id[unit_id] = speed_px_s
	controller.call("set_plane", collision_plane_world, safe_dir)
	controller.call("set_visual_length_px", visual_len_px)
	controller.call(
		"update_from_world_position",
		node.global_position,
		nose_contact_offset_px,
		_bee_clip_plane_offset_for_unit(unit_id)
	)
	_log_collision_clip_state(unit_id, "prime", controller, node, {
		"impact_world": impact_world,
		"collision_plane_world": collision_plane_world,
		"travel_dir_world": safe_dir
	})

func set_bee_clip_shield_active(unit_id: int, active: bool) -> void:
	if unit_id <= 0:
		return
	var controller: RefCounted = _bee_clip_by_unit_id.get(unit_id, null) as RefCounted
	if controller != null and controller.has_method("set_shield_active"):
		controller.call("set_shield_active", active)

func get_bee_clip_state(unit_id: int) -> Dictionary:
	var state: Dictionary = {
		"distance_to_plane_px": 0.0,
		"penetration_px": 0.0,
		"entering_state": false,
		"precontact_3_5px": false,
		"cut": 0.0,
		"shield_active": false
	}
	if unit_id <= 0:
		return state
	var controller: RefCounted = _bee_clip_by_unit_id.get(unit_id, null) as RefCounted
	if controller == null:
		return state
	state["distance_to_plane_px"] = float(controller.get("distance_to_plane_px"))
	state["penetration_px"] = float(controller.get("penetration_px"))
	state["entering_state"] = bool(controller.get("entering_state"))
	state["precontact_3_5px"] = bool(controller.get("precontact_3_5px"))
	state["cut"] = float(controller.get("cut_value"))
	state["shield_active"] = bool(controller.get("shield_active"))
	return state

func _should_delay_prune_for_bee_clip(unit_id: int, missing_ticks: int) -> bool:
	if not bee_clip_enabled or not bee_clip_hold_missing_until_clipped:
		return false
	if unit_id <= 0:
		return false
	if missing_ticks <= 0:
		return false
	if missing_ticks > max(1, bee_clip_missing_hold_max_ticks):
		return false
	if bool(_bee_clip_collision_active_by_unit_id.get(unit_id, false)):
		var min_collision_hold_ticks: int = max(1, bee_clip_collision_min_hold_ticks)
		if missing_ticks < min_collision_hold_ticks:
			return true
	var controller: RefCounted = _bee_clip_by_unit_id.get(unit_id, null) as RefCounted
	if controller == null:
		return false
	var cut_value_now: float = float(controller.get("cut_value"))
	return cut_value_now < 0.995

func _sync_unit_records(units: Array) -> Dictionary:
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
	if not unit_nodes_by_id.is_empty():
		_clear_unit_nodes()
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
	profile["scan_us"] = int(Time.get_ticks_usec() - scan_t0_us)
	var prune_t0_us: int = Time.get_ticks_usec()
	for existing_id_any in _unit_data_by_id.keys():
		var existing_id: int = int(existing_id_any)
		if seen_ids.has(existing_id):
			continue
		_unit_data_by_id.erase(existing_id)
		_unit_missing_ticks.erase(existing_id)
		_unit_visual_by_id.erase(existing_id)
		_unit_samples_by_id.erase(existing_id)
		_unit_style_sig_by_id.erase(existing_id)
		_diag_visual_phase_by_id.erase(existing_id)
		_clear_bee_clip_state(existing_id)
		profile["prune_n"] = int(profile.get("prune_n", 0)) + 1
	profile["prune_us"] = int(Time.get_ticks_usec() - prune_t0_us)
	var model_count: int = units.size()
	if model_count != _last_model_units_count or _last_live_nodes_count != 0:
		_last_model_units_count = model_count
		_last_live_nodes_count = 0
		if SFLog.verbose_sim:
			SFLog.throttled_info("UNIT_RENDER_COUNTS", {
				"model_units": units.size(),
				"live_nodes": 0,
				"batch_mode": true
			}, 500)
	profile["total_us"] = int(Time.get_ticks_usec() - total_t0_us)
	return profile

func _update_unit_records_positions(units: Array) -> Dictionary:
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
	var endpoint_cache: Dictionary = _cached_lane_endpoints
	var hive_anchor_cache: Dictionary = _cached_hive_anchor_info
	var sample_sim_us: int = int(round(float(model.get("sim_time_s", 0.0)) * 1000000.0))
	var endpoint_t0_us: int = Time.get_ticks_usec()
	for unit_any in units:
		if typeof(unit_any) != TYPE_DICTIONARY:
			continue
		var ud: Dictionary = unit_any as Dictionary
		var unit_id: int = int(ud.get("id", -1))
		if unit_id <= 0:
			continue
		var owner_id: int = _unit_owner_id(ud, hive_by_id)
		_unit_style_sig_by_id[unit_id] = _unit_style_sig(owner_id)
		_ingest_unit_sample(ud, hive_by_id, unit_id, endpoint_cache, hive_anchor_cache, sample_sim_us)
	profile["endpoint_eval_us"] = int(Time.get_ticks_usec() - endpoint_t0_us)
	profile["total_us"] = int(Time.get_ticks_usec() - total_t0_us)
	return profile

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
			_reset_unit_hive_occlusion_depth(node)
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
		if _should_delay_prune_for_bee_clip(existing_id, missing_ticks):
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
	_unit_style_sig_by_id.clear()
	_bee_clip_by_unit_id.clear()
	_bee_clip_plane_override_by_unit_id.clear()
	_bee_clip_last_world_pos_by_unit_id.clear()
	_bee_clip_last_update_us_by_unit_id.clear()
	_bee_clip_travel_dir_world_by_unit_id.clear()
	_bee_clip_speed_px_s_by_unit_id.clear()
	_bee_clip_entrance_world_by_unit_id.clear()
	_bee_clip_visual_len_by_unit_id.clear()
	_bee_clip_to_hive_id_by_unit_id.clear()
	_bee_clip_lane_id_by_unit_id.clear()
	_bee_clip_collision_active_by_unit_id.clear()
	_bee_clip_collision_last_log_ms_by_unit_id.clear()

func _clear_unit_multimesh_batches() -> void:
	for key_any in _unit_multimesh_batches.keys():
		var batch: Dictionary = _unit_multimesh_batches[key_any] as Dictionary
		var node: Node = batch.get("node", null) as Node
		if node != null and is_instance_valid(node):
			node.queue_free()
	_unit_multimesh_batches.clear()

func _unit_style_global_sig() -> int:
	var draw_bit: int = 1 if debug_draw_units else 0
	var radius_bucket: int = int(round(debug_force_big_radius_px * 10.0))
	return draw_bit * 100000 + radius_bucket

func _unit_style_sig(owner_id: int) -> int:
	return owner_id * 1000000 + _unit_style_global_sig()

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
	var sample_sim_us: int = int(round(float(model.get("sim_time_s", 0.0)) * 1000000.0))
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
		var owner_id: int = _unit_owner_id(ud, hive_by_id)
		var style_sig: int = _unit_style_sig(owner_id)
		var last_style_sig: int = int(_unit_style_sig_by_id.get(unit_id, -2147483648))
		var needs_style_refresh: bool = last_style_sig != style_sig or sprite.texture == null
		if needs_style_refresh:
			_update_unit_sprite(node, ud, hive_by_id, registry, false, owner_id)
			_unit_style_sig_by_id[unit_id] = style_sig
		else:
			node.visible = true
			sprite.visible = not debug_draw_units
		_ingest_unit_sample(ud, hive_by_id, unit_id, endpoint_cache, hive_anchor_cache, sample_sim_us)
		var state_any: Variant = _unit_visual_by_id.get(unit_id, null)
		if typeof(state_any) == TYPE_DICTIONARY:
			var state: Dictionary = state_any as Dictionary
			if bool(state.get("just_spawned", false)) or bool(state.get("warm_spawned", false)):
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
	hive_anchor_cache: Variant = null,
	sample_sim_us: int = -1
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
	var sample_wall_us: int = Time.get_ticks_usec()
	if sample_sim_us < 0:
		sample_sim_us = int(round(float(model.get("sim_time_s", 0.0)) * 1000000.0))
	var sample_time_s: float = float(sample_sim_us) / 1000000.0
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
		"ts_us": sample_sim_us
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
		var arrive_source: String = str(ud.get("arrive_source", "")).strip_edges().to_lower()
		var warm_start: bool = arrive_source == "pass_through" and bool(endpoints.get("ok", false))
		var emergence_start: bool = not warm_start and bool(endpoints.get("ok", false))
		var prev_pos: Vector2 = sample_pos
		var prev_t: float = target_t
		var prev_sim_us: int = sample_sim_us
		var prev_wall_us: int = sample_wall_us
		if warm_start or emergence_start:
			var warm_px: float = PASS_THROUGH_VISUAL_WARM_PX if warm_start else UNIT_SPAWN_VISUAL_WARM_PX
			prev_pos = sample_pos - (sample_dir_norm * warm_px)
			var lane_len_px: float = maxf(1.0, a_pos.distance_to(b_pos))
			var warm_t_step: float = minf(0.20, warm_px / lane_len_px)
			prev_t = clampf(target_t - (float(_unit_travel_sign(ud)) * warm_t_step), 0.0, 1.0)
			var warm_us: int = int(round(maxf(0.001, sim_dt_sec) * 1000000.0))
			prev_sim_us = sample_sim_us - warm_us
			prev_wall_us = sample_wall_us - warm_us
		entry["prev_pos"] = prev_pos
		entry["curr_pos"] = sample_pos
		entry["prev_t"] = prev_t
		entry["curr_t"] = target_t
		entry["prev_time_us"] = prev_sim_us
		entry["curr_time_us"] = sample_sim_us
		entry["prev_sim_us"] = prev_sim_us
		entry["curr_sim_us"] = sample_sim_us
		entry["prev_wall_us"] = prev_wall_us
		entry["curr_wall_us"] = sample_wall_us
		entry["prev_rot"] = sample_rot
		entry["curr_rot"] = sample_rot
		entry["render_pos"] = sample_pos
		entry["spawn_wall_us"] = sample_wall_us
		entry["spawn_sim_us"] = sample_sim_us
		entry["just_spawned"] = false
		entry["warm_spawned"] = warm_start or emergence_start
	else:
		var curr_pos: Vector2 = entry.get("curr_pos", sample_pos)
		entry["prev_pos"] = curr_pos
		entry["curr_pos"] = sample_pos
		var curr_t: float = float(entry.get("curr_t", target_t))
		entry["prev_t"] = curr_t
		entry["curr_t"] = target_t
		var curr_time_us: int = int(entry.get("curr_time_us", sample_sim_us))
		entry["prev_time_us"] = curr_time_us
		entry["curr_time_us"] = sample_sim_us
		var curr_sim_us: int = int(entry.get("curr_sim_us", sample_sim_us))
		entry["prev_sim_us"] = curr_sim_us
		entry["curr_sim_us"] = sample_sim_us
		var curr_wall_us: int = int(entry.get("curr_wall_us", sample_wall_us))
		entry["prev_wall_us"] = curr_wall_us
		entry["curr_wall_us"] = sample_wall_us
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
		var base_pos: Vector2 = a_pos.lerp(b_pos, t)
		var normal: Vector2 = _unit_visual_normal_from_endpoints(endpoints, a_pos, b_pos)
		return EdgeVisual.unit_point(base_pos, normal)
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

func _target_hive_boundary_world(to_hive_id: int, hive_by_id: Dictionary, travel_dir_world: Vector2) -> Variant:
	if to_hive_id <= 0:
		return null
	var dir: Vector2 = travel_dir_world
	if dir.length_squared() <= 0.000001:
		return null
	dir = dir.normalized()
	return _hive_shell_contact_world(to_hive_id, hive_by_id, -dir)

func _hive_shell_contact_world(hive_id: int, hive_by_id: Dictionary, outward_dir: Vector2) -> Variant:
	if hive_id <= 0:
		return null
	var center_any: Variant = _hive_world_pos(hive_id, hive_by_id)
	if not (center_any is Vector2):
		return null
	var center_world: Vector2 = center_any as Vector2
	var radius_px: float = _target_hive_radius_px(hive_id, hive_by_id)
	return HiveNodeScript.lane_shell_anchor_world(center_world, outward_dir, radius_px)

func _hive_shell_contact_local(hive_id: int, hive_by_id: Dictionary, outward_dir: Vector2) -> Variant:
	var shell_world_v: Variant = _hive_shell_contact_world(hive_id, hive_by_id, outward_dir)
	if not (shell_world_v is Vector2):
		return null
	var shell_world: Vector2 = shell_world_v as Vector2
	if _unit_space == "global":
		return shell_world
	return to_local(shell_world)

func _target_hive_radius_px(to_hive_id: int, hive_by_id: Dictionary) -> float:
	var radius_px: float = 18.0
	var hive_data_any: Variant = hive_by_id.get(to_hive_id, null)
	if typeof(hive_data_any) == TYPE_DICTIONARY:
		var hive_data: Dictionary = hive_data_any as Dictionary
		var radius_data_any: Variant = hive_data.get("radius_px", hive_data.get("radius", null))
		if typeof(radius_data_any) == TYPE_FLOAT or typeof(radius_data_any) == TYPE_INT:
			var radius_data: float = float(radius_data_any)
			if radius_data > 0.0:
				radius_px = radius_data
	var hive_node_any: Variant = hive_nodes_by_id.get(to_hive_id, null)
	if hive_node_any is Node:
		var hive_node: Node = hive_node_any as Node
		if hive_node != null and is_instance_valid(hive_node):
			var radius_any: Variant = hive_node.get("radius_px")
			if typeof(radius_any) == TYPE_FLOAT or typeof(radius_any) == TYPE_INT:
				var resolved_radius: float = float(radius_any)
				if resolved_radius > 0.0:
					radius_px = resolved_radius
	return radius_px

func _is_rear_hive_approach(travel_dir_world: Vector2) -> bool:
	if travel_dir_world.length_squared() <= 0.000001:
		return false
	var dir: Vector2 = travel_dir_world.normalized()
	return dir.y < -HIVE_REAR_APPROACH_Y_MIN

func _is_back_hive_approach(travel_dir_world: Vector2) -> bool:
	if travel_dir_world.length_squared() <= 0.000001:
		return false
	var dir: Vector2 = travel_dir_world.normalized()
	return dir.y > HIVE_REAR_APPROACH_Y_MIN

func _unit_source_hive_id(ud: Dictionary) -> int:
	var from_id: int = _resolve_id(ud.get("from_id", ud.get("from", ud.get("src_id", ud.get("source_id", -1)))))
	if from_id > 0:
		return from_id
	var sign: int = _unit_travel_sign(ud)
	if sign >= 0:
		return int(ud.get("a_id", -1))
	return int(ud.get("b_id", -1))

func _unit_target_hive_id(ud: Dictionary) -> int:
	var to_id: int = _resolve_id(ud.get("to_id", ud.get("to", ud.get("dst_id", ud.get("target_id", -1)))))
	if to_id > 0:
		return to_id
	var sign: int = _unit_travel_sign(ud)
	if sign >= 0:
		return int(ud.get("b_id", -1))
	return int(ud.get("a_id", -1))

func _reset_unit_hive_occlusion_depth(node: Node2D) -> void:
	if node == null:
		return
	node.z_as_relative = true
	node.z_index = HIVE_UNIT_DEFAULT_Z_INDEX

func _set_unit_hive_occlusion_depth(node: Node2D) -> void:
	if node == null:
		return
	node.z_as_relative = false
	node.z_index = HIVE_REAR_OCCLUSION_Z_INDEX

func _unit_emergence_reveal(ud: Dictionary, hive_by_id: Dictionary, render_pos: Vector2, dir_local: Vector2) -> float:
	if not unit_emergence_enabled or ud.is_empty():
		return 1.0
	if _unit_hive_occlusion_active(ud, hive_by_id, render_pos, dir_local):
		return 1.0
	if str(ud.get("arrive_source", "")).strip_edges().to_lower() == "pass_through":
		return 1.0
	var source_hive_id: int = _unit_source_hive_id(ud)
	if source_hive_id <= 0:
		return 1.0
	var travel_dir_world: Vector2 = _to_world_dir(dir_local)
	if travel_dir_world.length_squared() <= 0.000001:
		return 1.0
	travel_dir_world = travel_dir_world.normalized()
	var source_boundary_v: Variant = _hive_shell_contact_world(source_hive_id, hive_by_id, travel_dir_world)
	if not (source_boundary_v is Vector2):
		return 1.0
	var render_world: Vector2 = _to_world_pos(render_pos)
	var source_boundary_world: Vector2 = source_boundary_v as Vector2
	var traveled_from_shell_px: float = (render_world - source_boundary_world).dot(travel_dir_world)
	var distance_t: float = clampf(traveled_from_shell_px / maxf(1.0, UNIT_EMERGENCE_DISTANCE_PX), 0.0, 1.0)
	var distance_reveal: float = distance_t * distance_t * (3.0 - (2.0 * distance_t))
	var time_reveal: float = 1.0
	var unit_id: int = int(ud.get("id", -1))
	if unit_id > 0:
		var state_any: Variant = _unit_visual_by_id.get(unit_id, null)
		if typeof(state_any) == TYPE_DICTIONARY:
			var state: Dictionary = state_any as Dictionary
			var spawn_wall_us: int = int(state.get("spawn_wall_us", 0))
			if spawn_wall_us > 0:
				var elapsed_us: int = maxi(0, Time.get_ticks_usec() - spawn_wall_us - UNIT_EMERGENCE_HOLD_US)
				var time_t: float = clampf(float(elapsed_us) / float(maxi(1, UNIT_EMERGENCE_DURATION_US)), 0.0, 1.0)
				time_reveal = time_t * time_t * (3.0 - (2.0 * time_t))
	return minf(distance_reveal, time_reveal)

func _unit_emergence_axis_scale(reveal: float) -> float:
	return lerpf(UNIT_EMERGENCE_MIN_AXIS_SCALE, 1.0, clampf(reveal, 0.0, 1.0))

func _apply_unit_emergence_visuals(node: Node2D, ud: Dictionary, hive_by_id: Dictionary, render_pos: Vector2, dir_local: Vector2) -> void:
	if node == null:
		return
	var reveal: float = _unit_emergence_reveal(ud, hive_by_id, render_pos, dir_local)
	var sprite: Sprite2D = node.get_node_or_null("UnitSprite") as Sprite2D
	var outline_sprite: Sprite2D = node.get_node_or_null("UnitOutlineSprite") as Sprite2D
	if sprite != null:
		sprite.scale = _sprite_base_scale(sprite, UNIT_BASE_SCALE_META)
		sprite.position = Vector2.ZERO
	if outline_sprite != null:
		outline_sprite.scale = _sprite_base_scale(outline_sprite, UNIT_OUTLINE_BASE_SCALE_META)
		outline_sprite.position = Vector2.ZERO
	var unit_id: int = int(node.get_meta("unit_id", -1))
	if unit_id <= 0:
		return
	var reveal_enabled: bool = reveal < UNIT_EMERGENCE_FULL_EPS
	var reveal_dir: Vector2 = _bee_clip_local_cut_dir()
	var controller: RefCounted = _bee_clip_by_unit_id.get(unit_id, null) as RefCounted
	if controller != null and controller.has_method("set_source_reveal"):
		controller.call("set_source_reveal", reveal_enabled, reveal, reveal_dir, UNIT_EMERGENCE_REVEAL_SOFTNESS)
	var outline_controller: RefCounted = _bee_clip_outline_by_unit_id.get(unit_id, null) as RefCounted
	if outline_controller != null and outline_controller.has_method("set_source_reveal"):
		outline_controller.call("set_source_reveal", reveal_enabled, reveal, reveal_dir, UNIT_EMERGENCE_REVEAL_SOFTNESS)

func _unit_hive_occlusion_active(ud: Dictionary, hive_by_id: Dictionary, render_pos: Vector2, dir_local: Vector2) -> bool:
	if not unit_emergence_enabled or ud.is_empty():
		return false
	var travel_dir_world: Vector2 = _to_world_dir(dir_local)
	if travel_dir_world.length_squared() <= 0.000001:
		return false
	travel_dir_world = travel_dir_world.normalized()
	var render_world: Vector2 = _to_world_pos(render_pos)
	if _is_rear_hive_approach(travel_dir_world):
		var source_hive_id: int = _unit_source_hive_id(ud)
		if source_hive_id <= 0:
			return false
		var source_boundary_v: Variant = _hive_shell_contact_world(source_hive_id, hive_by_id, travel_dir_world)
		if not (source_boundary_v is Vector2):
			return false
		var source_boundary_world: Vector2 = source_boundary_v as Vector2
		var traveled_from_source_px: float = (render_world - source_boundary_world).dot(travel_dir_world)
		return traveled_from_source_px <= UNIT_EMERGENCE_DISTANCE_PX
	if _is_back_hive_approach(travel_dir_world):
		var to_hive_id: int = _unit_target_hive_id(ud)
		if to_hive_id <= 0:
			return false
		var target_boundary_v: Variant = _target_hive_boundary_world(to_hive_id, hive_by_id, travel_dir_world)
		if not (target_boundary_v is Vector2):
			return false
		var target_boundary_world: Vector2 = target_boundary_v as Vector2
		var remaining_to_target_px: float = (target_boundary_world - render_world).dot(travel_dir_world)
		return remaining_to_target_px <= UNIT_EMERGENCE_DISTANCE_PX
	return false

func _unit_directional_hive_hide(ud: Dictionary, hive_by_id: Dictionary, render_pos: Vector2, dir_local: Vector2) -> bool:
	return false

func _apply_unit_directional_visibility(node: Node2D, ud: Dictionary, hive_by_id: Dictionary, render_pos: Vector2, dir_local: Vector2) -> void:
	if node == null:
		return
	var sprite: Sprite2D = node.get_node_or_null("UnitSprite") as Sprite2D
	if sprite != null:
		sprite.visible = not debug_draw_units
	var outline_sprite: Sprite2D = node.get_node_or_null("UnitOutlineSprite") as Sprite2D
	if outline_sprite != null:
		outline_sprite.visible = UNIT_OUTLINE_ENABLED and not debug_draw_units

func _update_target_hive_occlusion_depth(node: Node2D, ud: Dictionary, hive_by_id: Dictionary, travel_dir_world: Vector2) -> void:
	if node == null:
		return
	if travel_dir_world.length_squared() <= 0.000001:
		_reset_unit_hive_occlusion_depth(node)
		return
	var render_pos: Vector2 = node.global_position if _unit_space == "global" else to_local(node.global_position)
	if _unit_hive_occlusion_active(ud, hive_by_id, render_pos, _to_local_dir(travel_dir_world)):
		_set_unit_hive_occlusion_depth(node)
		return
	var to_hive_id: int = _unit_target_hive_id(ud)
	if to_hive_id <= 0:
		_reset_unit_hive_occlusion_depth(node)
		return
	var dir: Vector2 = travel_dir_world.normalized()
	var boundary_v: Variant = _target_hive_boundary_world(to_hive_id, hive_by_id, dir)
	if boundary_v is Vector2 and _is_back_hive_approach(dir):
		var boundary_world: Vector2 = boundary_v as Vector2
		var along_to_back_shell: float = (node.global_position - boundary_world).dot(dir)
		var has_reached_back_shell: bool = along_to_back_shell >= -HIVE_BACK_SHELL_OCCLUSION_ENTRY_PAD_PX
		if has_reached_back_shell:
			_set_unit_hive_occlusion_depth(node)
			return
	var source_hive_id: int = _unit_source_hive_id(ud)
	if source_hive_id > 0 and _is_rear_hive_approach(dir):
		var source_boundary_v: Variant = _hive_shell_contact_world(source_hive_id, hive_by_id, dir)
		if source_boundary_v is Vector2:
			var source_boundary_world: Vector2 = source_boundary_v as Vector2
			var along_from_source_shell: float = (node.global_position - source_boundary_world).dot(dir)
			var still_clearing_source_top: bool = along_from_source_shell <= HIVE_SOURCE_OCCLUSION_EXIT_PAD_PX
			if still_clearing_source_top:
				_set_unit_hive_occlusion_depth(node)
				return
	_reset_unit_hive_occlusion_depth(node)

func _unit_visual_normal_from_endpoints(endpoints: Dictionary, a_pos: Vector2, b_pos: Vector2) -> Vector2:
	var normal_any: Variant = endpoints.get("normal", Vector2.ZERO)
	if normal_any is Vector2:
		var normal: Vector2 = normal_any as Vector2
		if normal.length_squared() > 0.000001:
			return normal.normalized()
	var axis: Vector2 = b_pos - a_pos
	if axis.length_squared() > 0.000001:
		var dir: Vector2 = axis.normalized()
		return Vector2(-dir.y, dir.x)
	return Vector2.ZERO

func _unit_colorkey_params(sprite_key: String, owner_id: int, registry: SpriteRegistry) -> Dictionary:
	var ck_enabled: bool = sprite_key.begins_with("unit.")
	var ck_color: Color = Color(1.0, 1.0, 1.0, 1.0) if ck_enabled else _owner_color(owner_id)
	var ck_threshold: float = 0.12 if ck_enabled else 0.28
	var ck_softness: float = 0.06 if ck_enabled else 0.10
	if registry != null:
		var ck: Dictionary = registry.get_colorkey(sprite_key)
		if bool(ck.get("enabled", false)):
			ck_enabled = true
			var ck_color_any: Variant = ck.get("color", ck_color)
			if ck_color_any is Color:
				ck_color = ck_color_any as Color
			ck_threshold = float(ck.get("threshold", ck_threshold))
			ck_softness = float(ck.get("softness", ck_softness))
	return {
		"enabled": ck_enabled,
		"color": ck_color,
		"threshold": ck_threshold,
		"softness": ck_softness
	}

func _unit_path_endpoints_map_local(
	ud: Dictionary,
	hive_by_id: Dictionary,
	endpoint_cache: Variant = null,
	hive_anchor_cache: Variant = null
) -> Dictionary:
	var unit_id: int = int(ud.get("id", -1))
	var lane_id: int = _resolve_id(ud.get("lane_id", 0))
	var a_id: int = _resolve_id(ud.get("a_id", 0))
	var b_id: int = _resolve_id(ud.get("b_id", 0))
	var from_id: int = _unit_source_hive_id(ud)
	var to_id: int = _unit_target_hive_id(ud)
	# Sim uses canonical lane endpoints (a_id->b_id) and encodes travel direction in dir/t.
	# Rendering against from_id/to_id can invert one side and create "phantom" collisions.
	if a_id > 0 and b_id > 0:
		var ab_endpoints: Dictionary = _lane_endpoints_map_local_from_hive_ids(a_id, b_id, hive_by_id, unit_id, endpoint_cache, hive_anchor_cache, lane_id)
		if bool(ab_endpoints.get("ok", false)):
			return ab_endpoints
	if from_id > 0 and to_id > 0:
		var ft_endpoints: Dictionary = _lane_endpoints_map_local_from_hive_ids(from_id, to_id, hive_by_id, unit_id, endpoint_cache, hive_anchor_cache, lane_id)
		if bool(ft_endpoints.get("ok", false)):
			return ft_endpoints
	var lane_renderer_authoritative: bool = _lane_renderer != null and is_instance_valid(_lane_renderer) and _lane_renderer.has_method("get_lane_endpoints_world")
	if lane_renderer_authoritative and ((from_id > 0 and to_id > 0) or (a_id > 0 and b_id > 0)):
		return {"ok": false, "a": Vector2.ZERO, "b": Vector2.ZERO, "normal": Vector2.ZERO}
	var from_pos_v: Variant = ud.get("from_pos", null)
	var to_pos_v: Variant = ud.get("to_pos", null)
	if from_pos_v is Vector2 and to_pos_v is Vector2:
		var from_pos: Vector2 = from_pos_v as Vector2
		var to_pos: Vector2 = to_pos_v as Vector2
		if _should_apply_lane_cap_trim(ud):
			var trimmed: Dictionary = _lane_geometry_for_endpoints(from_pos, to_pos)
			var start_space: Vector2 = trimmed.get("start", from_pos)
			var end_space: Vector2 = trimmed.get("end", to_pos)
			SFLog.info("UNIT_EDGE_BIND", {
				"lane_key": "fallback_pos",
				"a": trimmed.get("a_world", _to_world_pos(from_pos)),
				"b": trimmed.get("b_world", _to_world_pos(to_pos)),
				"start": trimmed.get("start_world", _to_world_pos(start_space)),
				"end": trimmed.get("end_world", _to_world_pos(end_space)),
				"normal": trimmed.get("normal", Vector2.ZERO)
			}, "", 250)
			var trimmed_out: Dictionary = {
				"ok": true,
				"a": start_space,
				"b": end_space,
				"normal": trimmed.get("normal", Vector2.ZERO)
			}
			return _apply_hive_back_skin_unit_endpoints(trimmed_out, from_id, to_id, hive_by_id)
		var axis: Vector2 = to_pos - from_pos
		var normal: Vector2 = Vector2.ZERO
		if axis.length_squared() > 0.000001:
			var dir: Vector2 = axis.normalized()
			normal = Vector2(-dir.y, dir.x)
		var pos_out: Dictionary = {"ok": true, "a": from_pos, "b": to_pos, "normal": normal}
		return _apply_hive_back_skin_unit_endpoints(pos_out, from_id, to_id, hive_by_id)
	return {"ok": false, "a": Vector2.ZERO, "b": Vector2.ZERO}

func _edge_geo_from_cache(lane_id: int, from_id: int, to_id: int) -> Variant:
	var edge_any: Variant = null
	if lane_id > 0:
		edge_any = OpsState.get_edge_for_lane_key(lane_id)
		if edge_any == null:
			edge_any = OpsState.get_edge_for_lane_key(str(lane_id))
	if edge_any == null and from_id > 0 and to_id > 0:
		edge_any = OpsState.get_edge_for_lane_key("%d->%d" % [from_id, to_id])
	return edge_any

func _edge_geo_to_unit_endpoints_local(edge_any: Variant, from_id: int, to_id: int) -> Dictionary:
	var start_world: Vector2 = Vector2.ZERO
	var end_world: Vector2 = Vector2.ZERO
	var normal_world: Vector2 = Vector2.ZERO
	var src_id: int = -1
	var dst_id: int = -1
	if edge_any is EdgeGeometry:
		var edge: EdgeGeometry = edge_any as EdgeGeometry
		start_world = edge.start
		end_world = edge.end
		normal_world = edge.normal
		src_id = edge.src_id
		dst_id = edge.dst_id
	elif typeof(edge_any) == TYPE_DICTIONARY:
		var d: Dictionary = edge_any as Dictionary
		start_world = d.get("start", d.get("a", Vector2.ZERO))
		end_world = d.get("end", d.get("b", Vector2.ZERO))
		normal_world = d.get("normal", Vector2.ZERO)
		src_id = int(d.get("src_id", -1))
		dst_id = int(d.get("dst_id", -1))
	else:
		return {"ok": false}
	if from_id > 0 and to_id > 0 and src_id == to_id and dst_id == from_id:
		var swap: Vector2 = start_world
		start_world = end_world
		end_world = swap
		normal_world = -normal_world
	var trimmed: Dictionary = EdgeEndpoints.compute(start_world, end_world, EdgeEndpoints.EDGE_TUCK_PX)
	start_world = trimmed.get("start", start_world)
	end_world = trimmed.get("end", end_world)
	var start_local: Vector2 = start_world
	var end_local: Vector2 = end_world
	if _unit_space != "global":
		start_local = to_local(start_world)
		end_local = to_local(end_world)
	return {
		"ok": true,
		"a": start_local,
		"b": end_local,
		"a_world": start_world,
		"b_world": end_world,
		"start_world": start_world,
		"end_world": end_world,
		"normal": normal_world
	}

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
		var center_offset: float = _grid_coord_render_offset()
		return Vector2((gx + center_offset) * cell_size, (gy + center_offset) * cell_size)
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

func _shared_hive_render_anchor_local(hive_id: int) -> Variant:
	if _lane_renderer == null or not is_instance_valid(_lane_renderer):
		return null
	if not _lane_renderer.has_method("get_hive_render_anchor_local"):
		return null
	var lane_local_any: Variant = _lane_renderer.call("get_hive_render_anchor_local", hive_id)
	if not (lane_local_any is Vector2):
		return null
	var lane_local: Vector2 = lane_local_any as Vector2
	if lane_local == Vector2.INF:
		return null
	if _lane_renderer is Node2D:
		var lane_node: Node2D = _lane_renderer as Node2D
		var anchor_global: Vector2 = lane_node.to_global(lane_local)
		if _unit_space == "global":
			return anchor_global
		return to_local(anchor_global)
	return lane_local

func _should_apply_lane_cap_trim(ud: Dictionary) -> bool:
	if int(ud.get("lane_id", 0)) > 0:
		return true
	var a_id: int = _resolve_id(ud.get("a_id", 0))
	var b_id: int = _resolve_id(ud.get("b_id", 0))
	return a_id > 0 and b_id > 0

func _lane_geometry_for_endpoints(a: Vector2, b: Vector2) -> Dictionary:
	var a_world: Vector2 = _to_world_pos(a)
	var b_world: Vector2 = _to_world_pos(b)
	var trimmed: Dictionary = EdgeEndpoints.compute(a_world, b_world, EdgeEndpoints.EDGE_TUCK_PX)
	var start_world: Vector2 = trimmed.get("start", a_world)
	var end_world: Vector2 = trimmed.get("end", b_world)
	var dir_world: Vector2 = trimmed.get("dir", Vector2.RIGHT)
	var delta_world: Vector2 = end_world - start_world
	var len_world: float = delta_world.length()
	var normal_world: Vector2 = Vector2.ZERO
	if dir_world.length_squared() > 0.000001:
		normal_world = Vector2(-dir_world.y, dir_world.x)
	var start: Vector2 = start_world
	var end: Vector2 = end_world
	if _unit_space != "global":
		start = to_local(start_world)
		end = to_local(end_world)
	return {
		"a_world": a_world,
		"b_world": b_world,
		"start_world": start_world,
		"end_world": end_world,
		"start": start,
		"end": end,
		"dir": dir_world,
		"normal": normal_world,
		"len": len_world
	}

func _apply_hive_back_skin_unit_endpoints(out_geo: Dictionary, from_id: int, to_id: int, hive_by_id: Dictionary) -> Dictionary:
	if not bool(out_geo.get("ok", false)):
		return out_geo
	if from_id <= 0 or to_id <= 0:
		return out_geo
	var a_local: Vector2 = out_geo.get("a", Vector2.ZERO)
	var b_local: Vector2 = out_geo.get("b", Vector2.ZERO)
	var lane_axis_world: Vector2 = _to_world_pos(b_local) - _to_world_pos(a_local)
	if lane_axis_world.length_squared() <= 0.000001:
		return out_geo
	lane_axis_world = lane_axis_world.normalized()
	var start_v: Variant = _hive_shell_contact_local(from_id, hive_by_id, lane_axis_world)
	var end_v: Variant = _hive_shell_contact_local(to_id, hive_by_id, -lane_axis_world)
	if not (start_v is Vector2) or not (end_v is Vector2):
		return out_geo
	var start_local: Vector2 = start_v as Vector2
	var end_local: Vector2 = end_v as Vector2
	var adjusted_axis: Vector2 = end_local - start_local
	if adjusted_axis.length_squared() <= 0.000001:
		return out_geo
	var adjusted_dir: Vector2 = adjusted_axis.normalized()
	out_geo["a"] = start_local
	out_geo["b"] = end_local
	out_geo["a_world"] = _to_world_pos(start_local)
	out_geo["b_world"] = _to_world_pos(end_local)
	out_geo["start_world"] = out_geo["a_world"]
	out_geo["end_world"] = out_geo["b_world"]
	out_geo["normal"] = Vector2(-adjusted_dir.y, adjusted_dir.x)
	out_geo["_unit_shell_endpoints"] = true
	return out_geo

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
	var source: String = ""
	var shared_anchor_v: Variant = _shared_hive_render_anchor_local(hive_id)
	if shared_anchor_v is Vector2:
		fallback_unit_local = shared_anchor_v as Vector2
		has_anchor = true
		source = "shared_anchor"
	else:
		var center_world_v: Variant = _hive_center_world_pos(hive_id, hive_by_id)
		if center_world_v is Vector2:
			var center_world: Vector2 = center_world_v as Vector2
			fallback_unit_local = _lane_anchor_local_from_center_world(center_world)
			has_anchor = true
			source = "center_world"
		else:
			var center_local_v: Variant = _hive_center_map_local(hive_id, hive_by_id)
			if center_local_v is Vector2:
				fallback_unit_local = center_local_v as Vector2
				has_anchor = true
				source = "center_map_local"
	var lane_anchor_local: Vector2 = fallback_unit_local
	var unit_anchor_local: Vector2 = fallback_unit_local
	var out: Dictionary = {
		"ok": has_anchor,
		"lane_local": lane_anchor_local,
		"unit_local": unit_anchor_local,
		"source": source
	}
	cache[hive_id] = out
	return out

func _lane_cache_key(lane_id: int, from_id: int, to_id: int) -> String:
	return "%d|%d>%d" % [lane_id, from_id, to_id]

func _endpoint_cache_sig() -> int:
	if _last_lane_sig >= 0:
		return _last_lane_sig
	return int(int(OpsState.edge_cache_version) * 131 + int(_hive_bind_version))

func _get_authoritative_endpoints_world(lane_id: int, from_id: int, to_id: int) -> Dictionary:
	if _lane_renderer == null or not is_instance_valid(_lane_renderer):
		return {"ok": false}
	if not _lane_renderer.has_method("get_lane_endpoints_world"):
		return {"ok": false}
	var d_any: Variant = _lane_renderer.call("get_lane_endpoints_world", lane_id, from_id, to_id)
	if typeof(d_any) != TYPE_DICTIONARY:
		return {"ok": false}
	return d_any as Dictionary

func _lane_endpoints_map_local_from_hive_ids(
	from_id: int,
	to_id: int,
	hive_by_id: Dictionary,
	unit_id: int = -1,
	endpoint_cache: Variant = null,
	hive_anchor_cache: Variant = null,
	lane_id: int = -1
) -> Dictionary:
	var endpoint_t0_us: int = Time.get_ticks_usec()
	var endpoint_cache_dict: Dictionary = _cached_lane_endpoints
	if typeof(endpoint_cache) == TYPE_DICTIONARY:
		endpoint_cache_dict = endpoint_cache as Dictionary
	var key: String = _lane_cache_key(lane_id, from_id, to_id)
	var sig: int = _endpoint_cache_sig()
	var lane_renderer_valid: bool = _lane_renderer != null and is_instance_valid(_lane_renderer)
	var lane_renderer_has_get_lane_endpoints_world: bool = lane_renderer_valid and _lane_renderer.has_method("get_lane_endpoints_world")
	var lane_renderer_has_get_edge_geo: bool = lane_renderer_valid and _lane_renderer.has_method("get_edge_geo")
	if endpoint_cache_dict.has(key):
		var cached_any: Variant = endpoint_cache_dict.get(key, null)
		if typeof(cached_any) == TYPE_DICTIONARY:
			var cached: Dictionary = cached_any as Dictionary
			var cached_sig: int = int(cached.get("sig", -1))
			if cached_sig == sig:
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
				if UNIT_ENDPOINT_PROFILE_CACHE_HITS:
					var eval_ms_hit: float = _us_to_ms(int(Time.get_ticks_usec() - endpoint_t0_us))
					var hit_spike: bool = eval_ms_hit > 10.0
					_endpoint_perf_record(eval_ms_hit, true, hit_spike)
				return cached
	var from_info: Dictionary = _resolve_hive_lane_anchor_info(from_id, hive_by_id, hive_anchor_cache)
	var to_info: Dictionary = _resolve_hive_lane_anchor_info(to_id, hive_by_id, hive_anchor_cache)
	if not bool(from_info.get("ok", false)) or not bool(to_info.get("ok", false)):
		var miss: Dictionary = {
			"ok": false,
			"a": Vector2.ZERO,
			"b": Vector2.ZERO,
			"normal": Vector2.ZERO,
			"sig": sig,
			"_branch": "anchor_missing",
			"_edge_geo_source": "none",
			"_fallback_used": false,
			"_fallback_path": "",
			"_shared_anchor_used": false
		}
		endpoint_cache_dict[key] = miss
		var eval_ms_miss: float = _us_to_ms(int(Time.get_ticks_usec() - endpoint_t0_us))
		var trace_miss: Dictionary = {
			"unit_id": unit_id,
			"lane_id": lane_id,
			"from_id": from_id,
			"to_id": to_id,
			"lane_key": key,
			"cache_hit": false,
			"edge_geo_cache": "none",
			"lane_renderer_valid": lane_renderer_valid,
			"lane_renderer_has_get_lane_endpoints_world": lane_renderer_has_get_lane_endpoints_world,
			"lane_renderer_has_get_edge_geo": lane_renderer_has_get_edge_geo,
			"shared_anchor_used": false,
			"fallback_used": false,
			"fallback_path": "",
			"branch": "anchor_missing",
			"scene_scan_count": 0,
			"scene_scan_ms": 0.0
		}
		_last_endpoint_trace = trace_miss
		var miss_spike: bool = eval_ms_miss > 10.0
		_endpoint_perf_record(eval_ms_miss, false, miss_spike)
		if miss_spike:
			_maybe_log_endpoint_spike(trace_miss, eval_ms_miss, 0.0)
		return miss
	var from_unit_local: Vector2 = from_info.get("unit_local", Vector2.ZERO)
	var to_unit_local: Vector2 = to_info.get("unit_local", Vector2.ZERO)
	var shared_anchor_used: bool = str(from_info.get("source", "")) == "shared_anchor" and str(to_info.get("source", "")) == "shared_anchor"

	if lane_renderer_has_get_lane_endpoints_world:
		var auth: Dictionary = _get_authoritative_endpoints_world(lane_id, from_id, to_id)
		if bool(auth.get("ok", false)):
			var start_world: Vector2 = auth.get("start_world", Vector2.ZERO)
			var end_world: Vector2 = auth.get("end_world", Vector2.ZERO)
			var start_local: Vector2 = start_world
			var end_local: Vector2 = end_world
			if _unit_space != "global":
				start_local = to_local(start_world)
				end_local = to_local(end_world)
			var normal: Vector2 = auth.get("normal", Vector2.ZERO)
			if normal.length_squared() <= 0.000001:
				var axis: Vector2 = end_local - start_local
				if axis.length_squared() > 0.000001:
					var dir: Vector2 = axis.normalized()
					normal = Vector2(-dir.y, dir.x)
			var edge_source: String = str(auth.get("source", "compute"))
			var branch_ok: String = "lane_authoritative_%s/%s" % [edge_source, "shared_anchor" if shared_anchor_used else "fallback_anchor"]
			var out_geo: Dictionary = {
				"ok": true,
				"a": start_local,
				"b": end_local,
				"normal": normal,
				"from_lane_local": from_info.get("lane_local", from_unit_local),
				"to_lane_local": to_info.get("lane_local", to_unit_local),
				"sig": sig,
				"_branch": branch_ok,
				"_edge_geo_source": edge_source,
				"_fallback_used": false,
				"_fallback_path": "",
				"_shared_anchor_used": shared_anchor_used
			}
			out_geo = _apply_hive_back_skin_unit_endpoints(out_geo, from_id, to_id, hive_by_id)
			endpoint_cache_dict[key] = out_geo
			_maybe_log_unit_baseline_audit(
				unit_id,
				from_id,
				to_id,
				out_geo.get("from_lane_local", from_unit_local),
				out_geo.get("to_lane_local", to_unit_local),
				start_local,
				end_local
			)
			SFLog.info("UNIT_EDGE_BIND", {
				"lane_key": key,
				"start": start_world,
				"end": end_world,
				"normal": normal
			}, "", 250)
			var eval_ms_ok: float = _us_to_ms(int(Time.get_ticks_usec() - endpoint_t0_us))
			var trace_ok: Dictionary = {
				"unit_id": unit_id,
				"lane_id": lane_id,
				"from_id": from_id,
				"to_id": to_id,
				"lane_key": key,
				"cache_hit": false,
				"edge_geo_cache": edge_source,
				"lane_renderer_valid": lane_renderer_valid,
				"lane_renderer_has_get_lane_endpoints_world": lane_renderer_has_get_lane_endpoints_world,
				"lane_renderer_has_get_edge_geo": lane_renderer_has_get_edge_geo,
				"shared_anchor_used": shared_anchor_used,
				"fallback_used": false,
				"fallback_path": "",
				"branch": branch_ok,
				"scene_scan_count": 0,
				"scene_scan_ms": 0.0
			}
			_last_endpoint_trace = trace_ok
			var ok_spike: bool = eval_ms_ok > 10.0
			_endpoint_perf_record(eval_ms_ok, false, ok_spike)
			if ok_spike:
				_maybe_log_endpoint_spike(trace_ok, eval_ms_ok, 0.0)
			return out_geo
		var auth_fail: Dictionary = {
			"ok": false,
			"a": Vector2.ZERO,
			"b": Vector2.ZERO,
			"normal": Vector2.ZERO,
			"sig": sig,
			"_branch": "lane_authoritative_fail/%s" % ("shared_anchor" if shared_anchor_used else "fallback_anchor"),
			"_edge_geo_source": "fail",
			"_fallback_used": false,
			"_fallback_path": "",
			"_shared_anchor_used": shared_anchor_used
		}
		endpoint_cache_dict[key] = auth_fail
		var eval_ms_fail: float = _us_to_ms(int(Time.get_ticks_usec() - endpoint_t0_us))
		var trace_fail: Dictionary = {
			"unit_id": unit_id,
			"lane_id": lane_id,
			"from_id": from_id,
			"to_id": to_id,
			"lane_key": key,
			"cache_hit": false,
			"edge_geo_cache": "fail",
			"lane_renderer_valid": lane_renderer_valid,
			"lane_renderer_has_get_lane_endpoints_world": lane_renderer_has_get_lane_endpoints_world,
			"lane_renderer_has_get_edge_geo": lane_renderer_has_get_edge_geo,
			"shared_anchor_used": shared_anchor_used,
			"fallback_used": false,
			"fallback_path": "",
			"branch": str(auth_fail.get("_branch", "")),
			"scene_scan_count": 0,
			"scene_scan_ms": 0.0
		}
		_last_endpoint_trace = trace_fail
		var fail_spike: bool = eval_ms_fail > 10.0
		_endpoint_perf_record(eval_ms_fail, false, fail_spike)
		if fail_spike:
			_maybe_log_endpoint_spike(trace_fail, eval_ms_fail, 0.0)
		return auth_fail

	var fallback_geo: Dictionary = _lane_geometry_for_endpoints(from_unit_local, to_unit_local)
	var start_fallback: Vector2 = fallback_geo.get("start", from_unit_local)
	var end_fallback: Vector2 = fallback_geo.get("end", to_unit_local)
	var fallback_path: String = "%s>%s" % [str(from_info.get("source", "")), str(to_info.get("source", ""))]
	SFLog.info("UNIT_EDGE_BIND", {
		"lane_key": key,
		"a": fallback_geo.get("a_world", _to_world_pos(from_unit_local)),
		"b": fallback_geo.get("b_world", _to_world_pos(to_unit_local)),
		"start": fallback_geo.get("start_world", _to_world_pos(start_fallback)),
		"end": fallback_geo.get("end_world", _to_world_pos(end_fallback)),
		"normal": fallback_geo.get("normal", Vector2.ZERO)
	}, "", 250)
	var out_fallback: Dictionary = {
		"ok": true,
		"a": start_fallback,
		"b": end_fallback,
		"normal": fallback_geo.get("normal", Vector2.ZERO),
		"from_lane_local": from_info.get("lane_local", from_unit_local),
		"to_lane_local": to_info.get("lane_local", to_unit_local),
		"sig": sig,
		"_branch": "no_lane_renderer/fallback_%s" % fallback_path,
		"_edge_geo_source": "none",
		"_fallback_used": true,
		"_fallback_path": fallback_path,
		"_shared_anchor_used": shared_anchor_used
	}
	out_fallback = _apply_hive_back_skin_unit_endpoints(out_fallback, from_id, to_id, hive_by_id)
	endpoint_cache_dict[key] = out_fallback
	_maybe_log_unit_baseline_audit(
		unit_id,
		from_id,
		to_id,
		out_fallback.get("from_lane_local", from_unit_local),
		out_fallback.get("to_lane_local", to_unit_local),
		start_fallback,
		end_fallback
	)
	var eval_ms_fallback: float = _us_to_ms(int(Time.get_ticks_usec() - endpoint_t0_us))
	var trace_fallback: Dictionary = {
		"unit_id": unit_id,
		"lane_id": lane_id,
		"from_id": from_id,
		"to_id": to_id,
		"lane_key": key,
		"cache_hit": false,
		"edge_geo_cache": "none",
		"lane_renderer_valid": lane_renderer_valid,
		"lane_renderer_has_get_lane_endpoints_world": lane_renderer_has_get_lane_endpoints_world,
		"lane_renderer_has_get_edge_geo": lane_renderer_has_get_edge_geo,
		"shared_anchor_used": shared_anchor_used,
		"fallback_used": true,
		"fallback_path": fallback_path,
		"branch": str(out_fallback.get("_branch", "")),
		"scene_scan_count": 0,
		"scene_scan_ms": 0.0
	}
	_last_endpoint_trace = trace_fallback
	var fallback_spike: bool = eval_ms_fallback > 10.0
	_endpoint_perf_record(eval_ms_fallback, false, fallback_spike)
	if fallback_spike:
		_maybe_log_endpoint_spike(trace_fallback, eval_ms_fallback, 0.0)
	return out_fallback

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
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "UnitSprite"
		node.add_child(sprite)
	sprite.z_index = 0
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.position = Vector2.ZERO
	return sprite

func _ensure_unit_outline_sprite(node: Node2D) -> Sprite2D:
	var sprite: Sprite2D = node.get_node_or_null("UnitOutlineSprite") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "UnitOutlineSprite"
		node.add_child(sprite)
	sprite.z_index = -1
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.position = Vector2.ZERO
	return sprite

func _sprite_base_scale(sprite: Sprite2D, meta_key: StringName) -> Vector2:
	if sprite == null:
		return Vector2.ONE
	var base_any: Variant = sprite.get_meta(meta_key, null)
	if base_any is Vector2:
		return base_any as Vector2
	return sprite.scale

func _remember_unit_base_scales(sprite: Sprite2D, outline_sprite: Sprite2D) -> void:
	if sprite != null:
		sprite.set_meta(UNIT_BASE_SCALE_META, sprite.scale)
	if outline_sprite != null:
		outline_sprite.set_meta(UNIT_OUTLINE_BASE_SCALE_META, outline_sprite.scale)

func _reset_unit_emergence_visuals(node: Node2D) -> void:
	if node == null:
		return
	var sprite: Sprite2D = node.get_node_or_null("UnitSprite") as Sprite2D
	if sprite != null:
		sprite.scale = _sprite_base_scale(sprite, UNIT_BASE_SCALE_META)
		sprite.position = Vector2.ZERO
	var outline_sprite: Sprite2D = node.get_node_or_null("UnitOutlineSprite") as Sprite2D
	if outline_sprite != null:
		outline_sprite.scale = _sprite_base_scale(outline_sprite, UNIT_OUTLINE_BASE_SCALE_META)
		outline_sprite.position = Vector2.ZERO

func _bee_clip_local_cut_dir() -> Vector2:
	var base_dir: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(-UNIT_SPRITE_FORWARD_DEG))
	if bee_clip_flip_forward_axis:
		base_dir = -base_dir
	if base_dir.length_squared() <= 0.000001:
		return Vector2.RIGHT
	return base_dir.normalized()

func _compute_bee_visual_length_px(sprite: Sprite2D) -> float:
	return _compute_bee_visual_length_px_scaled(sprite, bee_clip_length_scale)

func _compute_bee_visual_length_px_scaled(sprite: Sprite2D, length_scale: float) -> float:
	if bee_clip_visual_length_px_override > 0.0:
		return bee_clip_visual_length_px_override
	if sprite == null or sprite.texture == null:
		return maxf(1.0, bee_clip_min_visual_length_px)
	var tex_width: float = float(sprite.texture.get_width())
	var tex_height: float = float(sprite.texture.get_height())
	var scale_x: float = absf(sprite.global_scale.x) / UNIT_VISUAL_SCALE_MULT
	var scale_y: float = absf(sprite.global_scale.y) / UNIT_VISUAL_SCALE_MULT
	if scale_x <= 0.000001:
		scale_x = 1.0
	if scale_y <= 0.000001:
		scale_y = 1.0
	var base_len: float = maxf(tex_width * scale_x, tex_height * scale_y)
	var scaled_len: float = base_len * maxf(0.1, length_scale)
	return maxf(1.0, maxf(bee_clip_min_visual_length_px, scaled_len))

func _ensure_bee_clip_controller_from_store(store: Dictionary, unit_id: int, sprite: Sprite2D, clip_shader: Shader) -> RefCounted:
	if unit_id <= 0 or sprite == null:
		return null
	var controller: RefCounted = store.get(unit_id, null) as RefCounted
	if controller == null:
		controller = BeeClipControllerScript.new()
		store[unit_id] = controller
	if controller != null and controller.has_method("configure_sprite"):
		controller.call("configure_sprite", sprite, clip_shader)
		controller.call("set_local_cut_dir", _bee_clip_local_cut_dir())
	return controller

func _ensure_bee_clip_controller(unit_id: int, sprite: Sprite2D) -> RefCounted:
	return _ensure_bee_clip_controller_from_store(_bee_clip_by_unit_id, unit_id, sprite, BEE_CLIP_SHADER)

func _ensure_bee_clip_outline_controller(unit_id: int, sprite: Sprite2D) -> RefCounted:
	return _ensure_bee_clip_controller_from_store(_bee_clip_outline_by_unit_id, unit_id, sprite, BEE_CLIP_SHADER)

func _update_bee_clip_for_unit(unit_id: int, node: Node2D, ud: Dictionary, hive_by_id: Dictionary) -> void:
	if not bee_clip_enabled:
		return
	if unit_id <= 0 or node == null:
		return
	var sprite: Sprite2D = _ensure_unit_sprite(node)
	var outline_sprite: Sprite2D = _ensure_unit_outline_sprite(node)
	var controller: RefCounted = _ensure_bee_clip_controller(unit_id, sprite)
	var outline_controller: RefCounted = _ensure_bee_clip_outline_controller(unit_id, outline_sprite)
	if controller == null or outline_controller == null:
		return
	var owner_id: int = _unit_owner_id(ud, hive_by_id)
	var registry: SpriteRegistry = _get_sprite_registry()
	var sprite_key: String = "unit.%s" % SpriteRegistry.owner_key(owner_id)
	var key_params: Dictionary = _unit_colorkey_params(sprite_key, owner_id, registry)
	var key_enabled: bool = false
	var key_color: Color = key_params.get("color", Color(0.0, 0.0, 0.0, 1.0))
	var key_threshold: float = float(key_params.get("threshold", 0.28))
	var key_softness: float = float(key_params.get("softness", 0.10))
	if controller.has_method("set_colorkey"):
		controller.call("set_colorkey", key_enabled, key_color, key_threshold, key_softness)
	if outline_controller.has_method("set_colorkey"):
		outline_controller.call("set_colorkey", key_enabled, key_color, key_threshold, key_softness)

	var entrance_point_world: Vector2 = Vector2.ZERO
	var travel_dir_world: Vector2 = Vector2.RIGHT
	var have_plane: bool = false
	var has_override_plane: bool = false
	var motion_dir_world: Vector2 = Vector2.ZERO
	var state_any: Variant = _unit_visual_by_id.get(unit_id, null)
	if typeof(state_any) == TYPE_DICTIONARY:
		var state: Dictionary = state_any as Dictionary
		var prev_pos_any: Variant = state.get("prev_pos", null)
		var curr_pos_any: Variant = state.get("curr_pos", null)
		if prev_pos_any is Vector2 and curr_pos_any is Vector2:
			var motion_local: Vector2 = (curr_pos_any as Vector2) - (prev_pos_any as Vector2)
			if motion_local.length_squared() > 0.000001:
				motion_dir_world = _to_world_dir(motion_local)
		if motion_dir_world.length_squared() <= 0.000001:
			var state_dir_any: Variant = state.get("dir", null)
			if state_dir_any is Vector2:
				var state_dir_local: Vector2 = state_dir_any as Vector2
				if state_dir_local.length_squared() > 0.000001:
					motion_dir_world = _to_world_dir(state_dir_local)
	var override_any: Variant = _bee_clip_plane_override_by_unit_id.get(unit_id, null)
	if typeof(override_any) == TYPE_DICTIONARY:
		var override_dict: Dictionary = override_any as Dictionary
		var point_any: Variant = override_dict.get("point", null)
		var dir_any: Variant = override_dict.get("dir", null)
		if point_any is Vector2 and dir_any is Vector2:
			entrance_point_world = point_any as Vector2
			travel_dir_world = dir_any as Vector2
			have_plane = travel_dir_world.length_squared() > 0.000001
			has_override_plane = have_plane

	if not have_plane:
		if motion_dir_world.length_squared() > 0.000001:
			travel_dir_world = motion_dir_world
		var sample_any: Variant = _unit_samples_by_id.get(unit_id, null)
		var a_world: Vector2 = Vector2.ZERO
		var b_world: Vector2 = Vector2.ZERO
		var have_endpoints: bool = false
		if typeof(sample_any) == TYPE_DICTIONARY:
			var sample_buf: Dictionary = sample_any as Dictionary
			var s1_any: Variant = sample_buf.get("s1", null)
			if typeof(s1_any) == TYPE_DICTIONARY:
				var s1: Dictionary = s1_any as Dictionary
				var a_any: Variant = s1.get("a", null)
				var b_any: Variant = s1.get("b", null)
				if a_any is Vector2 and b_any is Vector2:
					a_world = _to_world_pos(a_any as Vector2)
					b_world = _to_world_pos(b_any as Vector2)
					have_endpoints = true
		if not have_endpoints:
			var endpoints: Dictionary = _unit_path_endpoints_map_local(ud, hive_by_id, _cached_lane_endpoints, _cached_hive_anchor_info)
			if bool(endpoints.get("ok", false)):
				var a_local: Vector2 = endpoints.get("a", Vector2.ZERO)
				var b_local: Vector2 = endpoints.get("b", Vector2.ZERO)
				a_world = _to_world_pos(a_local)
				b_world = _to_world_pos(b_local)
				have_endpoints = true
		if have_endpoints:
			var lane_axis: Vector2 = b_world - a_world
			if lane_axis.length_squared() > 0.000001:
				var lane_axis_norm: Vector2 = lane_axis.normalized()
				if motion_dir_world.length_squared() > 0.000001:
					travel_dir_world = motion_dir_world
				else:
					var travel_sign: int = _unit_travel_sign(ud)
					if travel_sign == 0:
						travel_sign = 1
					travel_dir_world = lane_axis_norm * float(travel_sign)
				var target_dot_a: float = (a_world - node.global_position).dot(travel_dir_world)
				var target_dot_b: float = (b_world - node.global_position).dot(travel_dir_world)
				entrance_point_world = b_world if target_dot_b >= target_dot_a else a_world
				have_plane = true

	if not have_plane:
		if controller.has_method("reset"):
			controller.call("reset")
		if outline_controller.has_method("reset"):
			outline_controller.call("reset")
		_reset_unit_hive_occlusion_depth(node)
		return
	if not has_override_plane:
		var to_hive_id_for_plane: int = _unit_target_hive_id(ud)
		var boundary_plane_v: Variant = _target_hive_boundary_world(to_hive_id_for_plane, hive_by_id, travel_dir_world)
		if boundary_plane_v is Vector2:
			entrance_point_world = boundary_plane_v as Vector2
		_update_target_hive_occlusion_depth(node, ud, hive_by_id, travel_dir_world)
	else:
		_reset_unit_hive_occlusion_depth(node)

	var clip_length_scale: float = bee_clip_collision_length_scale if bool(_bee_clip_collision_active_by_unit_id.get(unit_id, false)) else bee_clip_length_scale
	var bee_length_px: float = _compute_bee_visual_length_px_scaled(sprite, clip_length_scale)
	var speed_px_s: float = _estimate_unit_visual_speed_px_s(unit_id)
	if speed_px_s <= 0.0:
		speed_px_s = bee_clip_missing_speed_fallback_px_s
	var nose_contact_offset_px: float = bee_clip_nose_offset_px + (bee_length_px * 0.5)
	_bee_clip_last_world_pos_by_unit_id[unit_id] = node.global_position
	_bee_clip_last_update_us_by_unit_id[unit_id] = Time.get_ticks_usec()
	_bee_clip_travel_dir_world_by_unit_id[unit_id] = travel_dir_world
	_bee_clip_speed_px_s_by_unit_id[unit_id] = speed_px_s
	_bee_clip_entrance_world_by_unit_id[unit_id] = entrance_point_world
	_bee_clip_visual_len_by_unit_id[unit_id] = bee_length_px
	_bee_clip_to_hive_id_by_unit_id[unit_id] = _unit_target_hive_id(ud)
	_bee_clip_lane_id_by_unit_id[unit_id] = int(ud.get("lane_id", -1))
	controller.call("set_plane", entrance_point_world, travel_dir_world)
	controller.call("set_visual_length_px", bee_length_px)
	outline_controller.call("set_plane", entrance_point_world, travel_dir_world)
	outline_controller.call("set_visual_length_px", bee_length_px)
	var cut_value_now: float = float(controller.call(
		"update_from_world_position",
		node.global_position,
		nose_contact_offset_px,
		_bee_clip_plane_offset_for_unit(unit_id)
	))
	outline_controller.call(
		"update_from_world_position",
		node.global_position,
		nose_contact_offset_px,
		_bee_clip_plane_offset_for_unit(unit_id)
	)
	if bool(_bee_clip_collision_active_by_unit_id.get(unit_id, false)):
		_log_collision_clip_state(unit_id, "live", controller, node, {
			"entrance_point_world": entrance_point_world,
			"travel_dir_world": travel_dir_world,
			"cut_value_now": cut_value_now
		})
	if bool(controller.call("consume_full_clip_transition")):
		var to_hive_id: int = _unit_target_hive_id(ud)
		var lane_id: int = int(ud.get("lane_id", -1))
		emit_signal("bee_clip_absorb_ready", unit_id, to_hive_id, lane_id, cut_value_now)
	if bee_clip_debug_logs:
		var now_ms: int = Time.get_ticks_msec()
		if _bee_clip_last_debug_log_ms <= 0 or now_ms - _bee_clip_last_debug_log_ms >= 200:
			_bee_clip_last_debug_log_ms = now_ms
			SFLog.info("BEE_CLIP_STATE", {
				"unit_id": unit_id,
				"distance_to_plane_px": float(controller.get("distance_to_plane_px")),
				"penetration_px": float(controller.get("penetration_px")),
				"entering_state": bool(controller.get("entering_state")),
				"precontact_3_5px": bool(controller.get("precontact_3_5px")),
				"cut": float(controller.get("cut_value"))
			})

func _estimate_unit_visual_speed_px_s(unit_id: int) -> float:
	var state_any: Variant = _unit_visual_by_id.get(unit_id, null)
	if typeof(state_any) != TYPE_DICTIONARY:
		return 0.0
	var state: Dictionary = state_any as Dictionary
	var prev_pos_any: Variant = state.get("prev_pos", null)
	var curr_pos_any: Variant = state.get("curr_pos", null)
	if not (prev_pos_any is Vector2 and curr_pos_any is Vector2):
		return 0.0
	var prev_pos_world: Vector2 = _to_world_pos(prev_pos_any as Vector2)
	var curr_pos_world: Vector2 = _to_world_pos(curr_pos_any as Vector2)
	var dist_px: float = prev_pos_world.distance_to(curr_pos_world)
	if dist_px <= 0.0001:
		return 0.0
	var prev_sim_us: int = int(state.get("prev_sim_us", state.get("prev_time_us", 0)))
	var curr_sim_us: int = int(state.get("curr_sim_us", state.get("curr_time_us", prev_sim_us)))
	var dt_us: int = curr_sim_us - prev_sim_us
	if dt_us <= 0:
		return 0.0
	var dt_s: float = float(dt_us) / 1000000.0
	if dt_s <= 0.000001:
		return 0.0
	return dist_px / dt_s

func _update_bee_clip_for_missing_unit(unit_id: int, node: Node2D, now_us: int) -> void:
	if not bee_clip_enabled:
		return
	var controller: RefCounted = _bee_clip_by_unit_id.get(unit_id, null) as RefCounted
	if controller == null:
		return
	var outline_controller: RefCounted = _bee_clip_outline_by_unit_id.get(unit_id, null) as RefCounted
	var dir_any: Variant = _bee_clip_travel_dir_world_by_unit_id.get(unit_id, null)
	if not (dir_any is Vector2):
		return
	var travel_dir_world: Vector2 = dir_any as Vector2
	if travel_dir_world.length_squared() <= 0.000001:
		return
	travel_dir_world = travel_dir_world.normalized()
	var last_pos_any: Variant = _bee_clip_last_world_pos_by_unit_id.get(unit_id, node.global_position)
	var world_pos: Vector2 = node.global_position
	if last_pos_any is Vector2:
		world_pos = last_pos_any as Vector2
	var last_us: int = int(_bee_clip_last_update_us_by_unit_id.get(unit_id, now_us))
	var dt_s: float = clampf(float(maxi(0, now_us - last_us)) / 1000000.0, 0.0, 0.05)
	var speed_px_s: float = float(_bee_clip_speed_px_s_by_unit_id.get(unit_id, bee_clip_missing_speed_fallback_px_s))
	if speed_px_s <= 0.0:
		speed_px_s = bee_clip_missing_speed_fallback_px_s
	world_pos += travel_dir_world * speed_px_s * dt_s
	_bee_clip_last_world_pos_by_unit_id[unit_id] = world_pos
	_bee_clip_last_update_us_by_unit_id[unit_id] = now_us
	node.global_position = world_pos
	var entrance_any: Variant = _bee_clip_entrance_world_by_unit_id.get(unit_id, null)
	if entrance_any is Vector2:
		controller.call("set_plane", entrance_any as Vector2, travel_dir_world)
		if outline_controller != null:
			outline_controller.call("set_plane", entrance_any as Vector2, travel_dir_world)
	var visual_len_px: float = float(_bee_clip_visual_len_by_unit_id.get(unit_id, bee_clip_min_visual_length_px))
	var nose_contact_offset_px: float = bee_clip_nose_offset_px + (visual_len_px * 0.5)
	controller.call("set_visual_length_px", visual_len_px)
	if outline_controller != null:
		outline_controller.call("set_visual_length_px", visual_len_px)
	var cut_value_now: float = float(controller.call(
		"update_from_world_position",
		world_pos,
		nose_contact_offset_px,
		_bee_clip_plane_offset_for_unit(unit_id)
	))
	if outline_controller != null:
		outline_controller.call(
			"update_from_world_position",
			world_pos,
			nose_contact_offset_px,
			_bee_clip_plane_offset_for_unit(unit_id)
		)
	if bool(_bee_clip_collision_active_by_unit_id.get(unit_id, false)):
		_log_collision_clip_state(unit_id, "missing", controller, node, {
			"world_pos": world_pos,
			"travel_dir_world": travel_dir_world,
			"cut_value_now": cut_value_now
		})
	if bool(controller.call("consume_full_clip_transition")):
		var to_hive_id: int = int(_bee_clip_to_hive_id_by_unit_id.get(unit_id, -1))
		var lane_id: int = int(_bee_clip_lane_id_by_unit_id.get(unit_id, -1))
		emit_signal("bee_clip_absorb_ready", unit_id, to_hive_id, lane_id, cut_value_now)

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
	apply_orientation: bool = true,
	owner_id_override: int = -1
) -> void:
	var owner_id: int = owner_id_override if owner_id_override >= 0 else _unit_owner_id(ud, hive_by_id)
	var unit_id := int(node.get_meta("unit_id", -1))
	var sprite := _ensure_unit_sprite(node)
	var outline_sprite: Sprite2D = _ensure_unit_outline_sprite(node)
	if sprite == null:
		return
	var tex: Texture2D = null
	var tex_path := ""
	var scale := 1.0
	var sprite_key := ""
	if registry != null:
		sprite_key = "unit.%s" % SpriteRegistry.owner_key(owner_id)
		tex = registry.get_tex(sprite_key)
		tex_path = registry.get_tex_path(sprite_key)
		scale = registry.get_scale(sprite_key)
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
		if outline_sprite != null:
			outline_sprite.visible = false
		return
	var resolved_path := tex.resource_path
	if resolved_path.is_empty():
		resolved_path = tex_path
	# Order: texture -> material -> self_modulate
	if sprite.texture == null or sprite.texture != tex:
		sprite.texture = tex
	var team_color: Color = _unit_modulate_color(owner_id)
	team_color.a = UNIT_COLOR.a
	if _color_changed(sprite.self_modulate, team_color):
		if AUDIT_RENDER:
			_audit_modulate_sets += 1
		sprite.self_modulate = team_color
	var key_params: Dictionary = _unit_colorkey_params(sprite_key, owner_id, registry)
	var needs_colorkey_material: bool = bool(key_params.get("enabled", false))
	var needs_neutral_recolor: bool = owner_id <= 0
	var has_resource_path: bool = not tex.resource_path.is_empty()
	if needs_neutral_recolor or has_resource_path or needs_colorkey_material:
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
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.position = Vector2.ZERO
	if outline_sprite != null:
		outline_sprite.centered = true
		outline_sprite.offset = Vector2.ZERO
		outline_sprite.position = Vector2.ZERO
		outline_sprite.texture = tex if UNIT_OUTLINE_ENABLED else null
		outline_sprite.material = null
		outline_sprite.self_modulate = UNIT_OUTLINE_COLOR if UNIT_OUTLINE_ENABLED else Color(1.0, 1.0, 1.0, 0.0)
	var tex_size := tex.get_size()
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		var size_px := debug_force_big_radius_px * 2.0 * scale * UNIT_RENDER_SCALE * UNIT_VISUAL_SCALE_MULT
		var sprite_scale: Vector2 = Vector2(size_px / tex_size.x, size_px / tex_size.y)
		sprite.scale = sprite_scale
		if outline_sprite != null:
			outline_sprite.scale = sprite_scale * UNIT_OUTLINE_SCALE_MULT if UNIT_OUTLINE_ENABLED else Vector2.ONE
		_remember_unit_base_scales(sprite, outline_sprite)
	if apply_orientation:
		var lane_id: int = int(ud.get("lane_id", 0))
		_apply_unit_orientation(node, sprite, ud, hive_by_id, unit_id, owner_id, lane_id)
	node.visible = true
	sprite.visible = not debug_draw_units
	if outline_sprite != null:
		outline_sprite.visible = UNIT_OUTLINE_ENABLED and not debug_draw_units

func _apply_debug_force_top_z() -> void:
	if debug_force_top_z == _last_force_top_z:
		return
	_last_force_top_z = debug_force_top_z
	if debug_force_top_z:
		z_as_relative = false
		z_index = 4095
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
	if _sim_events == null or not is_instance_valid(_sim_events):
		_try_bind_sim_events()
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
	var now_us: int = Time.get_ticks_usec()
	_render_units(now_us)

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
		var unit_data: Dictionary = {}
		if typeof(unit_any) == TYPE_DICTIONARY:
			var ud: Dictionary = unit_any as Dictionary
			unit_data = ud
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
		var visual_pos: Vector2 = start_pos.lerp(end_pos, phase)
		var normal_dir: Vector2 = Vector2.ZERO
		var axis: Vector2 = end_pos - start_pos
		if axis.length_squared() > 0.000001:
			var axis_dir: Vector2 = axis.normalized()
			normal_dir = Vector2(-axis_dir.y, axis_dir.x)
		node.position = EdgeVisual.unit_point(visual_pos, normal_dir)
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
		if not unit_data.is_empty():
			_update_bee_clip_for_unit(unit_id, node, unit_data, hive_by_id)

func _render_alpha_for_state(state: Dictionary, now_us: int, settle_active: bool = false) -> float:
	var prev_sim_us: int = int(state.get("prev_sim_us", state.get("prev_time_us", 0)))
	var curr_sim_us: int = int(state.get("curr_sim_us", state.get("curr_time_us", prev_sim_us)))
	if curr_sim_us <= prev_sim_us:
		return 1.0
	var interval_sim_us: int = curr_sim_us - prev_sim_us
	if interval_sim_us <= 0:
		return 1.0
	var curr_wall_us: int = int(state.get("curr_wall_us", now_us))
	var elapsed_wall_us: int = maxi(0, now_us - curr_wall_us)
	var interp_delay_us: int = int(maxf(0.0, BUTTER_INTERP_DELAY_TICKS) * float(interval_sim_us))
	var desired_sim_us: int = curr_sim_us + elapsed_wall_us - interp_delay_us
	if desired_sim_us <= prev_sim_us:
		return 0.0
	var alpha: float = float(desired_sim_us - prev_sim_us) / float(interval_sim_us)
	if alpha <= 1.0:
		return alpha
	var max_extrap_sec: float = _post_match_extrap_sec if settle_active else BUTTER_MAX_EXTRAP_SEC
	var max_extra_alpha: float = float(int(max_extrap_sec * 1000000.0)) / float(interval_sim_us)
	if max_extra_alpha <= 0.0:
		return 1.0
	return minf(alpha, 1.0 + max_extra_alpha)

func _render_settle_projected_pose(unit_id: int, state: Dictionary, alpha: float) -> Dictionary:
	var buf_any: Variant = _unit_samples_by_id.get(unit_id, null)
	if typeof(buf_any) != TYPE_DICTIONARY:
		return {"ok": false}
	var buf: Dictionary = buf_any as Dictionary
	var s0_any: Variant = buf.get("s0", null)
	var s1_any: Variant = buf.get("s1", null)
	if typeof(s0_any) != TYPE_DICTIONARY or typeof(s1_any) != TYPE_DICTIONARY:
		return {"ok": false}
	var s0: Dictionary = s0_any as Dictionary
	var s1: Dictionary = s1_any as Dictionary
	var a_pos_v: Variant = s1.get("a", null)
	var b_pos_v: Variant = s1.get("b", null)
	if not (a_pos_v is Vector2 and b_pos_v is Vector2):
		return {"ok": false}
	var a_pos: Vector2 = a_pos_v as Vector2
	var b_pos: Vector2 = b_pos_v as Vector2
	var prev_t: float = clampf(float(s0.get("t", state.get("prev_t", 0.0))), 0.0, 1.0)
	var curr_t: float = clampf(float(s1.get("t", state.get("curr_t", prev_t))), 0.0, 1.0)
	var projected_t: float = clampf(lerpf(prev_t, curr_t, alpha), 0.0, 1.0)
	var base_pos: Vector2 = a_pos.lerp(b_pos, projected_t)
	var axis: Vector2 = b_pos - a_pos
	var normal: Vector2 = Vector2.ZERO
	if axis.length_squared() > 0.000001:
		var axis_n: Vector2 = axis.normalized()
		normal = Vector2(-axis_n.y, axis_n.x)
	var render_pos: Vector2 = EdgeVisual.unit_point(base_pos, normal)
	var dir_vec: Vector2 = axis
	var dt_t: float = curr_t - prev_t
	if dir_vec.length_squared() > 0.000001:
		dir_vec = dir_vec.normalized()
		if dt_t < 0.0:
			dir_vec = -dir_vec
	else:
		var state_dir_any: Variant = state.get("dir", Vector2.RIGHT)
		if state_dir_any is Vector2:
			dir_vec = state_dir_any as Vector2
		if dir_vec.length_squared() <= 0.000001:
			dir_vec = Vector2.RIGHT
		else:
			dir_vec = dir_vec.normalized()
	var rot: float = dir_vec.angle() + deg_to_rad(UNIT_SPRITE_FORWARD_DEG)
	return {
		"ok": true,
		"pos": render_pos,
		"rot": rot
	}

func _unit_batch_key(owner_id: int, layer: String, outline: bool) -> String:
	return "%d|%s|%s" % [owner_id, layer, "outline" if outline else "fill"]

func _unit_batch_z_index(layer: String, outline: bool) -> int:
	var base_z: int = HIVE_REAR_OCCLUSION_Z_INDEX if layer == "rear" else HIVE_UNIT_DEFAULT_Z_INDEX
	return base_z - 1 if outline else base_z

func _unit_batch_texture(owner_id: int, registry: SpriteRegistry) -> Texture2D:
	if registry == null:
		return null
	var sprite_key: String = "unit.%s" % SpriteRegistry.owner_key(owner_id)
	var tex: Texture2D = registry.get_tex(sprite_key)
	if tex == null and sprite_key != "unit.neutral":
		tex = registry.get_tex("unit.neutral")
	return tex

func _unit_batch_scale(owner_id: int, registry: SpriteRegistry, tex: Texture2D, outline: bool) -> Vector2:
	if tex == null:
		return Vector2.ONE
	var sprite_key: String = "unit.%s" % SpriteRegistry.owner_key(owner_id)
	var sprite_scale: float = registry.get_scale(sprite_key) if registry != null else 1.0
	if sprite_scale <= 0.0:
		sprite_scale = 1.0
	var tex_size: Vector2 = tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Vector2.ONE
	var size_px: float = debug_force_big_radius_px * 2.0 * sprite_scale * UNIT_RENDER_SCALE * UNIT_VISUAL_SCALE_MULT
	var out: Vector2 = Vector2(size_px / tex_size.x, size_px / tex_size.y)
	if outline and UNIT_OUTLINE_ENABLED:
		out *= UNIT_OUTLINE_SCALE_MULT
	return out

func _unit_batch_material(owner_id: int, registry: SpriteRegistry, outline: bool) -> ShaderMaterial:
	if outline:
		return null
	var sprite_key: String = "unit.%s" % SpriteRegistry.owner_key(owner_id)
	return _get_unit_material(sprite_key, owner_id, registry)

func _ensure_unit_multimesh_batch(owner_id: int, layer: String, outline: bool, registry: SpriteRegistry) -> Dictionary:
	var key: String = _unit_batch_key(owner_id, layer, outline)
	var batch: Dictionary = {}
	var existing_any: Variant = _unit_multimesh_batches.get(key, null)
	if typeof(existing_any) == TYPE_DICTIONARY:
		batch = existing_any as Dictionary
	var node: MultiMeshInstance2D = batch.get("node", null) as MultiMeshInstance2D
	var mm: MultiMesh = batch.get("multimesh", null) as MultiMesh
	var created: bool = false
	if node == null or not is_instance_valid(node) or mm == null:
		node = MultiMeshInstance2D.new()
		node.name = "UnitBatch_%s_%s_%s" % [SpriteRegistry.owner_key(owner_id), layer, "outline" if outline else "fill"]
		node.z_as_relative = true
		add_child(node)
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.instance_count = 0
		node.multimesh = mm
		batch["node"] = node
		batch["multimesh"] = mm
		batch["capacity"] = 0
		batch["count"] = 0
		created = true
	var style_sig: int = _unit_style_sig(owner_id) * 10 + (1 if outline else 0)
	if created or int(batch.get("style_sig", -2147483648)) != style_sig or node.texture == null:
		var tex: Texture2D = _unit_batch_texture(owner_id, registry)
		node.texture = tex
		node.material = _unit_batch_material(owner_id, registry, outline)
		node.visible = tex != null
		batch["texture"] = tex
		batch["scale"] = _unit_batch_scale(owner_id, registry, tex, outline)
		batch["style_sig"] = style_sig
	node.z_as_relative = layer != "rear"
	node.z_index = _unit_batch_z_index(layer, outline)
	_unit_multimesh_batches[key] = batch
	return batch

func _ensure_unit_batch_capacity(batch: Dictionary, needed: int) -> void:
	var mm: MultiMesh = batch.get("multimesh", null) as MultiMesh
	if mm == null:
		return
	var capacity: int = int(batch.get("capacity", 0))
	if needed <= capacity:
		return
	var next_capacity: int = maxi(8, capacity)
	while next_capacity < needed:
		next_capacity *= 2
	mm.instance_count = next_capacity
	mm.visible_instance_count = int(batch.get("count", 0))
	batch["capacity"] = next_capacity

func _reset_unit_multimesh_counts() -> void:
	for key_any in _unit_multimesh_batches.keys():
		var batch: Dictionary = _unit_multimesh_batches[key_any] as Dictionary
		batch["count"] = 0
		var mm: MultiMesh = batch.get("multimesh", null) as MultiMesh
		if mm != null:
			mm.visible_instance_count = 0
		var node: MultiMeshInstance2D = batch.get("node", null) as MultiMeshInstance2D
		if node != null and is_instance_valid(node):
			node.visible = false

func _finalize_unit_multimesh_counts() -> void:
	for key_any in _unit_multimesh_batches.keys():
		var batch: Dictionary = _unit_multimesh_batches[key_any] as Dictionary
		var count: int = int(batch.get("count", 0))
		var mm: MultiMesh = batch.get("multimesh", null) as MultiMesh
		if mm != null:
			mm.visible_instance_count = count
		var node: MultiMeshInstance2D = batch.get("node", null) as MultiMeshInstance2D
		if node != null and is_instance_valid(node):
			node.visible = count > 0 and node.texture != null

func _submit_unit_multimesh_instance(
	owner_id: int,
	layer: String,
	pos: Vector2,
	rot: float,
	outline: bool,
	registry: SpriteRegistry,
	ud: Dictionary = {},
	hive_by_id: Dictionary = {},
	dir_local: Vector2 = Vector2.RIGHT
) -> void:
	var batch: Dictionary = _ensure_unit_multimesh_batch(owner_id, layer, outline, registry)
	var mm: MultiMesh = batch.get("multimesh", null) as MultiMesh
	var tex: Texture2D = batch.get("texture", null) as Texture2D
	if mm == null or tex == null:
		return
	var idx: int = int(batch.get("count", 0))
	_ensure_unit_batch_capacity(batch, idx + 1)
	var scale: Vector2 = batch.get("scale", Vector2.ONE)
	var adjusted_pos: Vector2 = pos
	var reveal: float = _unit_emergence_reveal(ud, hive_by_id, pos, dir_local)
	if reveal < UNIT_EMERGENCE_FULL_EPS:
		var axis_scale: float = _unit_emergence_axis_scale(reveal)
		var forward_local: Vector2 = _bee_clip_local_cut_dir()
		var dir_n: Vector2 = dir_local
		if dir_n.length_squared() <= 0.000001:
			dir_n = Vector2.RIGHT
		else:
			dir_n = dir_n.normalized()
		if absf(forward_local.x) > absf(forward_local.y):
			var half_len_x: float = float(tex.get_width()) * absf(scale.x) * 0.5
			scale.x *= axis_scale
			adjusted_pos += dir_n * half_len_x * (1.0 - axis_scale)
		else:
			var half_len_y: float = float(tex.get_height()) * absf(scale.y) * 0.5
			scale.y *= axis_scale
			adjusted_pos += dir_n * half_len_y * (1.0 - axis_scale)
	var tr: Transform2D = Transform2D(rot, adjusted_pos)
	tr.x *= scale.x
	tr.y *= scale.y
	mm.set_instance_transform_2d(idx, tr)
	var color: Color = UNIT_OUTLINE_COLOR if outline else _unit_modulate_color(owner_id)
	color.a = UNIT_OUTLINE_COLOR.a if outline else UNIT_COLOR.a
	mm.set_instance_color(idx, color)
	batch["count"] = idx + 1

func _unit_batch_layer(ud: Dictionary, hive_by_id: Dictionary, render_pos: Vector2, dir_local: Vector2) -> String:
	if ud.is_empty():
		return "main"
	if _unit_hive_occlusion_active(ud, hive_by_id, render_pos, dir_local):
		return "rear"
	var travel_dir_world: Vector2 = _to_world_dir(dir_local)
	if travel_dir_world.length_squared() <= 0.000001:
		return "main"
	travel_dir_world = travel_dir_world.normalized()
	var render_world: Vector2 = _to_world_pos(render_pos)
	if _is_back_hive_approach(travel_dir_world):
		var to_hive_id: int = _unit_target_hive_id(ud)
		if to_hive_id > 0:
			var boundary_v: Variant = _target_hive_boundary_world(to_hive_id, hive_by_id, travel_dir_world)
			if boundary_v is Vector2:
				var boundary_world: Vector2 = boundary_v as Vector2
				var along_to_back_shell: float = (render_world - boundary_world).dot(travel_dir_world)
				if along_to_back_shell >= -HIVE_BACK_SHELL_OCCLUSION_ENTRY_PAD_PX:
					return "rear"
	if _is_rear_hive_approach(travel_dir_world):
		var source_hive_id: int = _unit_source_hive_id(ud)
		if source_hive_id > 0:
			var source_boundary_v: Variant = _hive_shell_contact_world(source_hive_id, hive_by_id, travel_dir_world)
			if source_boundary_v is Vector2:
				var source_boundary_world: Vector2 = source_boundary_v as Vector2
				var along_from_source_shell: float = (render_world - source_boundary_world).dot(travel_dir_world)
				if along_from_source_shell <= HIVE_SOURCE_OCCLUSION_EXIT_PAD_PX:
					return "rear"
	return "main"

func _render_pose_for_unit(unit_id: int, unit_data: Dictionary, state: Dictionary, hive_by_id: Dictionary, sim_time_s: float, now_us: int, settle_active: bool) -> Dictionary:
	if bool(state.get("just_spawned", false)):
		var spawn_pos: Vector2 = state.get("curr_pos", Vector2.ZERO)
		if not unit_data.is_empty():
			spawn_pos += _unit_bobble_offset(unit_data, hive_by_id, sim_time_s)
		var spawn_rot: float = float(state.get("curr_rot", 0.0))
		var spawn_dir: Vector2 = state.get("dir", Vector2.RIGHT)
		state["render_pos"] = spawn_pos
		state["just_spawned"] = false
		state["warm_spawned"] = false
		_unit_visual_by_id[unit_id] = state
		return {"ok": true, "pos": spawn_pos, "rot": spawn_rot, "dir": spawn_dir}
	var alpha: float = _render_alpha_for_state(state, now_us, settle_active)
	if settle_active and alpha > 1.0:
		var settle_pose: Dictionary = _render_settle_projected_pose(unit_id, state, alpha)
		if bool(settle_pose.get("ok", false)):
			var settle_pos_v: Variant = settle_pose.get("pos", Vector2.ZERO)
			var settle_pos: Vector2 = settle_pos_v as Vector2 if settle_pos_v is Vector2 else Vector2.ZERO
			if not unit_data.is_empty():
				settle_pos += _unit_bobble_offset(unit_data, hive_by_id, sim_time_s)
			var settle_rot: float = float(settle_pose.get("rot", float(state.get("curr_rot", 0.0))))
			var settle_dir: Vector2 = state.get("dir", Vector2.RIGHT)
			state["render_pos"] = settle_pos
			state["warm_spawned"] = false
			_unit_visual_by_id[unit_id] = state
			return {"ok": true, "pos": settle_pos, "rot": settle_rot, "dir": settle_dir}
	if alpha > 1.0:
		if not settle_active:
			var curr_t: float = float(state.get("curr_t", 0.5))
			if curr_t <= 0.05 or curr_t >= 0.95:
				alpha = 1.0
	var prev_pos: Vector2 = state.get("prev_pos", Vector2.ZERO)
	var curr_pos: Vector2 = state.get("curr_pos", prev_pos)
	var render_pos: Vector2 = prev_pos.lerp(curr_pos, alpha)
	if not unit_data.is_empty():
		render_pos += _unit_bobble_offset(unit_data, hive_by_id, sim_time_s)
	var prev_rot: float = float(state.get("prev_rot", 0.0))
	var curr_rot: float = float(state.get("curr_rot", prev_rot))
	var render_rot: float = lerp_angle(prev_rot, curr_rot, alpha)
	var prev_dir: Vector2 = state.get("dir", Vector2.RIGHT)
	state["render_pos"] = render_pos
	state["warm_spawned"] = false
	_unit_visual_by_id[unit_id] = state
	return {"ok": true, "pos": render_pos, "rot": render_rot, "dir": prev_dir}

func _render_units_batched(now_us: int) -> void:
	_reset_unit_multimesh_counts()
	if _unit_visual_by_id.is_empty():
		_finalize_unit_multimesh_counts()
		return
	var registry: SpriteRegistry = _get_sprite_registry()
	if registry == null:
		_finalize_unit_multimesh_counts()
		return
	var settle_active: bool = _post_match_settle_is_active(now_us)
	var hive_by_id: Dictionary = _build_hive_by_id()
	var sim_time_s: float = float(model.get("sim_time_s", 0.0))
	var ids: Array = _unit_visual_by_id.keys()
	if AUDIT_RENDER:
		_audit_draw_ops += ids.size()
	for id_any in ids:
		var unit_id: int = int(id_any)
		var state_any: Variant = _unit_visual_by_id.get(unit_id, null)
		if typeof(state_any) != TYPE_DICTIONARY:
			continue
		var state: Dictionary = state_any as Dictionary
		var unit_any: Variant = _unit_data_by_id.get(unit_id, null)
		var unit_data: Dictionary = {}
		if typeof(unit_any) == TYPE_DICTIONARY:
			unit_data = unit_any as Dictionary
		var pose: Dictionary = _render_pose_for_unit(unit_id, unit_data, state, hive_by_id, sim_time_s, now_us, settle_active)
		if not bool(pose.get("ok", false)):
			continue
		var pos: Vector2 = pose.get("pos", Vector2.ZERO)
		var rot: float = float(pose.get("rot", 0.0))
		var dir_local: Vector2 = pose.get("dir", Vector2.RIGHT)
		var owner_id: int = _unit_owner_id(unit_data, hive_by_id)
		var layer: String = _unit_batch_layer(unit_data, hive_by_id, pos, dir_local)
		if UNIT_OUTLINE_ENABLED and not debug_draw_units:
			_submit_unit_multimesh_instance(owner_id, layer, pos, rot, true, registry, unit_data, hive_by_id, dir_local)
		if not debug_draw_units:
			_submit_unit_multimesh_instance(owner_id, layer, pos, rot, false, registry, unit_data, hive_by_id, dir_local)
	_finalize_unit_multimesh_counts()

func _render_units(now_us: int) -> void:
	if use_multimesh_units:
		_render_units_batched(now_us)
		return
	if _unit_visual_by_id.is_empty():
		return
	var settle_active: bool = _post_match_settle_is_active(now_us)
	var hive_by_id: Dictionary = _build_hive_by_id()
	var sim_time_s: float = float(model.get("sim_time_s", 0.0))
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
		var unit_any: Variant = _unit_data_by_id.get(unit_id, null)
		var unit_data: Dictionary = {}
		if typeof(unit_any) == TYPE_DICTIONARY:
			unit_data = unit_any as Dictionary
		var state_any: Variant = _unit_visual_by_id.get(unit_id, null)
		if typeof(state_any) == TYPE_DICTIONARY:
			var state: Dictionary = state_any as Dictionary
			if bool(state.get("just_spawned", false)):
				var spawn_base_pos: Vector2 = state.get("curr_pos", node.position)
				var spawn_pos: Vector2 = spawn_base_pos
				if not unit_data.is_empty():
					spawn_pos += _unit_bobble_offset(unit_data, hive_by_id, sim_time_s)
				node.position = _apply_swarm_absorb_visual(node, unit_id, unit_data, spawn_pos, hive_by_id)
				node.rotation = float(state.get("curr_rot", node.rotation))
				state["render_pos"] = node.position
				state["just_spawned"] = false
				state["warm_spawned"] = false
				_unit_visual_by_id[unit_id] = state
				var spawn_dir: Vector2 = state.get("dir", Vector2.RIGHT)
				_reset_unit_emergence_visuals(node)
				if not unit_data.is_empty():
					_update_bee_clip_for_unit(unit_id, node, unit_data, hive_by_id)
					_apply_unit_emergence_visuals(node, unit_data, hive_by_id, spawn_base_pos, spawn_dir)
					_apply_unit_directional_visibility(node, unit_data, hive_by_id, spawn_base_pos, spawn_dir)
				continue
			var alpha: float = _render_alpha_for_state(state, now_us, settle_active)
			if settle_active and alpha > 1.0:
				var settle_pose: Dictionary = _render_settle_projected_pose(unit_id, state, alpha)
				if bool(settle_pose.get("ok", false)):
					var settle_pos_v: Variant = settle_pose.get("pos", node.position)
					var settle_base_pos: Vector2 = node.position
					if settle_pos_v is Vector2:
						var settle_pos: Vector2 = settle_pos_v as Vector2
						settle_base_pos = settle_pos
						if not unit_data.is_empty():
							settle_pos += _unit_bobble_offset(unit_data, hive_by_id, sim_time_s)
						node.position = _apply_swarm_absorb_visual(node, unit_id, unit_data, settle_pos, hive_by_id)
					node.rotation = float(settle_pose.get("rot", float(state.get("curr_rot", node.rotation))))
					state["render_pos"] = node.position
					state["warm_spawned"] = false
					_unit_visual_by_id[unit_id] = state
					var settle_dir: Vector2 = state.get("dir", Vector2.RIGHT)
					_reset_unit_emergence_visuals(node)
					if not unit_data.is_empty():
						_update_bee_clip_for_unit(unit_id, node, unit_data, hive_by_id)
						_apply_unit_emergence_visuals(node, unit_data, hive_by_id, settle_base_pos, settle_dir)
						_apply_unit_directional_visibility(node, unit_data, hive_by_id, settle_base_pos, settle_dir)
					continue
			if alpha > 1.0:
				if not settle_active:
					var curr_t: float = float(state.get("curr_t", 0.5))
					# Avoid endpoint overshoot artifacts when units are about to arrive.
					if curr_t <= 0.05 or curr_t >= 0.95:
						alpha = 1.0
			var prev_pos: Vector2 = state.get("prev_pos", node.position)
			var curr_pos: Vector2 = state.get("curr_pos", prev_pos)
			var render_base_pos: Vector2 = prev_pos.lerp(curr_pos, alpha)
			var render_pos: Vector2 = render_base_pos
			if not unit_data.is_empty():
				render_pos += _unit_bobble_offset(unit_data, hive_by_id, sim_time_s)
			node.position = _apply_swarm_absorb_visual(node, unit_id, unit_data, render_pos, hive_by_id)
			var prev_rot: float = float(state.get("prev_rot", node.rotation))
			var curr_rot: float = float(state.get("curr_rot", prev_rot))
			node.rotation = lerp_angle(prev_rot, curr_rot, alpha)
			state["render_pos"] = node.position
			state["warm_spawned"] = false
			_unit_visual_by_id[unit_id] = state
			var render_dir: Vector2 = state.get("dir", Vector2.RIGHT)
			_reset_unit_emergence_visuals(node)
			if not unit_data.is_empty():
				_update_bee_clip_for_unit(unit_id, node, unit_data, hive_by_id)
				_apply_unit_emergence_visuals(node, unit_data, hive_by_id, render_base_pos, render_dir)
				_apply_unit_directional_visibility(node, unit_data, hive_by_id, render_base_pos, render_dir)
			else:
				_update_bee_clip_for_missing_unit(unit_id, node, now_us)

func _apply_swarm_absorb_visual(node: Node2D, unit_id: int, unit_data: Dictionary, render_pos: Vector2, hive_by_id: Dictionary) -> Vector2:
	if node == null:
		return render_pos
	node.scale = Vector2.ONE
	node.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if not SWARM_ABSORB_VISUAL_ENABLED or unit_data.is_empty() or swarm_nodes_by_id.is_empty():
		return render_pos
	var absorb: Dictionary = _nearest_swarm_absorb_target(unit_id, unit_data, render_pos, hive_by_id)
	if absorb.is_empty():
		return render_pos
	var dist: float = float(absorb.get("dist", SWARM_ABSORB_RADIUS_PX))
	var raw_t: float = clampf(1.0 - ((dist - SWARM_ABSORB_CORE_RADIUS_PX) / maxf(1.0, SWARM_ABSORB_RADIUS_PX - SWARM_ABSORB_CORE_RADIUS_PX)), 0.0, 1.0)
	var pull_t: float = raw_t * raw_t * (3.0 - 2.0 * raw_t)
	var target_pos: Vector2 = absorb.get("pos", render_pos)
	node.scale = Vector2.ONE * lerpf(1.0, SWARM_ABSORB_MIN_SCALE, pull_t)
	node.modulate = Color(1.0, 1.0, 1.0, lerpf(1.0, SWARM_ABSORB_MIN_ALPHA, pull_t))
	var pulled_pos: Vector2 = render_pos.lerp(target_pos, minf(SWARM_ABSORB_MAX_PULL, pull_t))
	if unit_id > 0:
		var state_any: Variant = _unit_visual_by_id.get(unit_id, null)
		if typeof(state_any) == TYPE_DICTIONARY:
			var state: Dictionary = state_any as Dictionary
			state["swarm_absorb_t"] = pull_t
			state["swarm_absorb_target"] = target_pos
			_unit_visual_by_id[unit_id] = state
	return pulled_pos

func _nearest_swarm_absorb_target(unit_id: int, unit_data: Dictionary, render_pos: Vector2, hive_by_id: Dictionary) -> Dictionary:
	var unit_lane_id: int = int(unit_data.get("lane_id", -1))
	if unit_lane_id <= 0:
		return {}
	var unit_owner_id: int = _unit_owner_id(unit_data, hive_by_id)
	var swarms_v: Variant = model.get("swarms", [])
	if typeof(swarms_v) != TYPE_ARRAY:
		return {}
	var best: Dictionary = {}
	var best_dist: float = SWARM_ABSORB_RADIUS_PX
	for swarm_any in swarms_v as Array:
		if typeof(swarm_any) != TYPE_DICTIONARY:
			continue
		var sd: Dictionary = swarm_any as Dictionary
		var swarm_id: int = int(sd.get("swarm_id", sd.get("id", -1)))
		if swarm_id <= 0:
			continue
		if int(sd.get("lane_id", -1)) != unit_lane_id:
			continue
		var swarm_owner_id: int = int(sd.get("owner_id", 0))
		if unit_owner_id > 0 and swarm_owner_id > 0 and swarm_owner_id != unit_owner_id:
			continue
		var swarm_node: Node2D = swarm_nodes_by_id.get(swarm_id, null)
		if swarm_node == null or not is_instance_valid(swarm_node):
			continue
		var swarm_pos: Vector2 = swarm_node.position
		var to_unit: Vector2 = render_pos - swarm_pos
		var dist: float = to_unit.length()
		if dist > best_dist:
			continue
		var halo_dir: Vector2 = to_unit.normalized() if dist > 0.001 else Vector2.RIGHT.rotated(float(unit_id % 360) * TAU / 360.0)
		best_dist = dist
		best = {
			"pos": swarm_pos + halo_dir * SWARM_ABSORB_HALO_RADIUS_PX,
			"dist": dist,
			"swarm_id": swarm_id
		}
	return best

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
	var ck_params: Dictionary = _unit_colorkey_params(sprite_key, owner_id, registry)
	var ck_color: Color = ck_params.get("color", _owner_color(owner_id))
	var ck_threshold: float = float(ck_params.get("threshold", 0.28))
	var ck_softness: float = float(ck_params.get("softness", 0.10))
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
	var mat := ShaderMaterial.new()
	mat.shader = COLORKEY_SHADER
	_mat_set(mat, "key_color", ck_color)
	_mat_set(mat, "threshold", ck_threshold)
	_mat_set(mat, "softness", ck_softness)
	_mat_set(mat, "outline_color", Color(0.0, 0.0, 0.0, 0.96))
	_mat_set(mat, "outline_px", 1.8)
	_mat_set(mat, "outline_strength", 1.0)
	_mat_set(mat, "inner_outline_strength", 0.78)
	var glow_color: Color = _owner_color(owner_id).lightened(0.18)
	glow_color.a = 1.0
	_mat_set(mat, "glow_color", glow_color)
	_mat_set(mat, "glow_strength", 0.72)
	_mat_set(mat, "glow_luma_floor", 0.04)
	_mat_set(mat, "glow_pulse_strength", 0.18)
	_mat_set(mat, "glow_pulse_speed", 5.2)
	_mat_set(mat, "glow_pulse_phase", float(owner_id) * 1.37)
	_unit_material_by_sprite[key] = mat
	return mat

func _get_neutral_unit_material(sprite_key: String, owner_id: int, _registry: SpriteRegistry) -> ShaderMaterial:
	var key := "%s|%d|neutral_recolor" % [sprite_key, owner_id]
	if _neutral_unit_material_by_sprite.has(key):
		return _neutral_unit_material_by_sprite[key]
	_audit_mark_rebuild("neutral_unit_recolor_material_cache_miss")
	var mat := ShaderMaterial.new()
	mat.shader = TEAM_GLOW_RECOLOR_SHADER
	var npc_color: Color = _owner_color(0)
	_mat_set(mat, "team_color", npc_color)
	_mat_set(mat, "glow_strength", 0.35)
	_mat_set(mat, "colorize_strength", 0.92)
	_mat_set(mat, "additive_glow", 0.0)
	_neutral_unit_material_by_sprite[key] = mat
	return mat

func _get_unit_material(sprite_key: String, owner_id: int, registry: SpriteRegistry) -> ShaderMaterial:
	if owner_id <= 0:
		return _get_neutral_unit_material(sprite_key, owner_id, registry)
	return _get_unit_colorkey_material(sprite_key, owner_id, registry)

func _ensure_unit_colorkey_material(
	sprite: Sprite2D,
	sprite_key: String,
	registry: SpriteRegistry,
	owner_id: int,
	unit_id: int
) -> ShaderMaterial:
	if sprite == null:
		return null
	var mat: ShaderMaterial = _get_unit_material(sprite_key, owner_id, registry)
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
		_update_swarm_node(node, sd, pos, swarm_radius, hive_by_id)
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
	root.set_meta("swarm_radius", swarm_radius)
	var renderer: Node2D = SwarmBeeRenderer.new()
	renderer.name = "SwarmBeeRenderer"
	root.add_child(renderer)
	return root

func _update_swarm_node(node: Node2D, sd: Dictionary, pos: Vector2, swarm_radius: float, hive_by_id: Dictionary) -> void:
	node.position = pos
	node.set_meta("swarm_radius", swarm_radius)
	var owner_id: int = int(sd.get("owner_id", 0))
	var color: Color = _owner_color(owner_id)
	color.a = UNIT_COLOR.a
	var count: int = int(sd.get("count", 0))
	var last_count: int = int(node.get_meta("count", -1))
	if count != last_count:
		node.set_meta("count", count)
		SFLog.info("SWARM_VIS_COUNT", {"swarm_id": int(sd.get("swarm_id", sd.get("id", -1))), "count": count})
	var renderer := node.get_node_or_null("SwarmBeeRenderer")
	if renderer != null:
		if renderer.has_method("set_swarm_power"):
			renderer.call("set_swarm_power", count)
		if renderer.has_method("set_team_color"):
			renderer.call("set_team_color", color)
		if renderer.has_method("set_target_direction"):
			renderer.call("set_target_direction", _swarm_target_direction(sd, pos, hive_by_id))

func _swarm_target_direction(sd: Dictionary, pos: Vector2, hive_by_id: Dictionary) -> Vector2:
	var dst_id: int = int(sd.get("dst", sd.get("to_id", 0)))
	if dst_id > 0:
		var dst_pos_v: Variant = _hive_pos(dst_id, hive_by_id)
		if dst_pos_v is Vector2:
			var to_dst: Vector2 = (dst_pos_v as Vector2) - pos
			if to_dst.length_squared() > 0.000001:
				return to_dst.normalized()
	var side: String = str(sd.get("side", "A"))
	return Vector2.RIGHT if side != "B" else Vector2.LEFT

func _clear_swarm_nodes() -> void:
	var ids: Array = swarm_nodes_by_id.keys()
	for swarm_id in ids:
		var node: Node2D = swarm_nodes_by_id.get(swarm_id, null)
		if node != null:
			node.queue_free()
			SFLog.info("SWARM_VIS_FREE", {"swarm_id": int(swarm_id)})
	swarm_nodes_by_id.clear()

func _unit_pos(u: Variant, hive_by_id: Dictionary) -> Array:
	if typeof(u) == TYPE_DICTIONARY:
		var ud: Dictionary = u as Dictionary
		var pos_v: Variant = ud.get("pos")
		if typeof(pos_v) == TYPE_VECTOR2:
			return [true, pos_v as Vector2]
		if ud.has("t"):
			var endpoints: Dictionary = _unit_path_endpoints_map_local(ud, hive_by_id)
			if bool(endpoints.get("ok", false)):
				var sample_pos: Vector2 = _sample_unit_pos_from_endpoints(ud, endpoints)
				return [true, sample_pos]
		var from_pos_v: Variant = ud.get("from_pos")
		var to_pos_v: Variant = ud.get("to_pos")
		if typeof(from_pos_v) == TYPE_VECTOR2 and typeof(to_pos_v) == TYPE_VECTOR2 and ud.has("t"):
			var from_pos: Vector2 = from_pos_v as Vector2
			var to_pos: Vector2 = to_pos_v as Vector2
			var t: float = clampf(float(ud.get("t", 0.0)), 0.0, 1.0)
			return [true, from_pos.lerp(to_pos, t)]
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
	var omega: float = BOBBLE_OMEGA * _unit_bobble_rate(unit_id)
	var primary: float = sin(omega * sim_time_s + phase) * amp
	var secondary_phase: float = _unit_phase(unit_id * 17 + 11)
	var secondary_amp: float = amp * _unit_bobble_secondary_scale(unit_id)
	var secondary: float = sin((omega * BOBBLE_SECONDARY_OMEGA_RATIO) * sim_time_s + secondary_phase) * secondary_amp
	var offset: float = primary + secondary
	var off: Vector2 = normal * offset
	off.y = clampf(off.y, -BOBBLE_Y_CLAMP_PX, BOBBLE_Y_CLAMP_PX)
	off.y += _unit_elevation_bobble_px(unit_id, sim_time_s)
	off.y = clampf(off.y, -BOBBLE_Y_CLAMP_PX - BOBBLE_ELEVATION_Y_CLAMP_PX, BOBBLE_Y_CLAMP_PX + BOBBLE_ELEVATION_Y_CLAMP_PX)
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
	var from_id: int = _resolve_id(ud.get("from_id", ud.get("from", ud.get("src_id", ud.get("source_id", -1)))))
	var to_id: int = _resolve_id(ud.get("to_id", ud.get("to", ud.get("dst_id", ud.get("target_id", -1)))))
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
	var local_endpoints: Dictionary = _unit_path_endpoints_map_local(ud, hive_by_id)
	if bool(local_endpoints.get("ok", false)):
		var local_a: Vector2 = local_endpoints.get("a", Vector2.ZERO)
		var local_b: Vector2 = local_endpoints.get("b", Vector2.ZERO)
		return {
			"ok": true,
			"a": _to_world_pos(local_a),
			"b": _to_world_pos(local_b)
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

func _unit_bobble_rate(unit_id: int) -> float:
	var h := _hash_unit_id(unit_id * 67 + 19)
	var frac := float((h >> 5) % 10000) / 10000.0
	return lerpf(BOBBLE_RATE_MIN, BOBBLE_RATE_MAX, frac)

func _unit_bobble_secondary_scale(unit_id: int) -> float:
	var h := _hash_unit_id(unit_id * 97 + 23)
	var frac := float((h >> 3) % 10000) / 10000.0
	return lerpf(BOBBLE_SECONDARY_SCALE_MIN, BOBBLE_SECONDARY_SCALE_MAX, frac)

func _unit_elevation_bobble_px(unit_id: int, sim_time_s: float) -> float:
	var amp: float = _unit_elevation_amp(unit_id)
	var omega: float = BOBBLE_OMEGA * _unit_elevation_rate(unit_id)
	var phase: float = _unit_phase(unit_id * 41 + 29)
	var primary: float = sin(omega * sim_time_s + phase) * amp
	var secondary_phase: float = _unit_phase(unit_id * 53 + 31)
	var secondary_amp: float = amp * _unit_elevation_secondary_scale(unit_id)
	var secondary: float = sin((omega * BOBBLE_SECONDARY_OMEGA_RATIO) * sim_time_s + secondary_phase) * secondary_amp
	return clampf(primary + secondary, -BOBBLE_ELEVATION_Y_CLAMP_PX, BOBBLE_ELEVATION_Y_CLAMP_PX)

func _unit_elevation_amp(unit_id: int) -> float:
	var h := _hash_unit_id(unit_id * 71 + 37)
	var frac := float((h >> 6) % 10000) / 10000.0
	return lerpf(BOBBLE_ELEVATION_AMP_MIN_PX, BOBBLE_ELEVATION_AMP_MAX_PX, frac)

func _unit_elevation_rate(unit_id: int) -> float:
	var h := _hash_unit_id(unit_id * 83 + 41)
	var frac := float((h >> 4) % 10000) / 10000.0
	return lerpf(BOBBLE_ELEVATION_RATE_MIN, BOBBLE_ELEVATION_RATE_MAX, frac)

func _unit_elevation_secondary_scale(unit_id: int) -> float:
	var h := _hash_unit_id(unit_id * 109 + 47)
	var frac := float((h >> 2) % 10000) / 10000.0
	return lerpf(BOBBLE_ELEVATION_SECONDARY_SCALE_MIN, BOBBLE_ELEVATION_SECONDARY_SCALE_MAX, frac)

func _hash_unit_id(unit_id: int) -> int:
	var x := int(unit_id)
	x = x ^ (x << 13)
	x = x ^ (x >> 17)
	x = x ^ (x << 5)
	return x & 0x7fffffff

func _owner_color(owner_id: int) -> Color:
	return TeamVisuals.owner_color(owner_id)

func _unit_modulate_color(owner_id: int) -> Color:
	if owner_id <= 0:
		return Color(1.0, 1.0, 1.0, UNIT_COLOR.a)
	return _owner_color(owner_id)

func _unit_owner_id(u: Variant, hive_by_id: Dictionary) -> int:
	if typeof(u) != TYPE_DICTIONARY:
		return 0
	var ud: Dictionary = u as Dictionary
	var owner_id := int(ud.get("owner_id", 0))
	if owner_id > 0:
		return owner_id
	var from_id := _unit_source_hive_id(ud)
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
		var center_offset: float = _grid_coord_render_offset()
		return Vector2((gx + center_offset) * cell_size, (gy + center_offset) * cell_size)
	return null

func _arena_node() -> Node:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return null
	var arena_node: Node = parent_node.get_parent()
	return arena_node

func _grid_coord_render_offset() -> float:
	var arena_node: Node = _arena_node()
	if arena_node != null and arena_node.has_method("get_grid_coord_render_offset"):
		return float(arena_node.call("get_grid_coord_render_offset"))
	return 0.5

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

func _to_world_dir(dir: Vector2) -> Vector2:
	if dir.length_squared() <= 0.000001:
		return Vector2.ZERO
	if _unit_space == "global":
		return dir.normalized()
	var world_vec: Vector2 = global_transform.basis_xform(dir)
	if world_vec.length_squared() <= 0.000001:
		return dir.normalized()
	return world_vec.normalized()

func _to_local_dir(dir: Vector2) -> Vector2:
	if dir.length_squared() <= 0.000001:
		return Vector2.ZERO
	if _unit_space == "global":
		return dir.normalized()
	var local_vec: Vector2 = global_transform.affine_inverse().basis_xform(dir)
	if local_vec.length_squared() <= 0.000001:
		return dir.normalized()
	return local_vec.normalized()

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
