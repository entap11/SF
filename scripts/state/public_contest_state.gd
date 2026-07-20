extends Node

signal contests_changed(contests: Array)
signal evidence_changed(evidence: Dictionary)

const Content := preload("res://scripts/state/public_contest_content.gd")
const PENDING_PATH := "user://public_contest_pending_evidence_v1.json"

var contests: Array = []
var boards: Dictionary = {}
var pending_evidence: Array = []

func _ready() -> void:
	_load_pending()

func refresh(family: String = "", scope: String = "", map_count: int = 0) -> Dictionary:
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	if handshake == null or not handshake.has_method("list_public_contests"):
		return {"ok": false, "err": "authenticated_transport_required"}
	var response: Dictionary = handshake.call("list_public_contests", family, scope, map_count) as Dictionary
	if not bool(response.get("ok", false)) or str(response.get("source", "")) != "SERVER_PUBLIC_CONTEST_STORE":
		return response
	var accepted: Array = []
	for value in response.get("contests", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = (value as Dictionary).duplicate(true)
		var validation: Dictionary = Content.validate_definition(definition)
		definition["client_content_validation"] = validation
		accepted.append(definition)
	contests = accepted
	emit_signal("contests_changed", contests.duplicate(true))
	return {"ok": true, "contests": contests.duplicate(true), "server_time": response.get("server_time", ""),
		"source": "SERVER_PUBLIC_CONTEST_STORE"}

func find_contest(family: String, scope: String, map_count: int = 0) -> Dictionary:
	for value in contests:
		var definition: Dictionary = value as Dictionary
		if str(definition.get("family", "")) == family.to_upper() \
				and str(definition.get("scope", "")) == scope.to_upper() \
				and (map_count <= 0 or int(definition.get("map_count", 0)) == map_count):
			return definition.duplicate(true)
	return {}

func enter(definition: Dictionary) -> Dictionary:
	var validation: Dictionary = definition.get("client_content_validation", {}) as Dictionary
	if not bool(validation.get("ok", false)):
		return {"ok": false, "err": str(validation.get("err", "public_contest_content_unverified"))}
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	if handshake == null:
		return {"ok": false, "err": "authenticated_transport_required"}
	return handshake.call("enter_public_contest", str(definition.get("contest_id", ""))) as Dictionary

func leaderboard(contest_id: String, limit: int = 25) -> Dictionary:
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	if handshake == null:
		return {"ok": false, "err": "authenticated_transport_required"}
	var response: Dictionary = handshake.call("get_public_contest_leaderboard", contest_id, limit) as Dictionary
	if bool(response.get("ok", false)) and str(response.get("source", "")) == "SERVER_PUBLIC_CONTEST_STORE":
		boards[contest_id] = response.duplicate(true)
	return response

func submit_evidence(contest_id: String, attempt: Dictionary, evidence: Dictionary, request_id: String = "") -> Dictionary:
	var resolved_request: String = request_id.strip_edges()
	if resolved_request.is_empty():
		resolved_request = "evidence-%s-%d" % [str(attempt.get("attempt_id", "")), Time.get_ticks_usec()]
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	if handshake == null:
		return {"ok": false, "err": "authenticated_transport_required"}
	var response: Dictionary = handshake.call("submit_public_contest_evidence",
		contest_id, attempt, evidence, resolved_request) as Dictionary
	if bool(response.get("ok", false)):
		emit_signal("evidence_changed", response.get("evidence", {}) as Dictionary)
		return response
	pending_evidence.append({"contest_id": contest_id, "attempt": attempt.duplicate(true),
		"evidence": evidence.duplicate(true), "request_id": resolved_request})
	_save_pending()
	return response

func retry_pending_evidence() -> int:
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	if handshake == null:
		return 0
	var remaining: Array = []
	var sent: int = 0
	for value in pending_evidence:
		var row: Dictionary = value as Dictionary
		var response: Dictionary = handshake.call("submit_public_contest_evidence", str(row.get("contest_id", "")),
			row.get("attempt", {}) as Dictionary, row.get("evidence", {}) as Dictionary,
			str(row.get("request_id", ""))) as Dictionary
		if bool(response.get("ok", false)):
			sent += 1
		else:
			remaining.append(row)
	pending_evidence = remaining
	_save_pending()
	return sent

func _load_pending() -> void:
	if not FileAccess.file_exists(PENDING_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PENDING_PATH))
	if parsed is Array:
		pending_evidence = (parsed as Array).duplicate(true)

func _save_pending() -> void:
	var file: FileAccess = FileAccess.open(PENDING_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(pending_evidence))
