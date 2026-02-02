extends RefCounted
class_name SFLog

const LOGGING_ENABLED: bool = false

enum Level { ERROR, WARN, INFO, DEBUG, TRACE, NONE }

# Global quiet mode: only allow explicitly whitelisted tags.
static var QUIET_MODE: bool = true
static var ALLOW_TAGS: PackedStringArray = PackedStringArray(["FRAME_HITCH"])

# Default runtime level (edit this to change verbosity).
static var LOG_LEVEL: int = Level.INFO
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
	if QUIET_MODE and msg != "FRAME_HITCH":
		return msg
	if QUIET_MODE and msg == "FRAME_HITCH":
		var dt_ms: int = int(data.get("dt_ms", -1))
		var event: String = str(data.get("event", ""))
		var event_age_ms: int = int(data.get("event_age_ms", -1))
		return "%s dt_ms=%d event=%s event_age_ms=%d" % [msg, dt_ms, event, event_age_ms]
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
