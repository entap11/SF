extends Node

signal app_backgrounded(reason: String, paused_at_msec: int, paused_at_unix: int)
signal app_foregrounded(reason: String, elapsed_msec: int, resumed_at_unix: int)
signal app_focus_changed(focused: bool, reason: String)
signal lifecycle_changed(snapshot: Dictionary)

const SFLog := preload("res://scripts/util/sf_log.gd")

var _is_backgrounded: bool = false
var _has_window_focus: bool = true
var _background_started_msec: int = 0
var _background_started_unix: int = 0
var _last_resume_msec: int = 0
var _last_background_reason: String = ""
var _last_foreground_reason: String = ""
var _background_count: int = 0
var _foreground_count: int = 0
var _focus_lost_count: int = 0
var _focus_gained_count: int = 0

func _notification(what: int) -> void:
	handle_lifecycle_notification(what)

func handle_lifecycle_notification(what: int) -> bool:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			record_background_event("application_paused")
			return true
		NOTIFICATION_APPLICATION_RESUMED:
			record_foreground_event("application_resumed")
			return true
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			record_focus_event(false, "window_focus_out")
			return true
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			record_focus_event(true, "window_focus_in")
			return true
	return false

func record_background_event(reason: String = "backgrounded") -> void:
	var clean_reason: String = _clean_reason(reason, "backgrounded")
	if _is_backgrounded:
		_last_background_reason = clean_reason
		_emit_lifecycle_changed()
		return
	_is_backgrounded = true
	_background_started_msec = Time.get_ticks_msec()
	_background_started_unix = int(Time.get_unix_time_from_system())
	_last_background_reason = clean_reason
	_background_count += 1
	SFLog.info("APP_BACKGROUND", {
		"reason": clean_reason,
		"msec": _background_started_msec,
		"unix": _background_started_unix,
		"count": _background_count
	})
	emit_signal("app_backgrounded", clean_reason, _background_started_msec, _background_started_unix)
	_emit_lifecycle_changed()

func record_foreground_event(reason: String = "foregrounded") -> void:
	var clean_reason: String = _clean_reason(reason, "foregrounded")
	var now_msec: int = Time.get_ticks_msec()
	var elapsed_msec: int = 0
	if _background_started_msec > 0:
		elapsed_msec = maxi(0, now_msec - _background_started_msec)
	if not _is_backgrounded:
		_last_foreground_reason = clean_reason
		_last_resume_msec = now_msec
		_emit_lifecycle_changed()
		return
	_is_backgrounded = false
	_last_resume_msec = now_msec
	_last_foreground_reason = clean_reason
	_foreground_count += 1
	SFLog.info("APP_FOREGROUND", {
		"reason": clean_reason,
		"elapsed_msec": elapsed_msec,
		"msec": now_msec,
		"unix": int(Time.get_unix_time_from_system()),
		"count": _foreground_count
	})
	emit_signal("app_foregrounded", clean_reason, elapsed_msec, int(Time.get_unix_time_from_system()))
	_emit_lifecycle_changed()

func record_focus_event(focused: bool, reason: String = "window_focus") -> void:
	var clean_reason: String = _clean_reason(reason, "window_focus")
	if _has_window_focus == focused:
		return
	_has_window_focus = focused
	if focused:
		_focus_gained_count += 1
	else:
		_focus_lost_count += 1
	SFLog.info("APP_FOCUS", {
		"focused": focused,
		"reason": clean_reason,
		"lost_count": _focus_lost_count,
		"gained_count": _focus_gained_count
	})
	emit_signal("app_focus_changed", focused, clean_reason)
	_emit_lifecycle_changed()

func is_backgrounded() -> bool:
	return _is_backgrounded

func has_window_focus() -> bool:
	return _has_window_focus

func background_elapsed_msec() -> int:
	if not _is_backgrounded or _background_started_msec <= 0:
		return 0
	return maxi(0, Time.get_ticks_msec() - _background_started_msec)

func get_snapshot() -> Dictionary:
	return {
		"is_backgrounded": _is_backgrounded,
		"has_window_focus": _has_window_focus,
		"background_started_msec": _background_started_msec,
		"background_started_unix": _background_started_unix,
		"background_elapsed_msec": background_elapsed_msec(),
		"last_resume_msec": _last_resume_msec,
		"last_background_reason": _last_background_reason,
		"last_foreground_reason": _last_foreground_reason,
		"background_count": _background_count,
		"foreground_count": _foreground_count,
		"focus_lost_count": _focus_lost_count,
		"focus_gained_count": _focus_gained_count
	}

func _emit_lifecycle_changed() -> void:
	emit_signal("lifecycle_changed", get_snapshot())

func _clean_reason(reason: String, fallback: String) -> String:
	var clean: String = str(reason).strip_edges()
	return fallback if clean.is_empty() else clean
