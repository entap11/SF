# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only emit intents/requests and render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
class_name WinSystem
extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")
const CONTESTABLE_KIND := {
	"hive": true,
	"mediumhive": true,
	"largehive": true
}
const DEBUG_HEARTBEAT_MS := 1000

var state: GameState = null
var ops_state: Object = null
var _dirty: bool = false

var debug_log: bool = false
var last_snapshot_hash: String = ""
var last_log_ms: int = 0
var last_candidate: int = 0
var _last_winner_candidate: int = 0
var last_counts: Dictionary = {}
var _last_snapshot: Dictionary = {}


func bind_state(s: GameState, ops_state_ref: Object) -> void:
	state = s
	ops_state = ops_state_ref
	_dirty = true
	last_snapshot_hash = ""
	last_log_ms = 0
	last_candidate = 0
	_last_winner_candidate = 0
	last_counts = {}
	_last_snapshot = {}

func notify_hive_owner_changed() -> void:
	_dirty = true

func tick(state_ref: GameState, now_ms: int) -> Variant:
	if state_ref == null or ops_state == null:
		return null
	if ops_state.match_over:
		return null
	if ops_state.match_phase != ops_state.MatchPhase.RUNNING:
		return null
	var heartbeat_due := debug_log and now_ms - last_log_ms >= DEBUG_HEARTBEAT_MS

	# Always evaluate snapshot so wins are detected even if nobody toggles _dirty.
	var snapshot := _build_snapshot(state_ref)

	# We still treat _dirty as "force log check" and heartbeat as "periodic log".
	var snapshot_hash := str(snapshot.get("hash", ""))
	var changed := snapshot_hash != last_snapshot_hash
	var winner_candidate := int(snapshot.get("winner_candidate", 0))
	if winner_candidate != _last_winner_candidate:
		_last_winner_candidate = winner_candidate
		SFLog.info("WIN_CANDIDATE", {
			"winner_candidate": winner_candidate,
			"contestable_total": int(snapshot.get("contestable_total", 0)),
			"owned": snapshot.get("owned_by_team", {})
		})

	if changed or _dirty:
		last_snapshot_hash = snapshot_hash
		last_candidate = winner_candidate
		last_counts = snapshot.get("owned_by_team", {}).duplicate()
		_last_snapshot = snapshot.duplicate(true)
		_log_win_change(snapshot)
		last_log_ms = now_ms
	elif heartbeat_due:
		_log_win_heartbeat(snapshot)
		last_log_ms = now_ms

	_dirty = false
	var winner_id := int(snapshot.get("winner_id", 0))
	if winner_id > 0:
		return {"winner_id": winner_id, "reason": str(snapshot.get("win_reason", "conquest"))}
	return null

func get_debug_snapshot() -> Dictionary:
	return _last_snapshot.duplicate(true)

func _build_snapshot(state_ref: GameState) -> Dictionary:
	var contestable_total := 0
	var neutral_count := 0
	var npc_count := 0
	var owned_by_team: Dictionary = {}
	var alive_player_teams: Dictionary = {}
	var winner_candidate := 0
	var split_owner := false
	var hives: Array = []
	var hives_by_id: Dictionary = state_ref.hive_by_id if state_ref != null else {}
	if hives_by_id.size() > 0:
		hives = hives_by_id.values()
	else:
		hives = state_ref.hives
	for h in hives:
		if h == null:
			continue
		var kind_norm := _normalized_kind(_hive_kind(h))
		if not CONTESTABLE_KIND.has(kind_norm):
			continue
		if _is_npc_hive(h, kind_norm):
			npc_count += 1
			continue
		contestable_total += 1
		var oid := _hive_owner_id(h)
		if oid <= 0:
			neutral_count += 1
			continue
		if oid >= 1 and oid <= 4:
			alive_player_teams[oid] = true
			owned_by_team[oid] = int(owned_by_team.get(oid, 0)) + 1
	var winner_id := 0
	var reason := ""
	var win_reason := ""
	if alive_player_teams.size() == 1:
		for team_id in alive_player_teams.keys():
			winner_candidate = int(team_id)
			break
	winner_id = winner_candidate
	split_owner = alive_player_teams.size() > 1
	if alive_player_teams.is_empty():
		reason = "no_player_hives"
	elif split_owner:
		reason = "split_ownership"
	elif winner_id > 0:
		reason = "winner_detected"
		win_reason = "conquest"
	else:
		reason = "no_candidate"
	var counts_key := _counts_key(owned_by_team)
	var snapshot_hash := "%d|%d|%d|%s|%d" % [
		contestable_total,
		neutral_count,
		npc_count,
		counts_key,
		winner_id
	]
	return {
		"contestable_total": contestable_total,
		"contestable_neutral_count": neutral_count,
		"contestable_npc_count": npc_count,
		"owned_by_team": owned_by_team,
		"winner_candidate": winner_candidate,
		"winner_id": winner_id,
		"reason": reason,
		"win_reason": win_reason,
		"hash": snapshot_hash
	}

func _log_win_change(snapshot: Dictionary) -> void:
	SFLog.info("WIN_CHECK_CHANGE", {
		"reason": str(snapshot.get("reason", "")),
		"contestable_total": int(snapshot.get("contestable_total", 0)),
		"contestable_owned_by_team": snapshot.get("owned_by_team", {}),
		"contestable_neutral_count": int(snapshot.get("contestable_neutral_count", 0)),
		"contestable_npc_count": int(snapshot.get("contestable_npc_count", 0)),
		"winner_candidate": int(snapshot.get("winner_candidate", 0))
	})

func _log_win_heartbeat(snapshot: Dictionary) -> void:
	SFLog.info("WIN_CHECK_HEARTBEAT", {
		"contestable_total": int(snapshot.get("contestable_total", 0)),
		"contestable_owned_by_team": snapshot.get("owned_by_team", {}),
		"contestable_neutral_count": int(snapshot.get("contestable_neutral_count", 0)),
		"contestable_npc_count": int(snapshot.get("contestable_npc_count", 0)),
		"winner_candidate": int(snapshot.get("winner_candidate", 0))
	})

func _counts_key(owned_by_team: Dictionary) -> String:
	if owned_by_team.is_empty():
		return ""
	var team_ids := owned_by_team.keys()
	team_ids.sort()
	var parts: Array = []
	for team_id in team_ids:
		parts.append("%d:%d" % [int(team_id), int(owned_by_team.get(team_id, 0))])
	return ",".join(parts)

func _hive_kind(hv: Variant) -> String:
	if typeof(hv) == TYPE_DICTIONARY:
		var hd: Dictionary = hv
		return str(hd.get("kind", ""))
	return str(hv.kind)

func _hive_owner_id(hv: Variant) -> int:
	if typeof(hv) == TYPE_DICTIONARY:
		var hd: Dictionary = hv
		return int(hd.get("owner_id", 0))
	return int(hv.owner_id)

func _normalized_kind(kind: String) -> String:
	var key := kind.strip_edges().to_lower()
	key = key.replace("_", "")
	if key == "playerhive":
		return "hive"
	return key

func _is_npc_hive(hv: Variant, kind_norm: String) -> bool:
	if kind_norm == "npc" or kind_norm == "npchive":
		return true
	if typeof(hv) == TYPE_DICTIONARY:
		var hd: Dictionary = hv
		if bool(hd.get("is_npc", false)):
			return true
		var owner_str := str(hd.get("owner", "")).strip_edges().to_lower()
		if owner_str == "npc":
			return true
	return false
