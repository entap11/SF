# Intent telemetry sink for bot tuning and player-style capture.
class_name BotTelemetryStore
extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")

const INTENT_LOG_PATH: String = "user://bot_intent_telemetry_v1.jsonl"
const SUMMARY_PATH: String = "user://bot_intent_summary_v1.json"
const SUMMARY_FLUSH_INTERVAL_MS: int = 1000

var _loaded: bool = false
var _summary: Dictionary = {}
var _summary_dirty: bool = false
var _last_summary_flush_ms: int = 0

func record_intent(event: Dictionary) -> void:
	if event == null or event.is_empty():
		return
	_ensure_loaded()
	var now_ms: int = Time.get_ticks_msec()
	var entry: Dictionary = event.duplicate(true)
	entry["ts_ms"] = now_ms
	entry["ts_unix"] = int(Time.get_unix_time_from_system())
	_append_jsonl(INTENT_LOG_PATH, entry)
	_apply_intent_to_summary(entry)
	_flush_summary_if_due(now_ms)

func flush() -> void:
	_ensure_loaded()
	_save_summary(true)

func get_summary_snapshot() -> Dictionary:
	_ensure_loaded()
	return _summary.duplicate(true)

func _ensure_loaded() -> void:
	if _loaded:
		return
	_summary = _load_summary()
	_loaded = true

func _load_summary() -> Dictionary:
	var defaults: Dictionary = {
		"version": 1,
		"total": 0,
		"ok": 0,
		"failed": 0,
		"by_actor": {},
		"last_ts_ms": 0
	}
	if not FileAccess.file_exists(SUMMARY_PATH):
		return defaults
	var file: FileAccess = FileAccess.open(SUMMARY_PATH, FileAccess.READ)
	if file == null:
		return defaults
	var text: String = file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return defaults
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return defaults
	var summary: Dictionary = parsed as Dictionary
	if not summary.has("version"):
		summary["version"] = 1
	if not summary.has("total"):
		summary["total"] = 0
	if not summary.has("ok"):
		summary["ok"] = 0
	if not summary.has("failed"):
		summary["failed"] = 0
	if not summary.has("by_actor"):
		summary["by_actor"] = {}
	if not summary.has("last_ts_ms"):
		summary["last_ts_ms"] = 0
	return summary

func _append_jsonl(path: String, payload: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE_READ)
	if file == null:
		SFLog.warn("BOT_TELEMETRY_IO_FAIL", {"path": path})
		return
	file.seek_end()
	file.store_line(JSON.stringify(payload))
	file.close()

func _apply_intent_to_summary(entry: Dictionary) -> void:
	_summary["total"] = int(_summary.get("total", 0)) + 1
	var ok: bool = bool(entry.get("ok", false))
	if ok:
		_summary["ok"] = int(_summary.get("ok", 0)) + 1
	else:
		_summary["failed"] = int(_summary.get("failed", 0)) + 1
	var actor_key: String = str(int(entry.get("actor_id", 0)))
	var by_actor: Dictionary = _summary.get("by_actor", {})
	var actor: Dictionary = by_actor.get(actor_key, {
		"total": 0,
		"ok": 0,
		"failed": 0,
		"attack": 0,
		"feed": 0,
		"swarm": 0,
		"last_reason": "",
		"budget_fail": 0,
		"no_lane_fail": 0,
		"max_src_available_lane_unattended_ms": 0,
		"max_src_high_power_idle_ms": 0,
		"last_src_available_targets": 0,
		"last_src_open_slots": 0
	})
	actor["total"] = int(actor.get("total", 0)) + 1
	if ok:
		actor["ok"] = int(actor.get("ok", 0)) + 1
	else:
		actor["failed"] = int(actor.get("failed", 0)) + 1
		actor["last_reason"] = str(entry.get("reason", ""))
		var fail_reason: String = str(entry.get("reason", ""))
		if fail_reason == "budget":
			actor["budget_fail"] = int(actor.get("budget_fail", 0)) + 1
		elif fail_reason == "no_lane":
			actor["no_lane_fail"] = int(actor.get("no_lane_fail", 0)) + 1
	var intent_key: String = str(entry.get("intent", ""))
	if intent_key.is_empty():
		intent_key = "unknown"
	actor[intent_key] = int(actor.get(intent_key, 0)) + 1
	actor["max_src_available_lane_unattended_ms"] = maxi(
		int(actor.get("max_src_available_lane_unattended_ms", 0)),
		int(entry.get("src_available_lane_unattended_ms", 0))
	)
	actor["max_src_high_power_idle_ms"] = maxi(
		int(actor.get("max_src_high_power_idle_ms", 0)),
		int(entry.get("src_high_power_idle_ms", 0))
	)
	actor["last_src_available_targets"] = int(entry.get("src_available_targets", 0))
	actor["last_src_open_slots"] = int(entry.get("src_open_slots", 0))
	by_actor[actor_key] = actor
	_summary["by_actor"] = by_actor
	_summary_dirty = true

func _flush_summary_if_due(now_ms: int) -> void:
	if not _summary_dirty:
		return
	if now_ms - _last_summary_flush_ms < SUMMARY_FLUSH_INTERVAL_MS:
		return
	_save_summary(false)

func _save_summary(force: bool) -> void:
	if not _summary_dirty and not force:
		return
	_summary["last_ts_ms"] = int(Time.get_ticks_msec())
	var file: FileAccess = FileAccess.open(SUMMARY_PATH, FileAccess.WRITE)
	if file == null:
		SFLog.warn("BOT_TELEMETRY_IO_FAIL", {"path": SUMMARY_PATH})
		return
	file.store_string(JSON.stringify(_summary))
	file.close()
	_summary_dirty = false
	_last_summary_flush_ms = int(Time.get_ticks_msec())
