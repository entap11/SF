# Render-only influence map system for reactive arena floor visuals.
# Reads authoritative state snapshots and emits texture artifacts only.
class_name ArenaFloorInfluenceSystem
extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")
const FloorInfluenceConfig := preload("res://scripts/fx/arena_floor_influence_config.gd")
const FLOOR_SHADER: Shader = preload("res://shaders/arena_floor_reactive.gdshader")
const BLOB_SHADER: Shader = preload("res://shaders/arena_influence_blob.gdshader")

const CONFIG_PATH: String = "res://data/fx/arena_floor_influence_config.tres"
const DEFAULT_BLOB_TEX_SIZE: int = 96
const DEFAULT_PULSE_UPDATE_HZ: float = 4.0

var _config = null
var _map_root: Node2D = null
var _pools_root: Node = null
var _floor_renderer: FloorRenderer = null

var _influence_viewport: SubViewport = null
var _influence_canvas: Node2D = null
var _blob_texture: Texture2D = null
var _noise_texture: Texture2D = null
var _probe_magenta_texture: Texture2D = null
var _blob_pool: Array[Sprite2D] = []
var _influence_image: Image = null
var _influence_texture: ImageTexture = null

var _debug_layer: CanvasLayer = null
var _debug_panel: PanelContainer = null
var _debug_texture_rect: TextureRect = null

var _floor_material: ShaderMaterial = null
var _material_target: Sprite2D = null
var _floor_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1.0, 1.0))

var _cached_model: Dictionary = {}
var _emitters: Array = []
var _owner_by_key: Dictionary = {}
var _pulses_by_key: Dictionary = {}

var _last_emitters_sig: int = 0
var _pending_rerender: bool = true
var _next_rerender_ms: int = 0
var _last_maturity: float = -1.0
var _last_debug_enabled: bool = false
var _runtime_enabled: bool = true
var _last_runtime_diag_ms: int = 0
var _probe_restore: Array = []
var _probe_pending_on_first_render: bool = true

func setup(map_root: Node2D, pools_root: Node, floor_renderer: FloorRenderer) -> void:
	_map_root = map_root
	_pools_root = pools_root
	_floor_renderer = floor_renderer
	SFLog.allow_tag("FLOOR_INFLUENCE_DISABLED_PLATFORM")
	SFLog.allow_tag("FLOOR_INFLUENCE_ACTIVE")
	SFLog.allow_tag("FLOOR_INFLUENCE_INIT")
	SFLog.allow_tag("FLOOR_INFLUENCE_PULSE")
	SFLog.allow_tag("FLOOR_INFLUENCE_RERENDER")
	SFLog.allow_tag("FLOOR_INFLUENCE_RUNTIME")
	SFLog.allow_tag("FLOOR_INFLUENCE_PROBE")
	_load_config()
	_runtime_enabled = _compute_runtime_enabled()
	if not _runtime_enabled:
		_remove_floor_material_if_present()
		set_process(false)
		SFLog.warn("FLOOR_INFLUENCE_DISABLED_PLATFORM", {
			"adapter": _video_adapter_name(),
			"render_method": _render_method_name()
		})
		return
	_ensure_influence_viewport()
	_ensure_floor_material()
	_configure_floor_bounds_from_renderer()
	var env_force_debug: bool = _env_flag("SF_FORCE_FLOOR_INFLUENCE_DEBUG")
	set_debug_enabled(bool(_config.show_influence_debug) or env_force_debug)
	_pending_rerender = true
	set_process(true)
	_probe_pending_on_first_render = true
	var target_path: String = ""
	if _material_target != null and is_instance_valid(_material_target):
		target_path = str(_material_target.get_path())
	SFLog.warn("FLOOR_INFLUENCE_ACTIVE", {
		"target_sprite": target_path,
		"debug_enabled": _last_debug_enabled
	})
	SFLog.info("FLOOR_INFLUENCE_INIT", {
		"viewport_size": _influence_viewport.size if _influence_viewport != null else Vector2i.ZERO,
		"update_mode": int(_config.update_mode) if _config != null else -1
	})

func set_debug_enabled(enabled: bool) -> void:
	if not _runtime_enabled:
		return
	if _config != null:
		_config.show_influence_debug = enabled
	if enabled:
		_ensure_debug_overlay()
	if _debug_layer != null:
		_debug_layer.visible = enabled
	_last_debug_enabled = enabled

func configure_floor_bounds(bounds: Rect2) -> void:
	if not _runtime_enabled:
		return
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		return
	_floor_bounds = bounds
	_pending_rerender = true

func notify_match_started() -> void:
	if not _runtime_enabled:
		return
	_probe_pending_on_first_render = true
	_pending_rerender = true

func notify_match_ended() -> void:
	if not _runtime_enabled:
		return
	_pending_rerender = true

func notify_overtime_started() -> void:
	if not _runtime_enabled:
		return
	_pending_rerender = true

func notify_ownership_changed(entity_type: String, entity_id: int, prev_owner: int, next_owner: int) -> void:
	if not _runtime_enabled:
		return
	if _config == null or not bool(_config.capture_pulse_enabled):
		return
	if entity_id <= 0:
		return
	if prev_owner == next_owner:
		return
	var owner_index: int = _owner_to_player_index(next_owner)
	if owner_index < 0:
		return
	var key: String = "%s:%d" % [entity_type, entity_id]
	_add_pulse(key, owner_index)

func apply_render_model(render_model: Dictionary) -> void:
	if not _runtime_enabled:
		return
	if render_model == null or render_model.is_empty():
		return
	_cached_model = render_model
	if _config == null:
		_load_config()
	_update_maturity_from_model(render_model)
	var emitters: Array = _build_emitters(render_model)
	_sync_owner_index_and_pulses(emitters)
	var sig: int = _compute_emitters_signature(emitters)
	if sig != _last_emitters_sig:
		_last_emitters_sig = sig
		_emitters = emitters
		_pending_rerender = true
	if _is_event_driven_mode() and _should_rerender_now(Time.get_ticks_msec()):
		_rerender_influence_map("event_driven")

func _process(_delta: float) -> void:
	if not _runtime_enabled:
		return
	_tick_magenta_probe_restore()
	if _config == null:
		return
	_update_maturity_from_ops_state()
	if _tick_pulses_and_mark_dirty():
		_pending_rerender = true
	if not _pending_rerender:
		return
	var now_ms: int = Time.get_ticks_msec()
	if not _should_rerender_now(now_ms):
		return
	if _is_fixed_hz_mode():
		_rerender_influence_map("fixed_hz")
		return
	_rerender_influence_map("event")

func _load_config() -> void:
	var loaded_any: Variant = load(CONFIG_PATH)
	if loaded_any != null:
		_config = loaded_any
	else:
		_config = FloorInfluenceConfig.new()
	if _config == null or not _config.has_method("sanitized_texture_size"):
		_config = FloorInfluenceConfig.new()
	_config.influence_tex_size = _config.sanitized_texture_size()
	if _config.update_hz <= 0.1:
		_config.update_hz = 6.0
	if _config.global_maturity_seconds <= 1.0:
		_config.global_maturity_seconds = 120.0
	if _config.max_influence_per_pixel <= 0.01:
		_config.max_influence_per_pixel = 1.0

func _ensure_influence_viewport() -> void:
	if _pools_root == null:
		return
	if _influence_viewport == null or not is_instance_valid(_influence_viewport):
		var existing_vp: Node = _pools_root.get_node_or_null("InfluenceViewport")
		if existing_vp is SubViewport:
			_influence_viewport = existing_vp as SubViewport
		else:
			_influence_viewport = SubViewport.new()
			_influence_viewport.name = "InfluenceViewport"
			_pools_root.add_child(_influence_viewport)
	if _influence_viewport == null:
		return
	var size_px: int = _config.sanitized_texture_size() if _config != null else 256
	_influence_viewport.size = Vector2i(size_px, size_px)
	_influence_viewport.disable_3d = true
	_influence_viewport.transparent_bg = true
	_influence_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_influence_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	if _influence_canvas == null or not is_instance_valid(_influence_canvas):
		var existing_canvas: Node = _influence_viewport.get_node_or_null("InfluenceCanvas")
		if existing_canvas is Node2D:
			_influence_canvas = existing_canvas as Node2D
		else:
			_influence_canvas = Node2D.new()
			_influence_canvas.name = "InfluenceCanvas"
			_influence_viewport.add_child(_influence_canvas)
	if _blob_texture == null:
		_blob_texture = _build_blob_texture(DEFAULT_BLOB_TEX_SIZE)
	if _noise_texture == null:
		_noise_texture = _build_noise_texture(64)

func _ensure_floor_material() -> void:
	if _floor_renderer == null:
		return
	var target_sprite: Sprite2D = _pick_material_target_sprite()
	if target_sprite == null:
		return
	_material_target = target_sprite
	if _floor_material == null:
		_floor_material = ShaderMaterial.new()
		_floor_material.shader = FLOOR_SHADER
	target_sprite.material = _floor_material
	_apply_shader_uniforms(target_sprite)

func _pick_material_target_sprite() -> Sprite2D:
	if _floor_renderer == null:
		return null
	var overlay_sprite: Sprite2D = _floor_renderer.get_overlay_floor_sprite()
	if overlay_sprite != null and is_instance_valid(overlay_sprite) and overlay_sprite.visible:
		return overlay_sprite
	var base_sprite: Sprite2D = _floor_renderer.get_base_floor_sprite()
	if base_sprite != null and is_instance_valid(base_sprite):
		return base_sprite
	return null

func _configure_floor_bounds_from_renderer() -> void:
	if _floor_renderer == null:
		return
	var bounds: Rect2 = _floor_renderer.get_floor_bounds_rect()
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		return
	_floor_bounds = bounds
	_pending_rerender = true

func _apply_shader_uniforms(base_sprite: Sprite2D) -> void:
	if _floor_material == null:
		return
	if _influence_texture != null:
		_floor_material.set_shader_parameter("influence_tex", _influence_texture)
	elif _influence_viewport != null:
		_floor_material.set_shader_parameter("influence_tex", _influence_viewport.get_texture())
	var base_tex: Texture2D = base_sprite.texture
	if base_tex != null:
		_floor_material.set_shader_parameter("base_floor_tex", base_tex)
		_floor_material.set_shader_parameter("use_base_floor_tex", true)
	else:
		_floor_material.set_shader_parameter("use_base_floor_tex", false)
	if _noise_texture != null:
		_floor_material.set_shader_parameter("noise_tex", _noise_texture)
		_floor_material.set_shader_parameter("use_noise_tex", true)
	else:
		_floor_material.set_shader_parameter("use_noise_tex", false)
	var colors: Array[Color] = _resolve_player_colors()
	_floor_material.set_shader_parameter("player_color_0", colors[0])
	_floor_material.set_shader_parameter("player_color_1", colors[1])
	_floor_material.set_shader_parameter("player_color_2", colors[2])
	_floor_material.set_shader_parameter("player_color_3", colors[3])
	_floor_material.set_shader_parameter("neutral_floor_strength", float(_config.neutral_floor_strength))
	_floor_material.set_shader_parameter("initial_maturity_floor", clampf(float(_config.initial_maturity_floor), 0.0, 1.0))
	_floor_material.set_shader_parameter("noise_strength", float(_config.noise_strength))
	_floor_material.set_shader_parameter("noise_scroll_speed", float(_config.noise_scroll_speed))
	_floor_material.set_shader_parameter("edge_glow_strength", float(_config.edge_glow_strength))
	_floor_material.set_shader_parameter("edge_glow_threshold", float(_config.edge_glow_threshold))
	_floor_material.set_shader_parameter("circuit_emphasis", clampf(float(_config.circuit_emphasis), 0.0, 1.0))
	_floor_material.set_shader_parameter("circuit_threshold", clampf(float(_config.circuit_threshold), 0.0, 1.0))
	_floor_material.set_shader_parameter("circuit_softness", maxf(0.001, float(_config.circuit_softness)))
	_floor_material.set_shader_parameter("circuit_edge_emphasis", clampf(float(_config.circuit_edge_emphasis), 0.0, 1.0))
	_floor_material.set_shader_parameter("circuit_edge_threshold", clampf(float(_config.circuit_edge_threshold), 0.0, 1.0))
	_floor_material.set_shader_parameter("circuit_edge_softness", maxf(0.001, float(_config.circuit_edge_softness)))
	_floor_material.set_shader_parameter("circuit_background_leak", clampf(float(_config.circuit_background_leak), 0.0, 1.0))
	_floor_material.set_shader_parameter("territory_threshold", clampf(float(_config.territory_threshold), 0.0, 1.0))
	_floor_material.set_shader_parameter("territory_softness", maxf(0.001, float(_config.territory_softness)))
	_floor_material.set_shader_parameter("dominance_threshold", clampf(float(_config.dominance_threshold), 0.0, 1.0))
	_floor_material.set_shader_parameter("wire_base_strength", maxf(0.0, float(_config.wire_base_strength)))
	_floor_material.set_shader_parameter("wire_pulse_strength", maxf(0.0, float(_config.wire_pulse_strength)))
	_floor_material.set_shader_parameter("wire_pulse_speed", maxf(0.0, float(_config.wire_pulse_speed)))
	_floor_material.set_shader_parameter("wire_phase_scale", maxf(0.0, float(_config.wire_phase_scale)))
	_floor_material.set_shader_parameter("max_influence_per_pixel", float(_config.max_influence_per_pixel))
	_floor_material.set_shader_parameter("blend_mode", int(_config.blend_mode))
	var hard_debug: bool = bool(_config.debug_influence_preview) or _env_flag("SF_FLOOR_INFLUENCE_HARD_DEBUG")
	_floor_material.set_shader_parameter("debug_influence_preview", hard_debug)
	_floor_material.set_shader_parameter("debug_force_magenta", false)
	_floor_material.set_shader_parameter("maturity", 0.0)

func _resolve_player_colors() -> Array[Color]:
	var out: Array[Color] = []
	if _config != null and _config.player_colors.size() >= 4:
		for i in range(4):
			out.append(_config.player_colors[i])
	if out.size() >= 4:
		return out
	out.clear()
	out.append(Color(0.95, 0.85, 0.20, 1.0))
	out.append(Color(0.90, 0.22, 0.22, 1.0))
	out.append(Color(0.20, 0.62, 0.26, 1.0))
	out.append(Color(0.22, 0.52, 0.95, 1.0))
	return out

func _build_emitters(render_model: Dictionary) -> Array:
	var emitters: Array = []
	_append_emitters_from_list(emitters, render_model.get("hives", []), "hive", _config.hive_radius_px, _config.hive_strength)
	_append_emitters_from_list(emitters, render_model.get("towers", []), "tower", _config.tower_radius_px, _config.tower_strength)
	_append_emitters_from_list(emitters, render_model.get("barracks", []), "barracks", _config.barracks_radius_px, _config.barracks_strength)
	return emitters

func _append_emitters_from_list(
	emitters: Array,
	source_any: Variant,
	entity_type: String,
	radius_px: float,
	strength: float
) -> void:
	if typeof(source_any) != TYPE_ARRAY:
		return
	for row_any in source_any as Array:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		var owner_id: int = int(row.get("owner_id", 0))
		var owner_index: int = _owner_to_player_index(owner_id)
		if owner_index < 0:
			continue
		var entity_id: int = int(row.get("id", -1))
		if entity_id <= 0:
			continue
		var pos: Vector2 = _extract_emitter_position(row)
		var radius_value: float = maxf(1.0, radius_px)
		var strength_value: float = maxf(0.01, strength)
		if entity_type == "hive":
			var power_raw: int = int(row.get("pwr", row.get("power", 0)))
			var power_t: float = _normalized_hive_power(power_raw)
			var radius_scale: float = lerpf(1.0, maxf(1.0, float(_config.hive_power_radius_scale_max)), power_t)
			var strength_scale: float = lerpf(1.0, maxf(1.0, float(_config.hive_power_strength_scale_max)), power_t)
			radius_value *= radius_scale
			strength_value *= strength_scale
			_append_emitter_entry(
				emitters,
				"%s:%d" % [entity_type, entity_id],
				entity_type,
				entity_id,
				owner_index,
				pos,
				radius_value,
				strength_value
			)
			# Add a broader territory field so controlled corners pulse as a region.
			var area_radius_scale: float = lerpf(
				maxf(1.0, float(_config.hive_area_radius_scale_min)),
				maxf(1.0, float(_config.hive_area_radius_scale_max)),
				power_t
			)
			var area_strength_scale: float = lerpf(
				maxf(0.01, float(_config.hive_area_strength_scale_min)),
				maxf(0.01, float(_config.hive_area_strength_scale_max)),
				power_t
			)
			_append_emitter_entry(
				emitters,
				"%s:%d:area" % [entity_type, entity_id],
				entity_type,
				entity_id,
				owner_index,
				pos,
				radius_value * area_radius_scale,
				strength_value * area_strength_scale
			)
			continue
		_append_emitter_entry(
			emitters,
			"%s:%d" % [entity_type, entity_id],
			entity_type,
			entity_id,
			owner_index,
			pos,
			radius_value,
			strength_value
		)
		var structure_area_radius_scale: float = maxf(1.0, float(_config.structure_area_radius_scale))
		var structure_area_strength_scale: float = maxf(0.01, float(_config.structure_area_strength_scale))
		_append_emitter_entry(
			emitters,
			"%s:%d:area" % [entity_type, entity_id],
			entity_type,
			entity_id,
			owner_index,
			pos,
			radius_value * structure_area_radius_scale,
			strength_value * structure_area_strength_scale
		)

func _append_emitter_entry(
	emitters: Array,
	key: String,
	entity_type: String,
	entity_id: int,
	owner_index: int,
	pos: Vector2,
	radius_px: float,
	strength: float
) -> void:
	emitters.append({
		"key": key,
		"type": entity_type,
		"id": entity_id,
		"owner_index": owner_index,
		"pos": pos,
		"radius_px": maxf(1.0, radius_px),
		"strength": maxf(0.01, strength)
	})

func _normalized_hive_power(power_value: int) -> float:
	if _config == null:
		return 0.0
	var p: float = maxf(0.0, float(power_value))
	var p_min: float = maxf(0.0, float(_config.hive_power_min))
	var p_full: float = maxf(p_min + 0.01, float(_config.hive_power_full))
	return clampf(inverse_lerp(p_min, p_full, p), 0.0, 1.0)

func _extract_emitter_position(row: Dictionary) -> Vector2:
	var pos_any: Variant = row.get("pos", null)
	if pos_any is Vector2:
		return pos_any as Vector2
	pos_any = row.get("pos_px", null)
	if pos_any is Vector2:
		return pos_any as Vector2
	pos_any = row.get("world_pos", null)
	if pos_any is Vector2:
		return pos_any as Vector2
	return Vector2.ZERO

func _owner_to_player_index(owner_id: int) -> int:
	if owner_id < 1 or owner_id > 4:
		return -1
	return owner_id - 1

func _sync_owner_index_and_pulses(emitters: Array) -> void:
	var next_owner_by_key: Dictionary = {}
	for emitter_any in emitters:
		if typeof(emitter_any) != TYPE_DICTIONARY:
			continue
		var emitter: Dictionary = emitter_any as Dictionary
		var key: String = str(emitter.get("key", ""))
		if key.is_empty():
			continue
		var owner_index: int = int(emitter.get("owner_index", -1))
		next_owner_by_key[key] = owner_index
		if _owner_by_key.has(key):
			var prev_owner_index: int = int(_owner_by_key.get(key, -1))
			if prev_owner_index != owner_index:
				_add_pulse(key, owner_index)
	_owner_by_key = next_owner_by_key

func _add_pulse(key: String, owner_index: int) -> void:
	if _config == null or not bool(_config.capture_pulse_enabled):
		return
	if owner_index < 0 or owner_index > 3:
		return
	var now_ms: int = Time.get_ticks_msec()
	var duration_ms: int = int(maxf(0.1, float(_config.capture_pulse_duration_sec)) * 1000.0)
	_pulses_by_key[key] = {
		"owner_index": owner_index,
		"started_ms": now_ms,
		"end_ms": now_ms + duration_ms
	}
	_pending_rerender = true
	SFLog.info("FLOOR_INFLUENCE_PULSE", {
		"key": key,
		"owner_index": owner_index,
		"duration_ms": duration_ms
	})

func _tick_pulses_and_mark_dirty() -> bool:
	if _pulses_by_key.is_empty():
		return false
	var now_ms: int = Time.get_ticks_msec()
	var expired: Array[String] = []
	for key_any in _pulses_by_key.keys():
		var key: String = str(key_any)
		var pulse_any: Variant = _pulses_by_key.get(key, {})
		if typeof(pulse_any) != TYPE_DICTIONARY:
			expired.append(key)
			continue
		var pulse: Dictionary = pulse_any as Dictionary
		if now_ms >= int(pulse.get("end_ms", 0)):
			expired.append(key)
	for key in expired:
		_pulses_by_key.erase(key)
	return true

func _compute_emitters_signature(emitters: Array) -> int:
	var sig: int = emitters.size()
	for emitter_any in emitters:
		if typeof(emitter_any) != TYPE_DICTIONARY:
			continue
		var emitter: Dictionary = emitter_any as Dictionary
		var key: String = str(emitter.get("key", ""))
		var owner_index: int = int(emitter.get("owner_index", -1))
		var pos: Vector2 = emitter.get("pos", Vector2.ZERO) as Vector2
		var pos_x: int = int(round(pos.x))
		var pos_y: int = int(round(pos.y))
		sig = int((sig * 33 + key.hash()) & 0x7fffffff)
		sig = int((sig * 33 + owner_index) & 0x7fffffff)
		sig = int((sig * 33 + pos_x) & 0x7fffffff)
		sig = int((sig * 33 + pos_y) & 0x7fffffff)
	return sig

func _should_rerender_now(now_ms: int) -> bool:
	if _next_rerender_ms <= 0:
		return true
	return now_ms >= _next_rerender_ms

func _is_fixed_hz_mode() -> bool:
	return _config != null and int(_config.update_mode) == int(FloorInfluenceConfig.UpdateMode.FIXED_HZ)

func _is_event_driven_mode() -> bool:
	return not _is_fixed_hz_mode()

func _schedule_next_rerender(now_ms: int, has_pulses: bool) -> void:
	if _config == null:
		_next_rerender_ms = now_ms + 100
		return
	var hz: float = maxf(1.0, float(_config.update_hz))
	if has_pulses and _is_event_driven_mode():
		hz = maxf(hz, DEFAULT_PULSE_UPDATE_HZ)
	var interval_ms: int = int(round(1000.0 / hz))
	_next_rerender_ms = now_ms + maxi(16, interval_ms)

func _rerender_influence_map(reason: String) -> void:
	if _config == null:
		return
	_ensure_influence_viewport()
	_ensure_floor_material()
	if _influence_viewport == null or _influence_canvas == null:
		return
	if _probe_pending_on_first_render:
		_probe_pending_on_first_render = false
		_run_visibility_probe_if_enabled()
	if _material_target != null and is_instance_valid(_material_target) and _material_target.material != _floor_material:
		_material_target.material = _floor_material
		SFLog.warn("FLOOR_INFLUENCE_ACTIVE", {
			"target_sprite": str(_material_target.get_path()),
			"reason": "material_rebound"
		})
		_apply_shader_uniforms(_material_target)
	var emitter_count: int = _emitters.size()
	_ensure_blob_capacity(emitter_count)
	var tex_size: int = int(_influence_viewport.size.x)
	var now_ms: int = Time.get_ticks_msec()
	var first_uv: Vector2 = Vector2(-1.0, -1.0)
	var used_count: int = 0
	var cpu_emitters: Array = []
	for emitter_any in _emitters:
		if typeof(emitter_any) != TYPE_DICTIONARY:
			continue
		var emitter: Dictionary = emitter_any as Dictionary
		var uv: Vector2 = world_to_uv(emitter.get("pos", Vector2.ZERO) as Vector2)
		if uv.x < -0.2 or uv.x > 1.2 or uv.y < -0.2 or uv.y > 1.2:
			continue
		if used_count == 0:
			first_uv = uv
		var radius_px: float = float(emitter.get("radius_px", 10.0))
		var strength: float = float(emitter.get("strength", 1.0))
		var pulse_gain: Dictionary = _pulse_gain_for_key(str(emitter.get("key", "")), now_ms)
		radius_px += float(pulse_gain.get("radius_boost", 0.0))
		strength += float(pulse_gain.get("strength_boost", 0.0))
		var owner_index: int = int(emitter.get("owner_index", -1))
		if owner_index < 0 or owner_index > 3:
			continue
		cpu_emitters.append({
			"uv": uv,
			"radius_px": radius_px,
			"strength": strength,
			"owner_index": owner_index
		})
		var sprite: Sprite2D = _blob_pool[used_count]
		_apply_blob_sprite(sprite, uv, tex_size, radius_px, strength, owner_index)
		used_count += 1
	for i in range(used_count, _blob_pool.size()):
		_blob_pool[i].visible = false
	_rasterize_cpu_influence_map(tex_size, cpu_emitters)
	if _floor_material != null and _influence_texture != null:
		_floor_material.set_shader_parameter("influence_tex", _influence_texture)
	_pending_rerender = false
	_schedule_next_rerender(now_ms, not _pulses_by_key.is_empty())
	if _debug_texture_rect != null and is_instance_valid(_debug_texture_rect):
		if _influence_texture != null:
			_debug_texture_rect.texture = _influence_texture
		else:
			_debug_texture_rect.texture = _influence_viewport.get_texture()
	if now_ms - _last_runtime_diag_ms >= 1000:
		_last_runtime_diag_ms = now_ms
		SFLog.warn("FLOOR_INFLUENCE_RUNTIME", {
			"emitters_total": emitter_count,
			"emitters_used": used_count,
			"first_uv": first_uv,
			"maturity": _last_maturity
		})
	SFLog.info("FLOOR_INFLUENCE_RERENDER", {
		"reason": reason,
		"emitters": used_count,
		"tex_size": tex_size,
		"pulses": _pulses_by_key.size()
	})

func _rasterize_cpu_influence_map(tex_size: int, emitters: Array) -> void:
	if tex_size <= 0:
		return
	if _influence_image == null or _influence_image.get_width() != tex_size or _influence_image.get_height() != tex_size:
		_influence_image = Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	if _influence_image == null:
		return
	_influence_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var max_per_pixel: float = maxf(0.01, float(_config.max_influence_per_pixel))
	for emitter_any in emitters:
		if typeof(emitter_any) != TYPE_DICTIONARY:
			continue
		var emitter: Dictionary = emitter_any as Dictionary
		var uv: Vector2 = emitter.get("uv", Vector2.ZERO) as Vector2
		var radius_px: float = maxf(0.5, float(emitter.get("radius_px", 1.0)))
		var strength: float = maxf(0.0, float(emitter.get("strength", 0.0)))
		var owner_index: int = int(emitter.get("owner_index", -1))
		if owner_index < 0 or owner_index > 3:
			continue
		var cx: float = uv.x * float(tex_size)
		var cy: float = uv.y * float(tex_size)
		var min_x: int = maxi(0, int(floor(cx - radius_px)))
		var max_x: int = mini(tex_size - 1, int(ceil(cx + radius_px)))
		var min_y: int = maxi(0, int(floor(cy - radius_px)))
		var max_y: int = mini(tex_size - 1, int(ceil(cy + radius_px)))
		var inv_r: float = 1.0 / maxf(radius_px, 0.001)
		for y in range(min_y, max_y + 1):
			var dy: float = (float(y) + 0.5 - cy) * inv_r
			var dy2: float = dy * dy
			if dy2 >= 1.0:
				continue
			for x in range(min_x, max_x + 1):
				var dx: float = (float(x) + 0.5 - cx) * inv_r
				var d2: float = dx * dx + dy2
				if d2 >= 1.0:
					continue
				var d: float = sqrt(d2)
				var t: float = clampf(1.0 - d, 0.0, 1.0)
				var blob: float = t * t * (3.0 - 2.0 * t)
				var add: float = blob * strength
				var c: Color = _influence_image.get_pixel(x, y)
				match owner_index:
					0:
						c.r = minf(max_per_pixel, c.r + add)
					1:
						c.g = minf(max_per_pixel, c.g + add)
					2:
						c.b = minf(max_per_pixel, c.b + add)
					3:
						c.a = minf(max_per_pixel, c.a + add)
				_influence_image.set_pixel(x, y, c)
	_apply_territory_domain_fill(tex_size, emitters, max_per_pixel)
	if _influence_texture == null:
		_influence_texture = ImageTexture.create_from_image(_influence_image)
	else:
		_influence_texture.update(_influence_image)

func _apply_territory_domain_fill(tex_size: int, emitters: Array, max_per_pixel: float) -> void:
	if _config == null:
		return
	if not bool(_config.territory_domain_enabled):
		return
	if emitters.is_empty():
		return
	var domain_base_strength: float = maxf(0.0, float(_config.territory_domain_base_strength))
	if domain_base_strength <= 0.0:
		return
	var falloff: float = maxf(0.25, float(_config.territory_domain_falloff))
	var radius_bias: float = maxf(0.0, float(_config.territory_domain_radius_bias))
	var conflict_threshold: float = clampf(float(_config.territory_domain_conflict_threshold), 0.0, 1.0)
	var conflict_blend: float = clampf(float(_config.territory_domain_conflict_blend), 0.0, 1.0)
	var low_res_divisor: int = maxi(1, int(_config.territory_domain_low_res_divisor))
	var domain_size: int = maxi(int(_config.territory_domain_min_resolution), int(round(float(tex_size) / float(low_res_divisor))))
	domain_size = clampi(domain_size, 16, tex_size)

	var domain_emitters: Array = []
	for emitter_any in emitters:
		if typeof(emitter_any) != TYPE_DICTIONARY:
			continue
		var emitter: Dictionary = emitter_any as Dictionary
		var uv: Vector2 = emitter.get("uv", Vector2.ZERO) as Vector2
		var owner_index: int = int(emitter.get("owner_index", -1))
		if owner_index < 0 or owner_index > 3:
			continue
		var radius_px: float = maxf(1.0, float(emitter.get("radius_px", 1.0)))
		var strength: float = maxf(0.01, float(emitter.get("strength", 0.01)))
		domain_emitters.append({
			"x": uv.x * float(tex_size),
			"y": uv.y * float(tex_size),
			"radius_px": radius_px,
			"strength": strength,
			"owner_index": owner_index
		})
	if domain_emitters.is_empty():
		return

	var domain_channels: PackedFloat32Array = PackedFloat32Array()
	domain_channels.resize(domain_size * domain_size * 4)

	var tex_to_domain: float = float(tex_size) / float(domain_size)
	for y in range(domain_size):
		var py: float = (float(y) + 0.5) * tex_to_domain
		for x in range(domain_size):
			var px: float = (float(x) + 0.5) * tex_to_domain
			var best_owner: int = -1
			var second_owner: int = -1
			var best_score: float = 0.0
			var second_score: float = 0.0
			for de_any in domain_emitters:
				var de: Dictionary = de_any as Dictionary
				var ex: float = float(de.get("x", 0.0))
				var ey: float = float(de.get("y", 0.0))
				var er: float = maxf(1.0, float(de.get("radius_px", 1.0)))
				var es: float = maxf(0.01, float(de.get("strength", 0.01)))
				var dx: float = px - ex
				var dy: float = py - ey
				var eff_radius: float = maxf(1.0, er * (1.0 + radius_bias))
				var norm2: float = (dx * dx + dy * dy) / (eff_radius * eff_radius)
				var score: float = es / (1.0 + norm2 * falloff)
				var owner_idx: int = int(de.get("owner_index", -1))
				if owner_idx < 0:
					continue
				if score > best_score:
					second_score = best_score
					second_owner = best_owner
					best_score = score
					best_owner = owner_idx
				elif score > second_score:
					second_score = score
					second_owner = owner_idx
			if best_owner < 0 or best_score <= 0.0001:
				continue
			var conflict_ratio: float = 0.0
			if second_score > 0.0:
				conflict_ratio = clampf(second_score / maxf(best_score, 0.0001), 0.0, 1.0)
			var primary_gain: float = domain_base_strength * (1.0 - conflict_ratio * 0.35)
			var secondary_gain: float = 0.0
			if second_owner >= 0 and conflict_ratio >= conflict_threshold:
				var t: float = (conflict_ratio - conflict_threshold) / maxf(0.0001, (1.0 - conflict_threshold))
				secondary_gain = domain_base_strength * conflict_blend * clampf(t, 0.0, 1.0)
			var di: int = (y * domain_size + x) * 4
			if best_owner == 0:
				domain_channels[di] = primary_gain
			elif best_owner == 1:
				domain_channels[di + 1] = primary_gain
			elif best_owner == 2:
				domain_channels[di + 2] = primary_gain
			elif best_owner == 3:
				domain_channels[di + 3] = primary_gain
			if secondary_gain > 0.0 and second_owner >= 0:
				if second_owner == 0:
					domain_channels[di] += secondary_gain
				elif second_owner == 1:
					domain_channels[di + 1] += secondary_gain
				elif second_owner == 2:
					domain_channels[di + 2] += secondary_gain
				elif second_owner == 3:
					domain_channels[di + 3] += secondary_gain

	for y_full in range(tex_size):
		var v: float = ((float(y_full) + 0.5) / float(tex_size)) * float(domain_size) - 0.5
		var y0: int = clampi(int(floor(v)), 0, domain_size - 1)
		var y1: int = clampi(y0 + 1, 0, domain_size - 1)
		var ty: float = clampf(v - float(y0), 0.0, 1.0)
		for x_full in range(tex_size):
			var u: float = ((float(x_full) + 0.5) / float(tex_size)) * float(domain_size) - 0.5
			var x0: int = clampi(int(floor(u)), 0, domain_size - 1)
			var x1: int = clampi(x0 + 1, 0, domain_size - 1)
			var tx: float = clampf(u - float(x0), 0.0, 1.0)
			var i00: int = (y0 * domain_size + x0) * 4
			var i10: int = (y0 * domain_size + x1) * 4
			var i01: int = (y1 * domain_size + x0) * 4
			var i11: int = (y1 * domain_size + x1) * 4
			var r0: float = lerpf(domain_channels[i00], domain_channels[i10], tx)
			var g0: float = lerpf(domain_channels[i00 + 1], domain_channels[i10 + 1], tx)
			var b0: float = lerpf(domain_channels[i00 + 2], domain_channels[i10 + 2], tx)
			var a0: float = lerpf(domain_channels[i00 + 3], domain_channels[i10 + 3], tx)
			var r1: float = lerpf(domain_channels[i01], domain_channels[i11], tx)
			var g1: float = lerpf(domain_channels[i01 + 1], domain_channels[i11 + 1], tx)
			var b1: float = lerpf(domain_channels[i01 + 2], domain_channels[i11 + 2], tx)
			var a1: float = lerpf(domain_channels[i01 + 3], domain_channels[i11 + 3], tx)
			var add_r: float = lerpf(r0, r1, ty)
			var add_g: float = lerpf(g0, g1, ty)
			var add_b: float = lerpf(b0, b1, ty)
			var add_a: float = lerpf(a0, a1, ty)
			if add_r <= 0.0001 and add_g <= 0.0001 and add_b <= 0.0001 and add_a <= 0.0001:
				continue
			var c: Color = _influence_image.get_pixel(x_full, y_full)
			c.r = minf(max_per_pixel, c.r + add_r)
			c.g = minf(max_per_pixel, c.g + add_g)
			c.b = minf(max_per_pixel, c.b + add_b)
			c.a = minf(max_per_pixel, c.a + add_a)
			_influence_image.set_pixel(x_full, y_full, c)

func _pulse_gain_for_key(key: String, now_ms: int) -> Dictionary:
	if key.is_empty() or not _pulses_by_key.has(key):
		return {"radius_boost": 0.0, "strength_boost": 0.0}
	var pulse_any: Variant = _pulses_by_key.get(key, {})
	if typeof(pulse_any) != TYPE_DICTIONARY:
		return {"radius_boost": 0.0, "strength_boost": 0.0}
	var pulse: Dictionary = pulse_any as Dictionary
	var start_ms: int = int(pulse.get("started_ms", now_ms))
	var end_ms: int = int(pulse.get("end_ms", now_ms))
	var total_ms: int = maxi(1, end_ms - start_ms)
	var remaining: float = clampf(float(end_ms - now_ms) / float(total_ms), 0.0, 1.0)
	return {
		"radius_boost": float(_config.capture_pulse_radius_boost) * remaining,
		"strength_boost": float(_config.capture_pulse_strength_boost) * remaining
	}

func _ensure_blob_capacity(target_count: int) -> void:
	if _influence_canvas == null:
		return
	while _blob_pool.size() < target_count:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.centered = true
		sprite.texture = _blob_texture
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = BLOB_SHADER
		sprite.material = mat
		sprite.visible = false
		_influence_canvas.add_child(sprite)
		_blob_pool.append(sprite)

func _apply_blob_sprite(
	sprite: Sprite2D,
	uv: Vector2,
	texture_size: int,
	radius_px: float,
	strength: float,
	owner_index: int
) -> void:
	sprite.visible = true
	sprite.position = Vector2(uv.x * float(texture_size), uv.y * float(texture_size))
	var scale_value: float = maxf(0.01, (radius_px * 2.0) / float(DEFAULT_BLOB_TEX_SIZE))
	sprite.scale = Vector2(scale_value, scale_value)
	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("channel_mask", _channel_mask_for_owner(owner_index))
	mat.set_shader_parameter("strength", maxf(0.0, strength))

func _channel_mask_for_owner(owner_index: int) -> Color:
	match owner_index:
		0:
			return Color(1.0, 0.0, 0.0, 0.0)
		1:
			return Color(0.0, 1.0, 0.0, 0.0)
		2:
			return Color(0.0, 0.0, 1.0, 0.0)
		3:
			return Color(0.0, 0.0, 0.0, 1.0)
		_:
			return Color(0.0, 0.0, 0.0, 0.0)

func _update_maturity_from_model(render_model: Dictionary) -> void:
	if _config == null:
		return
	var clock_any: Variant = render_model.get("clock", {})
	var elapsed_ms: int = 0
	if typeof(clock_any) == TYPE_DICTIONARY:
		elapsed_ms = int((clock_any as Dictionary).get("elapsed_ms", 0))
	_set_maturity_from_elapsed_ms(elapsed_ms)

func _update_maturity_from_ops_state() -> void:
	if _config == null:
		return
	var elapsed_ms: int = _ops_match_elapsed_ms()
	_set_maturity_from_elapsed_ms(elapsed_ms)

func _ops_match_elapsed_ms() -> int:
	var loop_any: Variant = Engine.get_main_loop()
	if not (loop_any is SceneTree):
		return 0
	var tree: SceneTree = loop_any as SceneTree
	if tree == null or tree.root == null:
		return 0
	var ops: Node = tree.root.get_node_or_null("OpsState")
	if ops == null:
		return 0
	var elapsed_any: Variant = ops.get("match_elapsed_ms")
	return maxi(0, int(elapsed_any))

func _set_maturity_from_elapsed_ms(elapsed_ms: int) -> void:
	var duration_sec: float = maxf(1.0, float(_config.global_maturity_seconds))
	var t: float = clampf(float(elapsed_ms) / (duration_sec * 1000.0), 0.0, 1.0)
	var maturity: float = _apply_growth_curve(t)
	if absf(maturity - _last_maturity) < 0.001:
		return
	_last_maturity = maturity
	if _floor_material != null:
		_floor_material.set_shader_parameter("maturity", maturity)

func _apply_growth_curve(t: float) -> float:
	var clamped_t: float = clampf(t, 0.0, 1.0)
	if _config == null:
		return clamped_t
	match int(_config.growth_curve):
		FloorInfluenceConfig.GrowthCurve.EASE_OUT:
			return 1.0 - pow(1.0 - clamped_t, 2.0)
		FloorInfluenceConfig.GrowthCurve.EASE_IN_OUT:
			if clamped_t < 0.5:
				return 2.0 * clamped_t * clamped_t
			return 1.0 - pow(-2.0 * clamped_t + 2.0, 2.0) / 2.0
		_:
			return clamped_t

func world_to_uv(world_pos: Vector2) -> Vector2:
	if _floor_bounds.size.x <= 0.01 or _floor_bounds.size.y <= 0.01:
		return Vector2.ZERO
	var min_x: float = _floor_bounds.position.x
	var max_x: float = _floor_bounds.position.x + _floor_bounds.size.x
	var min_y: float = _floor_bounds.position.y
	var max_y: float = _floor_bounds.position.y + _floor_bounds.size.y
	var u: float = inverse_lerp(min_x, max_x, world_pos.x)
	var v: float = inverse_lerp(min_y, max_y, world_pos.y)
	return Vector2(u, v)

func uv_to_tex(uv: Vector2) -> Vector2i:
	if _influence_viewport == null:
		return Vector2i.ZERO
	var width: int = int(_influence_viewport.size.x)
	var height: int = int(_influence_viewport.size.y)
	return Vector2i(
		int(clampf(uv.x, 0.0, 1.0) * float(maxi(1, width - 1))),
		int(clampf(uv.y, 0.0, 1.0) * float(maxi(1, height - 1)))
	)

func _ensure_debug_overlay() -> void:
	if _debug_layer == null or not is_instance_valid(_debug_layer):
		_debug_layer = CanvasLayer.new()
		_debug_layer.name = "InfluenceDebugLayer"
		add_child(_debug_layer)
	if _debug_panel == null or not is_instance_valid(_debug_panel):
		_debug_panel = PanelContainer.new()
		_debug_panel.name = "InfluenceDebugPanel"
		_debug_panel.anchor_left = 0.0
		_debug_panel.anchor_top = 0.0
		_debug_panel.anchor_right = 0.0
		_debug_panel.anchor_bottom = 0.0
		_debug_panel.offset_left = 16.0
		_debug_panel.offset_top = 16.0
		_debug_panel.offset_right = 248.0
		_debug_panel.offset_bottom = 248.0
		_debug_layer.add_child(_debug_panel)
	if _debug_texture_rect == null or not is_instance_valid(_debug_texture_rect):
		_debug_texture_rect = TextureRect.new()
		_debug_texture_rect.name = "InfluenceDebugTexture"
		_debug_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_debug_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_debug_texture_rect.anchor_left = 0.0
		_debug_texture_rect.anchor_top = 0.0
		_debug_texture_rect.anchor_right = 1.0
		_debug_texture_rect.anchor_bottom = 1.0
		_debug_texture_rect.offset_left = 6.0
		_debug_texture_rect.offset_top = 6.0
		_debug_texture_rect.offset_right = -6.0
		_debug_texture_rect.offset_bottom = -6.0
		_debug_panel.add_child(_debug_texture_rect)
	if _influence_texture != null:
		_debug_texture_rect.texture = _influence_texture
	elif _influence_viewport != null:
		_debug_texture_rect.texture = _influence_viewport.get_texture()

func _build_blob_texture(size_px: int) -> Texture2D:
	var dim: int = maxi(16, size_px)
	var img: Image = Image.create(dim, dim, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(float(dim - 1), float(dim - 1)) * 0.5
	var radius: float = float(dim) * 0.5
	for y in range(dim):
		for x in range(dim):
			var p: Vector2 = Vector2(float(x), float(y))
			var d: float = center.distance_to(p) / maxf(0.001, radius)
			var t: float = clampf(1.0 - d, 0.0, 1.0)
			var alpha: float = t * t * (3.0 - 2.0 * t)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)

func _build_noise_texture(size_px: int) -> Texture2D:
	var dim: int = maxi(8, size_px)
	var img: Image = Image.create(dim, dim, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x51F10E
	for y in range(dim):
		for x in range(dim):
			var n: float = rng.randf_range(0.35, 0.65)
			img.set_pixel(x, y, Color(n, n, n, 1.0))
	return ImageTexture.create_from_image(img)

func _remove_floor_material_if_present() -> void:
	if _floor_renderer == null:
		return
	var base_sprite: Sprite2D = _floor_renderer.get_base_floor_sprite()
	var overlay_sprite: Sprite2D = _floor_renderer.get_overlay_floor_sprite()
	if base_sprite != null and base_sprite.material == _floor_material:
		base_sprite.material = null
	if overlay_sprite != null and overlay_sprite.material == _floor_material:
		overlay_sprite.material = null

func _compute_runtime_enabled() -> bool:
	if _config == null:
		return true
	if not bool(_config.enabled):
		return false
	if bool(_config.force_enable_on_apple):
		return true
	if not bool(_config.disable_on_apple_forward_plus):
		return true
	var adapter: String = _video_adapter_name().to_lower()
	var renderer: String = _render_method_name().to_lower()
	var is_apple_gpu: bool = adapter.find("apple") != -1
	var is_mobile: bool = renderer.find("mobile") != -1
	var is_compatibility: bool = renderer.find("compatibility") != -1
	var should_disable_for_renderer: bool = not is_mobile and not is_compatibility
	if is_apple_gpu and should_disable_for_renderer:
		return false
	return true

func _video_adapter_name() -> String:
	return str(RenderingServer.get_video_adapter_name())

func _render_method_name() -> String:
	var key: String = "rendering/renderer/rendering_method"
	if not ProjectSettings.has_setting(key):
		return "forward_plus"
	return str(ProjectSettings.get_setting(key, "forward_plus"))

func _env_flag(name: String) -> bool:
	var raw: String = OS.get_environment(name).strip_edges().to_lower()
	if raw == "":
		return false
	return raw == "1" or raw == "true" or raw == "yes" or raw == "on"

func _run_visibility_probe_if_enabled() -> void:
	if _config == null:
		return
	var probe_enabled: bool = bool(_config.debug_magenta_probe) or _env_flag("SF_FLOOR_MAGENTA_PROBE")
	if not probe_enabled:
		return
	var candidates: Array = _collect_floor_sprite_candidates()
	for candidate_any in candidates:
		if not (candidate_any is CanvasItem):
			continue
		var sprite: CanvasItem = candidate_any as CanvasItem
		if sprite == null or not is_instance_valid(sprite):
			continue
		var tex_path: String = ""
		if sprite is Sprite2D:
			var sprite_tex: Texture2D = (sprite as Sprite2D).texture
			if sprite_tex != null:
				tex_path = str(sprite_tex.resource_path)
		SFLog.warn("FLOOR_INFLUENCE_PROBE", {
			"path": str(sprite.get_path()),
			"visible": sprite.visible,
			"z_index": sprite.z_index,
			"modulate": sprite.modulate,
			"tex": tex_path
		})
		_queue_magenta_probe(sprite)

func _collect_floor_sprite_candidates() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var target_nodes: Array = []
	if _floor_renderer != null:
		target_nodes.append(_floor_renderer)
		var base_sprite: Sprite2D = _floor_renderer.get_base_floor_sprite()
		var overlay_sprite: Sprite2D = _floor_renderer.get_overlay_floor_sprite()
		if base_sprite != null:
			target_nodes.append(base_sprite)
		if overlay_sprite != null:
			target_nodes.append(overlay_sprite)
	if _material_target != null:
		target_nodes.append(_material_target)
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null:
		_collect_floor_sprite_candidates_recursive(tree.root, target_nodes)
	for node_any in target_nodes:
		if not (node_any is CanvasItem):
			continue
		var sprite: CanvasItem = node_any as CanvasItem
		if sprite == null or not is_instance_valid(sprite):
			continue
		var key: int = sprite.get_instance_id()
		if seen.has(key):
			continue
		seen[key] = true
		out.append(sprite)
	return out

func _collect_floor_sprite_candidates_recursive(node: Node, out_nodes: Array) -> void:
	if node == null:
		return
	if node is CanvasItem and str(node.name).to_lower().find("floor") != -1:
		out_nodes.append(node)
	if node is Sprite2D:
		var sprite: Sprite2D = node as Sprite2D
		var tex_path: String = ""
		if sprite.texture != null:
			tex_path = str(sprite.texture.resource_path).to_lower()
		var node_name: String = str(sprite.name).to_lower()
		var is_floor_name: bool = node_name.find("floor") != -1
		var is_floor_tex: bool = tex_path.find("arena_floor") != -1 or tex_path.find("floor_sprite_final") != -1
		if is_floor_name or is_floor_tex:
			out_nodes.append(sprite)
	for child in node.get_children():
		if child is Node:
			_collect_floor_sprite_candidates_recursive(child as Node, out_nodes)

func _queue_magenta_probe(sprite: CanvasItem) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var duration_sec: float = 1.2
	if _config != null:
		duration_sec = maxf(0.1, float(_config.debug_magenta_probe_duration_sec))
	var end_ms: int = Time.get_ticks_msec() + int(duration_sec * 1000.0)
	var shader_mat: ShaderMaterial = null
	if sprite is Sprite2D:
		shader_mat = (sprite as Sprite2D).material as ShaderMaterial
	if shader_mat != null and shader_mat.shader == FLOOR_SHADER:
		var old_force_raw: Variant = shader_mat.get_shader_parameter("debug_force_magenta")
		var old_force: bool = false
		if typeof(old_force_raw) == TYPE_BOOL:
			old_force = old_force_raw as bool
		_probe_restore.append({
			"mode": "shader",
			"shader_mat": shader_mat,
			"old_force": old_force,
			"end_ms": end_ms
		})
		shader_mat.set_shader_parameter("debug_force_magenta", true)
	if sprite is Sprite2D:
		var sprite2d: Sprite2D = sprite as Sprite2D
		if _probe_magenta_texture == null:
			_probe_magenta_texture = _build_solid_texture(Color(1.0, 0.0, 1.0, 1.0), 8)
		_probe_restore.append({
			"mode": "texture",
			"sprite": sprite2d,
			"old_texture": sprite2d.texture,
			"end_ms": end_ms
		})
		sprite2d.texture = _probe_magenta_texture
		return
	_probe_restore.append({
		"mode": "modulate",
		"sprite": sprite,
		"modulate": sprite.modulate,
		"end_ms": end_ms
	})
	sprite.modulate = Color(1.0, 0.0, 1.0, 1.0)

func _tick_magenta_probe_restore() -> void:
	if _probe_restore.is_empty():
		return
	var now_ms: int = Time.get_ticks_msec()
	var keep: Array = []
	for entry_any in _probe_restore:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var mode: String = str(entry.get("mode", "modulate"))
		var end_ms: int = int(entry.get("end_ms", 0))
		if mode == "shader":
			var mat_any: Variant = entry.get("shader_mat", null)
			if not (mat_any is ShaderMaterial):
				continue
			var mat: ShaderMaterial = mat_any as ShaderMaterial
			if mat == null or not is_instance_valid(mat):
				continue
			if now_ms >= end_ms:
				var old_force_any: Variant = entry.get("old_force", false)
				var old_force: bool = false
				if typeof(old_force_any) == TYPE_BOOL:
					old_force = old_force_any as bool
				mat.set_shader_parameter("debug_force_magenta", old_force)
			else:
				keep.append(entry)
			continue
		if mode == "texture":
			var sprite_tex_any: Variant = entry.get("sprite", null)
			if not (sprite_tex_any is Sprite2D):
				continue
			var sprite_tex: Sprite2D = sprite_tex_any as Sprite2D
			if sprite_tex == null or not is_instance_valid(sprite_tex):
				continue
			if now_ms >= end_ms:
				var old_tex_any: Variant = entry.get("old_texture", null)
				if old_tex_any is Texture2D:
					sprite_tex.texture = old_tex_any as Texture2D
				else:
					sprite_tex.texture = null
			else:
				keep.append(entry)
			continue
		var sprite_any: Variant = entry.get("sprite", null)
		if not (sprite_any is CanvasItem):
			continue
		var sprite: CanvasItem = sprite_any as CanvasItem
		if sprite == null or not is_instance_valid(sprite):
			continue
		if now_ms >= end_ms:
			var old_modulate: Color = entry.get("modulate", Color(1.0, 1.0, 1.0, 1.0)) as Color
			sprite.modulate = old_modulate
		else:
			keep.append(entry)
	_probe_restore = keep

func _build_solid_texture(color: Color, size_px: int) -> Texture2D:
	var dim: int = maxi(2, size_px)
	var img: Image = Image.create(dim, dim, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
