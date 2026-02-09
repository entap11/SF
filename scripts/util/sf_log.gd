extends RefCounted
class_name SFLog

static var LOGGING_ENABLED: bool = OS.has_feature("editor") or OS.has_feature("server")

enum Level { ERROR, WARN, INFO, DEBUG, TRACE, NONE }

# Global quiet mode: only allow explicitly whitelisted tags.
static var QUIET_MODE: bool = true
static var ALLOW_TAGS: PackedStringArray = PackedStringArray(["FRAME_HITCH"])

# Default runtime level (edit this to change verbosity).
static var LOG_LEVEL: int = Level.WARN
static var CHANNEL_ENABLED: Dictionary = {}
static var verbose_sim: bool = false

static var _once_keys: Dictionary = {}
static var _last_values: Dictionary = {}
static var _throttle_next_ms: Dictionary = {}
static var _last_log_sig: Dictionary = {}
static var _last_ms_by_key: Dictionary = {}
static var _last_event_label: String = ""
static var _last_event_ms: int = 0

static func set_quiet_mode(enabled: bool) -> void:
	QUIET_MODE = enabled

static func set_tag_whitelist(tags: PackedStringArray) -> void:
	ALLOW_TAGS = tags

static func allow_tag(tag: String) -> void:
	if tag.is_empty():
		return
	if not ALLOW_TAGS.has(tag):
		ALLOW_TAGS.append(tag)

static func force_enable(enabled: bool = true) -> void:
	LOGGING_ENABLED = enabled

static func flush() -> void:
	print("")

static func mark_event(label: String) -> void:
	_last_event_label = label
	_last_event_ms = Time.get_ticks_msec()

static func get_last_event_label() -> String:
	return _last_event_label

static func get_last_event_ms() -> int:
	return _last_event_ms

static func _tag_allowed(tag: String) -> bool:
	if not QUIET_MODE:
		return true
	return ALLOW_TAGS.has(tag)

static func error(msg: String, data: Dictionary = {}, channel: String = "", throttle_ms: int = 0) -> void:
	if not LOGGING_ENABLED:
		return
	if not _tag_allowed(msg):
		return
	_log(Level.ERROR, msg, data, channel, throttle_ms)

static func warn(msg: String, data: Dictionary = {}, channel: String = "", throttle_ms: int = 0) -> void:
	if not LOGGING_ENABLED:
		return
	if not _tag_allowed(msg):
		return
	_log(Level.WARN, msg, data, channel, throttle_ms)

static func info(msg: String, data: Dictionary = {}, channel: String = "", throttle_ms: int = 0) -> void:
	if not LOGGING_ENABLED:
		return
	if not _tag_allowed(msg):
		return
	_log(Level.INFO, msg, data, channel, throttle_ms)

static func debug(msg: String, data: Dictionary = {}, channel: String = "", throttle_ms: int = 0) -> void:
	if not LOGGING_ENABLED:
		return
	if not _tag_allowed(msg):
		return
	_log(Level.DEBUG, msg, data, channel, throttle_ms)

static func trace(msg: String, data: Dictionary = {}, channel: String = "", throttle_ms: int = 0) -> void:
	if not LOGGING_ENABLED:
		return
	if not _tag_allowed(msg):
		return
	_log(Level.TRACE, msg, data, channel, throttle_ms)

static func throttled_info(key: String, data: Dictionary = {}, min_interval_ms: int = 250) -> void:
	if not LOGGING_ENABLED:
		return
	var now := Time.get_ticks_msec()
	var last := int(_last_ms_by_key.get(key, -999999999))
	if now - last < min_interval_ms:
		return
	_last_ms_by_key[key] = now
	info(key, data)

static func set_channel_enabled(channel: String, enabled: bool) -> void:
	CHANNEL_ENABLED[channel] = enabled

static func is_channel_enabled(channel: String) -> bool:
	if channel == "":
		return true
	if CHANNEL_ENABLED.has(channel):
		return bool(CHANNEL_ENABLED[channel])
	return true

static func log_once(key: String, msg: String, level: int = Level.DEBUG, data: Dictionary = {}, channel: String = "") -> void:
	if not LOGGING_ENABLED:
		return
	if _once_keys.has(key):
		return
	_once_keys[key] = true
	_log(level, msg, data, channel)

static func log_on_change(key: String, value: Variant, msg_builder: Callable, level: int = Level.DEBUG, channel: String = "") -> void:
	if not LOGGING_ENABLED:
		return
	if _last_values.has(key) and _last_values[key] == value:
		return
	_last_values[key] = value
	var msg: String = str(msg_builder.call(value))
	_log(level, msg, {}, channel)

static func log_on_change_payload(key: String, sig: Variant, payload: Dictionary) -> void:
	if not LOGGING_ENABLED:
		return
	if _last_log_sig.has(key) and _last_log_sig[key] == sig:
		return
	_last_log_sig[key] = sig
	_log(Level.INFO, key, payload)

static func throttle(key: String, seconds: float, msg: String, level: int = Level.DEBUG) -> void:
	if not LOGGING_ENABLED:
		return
	var now_ms: int = Time.get_ticks_msec()
	var throttle_key := "custom:" + key
	var next_ms: int = int(_throttle_next_ms.get(throttle_key, 0))
	if now_ms < next_ms:
		return
	_throttle_next_ms[throttle_key] = now_ms + int(seconds * 1000.0)
	_log(level, msg)

static func _log(level: int, msg: String, data: Dictionary = {}, channel: String = "", throttle_ms: int = 0) -> void:
	if not LOGGING_ENABLED:
		return
	if not _tag_allowed(msg):
		return
	if not _enabled(level, channel, msg, throttle_ms):
		return
	var text: String = _format_payload(msg, data)
	var prefix: String = _prefix(level, channel)
	if QUIET_MODE:
		print(prefix + text)
		return
	match level:
		Level.ERROR:
			push_error(prefix + text)
		Level.WARN:
			push_warning(prefix + text)
		_:
			print(prefix + text)

static func _enabled(level: int, channel: String, msg: String, throttle_ms: int) -> bool:
	if LOG_LEVEL == Level.NONE:
		return false
	if level > LOG_LEVEL:
		return false
	if not is_channel_enabled(channel):
		return false
	if throttle_ms > 0:
		var key := _callsite_throttle_key(channel, msg)
		var now_ms: int = Time.get_ticks_msec()
		var next_ms: int = int(_throttle_next_ms.get(key, 0))
		if now_ms < next_ms:
			return false
		_throttle_next_ms[key] = now_ms + throttle_ms
	return true

static func _callsite_throttle_key(channel: String, msg: String) -> String:
	if channel == "":
		return "callsite:" + msg
	return "callsite:" + channel + ":" + msg

static func _format_payload(msg: String, data: Dictionary) -> String:
	if data.is_empty():
		return msg
	if QUIET_MODE:
		if msg == "FRAME_HITCH":
			var hitch_dt_ms: int = int(data.get("dt_ms", -1))
			var event: String = str(data.get("event", ""))
			var event_age_ms: int = int(data.get("event_age_ms", -1))
			return "%s dt_ms=%d event=%s event_age_ms=%d" % [msg, hitch_dt_ms, event, event_age_ms]
		if msg == "SIM_TICK":
			var frame: int = int(data.get("frame", -1))
			var physics: int = int(data.get("physics", -1))
			return "%s frame=%d physics=%d" % [msg, frame, physics]
		if msg == "SIM_HITCH":
			var dt_ms: int = int(data.get("dt_ms", -1))
			var dt_us: int = int(data.get("dt_us", -1))
			var expected_ms: int = int(data.get("expected_ms", -1))
			var hitch_frame: int = int(data.get("frame", -1))
			var hitch_physics: int = int(data.get("physics", -1))
			return "%s dt_ms=%d dt_us=%d expected_ms=%d frame=%d physics=%d" % [msg, dt_ms, dt_us, expected_ms, hitch_frame, hitch_physics]
		if msg == "SIM_COST":
			var label: String = str(data.get("label", ""))
			var cost_dt_ms: float = float(data.get("dt_ms", -1.0))
			return "%s label=%s dt_ms=%.1f" % [msg, label, cost_dt_ms]
		if msg == "SIM_HEARTBEAT":
			var ticks: int = int(data.get("ticks", -1))
			var max_tick_ms: float = float(data.get("max_tick_ms", -1.0))
			return "%s ticks=%d max_tick_ms=%.1f" % [msg, ticks, max_tick_ms]
		if msg == "SIM_TICK_COST":
			var tick_cost_ms: float = float(data.get("dt_ms", -1.0))
			return "%s dt_ms=%.1f" % [msg, tick_cost_ms]
		if msg == "SIM_TICK_PHASE":
			var phase: String = str(data.get("phase", ""))
			var phase_dt_ms: float = float(data.get("dt_ms", -1.0))
			return "%s phase=%s dt_ms=%.1f" % [msg, phase, phase_dt_ms]
		if msg == "ARENA_FRAME_HEARTBEAT":
			var frames: int = int(data.get("frames", -1))
			var fps: float = float(data.get("fps", -1.0))
			var max_frame_ms: float = float(data.get("max_frame_ms", -1.0))
			var avg_frame_ms: float = float(data.get("avg_frame_ms", -1.0))
			var max_physics_ms: float = float(data.get("max_physics_ms", -1.0))
			return "%s frames=%d fps=%.1f max_frame_ms=%.1f avg_frame_ms=%.1f max_physics_ms=%.1f" % [msg, frames, fps, max_frame_ms, avg_frame_ms, max_physics_ms]
		if msg == "RENDER_AUDIT_UNITS":
			var units: int = int(data.get("units", -1))
			var unit_draw_ops: int = int(data.get("draw_ops", -1))
			var unit_mat_sets: int = int(data.get("mat_sets", -1))
			var unit_rebuilds: int = int(data.get("rebuilds", -1))
			var unit_material_sets: int = int(data.get("material_sets", -1))
			var unit_modulate_sets: int = int(data.get("modulate_sets", -1))
			return "%s units=%d draw_ops=%d mat_sets=%d rebuilds=%d material_sets=%d modulate_sets=%d" % [msg, units, unit_draw_ops, unit_mat_sets, unit_rebuilds, unit_material_sets, unit_modulate_sets]
		if msg == "RENDER_AUDIT_UNITS_TOP_MAT_KEYS":
			var top_total: int = int(data.get("total_mat_sets", -1))
			var top_blob: String = str(data.get("top", []))
			return "%s total_mat_sets=%d top=%s" % [msg, top_total, top_blob]
		if msg == "RENDER_AUDIT_UNITS_REBUILDS":
			var rebuild_total: int = int(data.get("total_rebuilds", -1))
			var rebuild_blob: String = str(data.get("rebuilds", []))
			return "%s total_rebuilds=%d rebuilds=%s" % [msg, rebuild_total, rebuild_blob]
		if msg == "RENDER_AUDIT_LANES":
			var lanes: int = int(data.get("lanes", -1))
			var lane_draw_ops: int = int(data.get("draw_ops", -1))
			var lane_mat_sets: int = int(data.get("mat_sets", -1))
			var lane_rebuilds: int = int(data.get("rebuilds", -1))
			return "%s lanes=%d draw_ops=%d mat_sets=%d rebuilds=%d" % [msg, lanes, lane_draw_ops, lane_mat_sets, lane_rebuilds]
		return "%s %s" % [msg, str(data)]
	return "%s %s" % [msg, str(data)]

static func _prefix(level: int, channel: String = "") -> String:
	var label := "SF_LOG"
	match level:
		Level.ERROR:
			label = "SF_ERROR"
		Level.WARN:
			label = "SF_WARN"
		Level.INFO:
			label = "SF_INFO"
		Level.DEBUG:
			label = "SF_DEBUG"
		Level.TRACE:
			label = "SF_TRACE"
		_:
			label = "SF_LOG"
	if channel == "":
		return label + ": "
	return "%s[%s]: " % [label, channel]
