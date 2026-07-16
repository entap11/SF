class_name HiveDistressLight
extends Node2D

const HiveDistressRules := preload("res://scripts/hive/hive_distress_rules.gd")

const RECOVERY_FADE_SEC: float = 0.18
const CAPTURE_SUPPRESS_SEC: float = 0.12
const MAX_MOTES: int = 6
const CRITICAL_MOTES: int = 3
const IMMINENT_MOTES: int = 6

var _state: int = HiveDistressRules.STATE_NORMAL
var _viewer_owner_id: int = 0
var _owner_id: int = 0
var _power: int = 0
var _hostile_capture_pressure: bool = false
var _owner_color: Color = Color.WHITE
var _motion_mode: String = "full"
var _presentation_t: float = 0.0
var _target_intensity: float = 0.0
var _current_intensity: float = 0.0
var _capture_suppress_remaining: float = 0.0
var _growth_suppressed: bool = false
var _lifecycle_suspended: bool = false
var _configured: bool = false
var _stable_seed: int = 1

func _ready() -> void:
	z_index = 4
	var additive_material := CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive_material
	set_process(false)
	queue_redraw()

func apply_presentation(
	hive_id: int,
	viewer_owner_id: int,
	owner_id: int,
	power: int,
	hostile_capture_pressure: bool,
	outlet_anchor: Vector2,
	owner_color: Color,
	motion_mode: String
) -> void:
	var owner_changed: bool = _configured and owner_id != _owner_id
	_configured = true
	_stable_seed = maxi(1, hive_id)
	_viewer_owner_id = viewer_owner_id
	_owner_id = owner_id
	_power = power
	_hostile_capture_pressure = hostile_capture_pressure
	_owner_color = owner_color
	_motion_mode = _sanitize_motion_mode(motion_mode)
	position = outlet_anchor
	if owner_changed:
		_begin_capture_precedence()
	_update_target_state()

func set_growth_suppressed(suppressed: bool) -> void:
	if _growth_suppressed == suppressed:
		return
	_growth_suppressed = suppressed
	if suppressed:
		_current_intensity = 0.0
	_update_target_state()

func set_lifecycle_suspended(suspended: bool) -> void:
	if _lifecycle_suspended == suspended:
		return
	_lifecycle_suspended = suspended
	queue_redraw()
	_update_processing()

func reset_presentation() -> void:
	_state = HiveDistressRules.STATE_NORMAL
	_target_intensity = 0.0
	_current_intensity = 0.0
	_capture_suppress_remaining = 0.0
	_growth_suppressed = false
	_configured = false
	visible = false
	set_process(false)
	queue_redraw()

func _begin_capture_precedence() -> void:
	_capture_suppress_remaining = CAPTURE_SUPPRESS_SEC
	_state = HiveDistressRules.STATE_NORMAL
	_target_intensity = 0.0
	_current_intensity = 0.0
	queue_redraw()

func _update_target_state() -> void:
	_state = HiveDistressRules.next_state(
		_state,
		_viewer_owner_id,
		_owner_id,
		_power,
		_hostile_capture_pressure
	)
	var severity: float = HiveDistressRules.severity_for_power(_power)
	var base_intensity: float = lerpf(0.35, 1.0, severity)
	if _state == HiveDistressRules.STATE_IMMINENT:
		base_intensity = maxf(0.72, base_intensity)
	_target_intensity = base_intensity if _state != HiveDistressRules.STATE_NORMAL else 0.0
	if _growth_suppressed or _capture_suppress_remaining > 0.0:
		_target_intensity = 0.0
	_update_processing()
	queue_redraw()

func _process(delta: float) -> void:
	var safe_delta: float = maxf(0.0, delta)
	if not _lifecycle_suspended and _motion_mode == "full":
		_presentation_t += safe_delta
	if _capture_suppress_remaining > 0.0:
		_capture_suppress_remaining = maxf(0.0, _capture_suppress_remaining - safe_delta)
		if _capture_suppress_remaining <= 0.0:
			_update_target_state()
	var fade_rate: float = 1.0 / maxf(0.001, RECOVERY_FADE_SEC)
	if _target_intensity > _current_intensity:
		_current_intensity = move_toward(_current_intensity, _target_intensity, safe_delta * 5.5)
	else:
		_current_intensity = move_toward(_current_intensity, _target_intensity, safe_delta * fade_rate)
	visible = _current_intensity > 0.001
	queue_redraw()
	_update_processing()

func _update_processing() -> void:
	var should_process: bool = (
		_capture_suppress_remaining > 0.0
		or _target_intensity > 0.001
		or _current_intensity > 0.001
	)
	set_process(should_process)
	visible = should_process and (
		_current_intensity > 0.001
		or (_target_intensity > 0.001 and not _growth_suppressed)
	)

func _draw() -> void:
	var intensity: float = _current_intensity
	if intensity <= 0.001 or _growth_suppressed or _capture_suppress_remaining > 0.0:
		return
	var reduced: bool = _motion_mode != "full" or _lifecycle_suspended
	var hot_color: Color = _owner_color.lerp(Color.WHITE, 0.88)
	var core_color: Color = hot_color.lerp(Color.WHITE, 0.68)
	var variation: float = 0.5
	var width_variation: float = 0.5
	if not reduced:
		variation = _smooth_noise(11, 7.5)
		width_variation = _smooth_noise(29, 5.3)
	var plume_height: float = lerpf(19.0, 42.0, intensity)
	if reduced:
		plume_height *= 0.64
	else:
		plume_height *= lerpf(0.86, 1.12, variation)
	var half_width: float = lerpf(2.8, 5.4, intensity)
	half_width *= lerpf(0.88, 1.12, width_variation)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.65, 0.42))
	var glow_color: Color = hot_color
	glow_color.a = 0.24 + (0.34 * intensity)
	draw_circle(Vector2.ZERO, 9.0 + (4.0 * intensity), glow_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var outer_color: Color = hot_color
	outer_color.a = 0.15 + (0.24 * intensity)
	var middle_color: Color = hot_color.lerp(Color.WHITE, 0.25)
	middle_color.a = 0.22 + (0.34 * intensity)
	var core_alpha: float = 0.34 + (0.48 * intensity)
	var core_draw_color: Color = core_color
	core_draw_color.a = core_alpha
	_draw_plume_layer(plume_height, half_width * 1.28, outer_color, 0)
	_draw_plume_layer(plume_height * 0.84, half_width * 0.82, middle_color, 17)
	_draw_plume_layer(plume_height * 0.55, half_width * 0.36, core_draw_color, 31)

	if reduced:
		return
	var mote_count: int = IMMINENT_MOTES if _state == HiveDistressRules.STATE_IMMINENT else CRITICAL_MOTES
	for i in range(mini(mote_count, MAX_MOTES)):
		_draw_mote(i, plume_height, half_width, hot_color, intensity)

func _draw_plume_layer(
	height: float,
	half_width: float,
	color: Color,
	noise_channel: int
) -> void:
	const SEGMENT_COUNT: int = 4
	var bend: float = lerpf(-2.2, 2.2, _smooth_noise(47 + noise_channel, 3.9))
	for segment_index in range(SEGMENT_COUNT):
		var lower_t: float = float(segment_index) / float(SEGMENT_COUNT)
		var upper_t: float = float(segment_index + 1) / float(SEGMENT_COUNT)
		var gap_t: float = 0.025 + (
			_hash01(_stable_seed * 733 + noise_channel * 43 + segment_index * 97) * 0.025
		)
		lower_t += gap_t if segment_index > 0 else 0.0
		upper_t -= gap_t if segment_index < SEGMENT_COUNT - 1 else 0.0
		var lower_width: float = maxf(0.45, half_width * lerpf(1.0, 0.22, lower_t))
		var upper_width: float = maxf(0.35, half_width * lerpf(1.0, 0.22, upper_t))
		var lower_center_x: float = bend * lower_t + lerpf(
			-1.1,
			1.1,
			_smooth_noise(101 + noise_channel + segment_index * 5, 4.1)
		)
		var upper_center_x: float = bend * upper_t + lerpf(
			-1.1,
			1.1,
			_smooth_noise(121 + noise_channel + segment_index * 7, 4.7)
		)
		var segment_color: Color = color
		segment_color.a *= lerpf(1.0, 0.34, upper_t)
		var points := PackedVector2Array([
			Vector2(lower_center_x - lower_width, -height * lower_t),
			Vector2(upper_center_x - upper_width, -height * upper_t),
			Vector2(upper_center_x + upper_width, -height * upper_t),
			Vector2(lower_center_x + lower_width, -height * lower_t)
		])
		draw_colored_polygon(points, segment_color)

func _draw_mote(
	index: int,
	plume_height: float,
	half_width: float,
	color: Color,
	intensity: float
) -> void:
	var offset: float = _hash01(_stable_seed * 97 + index * 131)
	var speed: float = lerpf(0.42, 0.86, _hash01(_stable_seed * 41 + index * 173))
	var phase: float = fposmod((_presentation_t * speed) + offset, 1.0)
	var sideways: float = lerpf(
		-half_width * 1.65,
		half_width * 1.65,
		_hash01(_stable_seed * 211 + index * 67)
	)
	var drift: float = lerpf(-2.5, 2.5, _smooth_noise(83 + index * 7, 2.7 + float(index) * 0.19))
	var pos := Vector2(
		sideways + (drift * phase),
		-4.0 - (phase * plume_height * 1.18)
	)
	var fade: float = 1.0 - absf((phase * 2.0) - 1.0)
	var mote_color: Color = color.lerp(Color.WHITE, 0.35)
	mote_color.a = fade * (0.24 + 0.50 * intensity)
	var radius: float = lerpf(0.85, 1.65, _hash01(_stable_seed * 313 + index * 109))
	draw_circle(pos, radius, mote_color)

func _smooth_noise(channel: int, rate: float) -> float:
	var sample_pos: float = _presentation_t * rate
	var sample_index: int = int(floor(sample_pos))
	var mix_t: float = smoothstep(0.0, 1.0, sample_pos - float(sample_index))
	var a: float = _hash01(_stable_seed * 4099 + channel * 257 + sample_index)
	var b: float = _hash01(_stable_seed * 4099 + channel * 257 + sample_index + 1)
	return lerpf(a, b, mix_t)

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

func get_debug_snapshot() -> Dictionary:
	return {
		"state": HiveDistressRules.state_name(_state),
		"state_id": _state,
		"viewer_owner_id": _viewer_owner_id,
		"owner_id": _owner_id,
		"power": _power,
		"hostile_capture_pressure": _hostile_capture_pressure,
		"target_intensity": _target_intensity,
		"current_intensity": _current_intensity,
		"capture_suppressed": _capture_suppress_remaining > 0.0,
		"growth_suppressed": _growth_suppressed,
		"lifecycle_suspended": _lifecycle_suspended,
		"motion_mode": _motion_mode,
		"max_motes": MAX_MOTES,
		"material_instance_id": material.get_instance_id() if material != null else 0,
		"child_count": get_child_count()
	}
