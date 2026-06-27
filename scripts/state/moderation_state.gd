extends Node

signal moderation_state_changed(snapshot: Dictionary)
signal moderation_report_submitted(report: Dictionary)
signal moderation_action_recorded(action: Dictionary)
signal moderation_appeal_submitted(appeal: Dictionary)
signal moderation_appeal_reviewed(appeal: Dictionary)

const SFLog := preload("res://scripts/util/sf_log.gd")

const SAVE_PATH: String = "user://moderation_state.json"
const SAVE_SCHEMA_VERSION: int = 1
const REPORT_STATUS_OPEN: String = "open"
const REPORT_STATUS_REVIEWED: String = "reviewed"
const REPORT_STATUS_DISMISSED: String = "dismissed"
const APPEAL_STATUS_NONE: String = "none"
const APPEAL_STATUS_OPEN: String = "open"
const APPEAL_STATUS_UPHELD: String = "upheld"
const APPEAL_STATUS_OVERTURNED: String = "overturned"

const ACTION_WARNING: String = "warning"
const ACTION_FORCED_RENAME: String = "forced_rename"
const ACTION_MUTE: String = "mute"
const ACTION_SUSPENSION: String = "suspension"
const ACTION_BAN: String = "ban"

var _reports_by_id: Dictionary = {}
var _actions_by_id: Dictionary = {}
var _appeals_by_id: Dictionary = {}
var _next_report_seq: int = 1
var _next_action_seq: int = 1
var _next_appeal_seq: int = 1

func _ready() -> void:
	_load_state()

func get_snapshot() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"reports_by_id": _reports_by_id.duplicate(true),
		"actions_by_id": _actions_by_id.duplicate(true),
		"appeals_by_id": _appeals_by_id.duplicate(true),
		"next_report_seq": _next_report_seq,
		"next_action_seq": _next_action_seq,
		"next_appeal_seq": _next_appeal_seq
	}

func debug_reset_state() -> void:
	_reports_by_id.clear()
	_actions_by_id.clear()
	_appeals_by_id.clear()
	_next_report_seq = 1
	_next_action_seq = 1
	_next_appeal_seq = 1
	_save_and_emit()

func submit_report(
		reporter_player_id: String,
		target_type: String,
		target_id: String,
		category: String,
		summary: String,
		context: Dictionary = {}
	) -> Dictionary:
	var reporter_id: String = _sanitize_id(reporter_player_id)
	var clean_target_type: String = _sanitize_token(target_type, "player")
	var clean_target_id: String = _sanitize_id(target_id)
	var clean_category: String = _sanitize_token(category, "other")
	var clean_summary: String = _sanitize_text(summary, 500)
	if reporter_id.is_empty():
		return {"ok": false, "reason": "missing_reporter_id"}
	if clean_target_id.is_empty():
		return {"ok": false, "reason": "missing_target_id"}
	if clean_summary.is_empty():
		return {"ok": false, "reason": "missing_summary"}
	var report_id: String = _next_id("rep", _next_report_seq)
	_next_report_seq += 1
	var report: Dictionary = {
		"report_id": report_id,
		"reporter_player_id": reporter_id,
		"target_type": clean_target_type,
		"target_id": clean_target_id,
		"category": clean_category,
		"summary": clean_summary,
		"context": _sanitize_context(context),
		"status": REPORT_STATUS_OPEN,
		"created_at_unix": _now_unix(),
		"reviewed_at_unix": 0,
		"reviewed_by": ""
	}
	_reports_by_id[report_id] = report
	_save_and_emit()
	SFLog.info("MODERATION_REPORT_SUBMITTED", {
		"report_id": report_id,
		"target_type": clean_target_type,
		"category": clean_category
	})
	moderation_report_submitted.emit(report.duplicate(true))
	return {"ok": true, "report": report.duplicate(true)}

func record_moderation_action(
		target_player_id: String,
		action_type: String,
		reason: String,
		moderator_id: String = "",
		metadata: Dictionary = {}
	) -> Dictionary:
	var clean_target_id: String = _sanitize_id(target_player_id)
	var clean_action_type: String = _sanitize_action_type(action_type)
	var clean_reason: String = _sanitize_text(reason, 500)
	if clean_target_id.is_empty():
		return {"ok": false, "reason": "missing_target_player_id"}
	if clean_reason.is_empty():
		return {"ok": false, "reason": "missing_reason"}
	var action_id: String = _next_id("mod", _next_action_seq)
	_next_action_seq += 1
	var appealable: bool = _is_appealable_action(clean_action_type)
	var action: Dictionary = {
		"action_id": action_id,
		"target_player_id": clean_target_id,
		"action_type": clean_action_type,
		"reason": clean_reason,
		"moderator_id": _sanitize_id(moderator_id),
		"metadata": _sanitize_context(metadata),
		"appealable": appealable,
		"appeal_status": APPEAL_STATUS_NONE,
		"created_at_unix": _now_unix(),
		"review_required": appealable,
		"reviewed_by": "",
		"reviewed_at_unix": 0
	}
	_actions_by_id[action_id] = action
	_apply_local_profile_action(action)
	_save_and_emit()
	SFLog.info("MODERATION_ACTION_RECORDED", {
		"action_id": action_id,
		"action_type": clean_action_type,
		"target_player_id": clean_target_id
	})
	moderation_action_recorded.emit(action.duplicate(true))
	return {"ok": true, "action": action.duplicate(true)}

func submit_appeal(action_id: String, player_id: String, statement: String) -> Dictionary:
	var clean_action_id: String = _sanitize_id(action_id)
	var clean_player_id: String = _sanitize_id(player_id)
	var clean_statement: String = _sanitize_text(statement, 1200)
	if not _actions_by_id.has(clean_action_id):
		return {"ok": false, "reason": "action_not_found"}
	var action: Dictionary = _actions_by_id.get(clean_action_id, {}) as Dictionary
	if not bool(action.get("appealable", false)):
		return {"ok": false, "reason": "action_not_appealable"}
	if clean_player_id != str(action.get("target_player_id", "")):
		return {"ok": false, "reason": "player_mismatch"}
	if clean_statement.is_empty():
		return {"ok": false, "reason": "missing_statement"}
	var appeal_id: String = _next_id("app", _next_appeal_seq)
	_next_appeal_seq += 1
	var appeal: Dictionary = {
		"appeal_id": appeal_id,
		"action_id": clean_action_id,
		"player_id": clean_player_id,
		"statement": clean_statement,
		"status": APPEAL_STATUS_OPEN,
		"created_at_unix": _now_unix(),
		"reviewed_by": "",
		"reviewed_at_unix": 0,
		"review_notes": ""
	}
	_appeals_by_id[appeal_id] = appeal
	action["appeal_status"] = APPEAL_STATUS_OPEN
	_actions_by_id[clean_action_id] = action
	_save_and_emit()
	moderation_appeal_submitted.emit(appeal.duplicate(true))
	return {"ok": true, "appeal": appeal.duplicate(true)}

func review_appeal(appeal_id: String, reviewer_id: String, decision: String, notes: String = "") -> Dictionary:
	var clean_appeal_id: String = _sanitize_id(appeal_id)
	if not _appeals_by_id.has(clean_appeal_id):
		return {"ok": false, "reason": "appeal_not_found"}
	var clean_decision: String = decision.strip_edges().to_lower()
	if clean_decision != APPEAL_STATUS_UPHELD and clean_decision != APPEAL_STATUS_OVERTURNED:
		return {"ok": false, "reason": "invalid_decision"}
	var appeal: Dictionary = _appeals_by_id.get(clean_appeal_id, {}) as Dictionary
	appeal["status"] = clean_decision
	appeal["reviewed_by"] = _sanitize_id(reviewer_id)
	appeal["reviewed_at_unix"] = _now_unix()
	appeal["review_notes"] = _sanitize_text(notes, 1200)
	_appeals_by_id[clean_appeal_id] = appeal
	var action_id: String = str(appeal.get("action_id", ""))
	if _actions_by_id.has(action_id):
		var action: Dictionary = _actions_by_id.get(action_id, {}) as Dictionary
		action["appeal_status"] = clean_decision
		action["reviewed_by"] = _sanitize_id(reviewer_id)
		action["reviewed_at_unix"] = int(appeal.get("reviewed_at_unix", 0))
		_actions_by_id[action_id] = action
	_save_and_emit()
	moderation_appeal_reviewed.emit(appeal.duplicate(true))
	return {"ok": true, "appeal": appeal.duplicate(true)}

func _apply_local_profile_action(action: Dictionary) -> void:
	if str(action.get("action_type", "")) != ACTION_FORCED_RENAME:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var profile_manager: Node = tree.root.get_node_or_null("ProfileManager")
	if profile_manager == null or not profile_manager.has_method("get_user_id") or not profile_manager.has_method("require_forced_handle_change"):
		return
	var local_player_id: String = str(profile_manager.call("get_user_id")).strip_edges()
	if local_player_id != str(action.get("target_player_id", "")).strip_edges():
		return
	profile_manager.call("require_forced_handle_change", str(action.get("reason", "")), str(action.get("action_id", "")))

func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed_any: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed_any) != TYPE_DICTIONARY:
		return
	var parsed: Dictionary = parsed_any as Dictionary
	_reports_by_id = _sanitize_record_map(parsed.get("reports_by_id", {}))
	_actions_by_id = _sanitize_record_map(parsed.get("actions_by_id", {}))
	_appeals_by_id = _sanitize_record_map(parsed.get("appeals_by_id", {}))
	_next_report_seq = maxi(1, int(parsed.get("next_report_seq", _reports_by_id.size() + 1)))
	_next_action_seq = maxi(1, int(parsed.get("next_action_seq", _actions_by_id.size() + 1)))
	_next_appeal_seq = maxi(1, int(parsed.get("next_appeal_seq", _appeals_by_id.size() + 1)))

func _save_and_emit() -> void:
	_save_state()
	moderation_state_changed.emit(get_snapshot())

func _save_state() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(get_snapshot(), "\t"))

func _sanitize_record_map(raw_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_any) != TYPE_DICTIONARY:
		return out
	var raw: Dictionary = raw_any as Dictionary
	for key_any in raw.keys():
		var key: String = _sanitize_id(str(key_any))
		if key.is_empty():
			continue
		var value: Variant = raw.get(key_any)
		if typeof(value) != TYPE_DICTIONARY:
			continue
		out[key] = (value as Dictionary).duplicate(true)
	return out

func _sanitize_context(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key_any in raw.keys():
		var key: String = _sanitize_token(str(key_any), "")
		if key.is_empty():
			continue
		var value: Variant = raw.get(key_any)
		match typeof(value):
			TYPE_STRING:
				out[key] = _sanitize_text(str(value), 500)
			TYPE_INT, TYPE_FLOAT, TYPE_BOOL:
				out[key] = value
			TYPE_ARRAY, TYPE_DICTIONARY:
				out[key] = JSON.parse_string(JSON.stringify(value))
			_:
				out[key] = str(value)
	return out

func _sanitize_action_type(action_type: String) -> String:
	var clean: String = _sanitize_token(action_type, ACTION_WARNING)
	match clean:
		ACTION_WARNING, ACTION_FORCED_RENAME, ACTION_MUTE, ACTION_SUSPENSION, ACTION_BAN:
			return clean
		_:
			return ACTION_WARNING

func _is_appealable_action(action_type: String) -> bool:
	return action_type == ACTION_FORCED_RENAME or action_type == ACTION_MUTE or action_type == ACTION_SUSPENSION or action_type == ACTION_BAN

func _sanitize_id(value: String) -> String:
	var clean: String = value.strip_edges()
	if clean.length() > 96:
		clean = clean.substr(0, 96)
	return clean

func _sanitize_token(value: String, fallback: String) -> String:
	var clean: String = value.strip_edges().to_lower()
	if clean.is_empty():
		return fallback
	var out: String = ""
	for i in range(clean.length()):
		var code: int = clean.unicode_at(i)
		var allowed: bool = (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95
		if allowed:
			out += clean.substr(i, 1)
	if out.is_empty():
		return fallback
	if out.length() > 48:
		out = out.substr(0, 48)
	return out

func _sanitize_text(value: String, max_len: int) -> String:
	var clean: String = value.strip_edges()
	clean = clean.replace("\u0000", "")
	if clean.length() > max_len:
		clean = clean.substr(0, max_len)
	return clean

func _next_id(prefix: String, seq: int) -> String:
	return "%s_%06d_%d" % [prefix, maxi(1, seq), _now_unix()]

func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())
