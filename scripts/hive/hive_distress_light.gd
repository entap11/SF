class_name HiveDistressLight
extends Node2D

const HiveDistressRules := preload("res://scripts/hive/hive_distress_rules.gd")

const RECOVERY_FADE_SEC: float = 0.18
const CAPTURE_SUPPRESS_SEC: float = 0.12
const LOCAL_Z_INDEX: int = 1
const MIN_FOOTPRINT: Vector2 = Vector2(40.0, 52.0)
const PLUME_HEIGHT_SCALE: float = 0.82
const PLUME_WIDTH_SCALE: float = 0.72
const PARTICLE_REACH_SCALE: float = 0.78

var _configured: bool = false
var _stable_seed: int = 1
var _owner_color: Color = Color.WHITE
var _motion_mode: String = "full"
var _hostile_capture_pressure: bool = false
var _pre_transition_size: Vector2 = MIN_FOOTPRINT
var _current_size: Vector2 = MIN_FOOTPRINT

var _critical_active: bool = false
var _critical_base_intensity: float = 0.0
var _target_base_intensity: float = 0.0
var _pressure_hold_remaining: float = 0.0
var _last_pressure_transition: String = HiveDistressRules.PRESSURE_RESET
var _critical_activation_serial: int = 0
var _pulse_index: int = 0
var _next_surge_in: float = 0.0
var _surge_elapsed: float = -1.0
var _surge_duration: float = 0.0
var _surge_strength: float = 0.0

var _burst_kind: String = HiveDistressRules.BURST_NONE
var _burst_profile: Dictionary = {}
var _burst_elapsed: float = 0.0
var _burst_serial: int = 0
var _minor_rupture_count: int = 0
var _major_rupture_count: int = 0
var _critical_entry_count: int = 0

var _capture_suppress_remaining: float = 0.0
var _growth_suppressed: bool = false
var _lifecycle_suspended: bool = false
var _presentation_t: float = 0.0

func _ready() -> void:
	# FxLayer is Z 18, so this resolves to Z 19: above the hive body while
	# remaining behind the Z 20 power projection and Z 24 budget indicators.
	z_index = LOCAL_Z_INDEX
	var additive_material := CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive_material
	set_process(false)
	queue_redraw()

func apply_presentation(
	hive_id: int,
	outlet_anchor: Vector2,
	owner_color: Color,
	motion_mode: String,
	presentation: Dictionary,
	hostile_capture_pressure: bool = false
) -> void:
	var was_configured: bool = _configured
	_configured = true
	_stable_seed = maxi(1, hive_id)
	position = outlet_anchor
	_owner_color = owner_color
	_motion_mode = _sanitize_motion_mode(motion_mode)
	_hostile_capture_pressure = hostile_capture_pressure
	_pre_transition_size = _sanitize_footprint(
		presentation.get("pre_transition_size", _current_size) as Vector2
	)
	_current_size = _sanitize_footprint(
		presentation.get("current_size", _pre_transition_size) as Vector2
	)

	var pressure_transition: String = str(
		presentation.get("pressure_transition", HiveDistressRules.PRESSURE_HOLD)
	)
	var reset_requested: bool = (
		bool(presentation.get("reset_transients", false))
		or pressure_transition == HiveDistressRules.PRESSURE_RESET
	)
	var was_critical: bool = _critical_active
	if reset_requested:
		_clear_transients()
		_critical_active = false
		_critical_base_intensity = 0.0
		_target_base_intensity = 0.0
		_pressure_hold_remaining = 0.0
		if was_configured:
			_capture_suppress_remaining = CAPTURE_SUPPRESS_SEC

	_last_pressure_transition = pressure_transition
	match pressure_transition:
		HiveDistressRules.PRESSURE_TRIGGER:
			_critical_active = true
			_pressure_hold_remaining = HiveDistressRules.PRESSURE_HOLD_SEC
		HiveDistressRules.PRESSURE_CLEAR:
			_critical_active = false
			_pressure_hold_remaining = 0.0
		HiveDistressRules.PRESSURE_RESET:
			_critical_active = false
			_pressure_hold_remaining = 0.0
		HiveDistressRules.PRESSURE_HOLD:
			pass
		_:
			_critical_active = false
			_pressure_hold_remaining = 0.0
	_target_base_intensity = 1.0 if _critical_active else 0.0
	if _critical_active and not was_critical:
		_critical_activation_serial += 1
		_pulse_index = 0
		_surge_elapsed = -1.0
		_next_surge_in = maxf(
			0.0,
			float(presentation.get("critical_surge_delay", 0.0))
		)
		if _next_surge_in <= 0.0:
			_next_surge_in = _next_critical_interval()
	elif not _critical_active and was_critical:
		_surge_elapsed = -1.0
		_next_surge_in = 0.0
		if _burst_kind == HiveDistressRules.BURST_CRITICAL_ENTRY:
			_clear_burst()

	var requested_burst: String = str(
		presentation.get("burst_kind", HiveDistressRules.BURST_NONE)
	)
	if requested_burst != HiveDistressRules.BURST_NONE:
		_start_burst(requested_burst)
	elif bool(presentation.get("play_pressure_entry", false)) and not was_critical:
		_start_burst(HiveDistressRules.BURST_CRITICAL_ENTRY)

	if _growth_suppressed or _capture_suppress_remaining > 0.0:
		_target_base_intensity = 0.0
	_update_processing()
	queue_redraw()

func set_growth_suppressed(suppressed: bool) -> void:
	if _growth_suppressed == suppressed:
		return
	_growth_suppressed = suppressed
	if suppressed:
		_clear_transients()
		_critical_active = false
		_pressure_hold_remaining = 0.0
		_critical_base_intensity = 0.0
		_target_base_intensity = 0.0
	else:
		_target_base_intensity = 1.0 if _critical_active else 0.0
		if _critical_active:
			_next_surge_in = _next_critical_interval()
	_update_processing()
	queue_redraw()

func set_lifecycle_suspended(suspended: bool) -> void:
	if _lifecycle_suspended == suspended:
		return
	_lifecycle_suspended = suspended
	_update_processing()
	queue_redraw()

func reset_presentation() -> void:
	_clear_transients()
	_critical_active = false
	_critical_base_intensity = 0.0
	_target_base_intensity = 0.0
	_pressure_hold_remaining = 0.0
	_last_pressure_transition = HiveDistressRules.PRESSURE_RESET
	_capture_suppress_remaining = 0.0
	_growth_suppressed = false
	_configured = false
	visible = false
	set_process(false)
	queue_redraw()

func _start_burst(kind: String) -> void:
	var profile: Dictionary = HiveDistressRules.profile_for_burst(kind)
	if profile.is_empty():
		return
	_burst_kind = kind
	_burst_profile = profile
	_burst_elapsed = 0.0
	_burst_serial += 1
	match kind:
		HiveDistressRules.BURST_MINOR_RUPTURE:
			_minor_rupture_count += 1
		HiveDistressRules.BURST_MAJOR_RUPTURE:
			_major_rupture_count += 1
		HiveDistressRules.BURST_CRITICAL_ENTRY:
			_critical_entry_count += 1
	if _critical_active:
		_next_surge_in = maxf(
			_next_surge_in,
			float(profile.get("critical_handoff_sec", 0.0))
		)

func _clear_burst() -> void:
	_burst_kind = HiveDistressRules.BURST_NONE
	_burst_profile = {}
	_burst_elapsed = 0.0

func _clear_transients() -> void:
	_clear_burst()
	_surge_elapsed = -1.0
	_surge_duration = 0.0
	_surge_strength = 0.0
	_next_surge_in = 0.0

func _process(delta: float) -> void:
	var safe_delta: float = maxf(0.0, delta)
	if _capture_suppress_remaining > 0.0:
		_capture_suppress_remaining = maxf(
			0.0,
			_capture_suppress_remaining - safe_delta
		)
		if _capture_suppress_remaining <= 0.0 and not _growth_suppressed:
			_target_base_intensity = 1.0 if _critical_active else 0.0

	if not _lifecycle_suspended:
		if _critical_active and _pressure_hold_remaining > 0.0:
			_pressure_hold_remaining = maxf(0.0, _pressure_hold_remaining - safe_delta)
			if _pressure_hold_remaining <= 0.0:
				_critical_active = false
				_target_base_intensity = 0.0
				_surge_elapsed = -1.0
				_next_surge_in = 0.0
				if _burst_kind == HiveDistressRules.BURST_CRITICAL_ENTRY:
					_clear_burst()
		if _motion_mode == "full":
			_presentation_t += safe_delta
		elif _motion_mode == "reduced":
			_presentation_t += safe_delta * 0.32
		_update_burst(safe_delta)
		_update_critical_surge(safe_delta)

	var desired_base: float = _target_base_intensity
	if _growth_suppressed or _capture_suppress_remaining > 0.0:
		desired_base = 0.0
	var rate: float = 4.6 if desired_base > _critical_base_intensity else 1.0 / RECOVERY_FADE_SEC
	_critical_base_intensity = move_toward(
		_critical_base_intensity,
		desired_base,
		safe_delta * rate
	)
	visible = _has_visible_energy()
	queue_redraw()
	_update_processing()

func _update_burst(delta: float) -> void:
	if _burst_kind == HiveDistressRules.BURST_NONE:
		return
	_burst_elapsed += delta
	var duration: float = float(_burst_profile.get("duration_sec", 0.0))
	if _burst_elapsed >= duration:
		_clear_burst()

func _update_critical_surge(delta: float) -> void:
	if not _critical_active or _growth_suppressed or _capture_suppress_remaining > 0.0:
		_surge_elapsed = -1.0
		return
	if _motion_mode == "none":
		return
	if _surge_elapsed >= 0.0:
		_surge_elapsed += delta
		if _surge_elapsed >= _surge_duration:
			_surge_elapsed = -1.0
			_next_surge_in = _next_critical_interval()
		return
	_next_surge_in -= delta
	if _next_surge_in <= 0.0:
		_begin_critical_surge()

func _begin_critical_surge() -> void:
	_pulse_index += 1
	var duration_mix: float = _sequence_hash(701 + _pulse_index * 17)
	_surge_duration = lerpf(
		HiveDistressRules.CRITICAL_SURGE_MIN_DURATION_SEC,
		HiveDistressRules.CRITICAL_SURGE_MAX_DURATION_SEC,
		duration_mix
	)
	var strong_period: int = 3 + int(floor(_sequence_hash(743) * 3.0))
	var strong: bool = _pulse_index % maxi(3, strong_period) == 0
	_surge_strength = 1.0 if strong else lerpf(
		0.58,
		0.82,
		_sequence_hash(811 + _pulse_index * 23)
	)
	_surge_elapsed = 0.0

func _next_critical_interval() -> float:
	var mix_value: float = _sequence_hash(907 + (_pulse_index + 1) * 29)
	var interval: float = lerpf(
		HiveDistressRules.CRITICAL_SURGE_MIN_INTERVAL_SEC,
		HiveDistressRules.CRITICAL_SURGE_MAX_INTERVAL_SEC,
		mix_value
	)
	return interval * (1.35 if _motion_mode == "reduced" else 1.0)

func _update_processing() -> void:
	var intensity_moving: bool = not is_equal_approx(
		_critical_base_intensity,
		_target_base_intensity
	)
	var animated_critical: bool = (
		_critical_active
		and _motion_mode != "none"
		and not _lifecycle_suspended
		and not _growth_suppressed
		and _capture_suppress_remaining <= 0.0
	)
	if _lifecycle_suspended:
		set_process(false)
		visible = _has_visible_energy()
		return
	var should_process: bool = (
		_capture_suppress_remaining > 0.0
		or _pressure_hold_remaining > 0.0
		or _burst_kind != HiveDistressRules.BURST_NONE
		or _surge_elapsed >= 0.0
		or intensity_moving
		or animated_critical
	)
	set_process(should_process)
	visible = _has_visible_energy()

func _has_visible_energy() -> bool:
	if _growth_suppressed or _capture_suppress_remaining > 0.0:
		return false
	return (
		_critical_base_intensity > 0.001
		or _burst_kind != HiveDistressRules.BURST_NONE
		or _surge_elapsed >= 0.0
	)

func _draw() -> void:
	if not _has_visible_energy():
		return
	var hot_color: Color = _owner_color.lerp(Color.WHITE, 0.55)
	var core_color: Color = hot_color.lerp(Color.WHITE, 0.70)
	if _critical_base_intensity > 0.001:
		_draw_critical_base(hot_color)
	if _burst_kind != HiveDistressRules.BURST_NONE:
		_draw_burst(hot_color, core_color)
	if _surge_elapsed >= 0.0 and _surge_duration > 0.0:
		_draw_critical_surge(hot_color, core_color)

func _draw_critical_base(hot_color: Color) -> void:
	var intensity: float = _critical_base_intensity
	var instability: float = 0.5
	if _motion_mode != "none" and not _lifecycle_suspended:
		instability = _smooth_noise(41, 6.2)
	var vent_height: float = (
		_current_size.y
		* lerpf(0.18, 0.42, instability)
		* PLUME_HEIGHT_SCALE
	)
	var vent_color: Color = hot_color
	vent_color.a = intensity * 0.24
	_draw_plume(
		vent_height,
		_current_size.x * 0.10 * PLUME_WIDTH_SCALE,
		vent_color,
		53,
		2
	)

func _draw_burst(hot_color: Color, core_color: Color) -> void:
	var duration: float = maxf(0.001, float(_burst_profile.get("duration_sec", 0.001)))
	var progress: float = clampf(_burst_elapsed / duration, 0.0, 1.0)
	var energy: float = 1.0 - smoothstep(0.12, 1.0, progress)
	var envelope: float = sin(progress * PI)
	var source_height: float = maxf(MIN_FOOTPRINT.y, _pre_transition_size.y)
	var source_width: float = maxf(MIN_FOOTPRINT.x, _pre_transition_size.x)
	var peak_height: float = source_height * float(_burst_profile.get("height_scale", 1.0))
	var major: bool = _burst_kind == HiveDistressRules.BURST_MAJOR_RUPTURE

	var plume_color: Color = hot_color
	plume_color.a = (0.17 if major else 0.11) + ((0.40 if major else 0.31) * energy)
	var layer_count: int = int(_burst_profile.get("plume_layers", 2))
	if _motion_mode != "full":
		layer_count = mini(2, layer_count)
	_draw_plume(
		peak_height * maxf(0.22, envelope) * PLUME_HEIGHT_SCALE,
		source_width * lerpf(0.18, 0.34, energy) * PLUME_WIDTH_SCALE,
		plume_color,
		101 + _burst_serial * 7,
		layer_count
	)

	if _motion_mode == "none":
		return
	var spark_count: int = int(_burst_profile.get("spark_count", 0))
	var fragment_count: int = int(_burst_profile.get("fragment_count", 0))
	if _motion_mode == "reduced":
		spark_count = mini(4, spark_count)
		fragment_count = mini(1, fragment_count)
	_draw_radial_sparks(
		spark_count,
		progress,
		source_width * PARTICLE_REACH_SCALE,
		source_height * PARTICLE_REACH_SCALE,
		hot_color,
		1201 + _burst_serial * 31
	)
	_draw_fragments(
		fragment_count,
		progress,
		source_width * PARTICLE_REACH_SCALE,
		source_height * PARTICLE_REACH_SCALE,
		core_color,
		1601 + _burst_serial * 37
	)

func _draw_critical_surge(hot_color: Color, core_color: Color) -> void:
	var progress: float = clampf(_surge_elapsed / maxf(0.001, _surge_duration), 0.0, 1.0)
	var envelope: float = sin(progress * PI)
	var energy: float = (1.0 - smoothstep(0.18, 1.0, progress)) * _surge_strength
	var plume_color: Color = hot_color
	plume_color.a = 0.16 + (0.42 * energy)
	_draw_plume(
		(
			_current_size.y
			* HiveDistressRules.CRITICAL_SURGE_HEIGHT_SCALE
			* maxf(0.16, envelope)
			* _surge_strength
			* PLUME_HEIGHT_SCALE
		),
		_current_size.x * lerpf(0.15, 0.34, energy) * PLUME_WIDTH_SCALE,
		plume_color,
		2003 + _pulse_index * 43,
		3
	)
	if _motion_mode != "full":
		return
	_draw_radial_sparks(
		HiveDistressRules.CRITICAL_MAX_SPARKS,
		progress,
		_current_size.x * PARTICLE_REACH_SCALE,
		_current_size.y * PARTICLE_REACH_SCALE,
		hot_color,
		2309 + _pulse_index * 47
	)
	_draw_fragments(
		HiveDistressRules.CRITICAL_MAX_FRAGMENTS,
		progress,
		_current_size.x * PARTICLE_REACH_SCALE,
		_current_size.y * PARTICLE_REACH_SCALE,
		core_color,
		2707 + _pulse_index * 53
	)

func _draw_plume(
	height: float,
	half_width: float,
	color: Color,
	channel: int,
	layer_count: int
) -> void:
	for layer_index in range(maxi(1, layer_count)):
		var layer_t: float = float(layer_index) / float(maxi(1, layer_count - 1))
		var layer_height: float = height * lerpf(1.0, 0.55, layer_t)
		var layer_width: float = half_width * lerpf(1.20, 0.34, layer_t)
		var layer_color: Color = color.lerp(Color.WHITE, layer_t * 0.62)
		layer_color.a *= lerpf(0.48, 1.0, layer_t)
		_draw_plume_layer(layer_height, layer_width, layer_color, channel + layer_index * 19)

func _draw_plume_layer(height: float, half_width: float, color: Color, channel: int) -> void:
	const SEGMENT_COUNT: int = 5
	var bend: float = lerpf(-height * 0.09, height * 0.09, _smooth_noise(channel, 3.9))
	for segment_index in range(SEGMENT_COUNT):
		var lower_t: float = float(segment_index) / float(SEGMENT_COUNT)
		var upper_t: float = float(segment_index + 1) / float(SEGMENT_COUNT)
		var lower_width: float = maxf(0.6, half_width * lerpf(1.0, 0.18, lower_t))
		var upper_width: float = maxf(0.4, half_width * lerpf(1.0, 0.18, upper_t))
		var lower_x: float = bend * lower_t + lerpf(-2.0, 2.0, _smooth_noise(channel + segment_index * 7, 4.6))
		var upper_x: float = bend * upper_t + lerpf(-2.0, 2.0, _smooth_noise(channel + segment_index * 11, 5.1))
		var segment_color: Color = color
		segment_color.a *= lerpf(1.0, 0.26, upper_t)
		var points := PackedVector2Array([
			Vector2(lower_x - lower_width, -height * lower_t),
			Vector2(upper_x - upper_width, -height * upper_t),
			Vector2(upper_x + upper_width, -height * upper_t),
			Vector2(lower_x + lower_width, -height * lower_t)
		])
		draw_colored_polygon(points, segment_color)

func _draw_radial_sparks(
	count: int,
	progress: float,
	width: float,
	height: float,
	color: Color,
	channel: int
) -> void:
	for spark_index in range(maxi(0, count)):
		var angle: float = lerpf(-PI * 0.92, -PI * 0.08, _hash01(channel + spark_index * 97))
		var travel: float = lerpf(0.44, 1.10, _hash01(channel + spark_index * 131))
		var distance := Vector2(width * travel, height * travel * 0.72) * progress
		var pos := Vector2(cos(angle) * distance.x, sin(angle) * distance.y)
		pos.y += height * 0.14 * progress * progress
		var spark_color: Color = color.lerp(Color.WHITE, 0.35)
		spark_color.a = (1.0 - progress) * lerpf(0.48, 0.90, _hash01(channel + spark_index * 173))
		var radius: float = lerpf(1.2, 2.6, _hash01(channel + spark_index * 211))
		draw_circle(pos, radius, spark_color)

func _draw_fragments(
	count: int,
	progress: float,
	width: float,
	height: float,
	color: Color,
	channel: int
) -> void:
	for fragment_index in range(maxi(0, count)):
		var direction: float = lerpf(-PI * 0.88, -PI * 0.12, _hash01(channel + fragment_index * 83))
		var distance: float = width * lerpf(0.42, 1.18, _hash01(channel + fragment_index * 127)) * progress
		var pos := Vector2(cos(direction), sin(direction) * 0.72) * distance
		pos.y += height * 0.24 * progress * progress
		var size: float = lerpf(2.4, 5.2, _hash01(channel + fragment_index * 179))
		var fragment_color: Color = color
		fragment_color.a = (1.0 - progress) * 0.82
		var points := PackedVector2Array([
			pos + Vector2(0.0, -size),
			pos + Vector2(size * 0.72, size * 0.52),
			pos + Vector2(-size * 0.62, size * 0.42)
		])
		draw_colored_polygon(points, fragment_color)

func _sanitize_footprint(raw: Vector2) -> Vector2:
	return Vector2(
		maxf(MIN_FOOTPRINT.x, absf(raw.x)),
		maxf(MIN_FOOTPRINT.y, absf(raw.y))
	)

func _smooth_noise(channel: int, rate: float) -> float:
	var sample_pos: float = _presentation_t * rate
	var sample_index: int = int(floor(sample_pos))
	var mix_t: float = smoothstep(0.0, 1.0, sample_pos - float(sample_index))
	var a: float = _hash01(_stable_seed * 4099 + channel * 257 + sample_index)
	var b: float = _hash01(_stable_seed * 4099 + channel * 257 + sample_index + 1)
	return lerpf(a, b, mix_t)

func _sequence_hash(channel: int) -> float:
	return _hash01(
		_stable_seed * 4099
		+ _critical_activation_serial * 911
		+ channel * 257
	)

static func _hash01(seed: int) -> float:
	var value: int = seed
	value = int((value ^ (value >> 16)) * 0x45d9f3b)
	value = int((value ^ (value >> 16)) * 0x45d9f3b)
	value = value ^ (value >> 16)
	return float(value & 0x7fffffff) / 2147483647.0

static func _sanitize_motion_mode(mode: String) -> String:
	var normalized: String = mode.strip_edges().to_lower()
	if normalized == "full" or normalized == "reduced" or normalized == "none":
		return normalized
	return "full"

func set_debug_presentation_phase(
	burst_progress: float = -1.0,
	surge_progress: float = -1.0,
	pulse_index: int = 1
) -> void:
	if burst_progress >= 0.0 and _burst_kind != HiveDistressRules.BURST_NONE:
		if burst_progress >= 1.0:
			_clear_burst()
		else:
			var duration: float = float(_burst_profile.get("duration_sec", 0.0))
			_burst_elapsed = duration * clampf(burst_progress, 0.0, 0.999)
	if surge_progress >= 0.0 and _critical_active:
		_pulse_index = maxi(1, pulse_index)
		_surge_duration = lerpf(
			HiveDistressRules.CRITICAL_SURGE_MIN_DURATION_SEC,
			HiveDistressRules.CRITICAL_SURGE_MAX_DURATION_SEC,
			0.58
		)
		_surge_strength = 1.0 if _pulse_index % 4 == 0 else 0.72
		_surge_elapsed = _surge_duration * clampf(surge_progress, 0.0, 0.999)
	queue_redraw()
	_update_processing()

func get_debug_snapshot() -> Dictionary:
	var state_name: String = "normal"
	if _burst_kind != HiveDistressRules.BURST_NONE:
		state_name = _burst_kind
	elif _critical_active:
		state_name = "critical"
	return {
		"state": state_name,
		"burst_kind": _burst_kind,
		"critical_active": _critical_active,
		"pressure_active": _critical_active,
		"pressure_transition": _last_pressure_transition,
		"pressure_hold_remaining": _pressure_hold_remaining,
		"pressure_hold_sec": HiveDistressRules.PRESSURE_HOLD_SEC,
		"critical_base_intensity": _critical_base_intensity,
		"target_intensity": _target_base_intensity,
		"current_intensity": _critical_base_intensity,
		"hostile_capture_pressure": _hostile_capture_pressure,
		"capture_suppressed": _capture_suppress_remaining > 0.0,
		"growth_suppressed": _growth_suppressed,
		"lifecycle_suspended": _lifecycle_suspended,
		"motion_mode": _motion_mode,
		"pre_transition_size": _pre_transition_size,
		"current_size": _current_size,
		"minor_rupture_count": _minor_rupture_count,
		"major_rupture_count": _major_rupture_count,
		"critical_entry_count": _critical_entry_count,
		"pulse_index": _pulse_index,
		"surge_active": _surge_elapsed >= 0.0,
		"burst_elapsed": _burst_elapsed,
		"burst_duration": float(_burst_profile.get("duration_sec", 0.0)),
		"max_sparks": HiveDistressRules.MAJOR_SPARK_COUNT,
		"max_fragments": HiveDistressRules.MAJOR_FRAGMENT_COUNT,
		"max_active_pulses": HiveDistressRules.CRITICAL_MAX_ACTIVE_PULSES,
		"material_instance_id": material.get_instance_id() if material != null else 0,
		"child_count": get_child_count()
	}
