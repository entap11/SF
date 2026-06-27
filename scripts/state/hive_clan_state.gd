extends Node

const SFLog = preload("res://scripts/util/sf_log.gd")

signal hive_clan_state_changed(snapshot: Dictionary)
signal hive_clan_event(event: Dictionary)

const SAVE_PATH: String = "user://hive_clan_state.json"
const SAVE_SCHEMA_VERSION: int = 6
const ROLE_QUEEN: String = "queen"
const ROLE_SOLDIER: String = "soldier"
const ROLE_MEMBER: String = "member"
const INVITE_STATUS_PENDING: String = "pending"
const INVITE_STATUS_ACCEPTED: String = "accepted"
const INVITE_STATUS_DECLINED: String = "declined"
const INVITE_STATUS_EXPIRED: String = "expired"
const HIVE_ID_PREFIX: String = "h_"
const INVITE_ID_PREFIX: String = "hi_"
const APPLICATION_ID_PREFIX: String = "ha_"
const ID_HEX_LEN: int = 10
const HIVE_NAME_MAX_LEN: int = 24
const MAX_SOLDIERS: int = 3
const MAX_HIVE_MEMBERS: int = 14
const MIN_LEADERSHIP_REMOVAL_VOTES: int = 9
const GOVERNANCE_VOTE_WINDOW_SEC: int = 48 * 60 * 60
const VOTE_ABSTAIN_INACTIVE_SEC: int = 7 * 24 * 60 * 60
const INACTIVE_QUEEN_SUCCESSION_SEC: int = 12 * 7 * 24 * 60 * 60
const HIVE_CREATE_LIMIT_COUNT: int = 1
const HIVE_CREATE_LIMIT_WINDOW_SEC: int = 7 * 24 * 60 * 60
const INVITE_EXPIRY_SEC: int = 48 * 60 * 60
const LEAVE_DELAY_SEC: int = 24 * 60 * 60
const REJOIN_SAME_HIVE_COOLDOWN_SEC: int = 7 * 24 * 60 * 60
const APPLICATION_STATUS_PENDING: String = "pending"
const APPLICATION_STATUS_ACCEPTED: String = "accepted"
const APPLICATION_STATUS_DECLINED: String = "declined"
const HIVE_FEED_LIMIT: int = 24
const HIVE_COMMS_POST_MAX_LEN: int = 180
const HIVE_PINNED_NOTICE_MAX_LEN: int = 220
const HIVE_ABOUT_MAX_LEN: int = 300
const HIVE_ABOUT_UPDATE_COOLDOWN_SEC: int = 24 * 60 * 60
const HIVE_AWARD_ID_PREFIX: String = "hwa_"
const HIVE_AWARD_TYPE_TROPHY: String = "trophy"
const HIVE_AWARD_TYPE_NFT: String = "nft"
const HIVE_AWARD_OWNER_HIVE: String = "hive"
const HIVE_AWARD_OWNER_COMPANY: String = "company"
const HIVE_RANK_TOURNAMENT_MULTIPLIER_BPS: int = 100
const HIVE_RANK_CHAMPIONSHIP_MULTIPLIER_BPS: int = 1000
const HIVE_TOURNAMENT_ROSTER_SIZE: int = 7
const HIVE_TOURNAMENT_MAP_COUNT: int = 3
const HIVE_TOURNAMENT_LOGIN_REPLACE_SEC: int = 3 * 24 * 60 * 60
const HIVE_TOURNAMENT_ROUND_WINDOW_SEC: int = 5 * 24 * 60 * 60
const HIVE_TOURNAMENT_DNF_TIME_MS: int = 60 * 60 * 1000
const TOURNAMENT_ROUND_ID_PREFIX: String = "htr_"
const TOURNAMENT_BRACKET_ID_PREFIX: String = "htb_"
const HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H: String = "single_elimination_h2h"
const HIVE_TOURNAMENT_STATUS_QUEUED: String = "queued"
const HIVE_TOURNAMENT_STATUS_ACTIVE: String = "active"
const HIVE_TOURNAMENT_STATUS_RESOLVED: String = "resolved"
const HIVE_TOURNAMENT_STATUS_FORFEIT: String = "forfeit"
const HIVE_TOURNAMENT_BRACKET_STATUS_ACTIVE: String = "active"
const HIVE_TOURNAMENT_BRACKET_STATUS_RESOLVED: String = "resolved"
const HIVE_TOURNAMENT_STAGE_MAP_PATHS: Array[String] = [
	"res://maps/_future/nomansland/MAP_nomansland__545__v01_top2_sides__1p.json",
	"res://maps/_future/nomansland/MAP_nomansland__545__v17_four_corners_only__1p.json",
	"res://maps/_future/nomansland/MAP_nomansland__444__v01_pinched_spine__1p.json"
]
const INVITE_OFFER_BUNDLES: Array[Dictionary] = [
	{"bundle_id": "starter", "title": "Starter Honey Gift", "honey_cost": 250, "detail": "Small welcome gift attached to the invite."},
	{"bundle_id": "rally", "title": "Rally Honey Gift", "honey_cost": 750, "detail": "Mid-tier recruiting offer for active players."},
	{"bundle_id": "elite", "title": "Elite Honey Gift", "honey_cost": 1500, "detail": "High-value offer for top targets."}
]
const HIVE_TOURNAMENT_ENTRIES: Array[Dictionary] = [
	{"tournament_id": "weekly_hive_skirmish", "title": "Weekly Hive Skirmish", "honey_cost": 1000, "detail": "Low-risk weekly bracket for active hives.", "format_id": HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H, "field_size": 4},
	{"tournament_id": "monthly_hive_cup", "title": "Monthly Hive Cup", "honey_cost": 3500, "detail": "Monthly team event with larger hive rank upside.", "format_id": HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H, "field_size": 8},
	{"tournament_id": "seasonal_royal_gauntlet", "title": "Seasonal Royal Gauntlet", "honey_cost": 9000, "detail": "High-cost seasonal run for serious teams.", "format_id": HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H, "field_size": 8}
]

var _save_schema_version: int = SAVE_SCHEMA_VERSION
var _hives_by_id: Dictionary = {}
var _invites_by_id: Dictionary = {}
var _applications_by_id: Dictionary = {}
var _player_to_hive_id: Dictionary = {}
var _pending_leave_by_player_id: Dictionary = {}
var _rejoin_cooldowns_by_player_id: Dictionary = {}
var _hive_creation_history_by_player_id: Dictionary = {}
var _hive_tournament_queue_by_tournament_id: Dictionary = {}
var _hive_tournament_brackets_by_id: Dictionary = {}
var _hive_tournament_rounds_by_id: Dictionary = {}
var _company_trophy_case: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var save_path: String = SAVE_PATH

func _ready() -> void:
	SFLog.allow_tag("HIVE_CLAN_STATE")
	SFLog.allow_tag("HIVE_CLAN_EVENT")
	_rng.randomize()
	_load_state()
	_refresh_runtime_state()
	_bootstrap_local_profile()
	_connect_profile_honey_signal()
	_connect_tree_signals()
	call_deferred("_scan_for_sim_runner")
	_emit_changed()

func get_snapshot() -> Dictionary:
	_refresh_runtime_state()
	var local_player_id: String = _local_player_id()
	return {
		"schema_version": _save_schema_version,
		"transport_mode": "local",
		"local_player_id": local_player_id,
		"local_membership": get_player_membership(local_player_id),
		"hives": _sorted_hive_snapshots(),
		"pending_invites": get_pending_invites_for_player(local_player_id),
		"visible_invites": get_visible_invites_for_player(local_player_id),
		"browseable_hives": get_browseable_hives(local_player_id),
		"comms_access": get_hive_comms_access_for_player(local_player_id),
		"discoverable_players": get_players_without_hive(),
		"pending_applications": get_applications_for_player(local_player_id),
		"received_applications": get_received_applications_for_player(local_player_id),
		"pending_governance_actions": get_pending_governance_actions_for_player(local_player_id),
		"active_tournament_assignment": get_player_active_tournament_assignment(local_player_id),
		"company_trophy_case": get_company_trophy_case()
	}

func get_hive_snapshot(hive_id: String) -> Dictionary:
	_refresh_runtime_state()
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {}
	return _build_hive_snapshot(hive)

func get_company_trophy_case() -> Array[Dictionary]:
	_refresh_runtime_state()
	return _company_trophy_case.duplicate(true)

func get_player_active_tournament_assignment(player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	if resolved_player_id.is_empty():
		return {}
	for round_any in _hive_tournament_rounds_by_id.values():
		var round: Dictionary = round_any as Dictionary
		if str(round.get("status", "")) != HIVE_TOURNAMENT_STATUS_ACTIVE:
			continue
		var assignment: Dictionary = _find_player_assignment_in_round(round, resolved_player_id)
		if assignment.is_empty():
			continue
		if str(assignment.get("slot_status", "")) == "submitted":
			continue
		return assignment
	return {}

func get_player_membership(player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	if resolved_player_id.is_empty():
		return {}
	var hive_id: String = str(_player_to_hive_id.get(resolved_player_id, ""))
	if hive_id.is_empty():
		return {}
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {}
	var member: Dictionary = _member_for_player(hive, resolved_player_id)
	if member.is_empty():
		return {}
	return {
		"hive_id": hive_id,
		"hive_name": str(hive.get("name", "")),
		"player_id": resolved_player_id,
		"display_name": str(member.get("display_name", "")),
		"role": str(member.get("role", ROLE_MEMBER)),
		"honey_contributed": int(member.get("honey_contributed", 0)),
		"hive_honey_strength": int(hive.get("hive_honey_strength", 0)),
		"total_honey_contributed": int(hive.get("total_honey_contributed", 0)),
		"leave_request": _build_leave_request_snapshot(resolved_player_id),
		"can_spend_hive_honey": can_spend_hive_honey(hive_id, resolved_player_id)
	}

func get_pending_invites_for_player(player_id: String = "") -> Array[Dictionary]:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	var out: Array[Dictionary] = []
	if resolved_player_id.is_empty():
		return out
	for invite_any in _invites_by_id.values():
		var invite: Dictionary = invite_any as Dictionary
		if str(invite.get("status", "")) != INVITE_STATUS_PENDING:
			continue
		if str(invite.get("target_player_id", "")) != resolved_player_id:
			continue
		out.append(_build_invite_snapshot(invite))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("created_at_unix", 0)) > int(b.get("created_at_unix", 0))
	)
	return out

func get_visible_invites_for_player(player_id: String = "") -> Array[Dictionary]:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	var out: Array[Dictionary] = []
	if resolved_player_id.is_empty():
		return out
	for invite_any in _invites_by_id.values():
		var invite: Dictionary = invite_any as Dictionary
		if str(invite.get("target_player_id", "")) != resolved_player_id:
			continue
		out.append(_build_invite_snapshot(invite, resolved_player_id))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("created_at_unix", 0)) > int(b.get("created_at_unix", 0))
	)
	return out

func get_browseable_hives(player_id: String = "") -> Array[Dictionary]:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	var out: Array[Dictionary] = []
	for hive_any in _hives_by_id.values():
		var hive: Dictionary = hive_any as Dictionary
		var snapshot: Dictionary = _build_hive_snapshot(hive)
		var hive_id: String = str(snapshot.get("hive_id", ""))
		var pending_invite: Dictionary = _find_invite_for_player(hive_id, resolved_player_id, INVITE_STATUS_PENDING)
		var expired_invite: Dictionary = _find_invite_for_player(hive_id, resolved_player_id, INVITE_STATUS_EXPIRED)
		var pending_application: Dictionary = _find_application_for_player(hive_id, resolved_player_id, APPLICATION_STATUS_PENDING)
		var blocked_until_unix: int = _rejoin_block_until(resolved_player_id, hive_id)
		var can_apply: bool = not resolved_player_id.is_empty()
		can_apply = can_apply and not _player_has_hive(resolved_player_id)
		can_apply = can_apply and pending_invite.is_empty()
		can_apply = can_apply and pending_application.is_empty()
		can_apply = can_apply and blocked_until_unix <= _now_unix()
		snapshot["pending_invite"] = pending_invite
		snapshot["expired_invite"] = expired_invite
		snapshot["pending_application"] = pending_application
		snapshot["blocked_until_unix"] = blocked_until_unix
		snapshot["can_apply"] = can_apply
		out.append(snapshot)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rank_a: int = int(a.get("rank_points", 0))
		var rank_b: int = int(b.get("rank_points", 0))
		if rank_a != rank_b:
			return rank_a > rank_b
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return out

func get_players_without_hive(limit: int = 50) -> Array[Dictionary]:
	_refresh_runtime_state()
	var out: Array[Dictionary] = []
	var rank_state: Node = _rank_state()
	if rank_state == null or not rank_state.has_method("get_leaderboard_snapshot"):
		return out
	var local_player_id: String = _local_player_id()
	var board: Dictionary = rank_state.call("get_leaderboard_snapshot", local_player_id, "GLOBAL", maxi(limit * 4, 100)) as Dictionary
	var rows_any: Variant = board.get("rows", [])
	if typeof(rows_any) != TYPE_ARRAY:
		return out
	for row_any in rows_any as Array:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		var player_id: String = _sanitize_player_id(str(row.get("player_id", "")))
		if player_id.is_empty() or player_id == local_player_id:
			continue
		if _player_has_hive(player_id):
			continue
		out.append({
			"player_id": player_id,
			"display_name": str(row.get("display_name", player_id)),
			"rank_global": int(row.get("rank_global", 0)),
			"tier_id": str(row.get("tier_id", "DRONE")),
			"color_id": str(row.get("color_id", "GREEN")),
			"wax_score": float(row.get("wax_score", 0.0))
		})
		if out.size() >= limit:
			break
	return out

func get_applications_for_player(player_id: String = "") -> Array[Dictionary]:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	var out: Array[Dictionary] = []
	if resolved_player_id.is_empty():
		return out
	for application_any in _applications_by_id.values():
		var application: Dictionary = application_any as Dictionary
		if str(application.get("player_id", "")) != resolved_player_id:
			continue
		out.append(_build_application_snapshot(application))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("created_at_unix", 0)) > int(b.get("created_at_unix", 0))
	)
	return out

func get_received_applications_for_player(player_id: String = "") -> Array[Dictionary]:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	var out: Array[Dictionary] = []
	if resolved_player_id.is_empty():
		return out
	for hive_any in _hives_by_id.values():
		var hive: Dictionary = hive_any as Dictionary
		if not _can_manage_invites(hive, resolved_player_id):
			continue
		var hive_id: String = str(hive.get("hive_id", ""))
		for application_any in _applications_by_id.values():
			var application: Dictionary = application_any as Dictionary
			if str(application.get("hive_id", "")) != hive_id:
				continue
			if str(application.get("status", "")) != APPLICATION_STATUS_PENDING:
				continue
			out.append(_build_application_snapshot(application))
		break
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("created_at_unix", 0)) > int(b.get("created_at_unix", 0))
	)
	return out

func get_hive_invites(hive_id: String, status_filter: String = "") -> Array[Dictionary]:
	_refresh_runtime_state()
	var out: Array[Dictionary] = []
	var filter_status: String = status_filter.strip_edges().to_lower()
	for invite_any in _invites_by_id.values():
		var invite: Dictionary = invite_any as Dictionary
		if str(invite.get("hive_id", "")) != hive_id:
			continue
		var invite_status: String = str(invite.get("status", INVITE_STATUS_PENDING))
		if not filter_status.is_empty() and invite_status != filter_status:
			continue
		out.append(_build_invite_snapshot(invite, str(invite.get("target_player_id", ""))))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var status_a: String = str(a.get("status", ""))
		var status_b: String = str(b.get("status", ""))
		if status_a != status_b:
			return status_a < status_b
		return int(a.get("created_at_unix", 0)) > int(b.get("created_at_unix", 0))
	)
	return out

func get_invite_offer_bundles() -> Array[Dictionary]:
	return INVITE_OFFER_BUNDLES.duplicate(true)

func get_hive_tournament_entries() -> Array[Dictionary]:
	return HIVE_TOURNAMENT_ENTRIES.duplicate(true)

func get_hive_tournament_dashboard(hive_id: String, tournament_id: String = "", player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var clean_hive_id: String = str(hive_id).strip_edges()
	if clean_hive_id.is_empty():
		return {}
	var hive: Dictionary = _hives_by_id.get(clean_hive_id, {}) as Dictionary
	if hive.is_empty():
		return {}
	var tournament_entries: Dictionary = hive.get("tournament_entries", {}) as Dictionary
	if tournament_entries.is_empty():
		return {}
	var clean_tournament_id: String = str(tournament_id).strip_edges()
	var entry: Dictionary = {}
	if clean_tournament_id.is_empty():
		entry = _most_relevant_hive_tournament_entry(tournament_entries)
	else:
		entry = tournament_entries.get(clean_tournament_id, {}) as Dictionary
	if entry.is_empty():
		return {}
	var resolved_tournament_id: String = str(entry.get("tournament_id", clean_tournament_id)).strip_edges()
	var clean_player_id: String = _resolve_player_id(player_id)
	var dashboard: Dictionary = {
		"hive_id": clean_hive_id,
		"hive_name": str(hive.get("name", "")),
		"tournament_id": resolved_tournament_id,
		"title": str(entry.get("title", "Hive Tournament")),
		"detail": str(entry.get("detail", "")),
		"queue_status": str(entry.get("queue_status", HIVE_TOURNAMENT_STATUS_QUEUED)),
		"bracket_id": str(entry.get("bracket_id", "")),
		"bracket_status": str(entry.get("bracket_status", HIVE_TOURNAMENT_BRACKET_STATUS_ACTIVE)),
		"format_id": str(entry.get("format_id", HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H)),
		"field_size": maxi(2, int(entry.get("field_size", 2))),
		"current_round_number": maxi(0, int(entry.get("current_round_number", 0))),
		"rounds_total": maxi(0, int(entry.get("rounds_total", 0))),
		"round_id": str(entry.get("round_id", "")),
		"opponent_hive_id": str(entry.get("opponent_hive_id", "")),
		"round_started_at_unix": maxi(0, int(entry.get("round_started_at_unix", 0))),
		"replace_deadline_unix": maxi(0, int(entry.get("replace_deadline_unix", 0))),
		"deadline_unix": maxi(0, int(entry.get("round_deadline_unix", 0))),
		"queued_at_unix": maxi(0, int(entry.get("queued_at_unix", 0))),
		"queue_position": _hive_tournament_queue_position(resolved_tournament_id, clean_hive_id),
		"queue_size": _hive_tournament_queue_size(resolved_tournament_id),
		"last_result": _sanitize_hive_tournament_result(entry.get("last_result", {})),
		"slot_matchups": [],
		"hive_completed_count": 0,
		"opponent_completed_count": 0,
		"roster_size": HIVE_TOURNAMENT_ROSTER_SIZE,
		"local_assignment": {},
		"status_summary": "",
		"status_detail": ""
	}
	var bracket_id: String = str(dashboard.get("bracket_id", ""))
	var bracket: Dictionary = _hive_tournament_brackets_by_id.get(bracket_id, {}) as Dictionary if not bracket_id.is_empty() else {}
	if not bracket.is_empty():
		dashboard["bracket_status"] = str(bracket.get("status", dashboard.get("bracket_status", HIVE_TOURNAMENT_BRACKET_STATUS_ACTIVE)))
		dashboard["current_round_number"] = maxi(int(dashboard.get("current_round_number", 0)), int(bracket.get("current_round_number", 0)))
		dashboard["rounds_total"] = maxi(int(dashboard.get("rounds_total", 0)), int(bracket.get("rounds_total", 0)))
		dashboard["field_size"] = maxi(int(dashboard.get("field_size", 2)), int(bracket.get("field_size", 2)))
	var round_id: String = str(dashboard.get("round_id", ""))
	var round: Dictionary = _hive_tournament_rounds_by_id.get(round_id, {}) as Dictionary if not round_id.is_empty() else {}
	if not round.is_empty():
		var perspective: Dictionary = _hive_tournament_round_perspective(round, clean_hive_id, clean_player_id)
		dashboard["opponent_hive_id"] = str(perspective.get("opponent_hive_id", dashboard.get("opponent_hive_id", "")))
		dashboard["opponent_hive_name"] = str(perspective.get("opponent_hive_name", ""))
		dashboard["slot_matchups"] = (perspective.get("slot_matchups", []) as Array).duplicate(true)
		dashboard["hive_completed_count"] = int(perspective.get("hive_completed_count", 0))
		dashboard["opponent_completed_count"] = int(perspective.get("opponent_completed_count", 0))
		dashboard["roster_size"] = int(perspective.get("roster_size", HIVE_TOURNAMENT_ROSTER_SIZE))
		dashboard["local_assignment"] = (perspective.get("local_assignment", {}) as Dictionary).duplicate(true)
		dashboard["round_started_at_unix"] = int(round.get("started_at_unix", dashboard.get("round_started_at_unix", 0)))
		dashboard["replace_deadline_unix"] = int(round.get("replace_deadline_unix", dashboard.get("replace_deadline_unix", 0)))
		dashboard["deadline_unix"] = int(round.get("deadline_unix", dashboard.get("deadline_unix", 0)))
		dashboard["current_round_number"] = maxi(int(dashboard.get("current_round_number", 0)), int(round.get("bracket_round_number", 0)))
		dashboard["status_summary"] = "Round %d/%d vs %s" % [
			maxi(1, int(dashboard.get("current_round_number", 1))),
			maxi(1, int(dashboard.get("rounds_total", 1))),
			str(dashboard.get("opponent_hive_name", "Opposing Hive"))
		]
		dashboard["status_detail"] = "%d/%d finished | %d/%d finished | Deadline %d" % [
			int(dashboard.get("hive_completed_count", 0)),
			int(dashboard.get("roster_size", HIVE_TOURNAMENT_ROSTER_SIZE)),
			int(dashboard.get("opponent_completed_count", 0)),
			int(dashboard.get("roster_size", HIVE_TOURNAMENT_ROSTER_SIZE)),
			int(dashboard.get("deadline_unix", 0))
		]
		return dashboard
	if str(dashboard.get("queue_status", "")) == HIVE_TOURNAMENT_STATUS_QUEUED:
		dashboard["status_summary"] = "Queued for bracket"
		dashboard["status_detail"] = "Field %d | Queue %d/%d" % [
			int(dashboard.get("field_size", 2)),
			maxi(1, int(dashboard.get("queue_position", 0))),
			maxi(1, int(dashboard.get("queue_size", 0)))
		]
	elif str(dashboard.get("queue_status", "")) == HIVE_TOURNAMENT_STATUS_RESOLVED or str(dashboard.get("queue_status", "")) == HIVE_TOURNAMENT_STATUS_FORFEIT:
		var last_result: Dictionary = dashboard.get("last_result", {}) as Dictionary
		var winner_hive_id: String = str(last_result.get("winner_hive_id", ""))
		if winner_hive_id == clean_hive_id:
			dashboard["status_summary"] = "Bracket complete: won"
		elif winner_hive_id.is_empty():
			dashboard["status_summary"] = "Bracket complete"
		else:
			dashboard["status_summary"] = "Bracket complete: lost"
		dashboard["status_detail"] = str(last_result.get("resolution_reason", "resolved")).strip_edges().replace("_", " ")
	else:
		dashboard["status_summary"] = "Awaiting next round"
		dashboard["status_detail"] = "Bracket %d/%d | Field %d" % [
			maxi(1, int(dashboard.get("current_round_number", 1))),
			maxi(1, int(dashboard.get("rounds_total", 1))),
			maxi(2, int(dashboard.get("field_size", 2)))
		]
	return dashboard

func intent_enter_hive_tournament(hive_id: String, tournament_id: String, actor_player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var actor_id: String = _resolve_player_id(actor_player_id)
	var resolved_tournament_id: String = str(tournament_id).strip_edges()
	if actor_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	if resolved_tournament_id.is_empty():
		return {"ok": false, "reason": "tournament_not_found"}
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	if _role_for_player(hive, actor_id) != ROLE_QUEEN:
		return {"ok": false, "reason": "forbidden"}
	var entry_def: Dictionary = _hive_tournament_entry_for_id(resolved_tournament_id)
	if entry_def.is_empty():
		return {"ok": false, "reason": "tournament_not_found"}
	if _current_hive_member_count(hive) < HIVE_TOURNAMENT_ROSTER_SIZE:
		return {
			"ok": false,
			"reason": "insufficient_hive_members",
			"required_members": HIVE_TOURNAMENT_ROSTER_SIZE,
			"member_count": _current_hive_member_count(hive)
		}
	var tournament_entries: Dictionary = hive.get("tournament_entries", {}) as Dictionary
	var existing_entry: Dictionary = tournament_entries.get(resolved_tournament_id, {}) as Dictionary
	if not existing_entry.is_empty():
		var existing_status: String = str(existing_entry.get("queue_status", HIVE_TOURNAMENT_STATUS_QUEUED))
		if existing_status == HIVE_TOURNAMENT_STATUS_QUEUED or existing_status == HIVE_TOURNAMENT_STATUS_ACTIVE:
			return {"ok": false, "reason": "tournament_already_entered", "entry": existing_entry.duplicate(true)}
	if _hive_has_open_tournament_commitment(hive_id):
		return {"ok": false, "reason": "active_round_in_progress"}
	var honey_cost: int = maxi(0, int(entry_def.get("honey_cost", 0)))
	var purchase_preview: Dictionary = preview_hive_honey_purchase(hive_id, honey_cost)
	var available_hive_honey: int = maxi(0, int(purchase_preview.get("available_hive_honey", hive.get("hive_honey_strength", 0))))
	if honey_cost <= 0:
		return {"ok": false, "reason": "invalid_tournament_cost"}
	if not bool(purchase_preview.get("ok", false)):
		return {
			"ok": false,
			"reason": str(purchase_preview.get("reason", "insufficient_hive_honey")),
			"available_hive_honey": available_hive_honey,
			"required_hive_honey": honey_cost
		}
	var debit_result: Dictionary = intent_debit_hive_honey_proportional(hive_id, honey_cost, "hive_tournament:%s" % resolved_tournament_id, {}, actor_id)
	if not bool(debit_result.get("ok", false)):
		return debit_result
	hive = _hives_by_id.get(hive_id, hive) as Dictionary
	var entry_record: Dictionary = {
		"tournament_id": resolved_tournament_id,
		"title": str(entry_def.get("title", "Hive Tournament")),
		"detail": str(entry_def.get("detail", "")),
		"honey_cost": honey_cost,
		"honey_deductions": (debit_result.get("deductions", []) as Array).duplicate(true),
		"entered_at_unix": _now_unix(),
		"entered_by_player_id": actor_id,
		"queue_status": HIVE_TOURNAMENT_STATUS_QUEUED,
		"round_id": "",
		"queued_at_unix": _now_unix(),
		"round_started_at_unix": 0,
		"round_deadline_unix": 0,
		"replace_deadline_unix": 0,
		"opponent_hive_id": "",
		"last_result": {}
	}
	tournament_entries[resolved_tournament_id] = entry_record
	hive["tournament_entries"] = tournament_entries
	_recompute_hive_metrics(hive)
	_hives_by_id[hive_id] = hive
	var queue_result: Dictionary = _queue_hive_tournament_entry(hive_id, resolved_tournament_id)
	var round: Dictionary = queue_result.get("round", {}) as Dictionary
	_save_state()
	_emit_event({
		"type": "hive_tournament_entered",
		"hive_id": hive_id,
		"player_id": actor_id,
		"tournament_id": resolved_tournament_id,
		"title": str(entry_record.get("title", "Hive Tournament")),
		"honey_cost": honey_cost,
		"honey_deductions": (debit_result.get("deductions", []) as Array).duplicate(true)
	})
	return {
		"ok": true,
		"hive": _build_hive_snapshot(_hives_by_id.get(hive_id, hive) as Dictionary),
		"entry": (( _hives_by_id.get(hive_id, hive) as Dictionary).get("tournament_entries", {}) as Dictionary).get(resolved_tournament_id, entry_record).duplicate(true),
		"round": round.duplicate(true),
		"bracket": (queue_result.get("bracket", {}) as Dictionary).duplicate(true)
	}

func intent_record_hive_tournament_submission(round_id: String, player_id: String = "", total_time_ms: int = 0, round_results: Array = []) -> Dictionary:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	var clean_round_id: String = str(round_id).strip_edges()
	if resolved_player_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	if clean_round_id.is_empty():
		return {"ok": false, "reason": "round_not_found"}
	var round: Dictionary = _hive_tournament_rounds_by_id.get(clean_round_id, {}) as Dictionary
	if round.is_empty():
		return {"ok": false, "reason": "round_not_found"}
	if str(round.get("status", "")) != HIVE_TOURNAMENT_STATUS_ACTIVE:
		return {"ok": false, "reason": "round_not_active"}
	var assignment: Dictionary = _find_player_assignment_in_round(round, resolved_player_id)
	if assignment.is_empty():
		return {"ok": false, "reason": "player_not_assigned"}
	var slot_status: String = str(assignment.get("slot_status", ""))
	if slot_status == "submitted":
		return {"ok": false, "reason": "submission_already_recorded"}
	var side_key: String = str(assignment.get("side_key", ""))
	var slot_index: int = int(assignment.get("slot_index", -1))
	if side_key.is_empty() or slot_index < 0:
		return {"ok": false, "reason": "player_not_assigned"}
	var slots: Array = (round.get(side_key, []) as Array).duplicate(true)
	if slot_index >= slots.size():
		return {"ok": false, "reason": "player_not_assigned"}
	var slot: Dictionary = slots[slot_index] as Dictionary
	slot["checked_in_at_unix"] = _now_unix()
	slot["submitted_at_unix"] = _now_unix()
	slot["total_time_ms"] = maxi(0, total_time_ms)
	slot["round_results"] = round_results.duplicate(true)
	slot["status"] = "submitted"
	slots[slot_index] = slot
	round[side_key] = slots
	_hive_tournament_rounds_by_id[clean_round_id] = round
	_save_state()
	_emit_event({
		"type": "hive_tournament_run_submitted",
		"hive_id": str(assignment.get("hive_id", "")),
		"player_id": resolved_player_id,
		"tournament_id": str(round.get("tournament_id", "")),
		"round_id": clean_round_id,
		"total_time_ms": maxi(0, total_time_ms)
	})
	if _round_is_ready_to_resolve(round):
		_resolve_hive_tournament_round(clean_round_id, "all_submissions_in")
	return {
		"ok": true,
		"round": (_hive_tournament_rounds_by_id.get(clean_round_id, round) as Dictionary).duplicate(true),
		"assignment": _find_player_assignment_in_round(_hive_tournament_rounds_by_id.get(clean_round_id, round) as Dictionary, resolved_player_id)
	}

func get_pending_governance_actions_for_player(player_id: String = "") -> Array[Dictionary]:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	var out: Array[Dictionary] = []
	if resolved_player_id.is_empty():
		return out
	var membership: Dictionary = get_player_membership(resolved_player_id)
	if membership.is_empty():
		return out
	var hive_id: String = str(membership.get("hive_id", ""))
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return out
	var local_role: String = _role_for_player(hive, resolved_player_id)
	var queen_id: String = _first_role_player_id(hive, ROLE_QUEEN)
	var queen_vote: Dictionary = _build_queen_removal_vote_snapshot(hive)
	if local_role == ROLE_SOLDIER and queen_id != resolved_player_id and not bool((hive.get("queen_removal_vote", {}) as Dictionary).get(resolved_player_id, false)):
		out.append({
			"type": "queen_removal_vote",
			"hive_id": hive_id,
			"target_player_id": queen_id,
			"target_role": ROLE_QUEEN,
			"votes_cast": int((queen_vote.get("voter_ids", []) as Array).size()),
			"votes_needed": int(queen_vote.get("votes_needed", MAX_SOLDIERS))
		})
	var soldier_demotion_votes: Array[Dictionary] = _build_all_soldier_demotion_vote_snapshots(hive)
	for vote in soldier_demotion_votes:
		var target_player_id: String = str(vote.get("target_player_id", ""))
		if target_player_id.is_empty() or target_player_id == resolved_player_id:
			continue
		if local_role != ROLE_QUEEN and local_role != ROLE_SOLDIER:
			continue
		var raw_vote_record: Dictionary = (hive.get("soldier_demotion_votes", {}) as Dictionary).get(target_player_id, {}) as Dictionary
		var votes_by_player_id: Dictionary = raw_vote_record.get("votes_by_player_id", {}) as Dictionary
		if bool(votes_by_player_id.get(resolved_player_id, false)):
			continue
		out.append({
			"type": "soldier_demotion_vote",
			"hive_id": hive_id,
			"target_player_id": target_player_id,
			"target_role": ROLE_SOLDIER,
			"votes_cast": int((vote.get("voter_ids", []) as Array).size()),
			"votes_needed": 2
		})
	var leadership_votes: Array[Dictionary] = _build_all_leadership_removal_vote_snapshots(hive)
	for vote in leadership_votes:
		var target_player_id: String = str(vote.get("target_player_id", ""))
		if target_player_id.is_empty() or target_player_id == resolved_player_id:
			continue
		var raw_vote_record: Dictionary = (hive.get("leadership_removal_votes", {}) as Dictionary).get(target_player_id, {}) as Dictionary
		var votes_by_player_id: Dictionary = raw_vote_record.get("votes_by_player_id", {}) as Dictionary
		var eligible_voters: Array[String] = _eligible_leadership_removal_voters(hive, target_player_id)
		if not eligible_voters.has(resolved_player_id) or bool(votes_by_player_id.get(resolved_player_id, false)):
			continue
		out.append({
			"type": "leadership_removal_vote",
			"hive_id": hive_id,
			"target_player_id": target_player_id,
			"target_role": str(vote.get("target_role", "")),
			"votes_cast": int((vote.get("voter_ids", []) as Array).size()),
			"votes_needed": int(vote.get("votes_needed", MIN_LEADERSHIP_REMOVAL_VOTES))
		})
	var promotion_votes: Array[Dictionary] = _build_all_soldier_promotion_vote_snapshots(hive)
	for vote in promotion_votes:
		var target_player_id: String = str(vote.get("target_player_id", ""))
		if target_player_id.is_empty() or target_player_id == resolved_player_id:
			continue
		var raw_vote_record: Dictionary = (hive.get("soldier_promotion_votes", {}) as Dictionary).get(target_player_id, {}) as Dictionary
		var votes_by_player_id: Dictionary = raw_vote_record.get("votes_by_player_id", {}) as Dictionary
		var eligible_voters: Array[String] = _eligible_promotion_voters(hive, target_player_id)
		if not eligible_voters.has(resolved_player_id) or bool(votes_by_player_id.get(resolved_player_id, false)):
			continue
		out.append({
			"type": "soldier_promotion_vote",
			"hive_id": hive_id,
			"target_player_id": target_player_id,
			"target_role": ROLE_MEMBER,
			"votes_cast": int((vote.get("voter_ids", []) as Array).size()),
			"votes_needed": int(vote.get("votes_needed", 0))
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var type_a: String = str(a.get("type", ""))
		var type_b: String = str(b.get("type", ""))
		if type_a != type_b:
			return type_a < type_b
		return str(a.get("target_player_id", "")) < str(b.get("target_player_id", ""))
	)
	return out

func get_hive_comms_access_for_player(player_id: String = "") -> Array[Dictionary]:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	var out: Array[Dictionary] = []
	if resolved_player_id.is_empty():
		return out
	var membership: Dictionary = get_player_membership(resolved_player_id)
	if not membership.is_empty():
		var member_hive: Dictionary = get_hive_snapshot(str(membership.get("hive_id", "")))
		if not member_hive.is_empty():
			out.append({
				"access_type": "member",
				"hive": member_hive,
				"invite": {}
			})
	for invite_any in get_pending_invites_for_player(resolved_player_id):
		if typeof(invite_any) != TYPE_DICTIONARY:
			continue
		var invite: Dictionary = invite_any as Dictionary
		var invite_hive: Dictionary = get_hive_snapshot(str(invite.get("hive_id", "")))
		if invite_hive.is_empty():
			continue
		out.append({
			"access_type": "invite",
			"hive": invite_hive,
			"invite": invite.duplicate(true)
		})
	return out

func intent_post_hive_message(hive_id: String, message_text: String, player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	var resolved_hive_id: String = str(hive_id).strip_edges()
	var sanitized_message: String = _sanitize_comms_text(message_text, HIVE_COMMS_POST_MAX_LEN)
	if resolved_player_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	if resolved_hive_id.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	if sanitized_message == "":
		return {"ok": false, "reason": "invalid_message"}
	var access: Dictionary = _comms_access_for_hive(resolved_player_id, resolved_hive_id)
	if access.is_empty():
		return {"ok": false, "reason": "forbidden"}
	var hive: Dictionary = _hives_by_id.get(resolved_hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	_emit_event({
		"type": "hive_message_posted",
		"hive_id": resolved_hive_id,
		"player_id": resolved_player_id,
		"message": sanitized_message,
		"access_type": str(access.get("access_type", "member"))
	})
	var updated_hive: Dictionary = _hives_by_id.get(resolved_hive_id, hive) as Dictionary
	return {
		"ok": true,
		"hive": _build_hive_snapshot(updated_hive),
		"message": sanitized_message
	}

func intent_set_pinned_notice(hive_id: String, notice_text: String, player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	var resolved_hive_id: String = str(hive_id).strip_edges()
	var sanitized_notice: String = _sanitize_comms_text(notice_text, HIVE_PINNED_NOTICE_MAX_LEN)
	if resolved_player_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	if resolved_hive_id.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	var hive: Dictionary = _hives_by_id.get(resolved_hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	var actor_role: String = _role_for_player(hive, resolved_player_id)
	if actor_role != ROLE_QUEEN and actor_role != ROLE_SOLDIER:
		return {"ok": false, "reason": "forbidden"}
	if sanitized_notice == "":
		hive["pinned_notice"] = {}
	else:
		hive["pinned_notice"] = {
			"message": sanitized_notice,
			"updated_at_unix": _now_unix(),
			"updated_by_player_id": resolved_player_id
		}
	_hives_by_id[resolved_hive_id] = hive
	_save_state()
	_emit_event({
		"type": "hive_pinned_notice_updated",
		"hive_id": resolved_hive_id,
		"player_id": resolved_player_id,
		"message": sanitized_notice
	})
	var updated_hive: Dictionary = _hives_by_id.get(resolved_hive_id, hive) as Dictionary
	return {
		"ok": true,
		"hive": _build_hive_snapshot(updated_hive),
		"cleared": sanitized_notice == ""
	}

func intent_set_hive_about(hive_id: String, about_text: String, player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	var resolved_hive_id: String = str(hive_id).strip_edges()
	var sanitized_about: String = _sanitize_comms_text(about_text, HIVE_ABOUT_MAX_LEN)
	if resolved_player_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	if resolved_hive_id.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	var hive: Dictionary = _hives_by_id.get(resolved_hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	var actor_role: String = _role_for_player(hive, resolved_player_id)
	if actor_role != ROLE_QUEEN:
		return {"ok": false, "reason": "forbidden"}
	var current_about: Dictionary = _sanitize_hive_about_profile(hive.get("about_profile", {}))
	var current_message: String = str(current_about.get("message", "")).strip_edges()
	var updated_at_unix: int = int(current_about.get("updated_at_unix", 0))
	var now_unix: int = _now_unix()
	if sanitized_about == current_message:
		return {
			"ok": true,
			"hive": _build_hive_snapshot(hive),
			"unchanged": true,
			"next_edit_at_unix": updated_at_unix + HIVE_ABOUT_UPDATE_COOLDOWN_SEC if updated_at_unix > 0 else 0
		}
	if updated_at_unix > 0 and updated_at_unix + HIVE_ABOUT_UPDATE_COOLDOWN_SEC > now_unix:
		return {
			"ok": false,
			"reason": "update_cooldown",
			"next_edit_at_unix": updated_at_unix + HIVE_ABOUT_UPDATE_COOLDOWN_SEC
		}
	if sanitized_about == "":
		hive["about_profile"] = {}
	else:
		hive["about_profile"] = {
			"message": sanitized_about,
			"updated_at_unix": now_unix,
			"updated_by_player_id": resolved_player_id
		}
	_hives_by_id[resolved_hive_id] = hive
	_save_state()
	_emit_event({
		"type": "hive_about_updated",
		"hive_id": resolved_hive_id,
		"player_id": resolved_player_id,
		"message": sanitized_about
	})
	var updated_hive: Dictionary = _hives_by_id.get(resolved_hive_id, hive) as Dictionary
	return {
		"ok": true,
		"hive": _build_hive_snapshot(updated_hive),
		"cleared": sanitized_about == "",
		"next_edit_at_unix": now_unix + HIVE_ABOUT_UPDATE_COOLDOWN_SEC if sanitized_about != "" else 0
	}

func intent_create_hive(hive_name: String) -> Dictionary:
	_refresh_runtime_state()
	var player_id: String = _local_player_id()
	if player_id.is_empty():
		return {"ok": false, "reason": "missing_local_player"}
	if _player_has_hive(player_id):
		return {"ok": false, "reason": "player_already_in_hive", "membership": get_player_membership(player_id)}
	var create_limit := _check_hive_create_limit(player_id)
	if not bool(create_limit.get("ok", false)):
		return create_limit
	var clean_name: String = _sanitize_hive_name(hive_name)
	if clean_name.is_empty():
		return {"ok": false, "reason": "invalid_hive_name"}
	var now_unix: int = _now_unix()
	var hive_id: String = _next_id(HIVE_ID_PREFIX)
	var queen_member: Dictionary = _new_member(player_id, _display_name_for_player(player_id), ROLE_QUEEN, now_unix)
	var hive: Dictionary = {
		"hive_id": hive_id,
		"name": clean_name,
			"created_at_unix": now_unix,
			"created_by_player_id": player_id,
			"members": {player_id: queen_member},
			"pinned_notice": {},
			"about_profile": {},
			"soldier_demotion_votes": {},
			"queen_removal_vote": {},
			"queen_removal_vote_started_at_unix": 0,
			"leadership_removal_votes": {},
			"soldier_promotion_votes": {},
		"tournament_entries": {},
		"tournament_wins": 0,
		"hive_championships": 0,
		"seasonal_best_finish": 0,
		"total_honey_spent": 0,
		"feed_entries": [],
		"total_honey_contributed": 0,
		"hive_honey_strength": 0
	}
	_recompute_hive_metrics(hive)
	_hives_by_id[hive_id] = hive
	_reindex_memberships()
	_record_hive_creation(player_id, now_unix)
	_save_state()
	var event: Dictionary = {
		"type": "hive_created",
		"hive_id": hive_id,
		"hive_name": clean_name,
		"player_id": player_id
	}
	_emit_event(event)
	return {"ok": true, "hive": _build_hive_snapshot(hive)}

func intent_invite_player(hive_id: String, target_player_id: String, target_display_name: String = "", role: String = ROLE_MEMBER, invited_by_player_id: String = "", offer_bundle_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var actor_id: String = _resolve_player_id(invited_by_player_id)
	var target_id: String = _sanitize_player_id(target_player_id)
	if actor_id.is_empty() or target_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found", "hive_id": hive_id}
	if not _can_manage_invites(hive, actor_id):
		return {"ok": false, "reason": "forbidden"}
	if _current_hive_member_count(hive) + _pending_invite_count(hive_id) >= MAX_HIVE_MEMBERS:
		return {"ok": false, "reason": "hive_member_limit_reached", "limit": MAX_HIVE_MEMBERS}
	if _player_has_hive(target_id):
		return {"ok": false, "reason": "target_already_in_hive", "membership": get_player_membership(target_id)}
	var clean_role: String = _sanitize_role(role)
	if clean_role != ROLE_MEMBER:
		clean_role = ROLE_MEMBER
	if _find_pending_invite_id(hive_id, target_id) != "":
		return {"ok": false, "reason": "invite_already_pending"}
	if _find_pending_application_id(hive_id, target_id) != "":
		return {"ok": false, "reason": "application_already_pending"}
	var offer_bundle: Dictionary = _invite_offer_bundle_for_id(offer_bundle_id)
	if not offer_bundle_id.strip_edges().is_empty() and offer_bundle.is_empty():
		return {"ok": false, "reason": "invalid_offer_bundle"}
	var invite_id: String = _next_id(INVITE_ID_PREFIX)
	var now_unix: int = _now_unix()
	var invite: Dictionary = {
		"invite_id": invite_id,
		"hive_id": hive_id,
		"target_player_id": target_id,
		"target_display_name": _display_name_for_player(target_id, target_display_name),
		"created_by_player_id": actor_id,
		"created_by_display_name": _display_name_for_player(actor_id),
		"role": clean_role,
		"status": INVITE_STATUS_PENDING,
		"created_at_unix": now_unix,
		"expires_at_unix": now_unix + INVITE_EXPIRY_SEC,
		"responded_at_unix": 0,
		"offer_bundle": offer_bundle
	}
	_invites_by_id[invite_id] = invite
	_save_state()
	var event: Dictionary = {
		"type": "hive_invite_created",
		"hive_id": hive_id,
		"invite_id": invite_id,
		"target_player_id": target_id,
		"created_by_player_id": actor_id
	}
	_emit_event(event)
	return {"ok": true, "invite": _build_invite_snapshot(invite, target_id)}

func intent_invite_recent_opponent(hive_id: String, opponent_player_id: String, opponent_display_name: String = "", actor_player_id: String = "") -> Dictionary:
	return intent_invite_player(hive_id, opponent_player_id, opponent_display_name, ROLE_MEMBER, actor_player_id)

func intent_apply_to_hive(hive_id: String, player_id: String = "", display_name: String = "") -> Dictionary:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	if resolved_player_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	if _player_has_hive(resolved_player_id):
		return {"ok": false, "reason": "player_already_in_hive", "membership": get_player_membership(resolved_player_id)}
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found", "hive_id": hive_id}
	if _current_hive_member_count(hive) + _pending_invite_count(hive_id) >= MAX_HIVE_MEMBERS:
		return {"ok": false, "reason": "hive_member_limit_reached", "limit": MAX_HIVE_MEMBERS}
	if _find_pending_invite_id(hive_id, resolved_player_id) != "":
		return {"ok": false, "reason": "invite_already_pending"}
	if _find_pending_application_id(hive_id, resolved_player_id) != "":
		return {"ok": false, "reason": "application_already_pending"}
	var blocked_until_unix: int = _rejoin_block_until(resolved_player_id, hive_id)
	if blocked_until_unix > _now_unix():
		return {"ok": false, "reason": "rejoin_cooldown_active", "blocked_until_unix": blocked_until_unix}
	var application_id: String = _next_id(APPLICATION_ID_PREFIX)
	var now_unix: int = _now_unix()
	var application: Dictionary = {
		"application_id": application_id,
		"hive_id": hive_id,
		"player_id": resolved_player_id,
		"player_display_name": _display_name_for_player(resolved_player_id, display_name),
		"status": APPLICATION_STATUS_PENDING,
		"created_at_unix": now_unix,
		"responded_at_unix": 0,
		"reviewed_by_player_id": ""
	}
	_applications_by_id[application_id] = application
	_save_state()
	_emit_event({
		"type": "hive_application_created",
		"hive_id": hive_id,
		"application_id": application_id,
		"player_id": resolved_player_id
	})
	return {"ok": true, "application": _build_application_snapshot(application)}

func intent_review_application(application_id: String, approve: bool, actor_player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var actor_id: String = _resolve_player_id(actor_player_id)
	if actor_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var application: Dictionary = _applications_by_id.get(application_id, {}) as Dictionary
	if application.is_empty():
		return {"ok": false, "reason": "application_not_found"}
	if str(application.get("status", "")) != APPLICATION_STATUS_PENDING:
		return {"ok": false, "reason": "application_not_pending"}
	var hive_id: String = str(application.get("hive_id", ""))
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found", "hive_id": hive_id}
	if not _can_manage_invites(hive, actor_id):
		return {"ok": false, "reason": "forbidden"}
	var target_player_id: String = str(application.get("player_id", ""))
	if _player_has_hive(target_player_id):
		application["status"] = APPLICATION_STATUS_DECLINED
		application["responded_at_unix"] = _now_unix()
		application["reviewed_by_player_id"] = actor_id
		_applications_by_id[application_id] = application
		_save_state()
		return {"ok": false, "reason": "player_already_in_hive"}
	var now_unix: int = _now_unix()
	if not approve:
		application["status"] = APPLICATION_STATUS_DECLINED
		application["responded_at_unix"] = now_unix
		application["reviewed_by_player_id"] = actor_id
		_applications_by_id[application_id] = application
		_save_state()
		_emit_event({
			"type": "hive_application_declined",
			"hive_id": hive_id,
			"application_id": application_id,
			"player_id": target_player_id,
			"reviewed_by_player_id": actor_id
		})
		return {"ok": true, "application": _build_application_snapshot(application)}
	if _current_hive_member_count(hive) >= MAX_HIVE_MEMBERS:
		return {"ok": false, "reason": "hive_member_limit_reached", "limit": MAX_HIVE_MEMBERS}
	var blocked_until_unix: int = _rejoin_block_until(target_player_id, hive_id)
	if blocked_until_unix > now_unix:
		return {"ok": false, "reason": "rejoin_cooldown_active", "blocked_until_unix": blocked_until_unix}
	var members: Dictionary = hive.get("members", {}) as Dictionary
	members[target_player_id] = _new_member(
		target_player_id,
		str(application.get("player_display_name", _display_name_for_player(target_player_id))),
		ROLE_MEMBER,
		now_unix
	)
	hive["members"] = members
	_apply_auto_soldier_assignment(hive, target_player_id)
	_recompute_hive_metrics(hive)
	_hives_by_id[hive_id] = hive
	application["status"] = APPLICATION_STATUS_ACCEPTED
	application["responded_at_unix"] = now_unix
	application["reviewed_by_player_id"] = actor_id
	_applications_by_id[application_id] = application
	_close_open_membership_requests_for_player(target_player_id, hive_id)
	_reindex_memberships()
	_save_state()
	_emit_event({
		"type": "hive_application_accepted",
		"hive_id": hive_id,
		"application_id": application_id,
		"player_id": target_player_id,
		"reviewed_by_player_id": actor_id
	})
	return {"ok": true, "hive": _build_hive_snapshot(hive), "membership": get_player_membership(target_player_id)}

func intent_accept_invite(invite_id: String, player_id: String = "", display_name: String = "") -> Dictionary:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	if resolved_player_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	if _player_has_hive(resolved_player_id):
		return {"ok": false, "reason": "player_already_in_hive", "membership": get_player_membership(resolved_player_id)}
	var invite: Dictionary = _invites_by_id.get(invite_id, {}) as Dictionary
	if invite.is_empty():
		return {"ok": false, "reason": "invite_not_found"}
	if str(invite.get("status", "")) != INVITE_STATUS_PENDING:
		return {"ok": false, "reason": "invite_not_pending"}
	if str(invite.get("target_player_id", "")) != resolved_player_id:
		return {"ok": false, "reason": "invite_target_mismatch"}
	var hive_id: String = str(invite.get("hive_id", ""))
	var rejoin_block_until: int = _rejoin_block_until(resolved_player_id, hive_id)
	if rejoin_block_until > _now_unix():
		return {"ok": false, "reason": "rejoin_cooldown_active", "blocked_until_unix": rejoin_block_until}
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found", "hive_id": hive_id}
	if _current_hive_member_count(hive) >= MAX_HIVE_MEMBERS:
		return {"ok": false, "reason": "hive_member_limit_reached", "limit": MAX_HIVE_MEMBERS}
	var now_unix: int = _now_unix()
	hive["members"][resolved_player_id] = _new_member(
		resolved_player_id,
		_display_name_for_player(resolved_player_id, display_name),
		_sanitize_role(str(invite.get("role", ROLE_MEMBER))),
		now_unix
	)
	_apply_auto_soldier_assignment(hive, resolved_player_id)
	_recompute_hive_metrics(hive)
	_hives_by_id[hive_id] = hive
	invite["status"] = INVITE_STATUS_ACCEPTED
	invite["responded_at_unix"] = now_unix
	_invites_by_id[invite_id] = invite
	_close_open_membership_requests_for_player(resolved_player_id, hive_id)
	_reindex_memberships()
	_save_state()
	var event: Dictionary = {
		"type": "hive_invite_accepted",
		"hive_id": hive_id,
		"invite_id": invite_id,
		"player_id": resolved_player_id
	}
	_emit_event(event)
	return {"ok": true, "hive": _build_hive_snapshot(hive), "membership": get_player_membership(resolved_player_id)}

func intent_decline_invite(invite_id: String, player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	if resolved_player_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var invite: Dictionary = _invites_by_id.get(invite_id, {}) as Dictionary
	if invite.is_empty():
		return {"ok": false, "reason": "invite_not_found"}
	if str(invite.get("status", "")) != INVITE_STATUS_PENDING:
		return {"ok": false, "reason": "invite_not_pending"}
	if str(invite.get("target_player_id", "")) != resolved_player_id:
		return {"ok": false, "reason": "invite_target_mismatch"}
	invite["status"] = INVITE_STATUS_DECLINED
	invite["responded_at_unix"] = _now_unix()
	_invites_by_id[invite_id] = invite
	_save_state()
	_emit_event({
		"type": "hive_invite_declined",
		"invite_id": invite_id,
		"player_id": resolved_player_id,
		"hive_id": str(invite.get("hive_id", ""))
	})
	return {"ok": true}

func intent_set_soldier(hive_id: String, target_player_id: String, enabled: bool, actor_player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var actor_id: String = _resolve_player_id(actor_player_id)
	var target_id: String = _sanitize_player_id(target_player_id)
	if actor_id.is_empty() or target_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	if _role_for_player(hive, actor_id) != ROLE_QUEEN:
		return {"ok": false, "reason": "forbidden"}
	var members: Dictionary = hive.get("members", {}) as Dictionary
	var member: Dictionary = members.get(target_id, {}) as Dictionary
	if member.is_empty():
		return {"ok": false, "reason": "member_not_found"}
	if target_id == actor_id:
		return {"ok": false, "reason": "queen_cannot_change_self"}
	if enabled:
		var soldier_count: int = _count_role(hive, ROLE_SOLDIER)
		if str(member.get("role", ROLE_MEMBER)) != ROLE_SOLDIER and soldier_count >= MAX_SOLDIERS:
			return {"ok": false, "reason": "soldier_limit_reached", "limit": MAX_SOLDIERS}
		member["role"] = ROLE_SOLDIER
	else:
		return {"ok": false, "reason": "use_demotion_vote"}
	members[target_id] = member
	hive["members"] = members
	_clear_governance_state_for_player(hive, target_id)
	_recompute_hive_metrics(hive)
	_hives_by_id[hive_id] = hive
	_save_state()
	_emit_event({
		"type": "hive_role_changed",
		"hive_id": hive_id,
		"target_player_id": target_id,
		"role": str(member.get("role", ROLE_MEMBER)),
		"changed_by_player_id": actor_id
	})
	return {"ok": true, "hive": _build_hive_snapshot(hive)}

func intent_vote_demote_soldier(hive_id: String, target_player_id: String, actor_player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var actor_id: String = _resolve_player_id(actor_player_id)
	var target_id: String = _sanitize_player_id(target_player_id)
	if actor_id.is_empty() or target_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	var actor_role: String = _role_for_player(hive, actor_id)
	if actor_role != ROLE_QUEEN and actor_role != ROLE_SOLDIER:
		return {"ok": false, "reason": "forbidden"}
	if actor_id == target_id:
		return {"ok": false, "reason": "cannot_target_self"}
	var members: Dictionary = hive.get("members", {}) as Dictionary
	var target_member: Dictionary = members.get(target_id, {}) as Dictionary
	if target_member.is_empty():
		return {"ok": false, "reason": "member_not_found"}
	if str(target_member.get("role", ROLE_MEMBER)) != ROLE_SOLDIER:
		return {"ok": false, "reason": "target_not_soldier"}
	var vote_key: String = target_id
	var demotion_votes: Dictionary = hive.get("soldier_demotion_votes", {}) as Dictionary
	var vote_record: Dictionary = demotion_votes.get(vote_key, {}) as Dictionary
	if vote_record.is_empty():
		vote_record = {
			"target_player_id": target_id,
			"created_at_unix": _now_unix(),
			"votes_by_player_id": {}
		}
	var votes_by_player_id: Dictionary = vote_record.get("votes_by_player_id", {}) as Dictionary
	votes_by_player_id[actor_id] = true
	vote_record["votes_by_player_id"] = votes_by_player_id
	demotion_votes[vote_key] = vote_record
	hive["soldier_demotion_votes"] = demotion_votes
	if _has_queen_and_supporting_soldier_vote(hive, vote_record, target_id):
		target_member["role"] = ROLE_MEMBER
		members[target_id] = target_member
		hive["members"] = members
		_clear_governance_state_for_player(hive, target_id)
		_recompute_hive_metrics(hive)
		_hives_by_id[hive_id] = hive
		_save_state()
		_emit_event({
			"type": "hive_soldier_demoted",
			"hive_id": hive_id,
			"target_player_id": target_id,
			"changed_by_player_id": actor_id
		})
		return {"ok": true, "hive": _build_hive_snapshot(hive), "demoted": true}
	_hives_by_id[hive_id] = hive
	_save_state()
	_emit_event({
		"type": "hive_soldier_demotion_vote_cast",
		"hive_id": hive_id,
		"target_player_id": target_id,
		"actor_player_id": actor_id
	})
	return {
		"ok": true,
		"hive": _build_hive_snapshot(hive),
		"demoted": false,
		"vote": _build_soldier_demotion_vote_snapshot(hive, target_id)
	}

func intent_vote_remove_queen(hive_id: String, actor_player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var actor_id: String = _resolve_player_id(actor_player_id)
	if actor_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	if _role_for_player(hive, actor_id) != ROLE_SOLDIER:
		return {"ok": false, "reason": "forbidden"}
	var queen_id: String = _first_role_player_id(hive, ROLE_QUEEN)
	if queen_id.is_empty():
		return {"ok": false, "reason": "queen_not_found"}
	var votes_by_player_id: Dictionary = hive.get("queen_removal_vote", {}) as Dictionary
	if votes_by_player_id.is_empty():
		hive["queen_removal_vote_started_at_unix"] = _now_unix()
	votes_by_player_id[actor_id] = true
	hive["queen_removal_vote"] = votes_by_player_id
	if _count_valid_queen_removal_votes(hive) >= MAX_SOLDIERS:
		var members: Dictionary = hive.get("members", {}) as Dictionary
		var queen_member: Dictionary = members.get(queen_id, {}) as Dictionary
		if queen_member.is_empty():
			return {"ok": false, "reason": "queen_not_found"}
		queen_member["role"] = ROLE_MEMBER
		members[queen_id] = queen_member
		var new_queen_id: String = _senior_soldier_player_id(hive)
		if new_queen_id.is_empty():
			new_queen_id = actor_id
		var new_queen_member: Dictionary = members.get(new_queen_id, {}) as Dictionary
		if new_queen_member.is_empty():
			return {"ok": false, "reason": "new_queen_not_found"}
		new_queen_member["role"] = ROLE_QUEEN
		members[new_queen_id] = new_queen_member
		hive["members"] = members
		hive["queen_removal_vote"] = {}
		hive["queen_removal_vote_started_at_unix"] = 0
		hive["soldier_demotion_votes"] = {}
		_recompute_hive_metrics(hive)
		_hives_by_id[hive_id] = hive
		_save_state()
		_emit_event({
			"type": "hive_queen_removed",
			"hive_id": hive_id,
			"removed_player_id": queen_id,
			"new_queen_player_id": new_queen_id
		})
		return {"ok": true, "hive": _build_hive_snapshot(hive), "queen_removed": true}
	_hives_by_id[hive_id] = hive
	_save_state()
	_emit_event({
		"type": "hive_queen_removal_vote_cast",
		"hive_id": hive_id,
		"actor_player_id": actor_id,
		"queen_player_id": queen_id
	})
	return {
		"ok": true,
		"hive": _build_hive_snapshot(hive),
		"queen_removed": false,
		"vote": _build_queen_removal_vote_snapshot(hive)
	}

func intent_claim_inactive_queen_succession(hive_id: String, actor_player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var actor_id: String = _resolve_player_id(actor_player_id)
	if actor_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	var members: Dictionary = hive.get("members", {}) as Dictionary
	if not members.has(actor_id):
		return {"ok": false, "reason": "forbidden"}
	if not _is_player_active_voter(hive, actor_id):
		return {"ok": false, "reason": "actor_inactive"}
	var queen_id: String = _first_role_player_id(hive, ROLE_QUEEN)
	if queen_id.is_empty():
		return {"ok": false, "reason": "queen_not_found"}
	if actor_id == queen_id:
		return {"ok": false, "reason": "queen_cannot_claim_own_succession"}
	var queen_last_seen_at: int = _member_last_seen_at_unix(hive, queen_id)
	var now_unix: int = _now_unix()
	var eligible_at_unix: int = queen_last_seen_at + INACTIVE_QUEEN_SUCCESSION_SEC if queen_last_seen_at > 0 else 0
	if queen_last_seen_at <= 0 or eligible_at_unix > now_unix:
		return {
			"ok": false,
			"reason": "queen_still_active",
			"queen_player_id": queen_id,
			"queen_last_seen_at_unix": queen_last_seen_at,
			"eligible_at_unix": eligible_at_unix
		}
	var new_queen_id: String = _select_inactive_queen_successor_id(hive, queen_id)
	if new_queen_id.is_empty():
		return {"ok": false, "reason": "no_active_successor"}
	var old_queen_member: Dictionary = members.get(queen_id, {}) as Dictionary
	var new_queen_member: Dictionary = members.get(new_queen_id, {}) as Dictionary
	if old_queen_member.is_empty() or new_queen_member.is_empty():
		return {"ok": false, "reason": "successor_not_found"}
	old_queen_member["role"] = ROLE_MEMBER
	new_queen_member["role"] = ROLE_QUEEN
	members[queen_id] = old_queen_member
	members[new_queen_id] = new_queen_member
	hive["members"] = members
	hive["queen_removal_vote"] = {}
	hive["queen_removal_vote_started_at_unix"] = 0
	_clear_governance_state_for_player(hive, queen_id)
	_clear_governance_state_for_player(hive, new_queen_id)
	_recompute_hive_metrics(hive)
	_hives_by_id[hive_id] = hive
	_save_state()
	_emit_event({
		"type": "hive_inactive_queen_succession_claimed",
		"hive_id": hive_id,
		"actor_player_id": actor_id,
		"old_queen_player_id": queen_id,
		"new_queen_player_id": new_queen_id,
		"queen_last_seen_at_unix": queen_last_seen_at,
		"inactive_window_sec": INACTIVE_QUEEN_SUCCESSION_SEC
	})
	return {
		"ok": true,
		"hive": _build_hive_snapshot(hive),
		"old_queen_player_id": queen_id,
		"new_queen_player_id": new_queen_id,
		"queen_last_seen_at_unix": queen_last_seen_at,
		"inactive_window_sec": INACTIVE_QUEEN_SUCCESSION_SEC
	}

func intent_vote_promote_soldier(hive_id: String, target_player_id: String, actor_player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var actor_id: String = _resolve_player_id(actor_player_id)
	var target_id: String = _sanitize_player_id(target_player_id)
	if actor_id.is_empty() or target_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	var members: Dictionary = hive.get("members", {}) as Dictionary
	if not members.has(actor_id):
		return {"ok": false, "reason": "forbidden"}
	var target_member: Dictionary = members.get(target_id, {}) as Dictionary
	if target_member.is_empty():
		return {"ok": false, "reason": "member_not_found"}
	if target_id == actor_id:
		return {"ok": false, "reason": "cannot_target_self"}
	if str(target_member.get("role", ROLE_MEMBER)) != ROLE_MEMBER:
		return {"ok": false, "reason": "target_already_leadership"}
	if _count_role(hive, ROLE_SOLDIER) >= MAX_SOLDIERS:
		return {"ok": false, "reason": "soldier_limit_reached", "limit": MAX_SOLDIERS}
	var promotion_votes: Dictionary = hive.get("soldier_promotion_votes", {}) as Dictionary
	var vote_record: Dictionary = promotion_votes.get(target_id, {}) as Dictionary
	if vote_record.is_empty():
		vote_record = {
			"target_player_id": target_id,
			"created_at_unix": _now_unix(),
			"votes_by_player_id": {}
		}
	var votes_by_player_id: Dictionary = vote_record.get("votes_by_player_id", {}) as Dictionary
	votes_by_player_id[actor_id] = true
	vote_record["votes_by_player_id"] = votes_by_player_id
	promotion_votes[target_id] = vote_record
	hive["soldier_promotion_votes"] = promotion_votes
	if _has_majority_promotion_vote(hive, vote_record, target_id):
		target_member["role"] = ROLE_SOLDIER
		members[target_id] = target_member
		hive["members"] = members
		_clear_governance_state_for_player(hive, target_id)
		_recompute_hive_metrics(hive)
		_hives_by_id[hive_id] = hive
		_save_state()
		_emit_event({
			"type": "hive_soldier_promoted",
			"hive_id": hive_id,
			"target_player_id": target_id,
			"changed_by_player_id": actor_id,
			"mode": "vote"
		})
		return {"ok": true, "hive": _build_hive_snapshot(hive), "promoted": true}
	_hives_by_id[hive_id] = hive
	_save_state()
	_emit_event({
		"type": "hive_soldier_promotion_vote_cast",
		"hive_id": hive_id,
		"target_player_id": target_id,
		"actor_player_id": actor_id
	})
	return {
		"ok": true,
		"hive": _build_hive_snapshot(hive),
		"promoted": false,
		"vote": _build_soldier_promotion_vote_snapshot(hive, target_id)
	}

func intent_apply_for_soldier(hive_id: String, player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var actor_id: String = _resolve_player_id(player_id)
	if actor_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	var members: Dictionary = hive.get("members", {}) as Dictionary
	var member: Dictionary = members.get(actor_id, {}) as Dictionary
	if member.is_empty():
		return {"ok": false, "reason": "forbidden"}
	if str(member.get("role", ROLE_MEMBER)) != ROLE_MEMBER:
		return {"ok": false, "reason": "already_leadership"}
	if _count_role(hive, ROLE_SOLDIER) >= MAX_SOLDIERS:
		return {"ok": false, "reason": "soldier_limit_reached", "limit": MAX_SOLDIERS}
	var promotion_votes: Dictionary = hive.get("soldier_promotion_votes", {}) as Dictionary
	var vote_record: Dictionary = promotion_votes.get(actor_id, {}) as Dictionary
	if vote_record.is_empty():
		vote_record = {
			"target_player_id": actor_id,
			"created_at_unix": _now_unix(),
			"votes_by_player_id": {},
			"applied_by_player_id": actor_id
		}
	else:
		vote_record["applied_by_player_id"] = actor_id
	promotion_votes[actor_id] = vote_record
	hive["soldier_promotion_votes"] = promotion_votes
	_hives_by_id[hive_id] = hive
	_save_state()
	_emit_event({
		"type": "hive_soldier_application_created",
		"hive_id": hive_id,
		"target_player_id": actor_id
	})
	return {
		"ok": true,
		"hive": _build_hive_snapshot(hive),
		"vote": _build_soldier_promotion_vote_snapshot(hive, actor_id)
	}

func intent_vote_remove_leadership(hive_id: String, target_player_id: String, actor_player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var actor_id: String = _resolve_player_id(actor_player_id)
	var target_id: String = _sanitize_player_id(target_player_id)
	if actor_id.is_empty() or target_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	var members: Dictionary = hive.get("members", {}) as Dictionary
	if not members.has(actor_id):
		return {"ok": false, "reason": "forbidden"}
	var target_member: Dictionary = members.get(target_id, {}) as Dictionary
	if target_member.is_empty():
		return {"ok": false, "reason": "member_not_found"}
	var target_role: String = str(target_member.get("role", ROLE_MEMBER))
	if target_role != ROLE_QUEEN and target_role != ROLE_SOLDIER:
		return {"ok": false, "reason": "target_not_leadership"}
	if actor_id == target_id:
		return {"ok": false, "reason": "cannot_target_self"}
	var eligible_voters: Array[String] = _eligible_leadership_removal_voters(hive, target_id)
	if eligible_voters.size() < MIN_LEADERSHIP_REMOVAL_VOTES:
		return {"ok": false, "reason": "not_enough_members_for_leadership_vote", "required_votes": MIN_LEADERSHIP_REMOVAL_VOTES}
	var removal_votes: Dictionary = hive.get("leadership_removal_votes", {}) as Dictionary
	var vote_record: Dictionary = removal_votes.get(target_id, {}) as Dictionary
	if vote_record.is_empty():
		vote_record = {
			"target_player_id": target_id,
			"target_role": target_role,
			"created_at_unix": _now_unix(),
			"votes_by_player_id": {}
		}
	var votes_by_player_id: Dictionary = vote_record.get("votes_by_player_id", {}) as Dictionary
	votes_by_player_id[actor_id] = true
	vote_record["votes_by_player_id"] = votes_by_player_id
	removal_votes[target_id] = vote_record
	hive["leadership_removal_votes"] = removal_votes
	if _has_unanimous_leadership_removal_vote(hive, vote_record, target_id):
		target_member["role"] = ROLE_MEMBER
		members[target_id] = target_member
		hive["members"] = members
		_clear_governance_state_for_player(hive, target_id)
		if target_role == ROLE_QUEEN:
			_ensure_hive_leadership(hive)
		_recompute_hive_metrics(hive)
		_hives_by_id[hive_id] = hive
		_save_state()
		_emit_event({
			"type": "hive_leadership_removed_by_hive_vote",
			"hive_id": hive_id,
			"target_player_id": target_id,
			"target_role": target_role
		})
		return {"ok": true, "hive": _build_hive_snapshot(hive), "removed": true}
	_hives_by_id[hive_id] = hive
	_save_state()
	_emit_event({
		"type": "hive_leadership_removal_vote_cast",
		"hive_id": hive_id,
		"target_player_id": target_id,
		"actor_player_id": actor_id
	})
	return {
		"ok": true,
		"hive": _build_hive_snapshot(hive),
		"removed": false,
		"vote": _build_leadership_removal_vote_snapshot(hive, target_id)
	}

func intent_record_hive_honey(hive_id: String, player_id: String, honey_amount: int, reason: String = "", metadata: Dictionary = {}) -> Dictionary:
	_refresh_runtime_state()
	var resolved_player_id: String = _sanitize_player_id(player_id)
	if resolved_player_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var safe_amount: int = maxi(0, honey_amount)
	if safe_amount <= 0:
		return {"ok": false, "reason": "invalid_honey_amount"}
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	var members: Dictionary = hive.get("members", {}) as Dictionary
	var member: Dictionary = members.get(resolved_player_id, {}) as Dictionary
	if member.is_empty():
		return {"ok": false, "reason": "member_not_found"}
	member["honey_contributed"] = int(member.get("honey_contributed", 0)) + safe_amount
	member["honey_balance_snapshot"] = maxi(0, int(member.get("honey_balance_snapshot", 0)) + safe_amount)
	member["last_honey_reason"] = reason.strip_edges()
	member["last_honey_at_unix"] = _now_unix()
	members[resolved_player_id] = member
	hive["members"] = members
	_recompute_hive_metrics(hive)
	_hives_by_id[hive_id] = hive
	_save_state()
	_emit_event({
		"type": "hive_honey_recorded",
		"hive_id": hive_id,
		"player_id": resolved_player_id,
		"honey_amount": safe_amount,
		"reason": reason.strip_edges(),
		"metadata": metadata.duplicate(true)
	})
	return {"ok": true, "membership": get_player_membership(resolved_player_id), "hive": _build_hive_snapshot(hive)}

func intent_sync_member_honey_balance(player_id: String, honey_balance: int, reason: String = "") -> Dictionary:
	_refresh_runtime_state()
	var resolved_player_id: String = _sanitize_player_id(player_id)
	if resolved_player_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var hive_id: String = str(_player_to_hive_id.get(resolved_player_id, "")).strip_edges()
	if hive_id.is_empty():
		return {"ok": true, "synced": false, "reason": "player_not_in_hive"}
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	var members: Dictionary = hive.get("members", {}) as Dictionary
	var member: Dictionary = members.get(resolved_player_id, {}) as Dictionary
	if member.is_empty():
		return {"ok": false, "reason": "member_not_found"}
	member["honey_balance_snapshot"] = maxi(0, honey_balance)
	member["last_honey_reason"] = reason.strip_edges()
	member["last_honey_at_unix"] = _now_unix()
	members[resolved_player_id] = member
	hive["members"] = members
	_recompute_hive_metrics(hive)
	_hives_by_id[hive_id] = hive
	_save_state()
	_emit_changed()
	return {"ok": true, "synced": true, "hive": _build_hive_snapshot(hive), "membership": get_player_membership(resolved_player_id)}

func preview_hive_honey_purchase(hive_id: String, honey_cost: int, balances_by_player: Dictionary = {}) -> Dictionary:
	_refresh_runtime_state()
	var clean_hive_id: String = str(hive_id).strip_edges()
	var cost: int = maxi(0, honey_cost)
	if cost <= 0:
		return {"ok": false, "reason": "invalid_honey_cost"}
	var hive: Dictionary = _hives_by_id.get(clean_hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	var members: Dictionary = hive.get("members", {}) as Dictionary
	var balances: Dictionary = _hive_member_honey_balances(hive, balances_by_player)
	var total_balance: int = 0
	for balance_any in balances.values():
		total_balance += maxi(0, int(balance_any))
	if total_balance < cost:
		return {
			"ok": false,
			"reason": "insufficient_hive_honey",
			"available_hive_honey": total_balance,
			"required_hive_honey": cost
		}
	var remaining: int = cost
	var deductions: Array[Dictionary] = []
	var member_ids: Array[String] = []
	for player_id_any in members.keys():
		var player_id: String = _sanitize_player_id(str(player_id_any))
		if player_id.is_empty():
			continue
		if maxi(0, int(balances.get(player_id, 0))) <= 0:
			continue
		member_ids.append(player_id)
	member_ids.sort()
	for i in range(member_ids.size()):
		var player_id: String = member_ids[i]
		var balance: int = maxi(0, int(balances.get(player_id, 0)))
		var deduction: int = 0
		if i == member_ids.size() - 1:
			deduction = remaining
		else:
			deduction = int(floor(float(cost) * float(balance) / float(maxi(1, total_balance))))
			deduction = mini(balance, deduction)
			remaining -= deduction
		if deduction <= 0 and balance <= 0:
			continue
		deductions.append({
			"player_id": player_id,
			"balance_before": balance,
			"deduction": deduction,
			"balance_after": maxi(0, balance - deduction),
			"share_bps": int(round(10000.0 * float(balance) / float(maxi(1, total_balance))))
		})
	return {
		"ok": true,
		"hive_id": clean_hive_id,
		"honey_cost": cost,
		"available_hive_honey": total_balance,
		"deductions": deductions,
		"deduction_model": "member_owned_proportional"
	}

func intent_debit_hive_honey_proportional(hive_id: String, honey_cost: int, reason: String = "", balances_by_player: Dictionary = {}, actor_player_id: String = "") -> Dictionary:
	var preview: Dictionary = preview_hive_honey_purchase(hive_id, honey_cost, balances_by_player)
	if not bool(preview.get("ok", false)):
		return preview
	var clean_hive_id: String = str(hive_id).strip_edges()
	var hive: Dictionary = _hives_by_id.get(clean_hive_id, {}) as Dictionary
	var members: Dictionary = hive.get("members", {}) as Dictionary
	var deductions: Array = preview.get("deductions", []) as Array
	for deduction_any in deductions:
		if typeof(deduction_any) != TYPE_DICTIONARY:
			continue
		var deduction: Dictionary = deduction_any as Dictionary
		var player_id: String = _sanitize_player_id(str(deduction.get("player_id", "")))
		var member: Dictionary = members.get(player_id, {}) as Dictionary
		if member.is_empty():
			continue
		member["honey_balance_snapshot"] = maxi(0, int(deduction.get("balance_after", 0)))
		member["honey_spent"] = maxi(0, int(member.get("honey_spent", 0))) + maxi(0, int(deduction.get("deduction", 0)))
		member["last_honey_reason"] = reason.strip_edges()
		member["last_honey_at_unix"] = _now_unix()
		members[player_id] = member
	hive["members"] = members
	hive["total_honey_spent"] = maxi(0, int(hive.get("total_honey_spent", 0))) + maxi(0, honey_cost)
	_recompute_hive_metrics(hive)
	_hives_by_id[clean_hive_id] = hive
	_save_state()
	_emit_event({
		"type": "hive_honey_debited",
		"hive_id": clean_hive_id,
		"player_id": _resolve_player_id(actor_player_id),
		"honey_cost": maxi(0, honey_cost),
		"reason": reason.strip_edges(),
		"deductions": deductions.duplicate(true),
		"deduction_model": "member_owned_proportional"
	})
	return {
		"ok": true,
		"hive": _build_hive_snapshot(hive),
		"honey_cost": maxi(0, honey_cost),
		"deductions": deductions.duplicate(true),
		"deduction_model": "member_owned_proportional"
	}

func intent_request_leave_hive(player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	if resolved_player_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var membership: Dictionary = get_player_membership(resolved_player_id)
	if membership.is_empty():
		return {"ok": false, "reason": "player_not_in_hive"}
	if _pending_leave_by_player_id.has(resolved_player_id):
		return {"ok": false, "reason": "leave_already_pending", "leave_request": _build_leave_request_snapshot(resolved_player_id)}
	var now_unix: int = _now_unix()
	var request: Dictionary = {
		"player_id": resolved_player_id,
		"hive_id": str(membership.get("hive_id", "")),
		"requested_at_unix": now_unix,
		"effective_at_unix": now_unix + LEAVE_DELAY_SEC
	}
	_pending_leave_by_player_id[resolved_player_id] = request
	_save_state()
	_emit_event({
		"type": "hive_leave_requested",
		"player_id": resolved_player_id,
		"hive_id": str(request.get("hive_id", "")),
		"effective_at_unix": int(request.get("effective_at_unix", 0))
	})
	return {"ok": true, "leave_request": request.duplicate(true)}

func intent_remove_member(hive_id: String, target_player_id: String, actor_player_id: String = "") -> Dictionary:
	_refresh_runtime_state()
	var actor_id: String = _resolve_player_id(actor_player_id)
	var target_id: String = _sanitize_player_id(target_player_id)
	if actor_id.is_empty() or target_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {"ok": false, "reason": "hive_not_found"}
	if _role_for_player(hive, actor_id) != ROLE_QUEEN:
		return {"ok": false, "reason": "forbidden"}
	if actor_id == target_id:
		return {"ok": false, "reason": "cannot_target_self"}
	var members: Dictionary = hive.get("members", {}) as Dictionary
	var target_member: Dictionary = members.get(target_id, {}) as Dictionary
	if target_member.is_empty():
		return {"ok": false, "reason": "member_not_found"}
	if str(target_member.get("role", ROLE_MEMBER)) != ROLE_MEMBER:
		return {"ok": false, "reason": "target_not_removable_member"}
	members.erase(target_id)
	hive["members"] = members
	_clear_governance_state_for_player(hive, target_id)
	if _pending_leave_by_player_id.has(target_id):
		_pending_leave_by_player_id.erase(target_id)
	var player_cooldowns: Dictionary = _rejoin_cooldowns_by_player_id.get(target_id, {}) as Dictionary
	player_cooldowns[hive_id] = _now_unix() + REJOIN_SAME_HIVE_COOLDOWN_SEC
	_rejoin_cooldowns_by_player_id[target_id] = player_cooldowns
	if members.is_empty():
		_retire_hive(hive_id)
	else:
		_recompute_hive_metrics(hive)
		_hives_by_id[hive_id] = hive
	_reindex_memberships()
	_save_state()
	_emit_event({
		"type": "hive_member_removed",
		"hive_id": hive_id,
		"target_player_id": target_id,
		"removed_by_player_id": actor_id,
		"rejoin_blocked_until_unix": _now_unix() + REJOIN_SAME_HIVE_COOLDOWN_SEC
	})
	return {"ok": true, "hive": _build_hive_snapshot(_hives_by_id.get(hive_id, {}) as Dictionary) if _hives_by_id.has(hive_id) else {}}

func intent_cancel_leave_hive(player_id: String = "") -> Dictionary:
	var resolved_player_id: String = _resolve_player_id(player_id)
	if resolved_player_id.is_empty():
		return {"ok": false, "reason": "missing_player_id"}
	if not _pending_leave_by_player_id.has(resolved_player_id):
		return {"ok": false, "reason": "leave_not_pending"}
	var request: Dictionary = _pending_leave_by_player_id.get(resolved_player_id, {}) as Dictionary
	_pending_leave_by_player_id.erase(resolved_player_id)
	_save_state()
	_emit_event({
		"type": "hive_leave_cancelled",
		"player_id": resolved_player_id,
		"hive_id": str(request.get("hive_id", ""))
	})
	return {"ok": true}

func can_spend_hive_honey(hive_id: String, player_id: String = "") -> bool:
	_refresh_runtime_state()
	var resolved_player_id: String = _resolve_player_id(player_id)
	if resolved_player_id.is_empty():
		return false
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return false
	var role: String = _role_for_player(hive, resolved_player_id)
	return role == ROLE_QUEEN or role == ROLE_SOLDIER

func debug_reset_state() -> void:
	_hives_by_id.clear()
	_invites_by_id.clear()
	_applications_by_id.clear()
	_player_to_hive_id.clear()
	_pending_leave_by_player_id.clear()
	_rejoin_cooldowns_by_player_id.clear()
	_hive_creation_history_by_player_id.clear()
	_hive_tournament_queue_by_tournament_id.clear()
	_hive_tournament_brackets_by_id.clear()
	_hive_tournament_rounds_by_id.clear()
	_save_state()
	_emit_changed()

func _emit_changed() -> void:
	hive_clan_state_changed.emit(get_snapshot())

func _emit_event(event: Dictionary) -> void:
	_record_hive_feed_event(event)
	hive_clan_event.emit(event)
	SFLog.info("HIVE_CLAN_EVENT", event)
	_emit_changed()

func _load_state() -> void:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed_any: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed_any) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = parsed_any as Dictionary
	_save_schema_version = int(payload.get("schema_version", SAVE_SCHEMA_VERSION))
	_hives_by_id = _sanitize_hives(payload.get("hives_by_id", {}))
	_invites_by_id = _sanitize_invites(payload.get("invites_by_id", {}))
	_applications_by_id = _sanitize_applications(payload.get("applications_by_id", {}))
	_pending_leave_by_player_id = _sanitize_leave_requests(payload.get("pending_leave_by_player_id", {}))
	_rejoin_cooldowns_by_player_id = _sanitize_rejoin_cooldowns(payload.get("rejoin_cooldowns_by_player_id", {}))
	_hive_creation_history_by_player_id = _sanitize_creation_history(payload.get("hive_creation_history_by_player_id", {}))
	_hive_tournament_queue_by_tournament_id = _sanitize_hive_tournament_queues(payload.get("hive_tournament_queue_by_tournament_id", {}))
	_hive_tournament_brackets_by_id = _sanitize_hive_tournament_brackets(payload.get("hive_tournament_brackets_by_id", {}))
	_hive_tournament_rounds_by_id = _sanitize_hive_tournament_rounds(payload.get("hive_tournament_rounds_by_id", {}))
	_company_trophy_case = _sanitize_hive_award_records(payload.get("company_trophy_case", []))
	_reindex_memberships()

func _save_state() -> void:
	var payload: Dictionary = {
		"schema_version": SAVE_SCHEMA_VERSION,
		"hives_by_id": _hives_by_id,
		"invites_by_id": _invites_by_id,
		"applications_by_id": _applications_by_id,
		"pending_leave_by_player_id": _pending_leave_by_player_id,
		"rejoin_cooldowns_by_player_id": _rejoin_cooldowns_by_player_id,
		"hive_creation_history_by_player_id": _hive_creation_history_by_player_id,
		"hive_tournament_queue_by_tournament_id": _hive_tournament_queue_by_tournament_id,
		"hive_tournament_brackets_by_id": _hive_tournament_brackets_by_id,
		"hive_tournament_rounds_by_id": _hive_tournament_rounds_by_id,
		"company_trophy_case": _company_trophy_case
	}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _bootstrap_local_profile() -> void:
	var local_player_id: String = _local_player_id()
	if local_player_id.is_empty():
		return
	var hive_id: String = str(_player_to_hive_id.get(local_player_id, ""))
	if hive_id.is_empty():
		return
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return
	var members: Dictionary = hive.get("members", {}) as Dictionary
	var member: Dictionary = members.get(local_player_id, {}) as Dictionary
	if member.is_empty():
		return
	var display_name: String = _display_name_for_player(local_player_id)
	if display_name == str(member.get("display_name", "")):
		return
	member["display_name"] = display_name
	member["last_seen_at_unix"] = _now_unix()
	members[local_player_id] = member
	hive["members"] = members
	_hives_by_id[hive_id] = hive
	_save_state()

func _sorted_hive_snapshots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for hive_any in _hives_by_id.values():
		out.append(_build_hive_snapshot(hive_any as Dictionary))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rank_a: int = int(a.get("rank_points", 0))
		var rank_b: int = int(b.get("rank_points", 0))
		if rank_a != rank_b:
			return rank_a > rank_b
		return int(a.get("total_honey_contributed", 0)) > int(b.get("total_honey_contributed", 0))
	)
	return out

func _build_hive_snapshot(hive: Dictionary) -> Dictionary:
	var members_out: Array[Dictionary] = []
	var members: Dictionary = hive.get("members", {}) as Dictionary
	for member_any in members.values():
		var member: Dictionary = member_any as Dictionary
		var player_id: String = str(member.get("player_id", ""))
		var rank_state: Node = _rank_state()
		var player_snapshot: Dictionary = rank_state.call("get_player_snapshot", player_id) as Dictionary if rank_state != null and rank_state.has_method("get_player_snapshot") else {}
		members_out.append({
			"player_id": player_id,
			"display_name": str(member.get("display_name", "")),
			"role": str(member.get("role", ROLE_MEMBER)),
			"joined_at_unix": int(member.get("joined_at_unix", 0)),
			"last_seen_at_unix": int(member.get("last_seen_at_unix", int(member.get("joined_at_unix", 0)))),
			"honey_contributed": int(member.get("honey_contributed", 0)),
			"honey_balance_snapshot": _member_honey_balance(member),
			"honey_spent": int(member.get("honey_spent", 0)),
			"rank_position": int(player_snapshot.get("rank_position", 0)),
			"tier_id": str(player_snapshot.get("tier_id", "DRONE")),
			"wax_score": float(player_snapshot.get("wax_score", 0.0))
		})
	members_out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rank_a: int = int(a.get("rank_position", 0))
		var rank_b: int = int(b.get("rank_position", 0))
		if rank_a > 0 and rank_b > 0 and rank_a != rank_b:
			return rank_a < rank_b
		if rank_a > 0 and rank_b <= 0:
			return true
		if rank_b > 0 and rank_a <= 0:
			return false
		var honey_a: int = int(a.get("honey_contributed", 0))
		var honey_b: int = int(b.get("honey_contributed", 0))
		if honey_a != honey_b:
			return honey_a > honey_b
		return str(a.get("display_name", "")) < str(b.get("display_name", ""))
	)
	var trophy_records: Array[Dictionary] = _build_trophy_records(hive)
	var feed_entries: Array[Dictionary] = _build_feed_snapshots(hive)
	var rank_breakdown: Dictionary = _build_hive_rank_breakdown(hive)
	return {
		"hive_id": str(hive.get("hive_id", "")),
		"name": str(hive.get("name", "")),
		"created_at_unix": int(hive.get("created_at_unix", 0)),
		"created_by_player_id": str(hive.get("created_by_player_id", "")),
		"member_count": members_out.size(),
		"member_limit": MAX_HIVE_MEMBERS,
		"members": members_out,
		"queen_player_id": _first_role_player_id(hive, ROLE_QUEEN),
		"soldier_player_ids": _player_ids_for_role(hive, ROLE_SOLDIER),
		"soldier_demotion_votes": _build_all_soldier_demotion_vote_snapshots(hive),
		"queen_removal_vote": _build_queen_removal_vote_snapshot(hive),
		"leadership_removal_votes": _build_all_leadership_removal_vote_snapshots(hive),
		"soldier_promotion_votes": _build_all_soldier_promotion_vote_snapshots(hive),
		"tournament_wins": int(hive.get("tournament_wins", 0)),
		"hive_championships": int(hive.get("hive_championships", 0)),
		"seasonal_best_finish": int(hive.get("seasonal_best_finish", 0)),
		"avg_member_service_days": _compute_avg_member_service_days(hive),
		"award_records": _sanitize_hive_award_records(hive.get("award_records", [])),
		"trophy_records": trophy_records,
		"pinned_notice": _sanitize_pinned_notice(hive.get("pinned_notice", {})),
		"about_profile": _sanitize_hive_about_profile(hive.get("about_profile", {})),
		"tournament_entries": _sanitize_hive_tournament_entries(hive.get("tournament_entries", {})),
		"feed_entries": feed_entries,
		"honey_earned_milestones": _build_honey_earned_milestones(int(hive.get("total_honey_contributed", 0))),
		"honey_spent_milestones": _build_honey_spent_milestones(int(hive.get("total_honey_spent", 0))),
		"total_honey_contributed": int(hive.get("total_honey_contributed", 0)),
		"total_honey_spent": int(hive.get("total_honey_spent", 0)),
		"hive_honey_strength": int(hive.get("hive_honey_strength", 0)),
		"rank_points": int(rank_breakdown.get("total", 0)),
		"rank_breakdown": rank_breakdown
	}

func _record_hive_feed_event(event: Dictionary) -> void:
	var hive_id: String = str(event.get("hive_id", "")).strip_edges()
	if hive_id.is_empty():
		return
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return
	var message: String = _feed_message_for_event(hive, event)
	if message == "":
		return
	var feed_any: Variant = hive.get("feed_entries", [])
	var feed_entries: Array = feed_any.duplicate(true) if typeof(feed_any) == TYPE_ARRAY else []
	feed_entries.append({
		"created_at_unix": _now_unix(),
		"message": message,
		"type": str(event.get("type", "system"))
	})
	while feed_entries.size() > HIVE_FEED_LIMIT:
		feed_entries.remove_at(0)
	hive["feed_entries"] = feed_entries
	_hives_by_id[hive_id] = hive
	_save_state()

func _feed_message_for_event(hive: Dictionary, event: Dictionary) -> String:
	var event_type: String = str(event.get("type", "")).strip_edges().to_lower()
	match event_type:
		"hive_created":
			return "%s founded the hive." % _display_name_from_hive_or_profile(hive, str(event.get("player_id", "")))
		"hive_invite_created":
			return "%s invited %s." % [
				_display_name_from_hive_or_profile(hive, str(event.get("created_by_player_id", ""))),
				_display_name_from_hive_or_profile(hive, str(event.get("target_player_id", "")))
			]
		"hive_invite_accepted":
			return "%s accepted a hive invite." % _display_name_from_hive_or_profile(hive, str(event.get("player_id", "")))
		"hive_invite_declined":
			return "%s declined a hive invite." % _display_name_from_hive_or_profile(hive, str(event.get("player_id", "")))
		"hive_application_created":
			return "%s applied to join the hive." % _display_name_from_hive_or_profile(hive, str(event.get("player_id", "")))
		"hive_application_accepted":
			return "%s was approved to join the hive." % _display_name_from_hive_or_profile(hive, str(event.get("player_id", "")))
		"hive_application_declined":
			return "%s's application was declined." % _display_name_from_hive_or_profile(hive, str(event.get("player_id", "")))
		"hive_role_changed":
			return "%s was promoted to %s." % [
				_display_name_from_hive_or_profile(hive, str(event.get("target_player_id", ""))),
				_role_title(str(event.get("role", ROLE_MEMBER)))
			]
		"hive_soldier_promoted":
			return "%s became a Soldier." % _display_name_from_hive_or_profile(hive, str(event.get("target_player_id", "")))
		"hive_soldier_application_created":
			return "%s applied to become a Soldier." % _display_name_from_hive_or_profile(hive, str(event.get("target_player_id", "")))
		"hive_soldier_demoted":
			return "%s was returned to Member." % _display_name_from_hive_or_profile(hive, str(event.get("target_player_id", "")))
		"hive_queen_removed":
			return "Queen removed. %s now leads the hive." % _display_name_from_hive_or_profile(hive, str(event.get("new_queen_player_id", "")))
		"hive_leadership_removed_by_hive_vote":
			return "%s was removed from leadership by hive vote." % _display_name_from_hive_or_profile(hive, str(event.get("target_player_id", "")))
		"hive_leave_requested":
			return "%s scheduled a hive departure." % _display_name_from_hive_or_profile(hive, str(event.get("player_id", "")))
		"hive_leave_cancelled":
			return "%s cancelled a pending departure." % _display_name_from_hive_or_profile(hive, str(event.get("player_id", "")))
		"hive_leave_finalized":
			return "%s left the hive." % _display_name_from_hive_or_profile(hive, str(event.get("player_id", "")))
		"hive_member_removed":
			return "%s was removed from the hive." % _display_name_from_hive_or_profile(hive, str(event.get("target_player_id", "")))
		"hive_honey_recorded":
			return "%s contributed %s honey." % [
				_display_name_from_hive_or_profile(hive, str(event.get("player_id", ""))),
				_format_honey_threshold(int(event.get("honey_amount", 0)))
			]
		"hive_tournament_entered":
			return "%s entered %s for %s hive honey." % [
				_display_name_from_hive_or_profile(hive, str(event.get("player_id", ""))),
				str(event.get("title", "a hive tournament")).strip_edges(),
				_format_honey_threshold(int(event.get("honey_cost", 0)))
			]
		"hive_tournament_round_started":
			return "%s is live. Opponent: %s. Submit within 5 days." % [
				str(event.get("title", "Hive Tournament")).strip_edges(),
				str(event.get("opponent_hive_name", "Opposing Hive")).strip_edges()
			]
		"hive_tournament_run_submitted":
			return "%s submitted a tournament run in %0.2fs." % [
				_display_name_from_hive_or_profile(hive, str(event.get("player_id", ""))),
				float(int(event.get("total_time_ms", 0))) / 1000.0
			]
		"hive_tournament_round_resolved":
			var winner_hive_id: String = str(event.get("winner_hive_id", "")).strip_edges()
			if winner_hive_id.is_empty():
				return "%s ended in a dead heat." % str(event.get("title", "Hive Tournament")).strip_edges()
			if winner_hive_id == str(event.get("hive_id", "")).strip_edges():
				return "%s won %s." % [str(hive.get("name", "Hive")).strip_edges(), str(event.get("title", "Hive Tournament")).strip_edges()]
			return "%s lost %s." % [str(hive.get("name", "Hive")).strip_edges(), str(event.get("title", "Hive Tournament")).strip_edges()]
		"hive_tournament_bracket_won":
			return "%s won the %s bracket." % [
				str(hive.get("name", "Hive")).strip_edges(),
				str(event.get("title", "Hive Tournament")).strip_edges()
			]
		"hive_pinned_notice_updated":
			if str(event.get("message", "")).strip_edges() == "":
				return "%s cleared the pinned notice." % _display_name_from_hive_or_profile(hive, str(event.get("player_id", "")))
			return "%s updated the pinned notice." % _display_name_from_hive_or_profile(hive, str(event.get("player_id", "")))
		"hive_about_updated":
			if str(event.get("message", "")).strip_edges() == "":
				return "%s cleared the hive profile." % _display_name_from_hive_or_profile(hive, str(event.get("player_id", "")))
			return "%s updated the hive profile." % _display_name_from_hive_or_profile(hive, str(event.get("player_id", "")))
		"hive_message_posted":
			return "%s: %s" % [
				_display_name_from_hive_or_profile(hive, str(event.get("player_id", ""))),
				str(event.get("message", "")).strip_edges()
			]
	return ""

func _sanitize_comms_text(text: String, max_len: int) -> String:
	var compact: String = text.replace("\r", "\n")
	var lines: PackedStringArray = compact.split("\n", false)
	var cleaned_lines: Array[String] = []
	for line in lines:
		var trimmed: String = String(line).strip_edges()
		if trimmed == "":
			continue
		cleaned_lines.append(trimmed)
	var joined: String = "\n".join(cleaned_lines).strip_edges()
	if joined.length() > max_len:
		joined = joined.substr(0, max_len).strip_edges()
	return joined

func _comms_access_for_hive(player_id: String, hive_id: String) -> Dictionary:
	var resolved_player_id: String = _resolve_player_id(player_id)
	var resolved_hive_id: String = str(hive_id).strip_edges()
	if resolved_player_id.is_empty() or resolved_hive_id.is_empty():
		return {}
	var membership: Dictionary = get_player_membership(resolved_player_id)
	if not membership.is_empty() and str(membership.get("hive_id", "")) == resolved_hive_id:
		return {
			"access_type": "member",
			"hive_id": resolved_hive_id,
			"membership": membership
		}
	for invite_any in get_pending_invites_for_player(resolved_player_id):
		if typeof(invite_any) != TYPE_DICTIONARY:
			continue
		var invite: Dictionary = invite_any as Dictionary
		if str(invite.get("hive_id", "")) != resolved_hive_id:
			continue
		return {
			"access_type": "invite",
			"hive_id": resolved_hive_id,
			"invite": invite.duplicate(true)
		}
	return {}

func _display_name_from_hive_or_profile(hive: Dictionary, player_id: String) -> String:
	var clean_player_id: String = _sanitize_player_id(player_id)
	if clean_player_id == "":
		return "Player"
	var member: Dictionary = _member_for_player(hive, clean_player_id)
	if not member.is_empty():
		return str(member.get("display_name", "Player"))
	return _display_name_for_player(clean_player_id)

func _role_title(role: String) -> String:
	match role.strip_edges().to_lower():
		ROLE_QUEEN:
			return "Queen"
		ROLE_SOLDIER:
			return "Soldier"
		_:
			return "Member"

func _build_invite_snapshot(invite: Dictionary, viewer_player_id: String = "") -> Dictionary:
	var hive_id: String = str(invite.get("hive_id", ""))
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	var resolved_viewer_id: String = _resolve_player_id(viewer_player_id)
	var blocked_until_unix: int = _rejoin_block_until(resolved_viewer_id, hive_id)
	var status: String = str(invite.get("status", INVITE_STATUS_PENDING))
	return {
		"invite_id": str(invite.get("invite_id", "")),
		"hive_id": hive_id,
		"hive_name": str(hive.get("name", "")),
		"target_player_id": str(invite.get("target_player_id", "")),
		"target_display_name": str(invite.get("target_display_name", "")),
		"created_by_player_id": str(invite.get("created_by_player_id", "")),
		"created_by_display_name": str(invite.get("created_by_display_name", "")),
		"role": str(invite.get("role", ROLE_MEMBER)),
		"status": status,
		"created_at_unix": int(invite.get("created_at_unix", 0)),
		"expires_at_unix": int(invite.get("expires_at_unix", 0)),
		"expired": status == INVITE_STATUS_EXPIRED,
			"blocked_until_unix": blocked_until_unix,
			"can_apply": status == INVITE_STATUS_EXPIRED and not _player_has_hive(resolved_viewer_id) and blocked_until_unix <= _now_unix(),
			"responded_at_unix": int(invite.get("responded_at_unix", 0)),
			"offer_bundle": (invite.get("offer_bundle", {}) as Dictionary).duplicate(true)
		}

func _build_application_snapshot(application: Dictionary) -> Dictionary:
	var hive_id: String = str(application.get("hive_id", ""))
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	return {
		"application_id": str(application.get("application_id", "")),
		"hive_id": hive_id,
		"hive_name": str(hive.get("name", "")),
		"player_id": str(application.get("player_id", "")),
		"player_display_name": str(application.get("player_display_name", "")),
		"status": str(application.get("status", APPLICATION_STATUS_PENDING)),
		"created_at_unix": int(application.get("created_at_unix", 0)),
		"responded_at_unix": int(application.get("responded_at_unix", 0)),
		"reviewed_by_player_id": str(application.get("reviewed_by_player_id", ""))
	}

func _sanitize_hives(raw_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_any) != TYPE_DICTIONARY:
		return out
	var raw: Dictionary = raw_any as Dictionary
	for hive_id_any in raw.keys():
		var hive: Dictionary = raw.get(hive_id_any, {}) as Dictionary
		var clean_hive: Dictionary = _sanitize_hive(hive)
		var hive_id: String = str(clean_hive.get("hive_id", ""))
		if hive_id.is_empty():
			continue
		out[hive_id] = clean_hive
	return out

func _sanitize_hive(raw: Dictionary) -> Dictionary:
	var hive_id: String = str(raw.get("hive_id", "")).strip_edges()
	var members_out: Dictionary = {}
	var members_raw: Dictionary = raw.get("members", {}) as Dictionary
	for player_id_any in members_raw.keys():
		var member: Dictionary = _sanitize_member(members_raw.get(player_id_any, {}) as Dictionary)
		var player_id: String = str(member.get("player_id", ""))
		if player_id.is_empty():
			continue
		members_out[player_id] = member
	var hive: Dictionary = {
		"hive_id": hive_id,
		"name": _sanitize_hive_name(str(raw.get("name", ""))),
		"created_at_unix": maxi(0, int(raw.get("created_at_unix", 0))),
		"created_by_player_id": _sanitize_player_id(str(raw.get("created_by_player_id", ""))),
		"members": members_out,
		"pinned_notice": _sanitize_pinned_notice(raw.get("pinned_notice", {})),
		"about_profile": _sanitize_hive_about_profile(raw.get("about_profile", {})),
		"soldier_demotion_votes": _sanitize_soldier_demotion_votes(raw.get("soldier_demotion_votes", {})),
		"queen_removal_vote": _sanitize_vote_map(raw.get("queen_removal_vote", {})),
		"queen_removal_vote_started_at_unix": maxi(0, int(raw.get("queen_removal_vote_started_at_unix", 0))),
		"leadership_removal_votes": _sanitize_leadership_removal_votes(raw.get("leadership_removal_votes", {})),
		"soldier_promotion_votes": _sanitize_soldier_promotion_votes(raw.get("soldier_promotion_votes", {})),
		"tournament_entries": _sanitize_hive_tournament_entries(raw.get("tournament_entries", {})),
		"tournament_wins": maxi(0, int(raw.get("tournament_wins", 0))),
		"hive_championships": maxi(0, int(raw.get("hive_championships", 0))),
		"seasonal_best_finish": maxi(0, int(raw.get("seasonal_best_finish", 0))),
		"award_records": _sanitize_hive_award_records(raw.get("award_records", [])),
		"total_honey_spent": maxi(0, int(raw.get("total_honey_spent", 0))),
		"feed_entries": _sanitize_feed_entries(raw.get("feed_entries", [])),
		"total_honey_contributed": maxi(0, int(raw.get("total_honey_contributed", 0))),
		"hive_honey_strength": maxi(0, int(raw.get("hive_honey_strength", 0)))
	}
	_recompute_hive_metrics(hive)
	return hive

func _sanitize_invites(raw_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_any) != TYPE_DICTIONARY:
		return out
	var raw: Dictionary = raw_any as Dictionary
	for invite_id_any in raw.keys():
		var invite: Dictionary = _sanitize_invite(raw.get(invite_id_any, {}) as Dictionary)
		var invite_id: String = str(invite.get("invite_id", ""))
		if invite_id.is_empty():
			continue
		out[invite_id] = invite
	return out

func _sanitize_invite(raw: Dictionary) -> Dictionary:
	var status: String = _sanitize_invite_status(str(raw.get("status", INVITE_STATUS_PENDING)))
	var created_at_unix: int = maxi(0, int(raw.get("created_at_unix", 0)))
	var expires_at_unix: int = maxi(0, int(raw.get("expires_at_unix", 0)))
	if expires_at_unix <= 0 and status == INVITE_STATUS_PENDING and created_at_unix > 0:
		expires_at_unix = created_at_unix + INVITE_EXPIRY_SEC
	return {
		"invite_id": str(raw.get("invite_id", "")).strip_edges(),
		"hive_id": str(raw.get("hive_id", "")).strip_edges(),
		"target_player_id": _sanitize_player_id(str(raw.get("target_player_id", ""))),
		"target_display_name": _sanitize_display_name(str(raw.get("target_display_name", ""))),
		"created_by_player_id": _sanitize_player_id(str(raw.get("created_by_player_id", ""))),
		"created_by_display_name": _sanitize_display_name(str(raw.get("created_by_display_name", ""))),
		"role": _sanitize_role(str(raw.get("role", ROLE_MEMBER))),
		"status": status,
			"created_at_unix": created_at_unix,
			"expires_at_unix": expires_at_unix,
			"responded_at_unix": maxi(0, int(raw.get("responded_at_unix", 0))),
			"offer_bundle": _sanitize_invite_offer_bundle(raw.get("offer_bundle", {}))
		}

func _sanitize_hive_tournament_entries(raw_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_any) != TYPE_DICTIONARY:
		return out
	var raw: Dictionary = raw_any as Dictionary
	for tournament_id_any in raw.keys():
		var tournament_id: String = str(tournament_id_any).strip_edges()
		if tournament_id.is_empty():
			continue
		var entry: Dictionary = raw.get(tournament_id_any, {}) as Dictionary
		out[tournament_id] = {
			"tournament_id": tournament_id,
			"title": str(entry.get("title", "Hive Tournament")).strip_edges(),
			"detail": str(entry.get("detail", "")).strip_edges(),
			"honey_cost": maxi(0, int(entry.get("honey_cost", 0))),
			"entered_at_unix": maxi(0, int(entry.get("entered_at_unix", 0))),
			"entered_by_player_id": _sanitize_player_id(str(entry.get("entered_by_player_id", ""))),
			"queue_status": _sanitize_hive_tournament_status(str(entry.get("queue_status", HIVE_TOURNAMENT_STATUS_QUEUED))),
			"round_id": str(entry.get("round_id", "")).strip_edges(),
			"bracket_id": str(entry.get("bracket_id", "")).strip_edges(),
			"bracket_status": _sanitize_hive_tournament_bracket_status(str(entry.get("bracket_status", HIVE_TOURNAMENT_BRACKET_STATUS_ACTIVE))),
			"format_id": str(entry.get("format_id", HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H)).strip_edges().to_lower(),
			"field_size": maxi(2, int(entry.get("field_size", 2))),
			"queued_at_unix": maxi(0, int(entry.get("queued_at_unix", int(entry.get("entered_at_unix", 0))))),
			"round_started_at_unix": maxi(0, int(entry.get("round_started_at_unix", 0))),
			"round_deadline_unix": maxi(0, int(entry.get("round_deadline_unix", 0))),
			"replace_deadline_unix": maxi(0, int(entry.get("replace_deadline_unix", 0))),
			"opponent_hive_id": str(entry.get("opponent_hive_id", "")).strip_edges(),
			"current_round_number": maxi(0, int(entry.get("current_round_number", 0))),
			"rounds_total": maxi(0, int(entry.get("rounds_total", 0))),
			"last_result": _sanitize_hive_tournament_result(entry.get("last_result", {}))
		}
	return out

func _invite_offer_bundle_for_id(bundle_id: String) -> Dictionary:
	var target_id: String = bundle_id.strip_edges().to_lower()
	if target_id.is_empty():
		return {}
	for bundle_any in INVITE_OFFER_BUNDLES:
		var bundle: Dictionary = bundle_any as Dictionary
		if str(bundle.get("bundle_id", "")).strip_edges().to_lower() == target_id:
			return bundle.duplicate(true)
	return {}

func _hive_tournament_entry_for_id(tournament_id: String) -> Dictionary:
	var target_id: String = tournament_id.strip_edges().to_lower()
	if target_id.is_empty():
		return {}
	for entry_any in HIVE_TOURNAMENT_ENTRIES:
		var entry: Dictionary = entry_any as Dictionary
		if str(entry.get("tournament_id", "")).strip_edges().to_lower() == target_id:
			return entry.duplicate(true)
	return {}

func _sanitize_invite_offer_bundle(raw_any: Variant) -> Dictionary:
	if typeof(raw_any) != TYPE_DICTIONARY:
		return {}
	var raw: Dictionary = raw_any as Dictionary
	var bundle_id: String = str(raw.get("bundle_id", "")).strip_edges().to_lower()
	var catalog_bundle: Dictionary = _invite_offer_bundle_for_id(bundle_id)
	if not catalog_bundle.is_empty():
		return catalog_bundle
	if bundle_id.is_empty():
		return {}
	return {
		"bundle_id": bundle_id,
		"title": str(raw.get("title", "Honey Gift")).strip_edges(),
		"honey_cost": maxi(0, int(raw.get("honey_cost", 0))),
		"detail": str(raw.get("detail", "")).strip_edges()
	}

func _sanitize_applications(raw_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_any) != TYPE_DICTIONARY:
		return out
	var raw: Dictionary = raw_any as Dictionary
	for application_id_any in raw.keys():
		var application: Dictionary = _sanitize_application(raw.get(application_id_any, {}) as Dictionary)
		var application_id: String = str(application.get("application_id", ""))
		if application_id.is_empty():
			continue
		out[application_id] = application
	return out

func _sanitize_application(raw: Dictionary) -> Dictionary:
	return {
		"application_id": str(raw.get("application_id", "")).strip_edges(),
		"hive_id": str(raw.get("hive_id", "")).strip_edges(),
		"player_id": _sanitize_player_id(str(raw.get("player_id", ""))),
		"player_display_name": _sanitize_display_name(str(raw.get("player_display_name", ""))),
		"status": _sanitize_application_status(str(raw.get("status", APPLICATION_STATUS_PENDING))),
		"created_at_unix": maxi(0, int(raw.get("created_at_unix", 0))),
		"responded_at_unix": maxi(0, int(raw.get("responded_at_unix", 0))),
		"reviewed_by_player_id": _sanitize_player_id(str(raw.get("reviewed_by_player_id", "")))
	}

func _sanitize_member(raw: Dictionary) -> Dictionary:
	var player_id: String = _sanitize_player_id(str(raw.get("player_id", "")))
	return {
		"player_id": player_id,
		"display_name": _display_name_for_player(player_id, str(raw.get("display_name", ""))),
		"role": _sanitize_role(str(raw.get("role", ROLE_MEMBER))),
		"joined_at_unix": maxi(0, int(raw.get("joined_at_unix", 0))),
		"last_seen_at_unix": maxi(0, int(raw.get("last_seen_at_unix", raw.get("joined_at_unix", 0)))),
		"honey_contributed": maxi(0, int(raw.get("honey_contributed", 0))),
		"honey_balance_snapshot": maxi(0, int(raw.get("honey_balance_snapshot", raw.get("honey_contributed", 0)))),
		"honey_spent": maxi(0, int(raw.get("honey_spent", 0))),
		"last_honey_reason": str(raw.get("last_honey_reason", "")),
		"last_honey_at_unix": maxi(0, int(raw.get("last_honey_at_unix", 0)))
	}

func _sanitize_pinned_notice(raw_any: Variant) -> Dictionary:
	if typeof(raw_any) != TYPE_DICTIONARY:
		return {}
	var raw: Dictionary = raw_any as Dictionary
	var message: String = _sanitize_comms_text(str(raw.get("message", "")), HIVE_PINNED_NOTICE_MAX_LEN)
	if message == "":
		return {}
	return {
		"message": message,
		"updated_at_unix": maxi(0, int(raw.get("updated_at_unix", 0))),
		"updated_by_player_id": _sanitize_player_id(str(raw.get("updated_by_player_id", "")))
	}

func _sanitize_hive_about_profile(raw_any: Variant) -> Dictionary:
	if typeof(raw_any) != TYPE_DICTIONARY:
		return {}
	var raw: Dictionary = raw_any as Dictionary
	var message: String = _sanitize_comms_text(str(raw.get("message", "")), HIVE_ABOUT_MAX_LEN)
	if message == "":
		return {}
	return {
		"message": message,
		"updated_at_unix": maxi(0, int(raw.get("updated_at_unix", 0))),
		"updated_by_player_id": _sanitize_player_id(str(raw.get("updated_by_player_id", ""))),
		"next_edit_at_unix": maxi(0, int(raw.get("updated_at_unix", 0))) + HIVE_ABOUT_UPDATE_COOLDOWN_SEC if maxi(0, int(raw.get("updated_at_unix", 0))) > 0 else 0
	}

func _sanitize_feed_entries(raw_any: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(raw_any) != TYPE_ARRAY:
		return out
	for entry_any in raw_any as Array:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry_raw: Dictionary = entry_any as Dictionary
		var message: String = str(entry_raw.get("message", "")).strip_edges()
		if message == "":
			continue
		out.append({
			"created_at_unix": maxi(0, int(entry_raw.get("created_at_unix", 0))),
			"message": message,
			"type": str(entry_raw.get("type", "system")).strip_edges().to_lower()
		})
	if out.size() > HIVE_FEED_LIMIT:
		out = out.slice(out.size() - HIVE_FEED_LIMIT, out.size())
	return out

func _sanitize_leave_requests(raw_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_any) != TYPE_DICTIONARY:
		return out
	var raw: Dictionary = raw_any as Dictionary
	for player_id_any in raw.keys():
		var player_id: String = _sanitize_player_id(str(player_id_any))
		if player_id.is_empty():
			continue
		var request_raw: Dictionary = raw.get(player_id_any, {}) as Dictionary
		var hive_id: String = str(request_raw.get("hive_id", "")).strip_edges()
		if hive_id.is_empty():
			continue
		out[player_id] = {
			"player_id": player_id,
			"hive_id": hive_id,
			"requested_at_unix": maxi(0, int(request_raw.get("requested_at_unix", 0))),
			"effective_at_unix": maxi(0, int(request_raw.get("effective_at_unix", 0)))
		}
	return out

func _sanitize_rejoin_cooldowns(raw_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_any) != TYPE_DICTIONARY:
		return out
	var raw: Dictionary = raw_any as Dictionary
	for player_id_any in raw.keys():
		var player_id: String = _sanitize_player_id(str(player_id_any))
		if player_id.is_empty():
			continue
		var hive_map_raw: Dictionary = raw.get(player_id_any, {}) as Dictionary
		var hive_map_out: Dictionary = {}
		for hive_id_any in hive_map_raw.keys():
			var hive_id: String = str(hive_id_any).strip_edges()
			if hive_id.is_empty():
				continue
			hive_map_out[hive_id] = maxi(0, int(hive_map_raw.get(hive_id_any, 0)))
		if not hive_map_out.is_empty():
			out[player_id] = hive_map_out
	return out

func _sanitize_creation_history(raw_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_any) != TYPE_DICTIONARY:
		return out
	var raw: Dictionary = raw_any as Dictionary
	for player_id_any in raw.keys():
		var player_id: String = _sanitize_player_id(str(player_id_any))
		if player_id.is_empty():
			continue
		var entries_any: Variant = raw.get(player_id_any, [])
		if typeof(entries_any) != TYPE_ARRAY:
			continue
		var entries_out: Array[int] = []
		for entry_any in entries_any as Array:
			var timestamp: int = maxi(0, int(entry_any))
			if timestamp > 0:
				entries_out.append(timestamp)
		if not entries_out.is_empty():
			out[player_id] = entries_out
	return out

func _sanitize_hive_award_records(raw_any: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(raw_any) != TYPE_ARRAY:
		return out
	for award_any in raw_any as Array:
		if typeof(award_any) != TYPE_DICTIONARY:
			continue
		var award: Dictionary = award_any as Dictionary
		var award_id: String = str(award.get("award_id", "")).strip_edges()
		if award_id.is_empty():
			continue
		var award_type: String = str(award.get("award_type", HIVE_AWARD_TYPE_TROPHY)).strip_edges().to_lower()
		if award_type != HIVE_AWARD_TYPE_NFT:
			award_type = HIVE_AWARD_TYPE_TROPHY
		var owner_kind: String = str(award.get("owner_kind", HIVE_AWARD_OWNER_HIVE)).strip_edges().to_lower()
		if owner_kind != HIVE_AWARD_OWNER_COMPANY:
			owner_kind = HIVE_AWARD_OWNER_HIVE
		out.append({
			"award_id": award_id,
			"title": str(award.get("title", "")).strip_edges(),
			"detail": str(award.get("detail", "")).strip_edges(),
			"award_type": award_type,
			"tournament_id": str(award.get("tournament_id", "")).strip_edges(),
			"tournament_title": str(award.get("tournament_title", "")).strip_edges(),
			"rank_multiplier_bps": maxi(0, int(award.get("rank_multiplier_bps", 0))),
			"awarded_at_unix": maxi(0, int(award.get("awarded_at_unix", 0))),
			"owner_kind": owner_kind,
			"owner_hive_id": str(award.get("owner_hive_id", "")).strip_edges(),
			"owner_hive_name": str(award.get("owner_hive_name", "")).strip_edges(),
			"source_hive_id": str(award.get("source_hive_id", "")).strip_edges(),
			"source_hive_name": str(award.get("source_hive_name", "")).strip_edges(),
			"archived_at_unix": maxi(0, int(award.get("archived_at_unix", 0))),
			"bracket_id": str(award.get("bracket_id", "")).strip_edges(),
			"round_id": str(award.get("round_id", "")).strip_edges()
		})
	return out

func _reindex_memberships() -> void:
	_player_to_hive_id.clear()
	for hive_id_any in _hives_by_id.keys():
		var hive_id: String = str(hive_id_any)
		var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
		var members: Dictionary = hive.get("members", {}) as Dictionary
		for player_id_any in members.keys():
			var player_id: String = str(player_id_any)
			if player_id.is_empty():
				continue
			_player_to_hive_id[player_id] = hive_id

func _recompute_hive_metrics(hive: Dictionary) -> void:
	var members: Dictionary = hive.get("members", {}) as Dictionary
	var total_honey_contributed: int = 0
	var spendable_honey: int = 0
	for member_any in members.values():
		var member: Dictionary = member_any as Dictionary
		total_honey_contributed += maxi(0, int(member.get("honey_contributed", 0)))
		spendable_honey += _member_honey_balance(member)
	hive["total_honey_contributed"] = total_honey_contributed
	hive["hive_honey_strength"] = spendable_honey

func _hive_member_honey_balances(hive: Dictionary, balances_by_player: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	var members: Dictionary = hive.get("members", {}) as Dictionary
	for player_id_any in members.keys():
		var player_id: String = _sanitize_player_id(str(player_id_any))
		if player_id.is_empty():
			continue
		var member: Dictionary = members.get(player_id, {}) as Dictionary
		if balances_by_player.has(player_id):
			out[player_id] = maxi(0, int(balances_by_player.get(player_id, 0)))
		else:
			out[player_id] = _member_honey_balance(member)
	return out

func _member_honey_balance(member: Dictionary) -> int:
	if member.has("honey_balance_snapshot"):
		return maxi(0, int(member.get("honey_balance_snapshot", 0)))
	return maxi(0, int(member.get("honey_contributed", 0)))

func _sanitize_hive_tournament_status(status: String) -> String:
	var clean_status: String = status.strip_edges().to_lower()
	match clean_status:
		HIVE_TOURNAMENT_STATUS_ACTIVE, HIVE_TOURNAMENT_STATUS_RESOLVED, HIVE_TOURNAMENT_STATUS_FORFEIT:
			return clean_status
		_:
			return HIVE_TOURNAMENT_STATUS_QUEUED

func _sanitize_hive_tournament_result(raw_any: Variant) -> Dictionary:
	if typeof(raw_any) != TYPE_DICTIONARY:
		return {}
	var raw: Dictionary = raw_any as Dictionary
	return {
		"winner_hive_id": str(raw.get("winner_hive_id", "")).strip_edges(),
		"loser_hive_id": str(raw.get("loser_hive_id", "")).strip_edges(),
		"resolution_reason": str(raw.get("resolution_reason", "")).strip_edges(),
		"team_a_slot_wins": maxi(0, int(raw.get("team_a_slot_wins", 0))),
		"team_b_slot_wins": maxi(0, int(raw.get("team_b_slot_wins", 0))),
		"team_a_total_time_ms": maxi(0, int(raw.get("team_a_total_time_ms", 0))),
		"team_b_total_time_ms": maxi(0, int(raw.get("team_b_total_time_ms", 0))),
		"resolved_at_unix": maxi(0, int(raw.get("resolved_at_unix", 0))),
		"forfeited_hive_id": str(raw.get("forfeited_hive_id", "")).strip_edges()
	}

func _sanitize_hive_tournament_bracket_status(status: String) -> String:
	var clean_status: String = status.strip_edges().to_lower()
	match clean_status:
		HIVE_TOURNAMENT_BRACKET_STATUS_RESOLVED:
			return clean_status
		_:
			return HIVE_TOURNAMENT_BRACKET_STATUS_ACTIVE

func _sanitize_hive_tournament_queues(raw_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_any) != TYPE_DICTIONARY:
		return out
	var raw: Dictionary = raw_any as Dictionary
	for tournament_id_any in raw.keys():
		var tournament_id: String = str(tournament_id_any).strip_edges()
		if tournament_id.is_empty():
			continue
		var queue_any: Variant = raw.get(tournament_id_any, [])
		if typeof(queue_any) != TYPE_ARRAY:
			continue
		var queue_out: Array[String] = []
		for hive_id_any in queue_any as Array:
			var hive_id: String = str(hive_id_any).strip_edges()
			if hive_id.is_empty() or queue_out.has(hive_id):
				continue
			queue_out.append(hive_id)
		out[tournament_id] = queue_out
	return out

func _sanitize_hive_tournament_brackets(raw_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_any) != TYPE_DICTIONARY:
		return out
	var raw: Dictionary = raw_any as Dictionary
	for bracket_id_any in raw.keys():
		var bracket_id: String = str(bracket_id_any).strip_edges()
		if bracket_id.is_empty():
			continue
		var bracket_raw: Dictionary = raw.get(bracket_id_any, {}) as Dictionary
		var entrants_any: Variant = bracket_raw.get("entrant_hive_ids", [])
		var entrant_hive_ids: Array[String] = []
		if typeof(entrants_any) == TYPE_ARRAY:
			for hive_id_any in entrants_any as Array:
				var hive_id: String = str(hive_id_any).strip_edges()
				if hive_id.is_empty() or entrant_hive_ids.has(hive_id):
					continue
				entrant_hive_ids.append(hive_id)
		var matches_any: Variant = bracket_raw.get("matches", {})
		var matches_out: Dictionary = {}
		if typeof(matches_any) == TYPE_DICTIONARY:
			var matches_raw: Dictionary = matches_any as Dictionary
			for match_key_any in matches_raw.keys():
				var match_key: String = str(match_key_any).strip_edges()
				if match_key.is_empty():
					continue
				var match_raw: Dictionary = matches_raw.get(match_key_any, {}) as Dictionary
				var source_any: Variant = match_raw.get("source_match_keys", [])
				var source_keys: Array[String] = []
				if typeof(source_any) == TYPE_ARRAY:
					for source_key_any in source_any as Array:
						var source_key: String = str(source_key_any).strip_edges()
						if source_key.is_empty():
							continue
						source_keys.append(source_key)
				matches_out[match_key] = {
					"match_key": match_key,
					"round_number": maxi(1, int(match_raw.get("round_number", 1))),
					"match_number": maxi(1, int(match_raw.get("match_number", 1))),
					"status": _sanitize_hive_tournament_status(str(match_raw.get("status", HIVE_TOURNAMENT_STATUS_QUEUED))),
					"round_id": str(match_raw.get("round_id", "")).strip_edges(),
					"hive_a_id": str(match_raw.get("hive_a_id", "")).strip_edges(),
					"hive_b_id": str(match_raw.get("hive_b_id", "")).strip_edges(),
					"winner_hive_id": str(match_raw.get("winner_hive_id", "")).strip_edges(),
					"loser_hive_id": str(match_raw.get("loser_hive_id", "")).strip_edges(),
					"source_match_keys": source_keys,
					"next_match_key": str(match_raw.get("next_match_key", "")).strip_edges()
				}
		out[bracket_id] = {
			"bracket_id": bracket_id,
			"tournament_id": str(bracket_raw.get("tournament_id", "")).strip_edges(),
			"title": str(bracket_raw.get("title", "Hive Tournament")).strip_edges(),
			"format_id": str(bracket_raw.get("format_id", HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H)).strip_edges().to_lower(),
			"field_size": maxi(2, int(bracket_raw.get("field_size", 2))),
			"status": _sanitize_hive_tournament_bracket_status(str(bracket_raw.get("status", HIVE_TOURNAMENT_BRACKET_STATUS_ACTIVE))),
			"created_at_unix": maxi(0, int(bracket_raw.get("created_at_unix", 0))),
			"resolved_at_unix": maxi(0, int(bracket_raw.get("resolved_at_unix", 0))),
			"current_round_number": maxi(1, int(bracket_raw.get("current_round_number", 1))),
			"rounds_total": maxi(1, int(bracket_raw.get("rounds_total", 1))),
			"entrant_hive_ids": entrant_hive_ids,
			"winner_hive_id": str(bracket_raw.get("winner_hive_id", "")).strip_edges(),
			"matches": matches_out
		}
	return out

func _sanitize_hive_tournament_slots(raw_any: Variant) -> Array:
	var out: Array = []
	if typeof(raw_any) != TYPE_ARRAY:
		return out
	for slot_any in raw_any as Array:
		if typeof(slot_any) != TYPE_DICTIONARY:
			continue
		var slot_raw: Dictionary = slot_any as Dictionary
		var previous_any: Variant = slot_raw.get("previous_player_ids", [])
		var previous_ids: Array[String] = []
		if typeof(previous_any) == TYPE_ARRAY:
			for player_id_any in previous_any as Array:
				var player_id: String = _sanitize_player_id(str(player_id_any))
				if player_id.is_empty() or previous_ids.has(player_id):
					continue
				previous_ids.append(player_id)
		var round_results_any: Variant = slot_raw.get("round_results", [])
		var round_results: Array = round_results_any.duplicate(true) if typeof(round_results_any) == TYPE_ARRAY else []
		var player_id_clean: String = _sanitize_player_id(str(slot_raw.get("player_id", "")))
		out.append({
			"slot_index": maxi(0, int(slot_raw.get("slot_index", out.size()))),
			"seed_rank": maxi(1, int(slot_raw.get("seed_rank", out.size() + 1))),
			"player_id": player_id_clean,
			"display_name": _display_name_for_player(player_id_clean, str(slot_raw.get("display_name", ""))),
			"assigned_at_unix": maxi(0, int(slot_raw.get("assigned_at_unix", 0))),
			"checked_in_at_unix": maxi(0, int(slot_raw.get("checked_in_at_unix", 0))),
			"submitted_at_unix": maxi(0, int(slot_raw.get("submitted_at_unix", 0))),
			"total_time_ms": maxi(0, int(slot_raw.get("total_time_ms", 0))),
			"status": str(slot_raw.get("status", "assigned")).strip_edges().to_lower(),
			"round_results": round_results,
			"previous_player_ids": previous_ids,
			"replaced_player_id": _sanitize_player_id(str(slot_raw.get("replaced_player_id", ""))),
			"replacement_seed_rank": maxi(0, int(slot_raw.get("replacement_seed_rank", 0))),
			"replaced_at_unix": maxi(0, int(slot_raw.get("replaced_at_unix", 0)))
		})
	return out

func _sanitize_hive_tournament_rounds(raw_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_any) != TYPE_DICTIONARY:
		return out
	var raw: Dictionary = raw_any as Dictionary
	for round_id_any in raw.keys():
		var round_id: String = str(round_id_any).strip_edges()
		if round_id.is_empty():
			continue
		var round_raw: Dictionary = raw.get(round_id_any, {}) as Dictionary
		out[round_id] = {
			"round_id": round_id,
			"tournament_id": str(round_raw.get("tournament_id", "")).strip_edges(),
			"title": str(round_raw.get("title", "Hive Tournament")).strip_edges(),
			"status": _sanitize_hive_tournament_status(str(round_raw.get("status", HIVE_TOURNAMENT_STATUS_ACTIVE))),
			"format_id": str(round_raw.get("format_id", HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H)).strip_edges().to_lower(),
			"bracket_id": str(round_raw.get("bracket_id", "")).strip_edges(),
			"bracket_round_number": maxi(0, int(round_raw.get("bracket_round_number", 0))),
			"bracket_match_number": maxi(0, int(round_raw.get("bracket_match_number", 0))),
			"roster_size": maxi(1, int(round_raw.get("roster_size", HIVE_TOURNAMENT_ROSTER_SIZE))),
			"map_paths": _sanitize_stage_map_paths(round_raw.get("map_paths", HIVE_TOURNAMENT_STAGE_MAP_PATHS)),
			"started_at_unix": maxi(0, int(round_raw.get("started_at_unix", 0))),
			"replace_deadline_unix": maxi(0, int(round_raw.get("replace_deadline_unix", 0))),
			"deadline_unix": maxi(0, int(round_raw.get("deadline_unix", 0))),
			"resolved_at_unix": maxi(0, int(round_raw.get("resolved_at_unix", 0))),
			"hive_a_id": str(round_raw.get("hive_a_id", "")).strip_edges(),
			"hive_b_id": str(round_raw.get("hive_b_id", "")).strip_edges(),
			"hive_a_name": str(round_raw.get("hive_a_name", "")).strip_edges(),
			"hive_b_name": str(round_raw.get("hive_b_name", "")).strip_edges(),
			"hive_a_slots": _sanitize_hive_tournament_slots(round_raw.get("hive_a_slots", [])),
			"hive_b_slots": _sanitize_hive_tournament_slots(round_raw.get("hive_b_slots", [])),
			"winner_hive_id": str(round_raw.get("winner_hive_id", "")).strip_edges(),
			"loser_hive_id": str(round_raw.get("loser_hive_id", "")).strip_edges(),
			"resolution_reason": str(round_raw.get("resolution_reason", "")).strip_edges(),
			"forfeited_hive_id": str(round_raw.get("forfeited_hive_id", "")).strip_edges(),
			"team_a_slot_wins": maxi(0, int(round_raw.get("team_a_slot_wins", 0))),
			"team_b_slot_wins": maxi(0, int(round_raw.get("team_b_slot_wins", 0))),
			"team_a_total_time_ms": maxi(0, int(round_raw.get("team_a_total_time_ms", 0))),
			"team_b_total_time_ms": maxi(0, int(round_raw.get("team_b_total_time_ms", 0)))
		}
	return out

func _sanitize_stage_map_paths(raw_any: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw_any) == TYPE_ARRAY:
		for map_path_any in raw_any as Array:
			var map_path: String = str(map_path_any).strip_edges()
			if map_path.is_empty():
				continue
			out.append(map_path)
	if out.is_empty():
		return HIVE_TOURNAMENT_STAGE_MAP_PATHS.duplicate()
	return out

func _most_relevant_hive_tournament_entry(tournament_entries: Dictionary) -> Dictionary:
	var best_entry: Dictionary = {}
	var best_priority: int = -1
	var best_timestamp: int = -1
	for entry_any in tournament_entries.values():
		var entry: Dictionary = entry_any as Dictionary
		var priority: int = _hive_tournament_entry_priority(entry)
		var timestamp: int = maxi(
			int(entry.get("round_started_at_unix", 0)),
			maxi(int(entry.get("queued_at_unix", 0)), int(entry.get("entered_at_unix", 0)))
		)
		if priority > best_priority or (priority == best_priority and timestamp > best_timestamp):
			best_entry = entry
			best_priority = priority
			best_timestamp = timestamp
	return best_entry.duplicate(true)

func _hive_tournament_entry_priority(entry: Dictionary) -> int:
	var queue_status: String = str(entry.get("queue_status", "")).strip_edges().to_lower()
	match queue_status:
		HIVE_TOURNAMENT_STATUS_ACTIVE:
			return 3
		HIVE_TOURNAMENT_STATUS_QUEUED:
			return 2
		HIVE_TOURNAMENT_STATUS_RESOLVED, HIVE_TOURNAMENT_STATUS_FORFEIT:
			return 1
		_:
			return 0

func _hive_tournament_queue_position(tournament_id: String, hive_id: String) -> int:
	var queue_any: Variant = _hive_tournament_queue_by_tournament_id.get(tournament_id, [])
	if typeof(queue_any) != TYPE_ARRAY:
		return 0
	var queue: Array = queue_any as Array
	for i in range(queue.size()):
		if str(queue[i]).strip_edges() == hive_id:
			return i + 1
	return 0

func _hive_tournament_queue_size(tournament_id: String) -> int:
	var queue_any: Variant = _hive_tournament_queue_by_tournament_id.get(tournament_id, [])
	if typeof(queue_any) != TYPE_ARRAY:
		return 0
	return (queue_any as Array).size()

func _hive_tournament_round_perspective(round: Dictionary, hive_id: String, player_id: String = "") -> Dictionary:
	var clean_hive_id: String = str(hive_id).strip_edges()
	if clean_hive_id.is_empty():
		return {}
	var is_hive_a: bool = str(round.get("hive_a_id", "")) == clean_hive_id
	var my_slots: Array = round.get("hive_a_slots", []) as Array if is_hive_a else round.get("hive_b_slots", []) as Array
	var opponent_slots: Array = round.get("hive_b_slots", []) as Array if is_hive_a else round.get("hive_a_slots", []) as Array
	var local_assignment: Dictionary = {}
	var slot_matchups: Array[Dictionary] = []
	var my_completed_count: int = 0
	var opponent_completed_count: int = 0
	var clean_player_id: String = _sanitize_player_id(player_id)
	for i in range(maxi(my_slots.size(), opponent_slots.size())):
		var my_slot: Dictionary = my_slots[i] as Dictionary if i < my_slots.size() else {}
		var opponent_slot: Dictionary = opponent_slots[i] as Dictionary if i < opponent_slots.size() else {}
		var my_status: String = str(my_slot.get("status", "assigned")).strip_edges().to_lower()
		var opponent_status: String = str(opponent_slot.get("status", "assigned")).strip_edges().to_lower()
		if my_status == "submitted":
			my_completed_count += 1
		if opponent_status == "submitted":
			opponent_completed_count += 1
		var matchup: Dictionary = {
			"slot_index": i,
			"slot_number": i + 1,
			"player_id": str(my_slot.get("player_id", "")),
			"display_name": str(my_slot.get("display_name", "")),
			"status": my_status,
			"submitted_at_unix": int(my_slot.get("submitted_at_unix", 0)),
			"checked_in_at_unix": int(my_slot.get("checked_in_at_unix", 0)),
			"opponent_player_id": str(opponent_slot.get("player_id", "")),
			"opponent_display_name": str(opponent_slot.get("display_name", "")),
			"opponent_status": opponent_status,
			"opponent_submitted_at_unix": int(opponent_slot.get("submitted_at_unix", 0)),
			"is_local_player": clean_player_id != "" and str(my_slot.get("player_id", "")) == clean_player_id
		}
		slot_matchups.append(matchup)
		if bool(matchup.get("is_local_player", false)):
			local_assignment = matchup.duplicate(true)
	return {
		"opponent_hive_id": str(round.get("hive_b_id", "")) if is_hive_a else str(round.get("hive_a_id", "")),
		"opponent_hive_name": str(round.get("hive_b_name", "")) if is_hive_a else str(round.get("hive_a_name", "")),
		"slot_matchups": slot_matchups,
		"hive_completed_count": my_completed_count,
		"opponent_completed_count": opponent_completed_count,
		"roster_size": maxi(my_slots.size(), opponent_slots.size()),
		"local_assignment": local_assignment
	}

func _queue_hive_tournament_entry(hive_id: String, tournament_id: String) -> Dictionary:
	var entry_def: Dictionary = _hive_tournament_entry_for_id(tournament_id)
	var format_id: String = str(entry_def.get("format_id", HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H)).strip_edges().to_lower()
	_remove_hive_from_tournament_queue(tournament_id, hive_id)
	_enqueue_hive_to_tournament_queue(tournament_id, hive_id)
	_set_hive_tournament_entry_fields(hive_id, tournament_id, {
		"queue_status": HIVE_TOURNAMENT_STATUS_QUEUED,
		"bracket_id": "",
		"bracket_status": HIVE_TOURNAMENT_BRACKET_STATUS_ACTIVE,
		"format_id": format_id,
		"field_size": maxi(2, int(entry_def.get("field_size", 2))),
		"round_id": "",
		"queued_at_unix": _now_unix(),
		"round_started_at_unix": 0,
		"round_deadline_unix": 0,
		"replace_deadline_unix": 0,
		"opponent_hive_id": "",
		"current_round_number": 0,
		"rounds_total": _single_elimination_rounds_total(maxi(2, int(entry_def.get("field_size", 2)))),
		"last_result": {}
	})
	match format_id:
		HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H:
			return _maybe_start_hive_tournament_brackets(tournament_id, entry_def, hive_id)
		_:
			return {}

func _enqueue_hive_to_tournament_queue(tournament_id: String, hive_id: String) -> void:
	var queue_any: Variant = _hive_tournament_queue_by_tournament_id.get(tournament_id, [])
	var queue: Array = queue_any.duplicate(true) if typeof(queue_any) == TYPE_ARRAY else []
	if not queue.has(hive_id):
		queue.append(hive_id)
	_hive_tournament_queue_by_tournament_id[tournament_id] = queue

func _eligible_hive_tournament_queue(tournament_id: String) -> Array[String]:
	var out: Array[String] = []
	var queue_any: Variant = _hive_tournament_queue_by_tournament_id.get(tournament_id, [])
	if typeof(queue_any) != TYPE_ARRAY:
		return out
	for hive_id_any in queue_any as Array:
		var hive_id: String = str(hive_id_any).strip_edges()
		if hive_id.is_empty() or out.has(hive_id):
			continue
		var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
		if hive.is_empty() or _hive_has_active_tournament_round(hive_id):
			continue
		var tournament_entry: Dictionary = (hive.get("tournament_entries", {}) as Dictionary).get(tournament_id, {}) as Dictionary
		if str(tournament_entry.get("queue_status", "")) != HIVE_TOURNAMENT_STATUS_QUEUED:
			continue
		out.append(hive_id)
	return out

func _maybe_start_hive_tournament_brackets(tournament_id: String, entry_def: Dictionary, focus_hive_id: String = "") -> Dictionary:
	var field_size: int = maxi(2, int(entry_def.get("field_size", 2)))
	var result: Dictionary = {}
	while true:
		var eligible_queue: Array[String] = _eligible_hive_tournament_queue(tournament_id)
		if eligible_queue.size() < field_size:
			break
		var entrants: Array[String] = []
		for i in range(field_size):
			entrants.append(eligible_queue[i])
		_remove_hive_ids_from_tournament_queue(tournament_id, entrants)
		var bracket: Dictionary = _create_hive_tournament_bracket(tournament_id, entry_def, entrants)
		if focus_hive_id != "" and entrants.has(focus_hive_id):
			result["bracket"] = bracket.duplicate(true)
			result["round"] = _find_active_round_for_hive_in_bracket(str(bracket.get("bracket_id", "")), focus_hive_id)
	return result

func _remove_hive_ids_from_tournament_queue(tournament_id: String, hive_ids: Array[String]) -> void:
	var queue_any: Variant = _hive_tournament_queue_by_tournament_id.get(tournament_id, [])
	if typeof(queue_any) != TYPE_ARRAY:
		return
	var queue_out: Array[String] = []
	for hive_id_any in queue_any as Array:
		var hive_id: String = str(hive_id_any).strip_edges()
		if hive_id.is_empty() or hive_ids.has(hive_id):
			continue
		queue_out.append(hive_id)
	_hive_tournament_queue_by_tournament_id[tournament_id] = queue_out

func _create_hive_tournament_bracket(tournament_id: String, entry_def: Dictionary, entrant_hive_ids: Array[String]) -> Dictionary:
	var bracket_id: String = _next_id(TOURNAMENT_BRACKET_ID_PREFIX)
	var field_size: int = entrant_hive_ids.size()
	var rounds_total: int = _single_elimination_rounds_total(field_size)
	var bracket: Dictionary = {
		"bracket_id": bracket_id,
		"tournament_id": tournament_id,
		"title": str(entry_def.get("title", "Hive Tournament")),
		"format_id": str(entry_def.get("format_id", HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H)).strip_edges().to_lower(),
		"field_size": field_size,
		"status": HIVE_TOURNAMENT_BRACKET_STATUS_ACTIVE,
		"created_at_unix": _now_unix(),
		"resolved_at_unix": 0,
		"current_round_number": 1,
		"rounds_total": rounds_total,
		"entrant_hive_ids": entrant_hive_ids.duplicate(),
		"winner_hive_id": "",
		"matches": _build_single_elimination_match_map(entrant_hive_ids)
	}
	_hive_tournament_brackets_by_id[bracket_id] = bracket
	for entrant_hive_id in entrant_hive_ids:
		_set_hive_tournament_entry_fields(entrant_hive_id, tournament_id, {
			"bracket_id": bracket_id,
			"bracket_status": HIVE_TOURNAMENT_BRACKET_STATUS_ACTIVE,
			"format_id": str(bracket.get("format_id", HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H)),
			"field_size": field_size,
			"rounds_total": rounds_total,
			"current_round_number": 1
		})
	var matches: Dictionary = bracket.get("matches", {}) as Dictionary
	for match_any in matches.values():
		var match_record: Dictionary = match_any as Dictionary
		if int(match_record.get("round_number", 0)) != 1:
			continue
		bracket = _activate_bracket_match_round(bracket, str(match_record.get("match_key", "")), str(match_record.get("hive_a_id", "")), str(match_record.get("hive_b_id", "")))
	_hive_tournament_brackets_by_id[bracket_id] = bracket
	_sync_hive_entries_for_bracket(bracket)
	return bracket

func _build_single_elimination_match_map(entrant_hive_ids: Array[String]) -> Dictionary:
	var matches: Dictionary = {}
	var field_size: int = entrant_hive_ids.size()
	var rounds_total: int = _single_elimination_rounds_total(field_size)
	var opening_match_count: int = int(field_size / 2)
	for match_index in range(opening_match_count):
		var match_number: int = match_index + 1
		var match_key: String = _hive_tournament_match_key(1, match_number)
		matches[match_key] = {
			"match_key": match_key,
			"round_number": 1,
			"match_number": match_number,
			"status": HIVE_TOURNAMENT_STATUS_QUEUED,
			"round_id": "",
			"hive_a_id": entrant_hive_ids[match_index],
			"hive_b_id": entrant_hive_ids[field_size - 1 - match_index],
			"winner_hive_id": "",
			"loser_hive_id": "",
			"source_match_keys": [],
			"next_match_key": _hive_tournament_match_key(2, int(match_index / 2) + 1) if rounds_total > 1 else ""
		}
	for round_number in range(2, rounds_total + 1):
		var match_count: int = int(field_size / int(pow(2.0, round_number)))
		for match_number in range(1, match_count + 1):
			var source_a_key: String = _hive_tournament_match_key(round_number - 1, ((match_number - 1) * 2) + 1)
			var source_b_key: String = _hive_tournament_match_key(round_number - 1, ((match_number - 1) * 2) + 2)
			var match_key: String = _hive_tournament_match_key(round_number, match_number)
			matches[match_key] = {
				"match_key": match_key,
				"round_number": round_number,
				"match_number": match_number,
				"status": HIVE_TOURNAMENT_STATUS_QUEUED,
				"round_id": "",
				"hive_a_id": "",
				"hive_b_id": "",
				"winner_hive_id": "",
				"loser_hive_id": "",
				"source_match_keys": [source_a_key, source_b_key],
				"next_match_key": _hive_tournament_match_key(round_number + 1, int((match_number - 1) / 2) + 1) if round_number < rounds_total else ""
			}
	return matches

func _hive_tournament_match_key(round_number: int, match_number: int) -> String:
	return "%d:%d" % [maxi(1, round_number), maxi(1, match_number)]

func _single_elimination_rounds_total(field_size: int) -> int:
	var rounds_total: int = 0
	var remaining: int = maxi(2, field_size)
	while remaining > 1:
		rounds_total += 1
		remaining = int(remaining / 2)
	return maxi(1, rounds_total)

func _activate_bracket_match_round(bracket: Dictionary, match_key: String, hive_a_id: String, hive_b_id: String) -> Dictionary:
	var matches: Dictionary = bracket.get("matches", {}) as Dictionary
	var match_record: Dictionary = matches.get(match_key, {}) as Dictionary
	if match_record.is_empty():
		return bracket
	var round_number: int = int(match_record.get("round_number", 1))
	var match_number: int = int(match_record.get("match_number", 1))
	var round: Dictionary = _create_hive_tournament_round(
		hive_a_id,
		hive_b_id,
		str(bracket.get("tournament_id", "")),
		{
			"title": str(bracket.get("title", "Hive Tournament")),
			"format_id": str(bracket.get("format_id", HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H)),
			"bracket_id": str(bracket.get("bracket_id", "")),
			"bracket_round_number": round_number,
			"bracket_match_number": match_number
		}
	)
	if round.is_empty():
		return bracket
	match_record["status"] = HIVE_TOURNAMENT_STATUS_ACTIVE
	match_record["round_id"] = str(round.get("round_id", ""))
	match_record["hive_a_id"] = hive_a_id
	match_record["hive_b_id"] = hive_b_id
	matches[match_key] = match_record
	bracket["matches"] = matches
	bracket["current_round_number"] = maxi(int(bracket.get("current_round_number", 1)), round_number)
	_hive_tournament_brackets_by_id[str(bracket.get("bracket_id", ""))] = bracket
	_emit_hive_tournament_round_started(round)
	return bracket

func _create_hive_tournament_round(hive_a_id: String, hive_b_id: String, tournament_id: String, context: Dictionary = {}) -> Dictionary:
	var hive_a: Dictionary = _hives_by_id.get(hive_a_id, {}) as Dictionary
	var hive_b: Dictionary = _hives_by_id.get(hive_b_id, {}) as Dictionary
	if hive_a.is_empty() or hive_b.is_empty():
		return {}
	var now_unix: int = _now_unix()
	var round_id: String = _next_id(TOURNAMENT_ROUND_ID_PREFIX)
	var title: String = str(context.get("title", _hive_tournament_entry_for_id(tournament_id).get("title", "Hive Tournament")))
	var round: Dictionary = {
		"round_id": round_id,
		"tournament_id": tournament_id,
		"title": title,
		"status": HIVE_TOURNAMENT_STATUS_ACTIVE,
		"format_id": str(context.get("format_id", HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H)).strip_edges().to_lower(),
		"bracket_id": str(context.get("bracket_id", "")).strip_edges(),
		"bracket_round_number": maxi(0, int(context.get("bracket_round_number", 0))),
		"bracket_match_number": maxi(0, int(context.get("bracket_match_number", 0))),
		"roster_size": HIVE_TOURNAMENT_ROSTER_SIZE,
		"map_paths": HIVE_TOURNAMENT_STAGE_MAP_PATHS.duplicate(),
		"started_at_unix": now_unix,
		"replace_deadline_unix": now_unix + HIVE_TOURNAMENT_LOGIN_REPLACE_SEC,
		"deadline_unix": now_unix + HIVE_TOURNAMENT_ROUND_WINDOW_SEC,
		"resolved_at_unix": 0,
		"hive_a_id": hive_a_id,
		"hive_b_id": hive_b_id,
		"hive_a_name": str(hive_a.get("name", "")),
		"hive_b_name": str(hive_b.get("name", "")),
		"hive_a_slots": _build_hive_tournament_slots(hive_a, now_unix),
		"hive_b_slots": _build_hive_tournament_slots(hive_b, now_unix),
		"winner_hive_id": "",
		"loser_hive_id": "",
		"resolution_reason": "",
		"forfeited_hive_id": "",
		"team_a_slot_wins": 0,
		"team_b_slot_wins": 0,
		"team_a_total_time_ms": 0,
		"team_b_total_time_ms": 0
	}
	_hive_tournament_rounds_by_id[round_id] = round
	return round

func _emit_hive_tournament_round_started(round: Dictionary) -> void:
	if round.is_empty():
		return
	for side_prefix in ["hive_a", "hive_b"]:
		_emit_event({
			"type": "hive_tournament_round_started",
			"hive_id": str(round.get("%s_id" % side_prefix, "")),
			"title": str(round.get("title", "Hive Tournament")),
			"tournament_id": str(round.get("tournament_id", "")),
			"round_id": str(round.get("round_id", "")),
			"bracket_id": str(round.get("bracket_id", "")),
			"bracket_round_number": int(round.get("bracket_round_number", 0)),
			"opponent_hive_name": str(round.get("hive_b_name", "")) if side_prefix == "hive_a" else str(round.get("hive_a_name", "")),
			"deadline_unix": int(round.get("deadline_unix", 0))
		})

func _build_hive_tournament_slots(hive: Dictionary, started_at_unix: int) -> Array:
	var ordered_members: Array = _sorted_hive_tournament_members(hive)
	var slots: Array = []
	for i in range(mini(HIVE_TOURNAMENT_ROSTER_SIZE, ordered_members.size())):
		var member: Dictionary = ordered_members[i] as Dictionary
		var last_seen_at_unix: int = int(member.get("last_seen_at_unix", 0))
		slots.append({
			"slot_index": i,
			"seed_rank": i + 1,
			"player_id": str(member.get("player_id", "")),
			"display_name": str(member.get("display_name", "")),
			"assigned_at_unix": started_at_unix,
			"checked_in_at_unix": last_seen_at_unix if last_seen_at_unix >= started_at_unix else 0,
			"submitted_at_unix": 0,
			"total_time_ms": 0,
			"status": "assigned",
			"round_results": [],
			"previous_player_ids": [str(member.get("player_id", ""))],
			"replaced_player_id": "",
			"replacement_seed_rank": 0,
			"replaced_at_unix": 0
		})
	return slots

func _sorted_hive_tournament_members(hive: Dictionary) -> Array:
	var out: Array = []
	var members: Dictionary = hive.get("members", {}) as Dictionary
	for member_any in members.values():
		var member: Dictionary = member_any as Dictionary
		var player_id: String = str(member.get("player_id", ""))
		if player_id.is_empty():
			continue
		var player_snapshot: Dictionary = {}
		var rank_state: Node = _rank_state()
		if rank_state != null and rank_state.has_method("get_player_snapshot"):
			player_snapshot = rank_state.call("get_player_snapshot", player_id) as Dictionary
		out.append({
			"player_id": player_id,
			"display_name": str(member.get("display_name", "")),
			"rank_position": int(player_snapshot.get("rank_position", 0)),
			"honey_contributed": int(member.get("honey_contributed", 0)),
			"last_seen_at_unix": int(member.get("last_seen_at_unix", int(member.get("joined_at_unix", 0))))
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rank_a: int = int(a.get("rank_position", 0))
		var rank_b: int = int(b.get("rank_position", 0))
		if rank_a > 0 and rank_b > 0 and rank_a != rank_b:
			return rank_a < rank_b
		if rank_a > 0 and rank_b <= 0:
			return true
		if rank_b > 0 and rank_a <= 0:
			return false
		var honey_a: int = int(a.get("honey_contributed", 0))
		var honey_b: int = int(b.get("honey_contributed", 0))
		if honey_a != honey_b:
			return honey_a > honey_b
		return str(a.get("display_name", "")) < str(b.get("display_name", ""))
	)
	return out

func _set_hive_tournament_entry_fields(hive_id: String, tournament_id: String, fields: Dictionary) -> void:
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return
	var tournament_entries: Dictionary = hive.get("tournament_entries", {}) as Dictionary
	var entry: Dictionary = tournament_entries.get(tournament_id, {}) as Dictionary
	if entry.is_empty():
		return
	for key_any in fields.keys():
		var key: String = str(key_any)
		entry[key] = fields.get(key_any)
	tournament_entries[tournament_id] = entry
	hive["tournament_entries"] = tournament_entries
	_hives_by_id[hive_id] = hive

func _remove_hive_from_tournament_queue(tournament_id: String, hive_id: String) -> void:
	var queue_any: Variant = _hive_tournament_queue_by_tournament_id.get(tournament_id, [])
	if typeof(queue_any) != TYPE_ARRAY:
		return
	var queue_out: Array[String] = []
	for hive_id_any in queue_any as Array:
		var queued_hive_id: String = str(hive_id_any).strip_edges()
		if queued_hive_id.is_empty() or queued_hive_id == hive_id or queue_out.has(queued_hive_id):
			continue
		queue_out.append(queued_hive_id)
	_hive_tournament_queue_by_tournament_id[tournament_id] = queue_out

func _hive_has_active_tournament_round(hive_id: String) -> bool:
	for round_any in _hive_tournament_rounds_by_id.values():
		var round: Dictionary = round_any as Dictionary
		if str(round.get("status", "")) != HIVE_TOURNAMENT_STATUS_ACTIVE:
			continue
		if str(round.get("hive_a_id", "")) == hive_id or str(round.get("hive_b_id", "")) == hive_id:
			return true
	return false

func _hive_has_open_tournament_commitment(hive_id: String) -> bool:
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return false
	var tournament_entries: Dictionary = hive.get("tournament_entries", {}) as Dictionary
	for entry_any in tournament_entries.values():
		var entry: Dictionary = entry_any as Dictionary
		var queue_status: String = str(entry.get("queue_status", "")).strip_edges().to_lower()
		if queue_status == HIVE_TOURNAMENT_STATUS_QUEUED or queue_status == HIVE_TOURNAMENT_STATUS_ACTIVE:
			return true
	return false

func _find_active_round_for_hive_in_bracket(bracket_id: String, hive_id: String) -> Dictionary:
	var clean_bracket_id: String = str(bracket_id).strip_edges()
	var clean_hive_id: String = str(hive_id).strip_edges()
	if clean_bracket_id.is_empty() or clean_hive_id.is_empty():
		return {}
	for round_any in _hive_tournament_rounds_by_id.values():
		var round: Dictionary = round_any as Dictionary
		if str(round.get("status", "")) != HIVE_TOURNAMENT_STATUS_ACTIVE:
			continue
		if str(round.get("bracket_id", "")) != clean_bracket_id:
			continue
		if str(round.get("hive_a_id", "")) == clean_hive_id or str(round.get("hive_b_id", "")) == clean_hive_id:
			return round
	return {}

func _find_player_assignment_in_round(round: Dictionary, player_id: String) -> Dictionary:
	var clean_player_id: String = _sanitize_player_id(player_id)
	if clean_player_id.is_empty():
		return {}
	for side_key in ["hive_a_slots", "hive_b_slots"]:
		var slots: Array = round.get(side_key, []) as Array
		for i in range(slots.size()):
			var slot: Dictionary = slots[i] as Dictionary
			if str(slot.get("player_id", "")) != clean_player_id:
				continue
			var opponent_side_key: String = "hive_b_slots" if side_key == "hive_a_slots" else "hive_a_slots"
			var opponent_slots: Array = round.get(opponent_side_key, []) as Array
			var opponent_slot: Dictionary = opponent_slots[i] as Dictionary if i < opponent_slots.size() else {}
			var hive_prefix: String = "hive_a" if side_key == "hive_a_slots" else "hive_b"
			var opponent_prefix: String = "hive_b" if hive_prefix == "hive_a" else "hive_a"
			return {
				"round_id": str(round.get("round_id", "")),
				"tournament_id": str(round.get("tournament_id", "")),
				"title": str(round.get("title", "Hive Tournament")),
				"format_id": str(round.get("format_id", HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H)),
				"bracket_id": str(round.get("bracket_id", "")),
				"bracket_round_number": int(round.get("bracket_round_number", 0)),
				"bracket_match_number": int(round.get("bracket_match_number", 0)),
				"hive_id": str(round.get("%s_id" % hive_prefix, "")),
				"hive_name": str(round.get("%s_name" % hive_prefix, "")),
				"opponent_hive_id": str(round.get("%s_id" % opponent_prefix, "")),
				"opponent_hive_name": str(round.get("%s_name" % opponent_prefix, "")),
				"started_at_unix": int(round.get("started_at_unix", 0)),
				"replace_deadline_unix": int(round.get("replace_deadline_unix", 0)),
				"deadline_unix": int(round.get("deadline_unix", 0)),
				"map_paths": (round.get("map_paths", []) as Array).duplicate(true),
				"slot_index": i,
				"slot_status": str(slot.get("status", "assigned")),
				"player_id": clean_player_id,
				"display_name": str(slot.get("display_name", "")),
				"checked_in_at_unix": int(slot.get("checked_in_at_unix", 0)),
				"submitted_at_unix": int(slot.get("submitted_at_unix", 0)),
				"total_time_ms": int(slot.get("total_time_ms", 0)),
				"opponent_player_id": str(opponent_slot.get("player_id", "")),
				"opponent_display_name": str(opponent_slot.get("display_name", "")),
				"side_key": side_key,
				"opponent_side_key": opponent_side_key
			}
	return {}

func _round_is_ready_to_resolve(round: Dictionary) -> bool:
	for side_key in ["hive_a_slots", "hive_b_slots"]:
		var slots: Array = round.get(side_key, []) as Array
		if slots.size() < int(round.get("roster_size", HIVE_TOURNAMENT_ROSTER_SIZE)):
			return false
		for slot_any in slots:
			if typeof(slot_any) != TYPE_DICTIONARY:
				return false
			var slot: Dictionary = slot_any as Dictionary
			if str(slot.get("status", "")) != "submitted":
				return false
	return true

func _sync_hive_tournament_round_checkins(round: Dictionary) -> bool:
	var changed: bool = false
	var started_at_unix: int = int(round.get("started_at_unix", 0))
	for side_key in ["hive_a_slots", "hive_b_slots"]:
		var hive_id_key: String = "hive_a_id" if side_key == "hive_a_slots" else "hive_b_id"
		var hive: Dictionary = _hives_by_id.get(str(round.get(hive_id_key, "")), {}) as Dictionary
		if hive.is_empty():
			continue
		var slots: Array = (round.get(side_key, []) as Array).duplicate(true)
		for i in range(slots.size()):
			var slot: Dictionary = slots[i] as Dictionary
			if int(slot.get("checked_in_at_unix", 0)) > 0:
				continue
			var last_seen_at_unix: int = _member_last_seen_at_unix(hive, str(slot.get("player_id", "")))
			if last_seen_at_unix < started_at_unix:
				continue
			slot["checked_in_at_unix"] = last_seen_at_unix
			slots[i] = slot
			changed = true
		round[side_key] = slots
	return changed

func _apply_hive_tournament_replacements(round: Dictionary, now_unix: int) -> Dictionary:
	for side_key in ["hive_a_slots", "hive_b_slots"]:
		var hive_id_key: String = "hive_a_id" if side_key == "hive_a_slots" else "hive_b_id"
		var hive_id: String = str(round.get(hive_id_key, ""))
		var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
		if hive.is_empty():
			return {"round": round, "forfeited_hive_id": hive_id}
		var slots: Array = (round.get(side_key, []) as Array).duplicate(true)
		for i in range(slots.size()):
			var slot: Dictionary = slots[i] as Dictionary
			if str(slot.get("status", "")) == "submitted" or int(slot.get("checked_in_at_unix", 0)) > 0:
				continue
			var replacement: Dictionary = _find_hive_tournament_replacement(hive, round, side_key, i)
			if replacement.is_empty():
				return {"round": round, "forfeited_hive_id": hive_id}
			var previous_any: Variant = slot.get("previous_player_ids", [])
			var previous_ids: Array = previous_any.duplicate(true) if typeof(previous_any) == TYPE_ARRAY else []
			var old_player_id: String = str(slot.get("player_id", ""))
			if not old_player_id.is_empty() and not previous_ids.has(old_player_id):
				previous_ids.append(old_player_id)
			slot["replaced_player_id"] = old_player_id
			slot["replaced_at_unix"] = now_unix
			slot["replacement_seed_rank"] = int(replacement.get("seed_rank", 0))
			slot["player_id"] = str(replacement.get("player_id", ""))
			slot["display_name"] = str(replacement.get("display_name", ""))
			slot["assigned_at_unix"] = now_unix
			slot["checked_in_at_unix"] = int(replacement.get("checked_in_at_unix", 0))
			slot["submitted_at_unix"] = 0
			slot["total_time_ms"] = 0
			slot["status"] = "assigned"
			slot["round_results"] = []
			if not previous_ids.has(str(replacement.get("player_id", ""))):
				previous_ids.append(str(replacement.get("player_id", "")))
			slot["previous_player_ids"] = previous_ids
			slots[i] = slot
		round[side_key] = slots
	return {"round": round, "forfeited_hive_id": ""}

func _find_hive_tournament_replacement(hive: Dictionary, round: Dictionary, side_key: String, slot_index: int) -> Dictionary:
	var ordered_members: Array = _sorted_hive_tournament_members(hive)
	var taken_player_ids: Array[String] = _round_assigned_player_ids(round, side_key)
	var slots: Array = round.get(side_key, []) as Array
	var slot: Dictionary = slots[slot_index] as Dictionary if slot_index >= 0 and slot_index < slots.size() else {}
	var previous_any: Variant = slot.get("previous_player_ids", [])
	var previous_ids: Array = previous_any.duplicate(true) if typeof(previous_any) == TYPE_ARRAY else []
	var started_at_unix: int = int(round.get("started_at_unix", 0))
	for i in range(ordered_members.size()):
		var member: Dictionary = ordered_members[i] as Dictionary
		var player_id: String = str(member.get("player_id", ""))
		if player_id.is_empty() or taken_player_ids.has(player_id) or previous_ids.has(player_id):
			continue
		return {
			"player_id": player_id,
			"display_name": str(member.get("display_name", "")),
			"seed_rank": i + 1,
			"checked_in_at_unix": int(member.get("last_seen_at_unix", 0)) if int(member.get("last_seen_at_unix", 0)) >= started_at_unix else 0
		}
	return {}

func _round_assigned_player_ids(round: Dictionary, side_key: String = "") -> Array[String]:
	var out: Array[String] = []
	var side_keys: Array[String] = [side_key] if not side_key.is_empty() else ["hive_a_slots", "hive_b_slots"]
	for current_side_key in side_keys:
		var slots: Array = round.get(current_side_key, []) as Array
		for slot_any in slots:
			if typeof(slot_any) != TYPE_DICTIONARY:
				continue
			var player_id: String = _sanitize_player_id(str((slot_any as Dictionary).get("player_id", "")))
			if player_id.is_empty() or out.has(player_id):
				continue
			out.append(player_id)
	return out

func _member_last_seen_at_unix(hive: Dictionary, player_id: String) -> int:
	var member: Dictionary = _member_for_player(hive, player_id)
	if member.is_empty():
		return 0
	return int(member.get("last_seen_at_unix", int(member.get("joined_at_unix", 0))))

func _process_hive_tournament_rounds() -> void:
	if _hive_tournament_rounds_by_id.is_empty():
		return
	var now_unix: int = _now_unix()
	var changed: bool = false
	for round_id_any in _hive_tournament_rounds_by_id.keys():
		var round_id: String = str(round_id_any)
		var round: Dictionary = _hive_tournament_rounds_by_id.get(round_id, {}) as Dictionary
		if round.is_empty() or str(round.get("status", "")) != HIVE_TOURNAMENT_STATUS_ACTIVE:
			continue
		if _sync_hive_tournament_round_checkins(round):
			_hive_tournament_rounds_by_id[round_id] = round
			changed = true
		if _round_is_ready_to_resolve(round):
			_resolve_hive_tournament_round(round_id, "all_submissions_in")
			continue
		if now_unix >= int(round.get("replace_deadline_unix", 0)):
			var replacement_result: Dictionary = _apply_hive_tournament_replacements(round, now_unix)
			round = replacement_result.get("round", round) as Dictionary
			_hive_tournament_rounds_by_id[round_id] = round
			changed = true
			var forfeited_hive_id: String = str(replacement_result.get("forfeited_hive_id", ""))
			if not forfeited_hive_id.is_empty():
				_resolve_hive_tournament_round(round_id, "replacement_forfeit", forfeited_hive_id)
				continue
		if _round_is_ready_to_resolve(round):
			_resolve_hive_tournament_round(round_id, "all_submissions_in")
			continue
		if now_unix >= int(round.get("deadline_unix", 0)):
			_resolve_hive_tournament_round(round_id, "deadline")
	if changed:
		_save_state()

func _resolve_hive_tournament_round(round_id: String, resolution_reason: String, forfeited_hive_id: String = "") -> Dictionary:
	var round: Dictionary = _hive_tournament_rounds_by_id.get(round_id, {}) as Dictionary
	if round.is_empty():
		return {}
	if str(round.get("status", "")) != HIVE_TOURNAMENT_STATUS_ACTIVE:
		return round
	round = _resolve_hive_tournament_round_scores(round, resolution_reason, forfeited_hive_id)
	_hive_tournament_rounds_by_id[round_id] = round
	var hive_a_id: String = str(round.get("hive_a_id", ""))
	var hive_b_id: String = str(round.get("hive_b_id", ""))
	_record_hive_tournament_entry_result(round, hive_a_id)
	_record_hive_tournament_entry_result(round, hive_b_id)
	var bracket_id: String = str(round.get("bracket_id", "")).strip_edges()
	if bracket_id.is_empty():
		_finalize_hive_tournament_entry_from_round(round, hive_a_id)
		_finalize_hive_tournament_entry_from_round(round, hive_b_id)
		if not str(round.get("winner_hive_id", "")).is_empty():
			_award_hive_tournament_bracket_winner({}, round)
	else:
		_advance_hive_tournament_bracket(round)
	_save_state()
	for hive_id in [hive_a_id, hive_b_id]:
		if hive_id.is_empty():
			continue
		_emit_event({
			"type": "hive_tournament_round_resolved",
			"hive_id": hive_id,
			"tournament_id": str(round.get("tournament_id", "")),
			"round_id": round_id,
			"title": str(round.get("title", "Hive Tournament")),
			"bracket_id": bracket_id,
			"bracket_round_number": int(round.get("bracket_round_number", 0)),
			"winner_hive_id": str(round.get("winner_hive_id", "")),
			"loser_hive_id": str(round.get("loser_hive_id", "")),
			"forfeited_hive_id": forfeited_hive_id,
			"resolution_reason": resolution_reason
		})
	return round

func _resolve_hive_tournament_round_scores(round: Dictionary, resolution_reason: String, forfeited_hive_id: String = "") -> Dictionary:
	var hive_a_id: String = str(round.get("hive_a_id", ""))
	var hive_b_id: String = str(round.get("hive_b_id", ""))
	var winner_hive_id: String = ""
	var loser_hive_id: String = ""
	var team_a_slot_wins: int = 0
	var team_b_slot_wins: int = 0
	var team_a_total_time_ms: int = 0
	var team_b_total_time_ms: int = 0
	if not forfeited_hive_id.is_empty():
		winner_hive_id = hive_b_id if forfeited_hive_id == hive_a_id else hive_a_id
		loser_hive_id = forfeited_hive_id
	else:
		var hive_a_slots: Array = round.get("hive_a_slots", []) as Array
		var hive_b_slots: Array = round.get("hive_b_slots", []) as Array
		var roster_size: int = mini(hive_a_slots.size(), hive_b_slots.size())
		for i in range(roster_size):
			var hive_a_slot: Dictionary = hive_a_slots[i] as Dictionary
			var hive_b_slot: Dictionary = hive_b_slots[i] as Dictionary
			var hive_a_submitted: bool = str(hive_a_slot.get("status", "")) == "submitted"
			var hive_b_submitted: bool = str(hive_b_slot.get("status", "")) == "submitted"
			var hive_a_time_ms: int = int(hive_a_slot.get("total_time_ms", 0)) if hive_a_submitted else HIVE_TOURNAMENT_DNF_TIME_MS
			var hive_b_time_ms: int = int(hive_b_slot.get("total_time_ms", 0)) if hive_b_submitted else HIVE_TOURNAMENT_DNF_TIME_MS
			team_a_total_time_ms += hive_a_time_ms
			team_b_total_time_ms += hive_b_time_ms
			if hive_a_submitted and not hive_b_submitted:
				team_a_slot_wins += 1
				continue
			if hive_b_submitted and not hive_a_submitted:
				team_b_slot_wins += 1
				continue
			if hive_a_submitted and hive_b_submitted:
				if hive_a_time_ms < hive_b_time_ms:
					team_a_slot_wins += 1
				elif hive_b_time_ms < hive_a_time_ms:
					team_b_slot_wins += 1
		if team_a_slot_wins > team_b_slot_wins:
			winner_hive_id = hive_a_id
			loser_hive_id = hive_b_id
		elif team_b_slot_wins > team_a_slot_wins:
			winner_hive_id = hive_b_id
			loser_hive_id = hive_a_id
		elif team_a_total_time_ms < team_b_total_time_ms:
			winner_hive_id = hive_a_id
			loser_hive_id = hive_b_id
		elif team_b_total_time_ms < team_a_total_time_ms:
			winner_hive_id = hive_b_id
			loser_hive_id = hive_a_id
	round["status"] = HIVE_TOURNAMENT_STATUS_FORFEIT if not forfeited_hive_id.is_empty() else HIVE_TOURNAMENT_STATUS_RESOLVED
	round["resolved_at_unix"] = _now_unix()
	round["winner_hive_id"] = winner_hive_id
	round["loser_hive_id"] = loser_hive_id
	round["resolution_reason"] = resolution_reason
	round["forfeited_hive_id"] = forfeited_hive_id
	round["team_a_slot_wins"] = team_a_slot_wins
	round["team_b_slot_wins"] = team_b_slot_wins
	round["team_a_total_time_ms"] = team_a_total_time_ms
	round["team_b_total_time_ms"] = team_b_total_time_ms
	return round

func _advance_hive_tournament_bracket(resolved_round: Dictionary) -> void:
	var bracket_id: String = str(resolved_round.get("bracket_id", "")).strip_edges()
	if bracket_id.is_empty():
		return
	var bracket: Dictionary = _hive_tournament_brackets_by_id.get(bracket_id, {}) as Dictionary
	if bracket.is_empty():
		return
	var matches: Dictionary = bracket.get("matches", {}) as Dictionary
	var match_key: String = _hive_tournament_match_key(int(resolved_round.get("bracket_round_number", 0)), int(resolved_round.get("bracket_match_number", 0)))
	var match_record: Dictionary = matches.get(match_key, {}) as Dictionary
	if not match_record.is_empty():
		match_record["status"] = HIVE_TOURNAMENT_STATUS_RESOLVED
		match_record["round_id"] = str(resolved_round.get("round_id", ""))
		match_record["hive_a_id"] = str(resolved_round.get("hive_a_id", ""))
		match_record["hive_b_id"] = str(resolved_round.get("hive_b_id", ""))
		match_record["winner_hive_id"] = str(resolved_round.get("winner_hive_id", ""))
		match_record["loser_hive_id"] = str(resolved_round.get("loser_hive_id", ""))
		matches[match_key] = match_record
	var next_match_key: String = str(match_record.get("next_match_key", "")).strip_edges()
	if next_match_key.is_empty():
		bracket["status"] = HIVE_TOURNAMENT_BRACKET_STATUS_RESOLVED
		bracket["resolved_at_unix"] = int(resolved_round.get("resolved_at_unix", _now_unix()))
		bracket["winner_hive_id"] = str(resolved_round.get("winner_hive_id", ""))
		bracket["current_round_number"] = int(resolved_round.get("bracket_round_number", int(bracket.get("rounds_total", 1))))
		bracket["matches"] = matches
		_hive_tournament_brackets_by_id[bracket_id] = bracket
		_sync_hive_entries_for_bracket(bracket)
		_finalize_hive_tournament_entry_from_round(resolved_round, str(resolved_round.get("hive_a_id", "")))
		_finalize_hive_tournament_entry_from_round(resolved_round, str(resolved_round.get("hive_b_id", "")))
		_award_hive_tournament_bracket_winner(bracket, resolved_round)
		return
	if matches.has(next_match_key):
		var next_match: Dictionary = matches.get(next_match_key, {}) as Dictionary
		var source_keys: Array = next_match.get("source_match_keys", []) as Array
		if source_keys.size() >= 2:
			var source_a: Dictionary = matches.get(str(source_keys[0]), {}) as Dictionary
			var source_b: Dictionary = matches.get(str(source_keys[1]), {}) as Dictionary
			if not str(source_a.get("winner_hive_id", "")).is_empty() and not str(source_b.get("winner_hive_id", "")).is_empty() and str(next_match.get("round_id", "")).is_empty():
				bracket["matches"] = matches
				bracket = _activate_bracket_match_round(bracket, next_match_key, str(source_a.get("winner_hive_id", "")), str(source_b.get("winner_hive_id", "")))
				matches = bracket.get("matches", {}) as Dictionary
		bracket["current_round_number"] = int((matches.get(next_match_key, {}) as Dictionary).get("round_number", int(bracket.get("current_round_number", 1))))
	bracket["matches"] = matches
	_hive_tournament_brackets_by_id[bracket_id] = bracket
	_sync_hive_entries_for_bracket(bracket)

func _sync_hive_entries_for_bracket(bracket: Dictionary) -> void:
	var bracket_id: String = str(bracket.get("bracket_id", "")).strip_edges()
	var tournament_id: String = str(bracket.get("tournament_id", "")).strip_edges()
	if bracket_id.is_empty() or tournament_id.is_empty():
		return
	var entrants: Array = bracket.get("entrant_hive_ids", []) as Array
	for entrant_any in entrants:
		var hive_id: String = str(entrant_any).strip_edges()
		if hive_id.is_empty():
			continue
		var active_round: Dictionary = _find_active_round_for_hive_in_bracket(bracket_id, hive_id)
		var eliminated: bool = _is_hive_eliminated_from_bracket(bracket, hive_id)
		var fields: Dictionary = {
			"bracket_id": bracket_id,
			"bracket_status": str(bracket.get("status", HIVE_TOURNAMENT_BRACKET_STATUS_ACTIVE)),
			"format_id": str(bracket.get("format_id", HIVE_TOURNAMENT_FORMAT_SINGLE_ELIMINATION_H2H)),
			"field_size": int(bracket.get("field_size", 2)),
			"rounds_total": int(bracket.get("rounds_total", 1)),
			"current_round_number": int(bracket.get("current_round_number", 1)),
			"round_id": "",
			"round_started_at_unix": 0,
			"round_deadline_unix": 0,
			"replace_deadline_unix": 0,
			"opponent_hive_id": ""
		}
		if not active_round.is_empty():
			fields["queue_status"] = HIVE_TOURNAMENT_STATUS_ACTIVE
			fields["current_round_number"] = int(active_round.get("bracket_round_number", int(bracket.get("current_round_number", 1))))
			fields["round_id"] = str(active_round.get("round_id", ""))
			fields["round_started_at_unix"] = int(active_round.get("started_at_unix", 0))
			fields["round_deadline_unix"] = int(active_round.get("deadline_unix", 0))
			fields["replace_deadline_unix"] = int(active_round.get("replace_deadline_unix", 0))
			fields["opponent_hive_id"] = str(active_round.get("hive_b_id", "")) if str(active_round.get("hive_a_id", "")) == hive_id else str(active_round.get("hive_a_id", ""))
		elif str(bracket.get("status", "")) == HIVE_TOURNAMENT_BRACKET_STATUS_RESOLVED or eliminated:
			fields["queue_status"] = HIVE_TOURNAMENT_STATUS_RESOLVED
		else:
			fields["queue_status"] = HIVE_TOURNAMENT_STATUS_ACTIVE
		_set_hive_tournament_entry_fields(hive_id, tournament_id, fields)

func _is_hive_eliminated_from_bracket(bracket: Dictionary, hive_id: String) -> bool:
	var matches: Dictionary = bracket.get("matches", {}) as Dictionary
	for match_any in matches.values():
		var match_record: Dictionary = match_any as Dictionary
		if str(match_record.get("loser_hive_id", "")) == hive_id:
			return true
	return false

func _award_hive_tournament_bracket_winner(bracket: Dictionary, resolved_round: Dictionary) -> void:
	var winner_hive_id: String = str(resolved_round.get("winner_hive_id", "")).strip_edges()
	if winner_hive_id.is_empty():
		return
	var winner_hive: Dictionary = _hives_by_id.get(winner_hive_id, {}) as Dictionary
	if winner_hive.is_empty():
		return
	winner_hive["tournament_wins"] = int(winner_hive.get("tournament_wins", 0)) + 1
	if str(resolved_round.get("tournament_id", "")) == "seasonal_royal_gauntlet":
		winner_hive["hive_championships"] = int(winner_hive.get("hive_championships", 0)) + 1
		winner_hive["seasonal_best_finish"] = 1
	winner_hive = _grant_hive_awards_for_tournament_victory(winner_hive, bracket, resolved_round)
	var competitive_wax_result: Dictionary = _publish_hive_tournament_wax_result(winner_hive, bracket, resolved_round)
	if not competitive_wax_result.is_empty():
		winner_hive["last_tournament_wax_result"] = competitive_wax_result
	_hives_by_id[winner_hive_id] = winner_hive
	if not bracket.is_empty():
		_emit_event({
			"type": "hive_tournament_bracket_won",
			"hive_id": winner_hive_id,
			"tournament_id": str(resolved_round.get("tournament_id", "")),
			"title": str(resolved_round.get("title", "Hive Tournament")),
			"bracket_id": str(bracket.get("bracket_id", "")),
			"winner_hive_id": winner_hive_id,
			"competitive_wax_result": competitive_wax_result
		})

func _publish_hive_tournament_wax_result(winner_hive: Dictionary, bracket: Dictionary, resolved_round: Dictionary) -> Dictionary:
	var crucible_state: Node = get_node_or_null("/root/CrucibleState")
	if crucible_state == null or not crucible_state.has_method("intent_apply_competitive_wax_result"):
		return {"ok": false, "err": "crucible_state_unavailable"}
	var tournament_id: String = str(resolved_round.get("tournament_id", "")).strip_edges().to_lower()
	var winner_hive_id: String = str(winner_hive.get("hive_id", resolved_round.get("winner_hive_id", ""))).strip_edges()
	var representative_player_id: String = _hive_tournament_wax_representative_player_id(winner_hive)
	if tournament_id.is_empty() or winner_hive_id.is_empty() or representative_player_id.is_empty():
		return {"ok": false, "err": "missing_hive_tournament_wax_fields"}
	var bracket_id: String = str(bracket.get("bracket_id", resolved_round.get("bracket_id", ""))).strip_edges()
	var round_id: String = str(resolved_round.get("round_id", "")).strip_edges()
	var match_key: String = bracket_id if not bracket_id.is_empty() else round_id
	if match_key.is_empty():
		match_key = "%s:%s" % [tournament_id, winner_hive_id]
	var field_size: int = _hive_tournament_wax_field_size(tournament_id, bracket, resolved_round)
	var metadata: Dictionary = {
		"event_id": "competitive_wax:hive_tournament:%s:%s:%s" % [tournament_id, winner_hive_id, match_key],
		"tournament_scope": _hive_tournament_wax_scope(tournament_id),
		"contest_scope": _hive_tournament_wax_scope(tournament_id),
		"placement": 1,
		"field_size": field_size,
		"participant_count": field_size,
		"hive_tournament": true,
		"hive_id": winner_hive_id,
		"winner_hive_id": winner_hive_id,
		"representative_player_id": representative_player_id,
		"tournament_id": tournament_id,
		"bracket_id": bracket_id,
		"round_id": round_id,
		"bracket_round_number": int(resolved_round.get("bracket_round_number", 0)),
		"team_a_slot_wins": int(resolved_round.get("team_a_slot_wins", 0)),
		"team_b_slot_wins": int(resolved_round.get("team_b_slot_wins", 0)),
		"team_a_total_time_ms": int(resolved_round.get("team_a_total_time_ms", 0)),
		"team_b_total_time_ms": int(resolved_round.get("team_b_total_time_ms", 0)),
		"resolution_reason": str(resolved_round.get("resolution_reason", "")),
		"forfeited_hive_id": str(resolved_round.get("forfeited_hive_id", ""))
	}
	return crucible_state.call(
		"intent_apply_competitive_wax_result",
		"hive_tournament:%s" % match_key,
		representative_player_id,
		"",
		true,
		"TOURNAMENT",
		metadata
	) as Dictionary

func _hive_tournament_wax_representative_player_id(hive: Dictionary) -> String:
	var members: Dictionary = hive.get("members", {}) as Dictionary
	for member_any in members.values():
		if typeof(member_any) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = member_any as Dictionary
		if str(member.get("role", "")).strip_edges().to_lower() == ROLE_QUEEN:
			var queen_id: String = _sanitize_player_id(str(member.get("player_id", "")))
			if not queen_id.is_empty():
				return queen_id
	return _sanitize_player_id(str(hive.get("created_by_player_id", "")))

func _hive_tournament_wax_field_size(tournament_id: String, bracket: Dictionary, resolved_round: Dictionary) -> int:
	var field_size: int = int(bracket.get("field_size", resolved_round.get("field_size", 0)))
	if field_size > 0:
		return field_size
	var entry: Dictionary = _hive_tournament_entry_for_id(tournament_id)
	return maxi(2, int(entry.get("field_size", 2)))

func _hive_tournament_wax_scope(tournament_id: String) -> String:
	match tournament_id.strip_edges().to_lower():
		"monthly_hive_cup":
			return "MONTHLY"
		"seasonal_royal_gauntlet":
			return "SEASONAL"
		_:
			return "WEEKLY"

func _finalize_hive_tournament_entry_from_round(round: Dictionary, hive_id: String) -> void:
	var tournament_id: String = str(round.get("tournament_id", ""))
	_record_hive_tournament_entry_result(round, hive_id)
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return
	var tournament_entries: Dictionary = hive.get("tournament_entries", {}) as Dictionary
	var entry: Dictionary = tournament_entries.get(tournament_id, {}) as Dictionary
	if entry.is_empty():
		return
	entry["queue_status"] = str(round.get("status", HIVE_TOURNAMENT_STATUS_RESOLVED))
	entry["round_id"] = str(round.get("round_id", ""))
	tournament_entries[tournament_id] = entry
	hive["tournament_entries"] = tournament_entries
	_hives_by_id[hive_id] = hive

func _record_hive_tournament_entry_result(round: Dictionary, hive_id: String) -> void:
	var tournament_id: String = str(round.get("tournament_id", ""))
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return
	var tournament_entries: Dictionary = hive.get("tournament_entries", {}) as Dictionary
	var entry: Dictionary = tournament_entries.get(tournament_id, {}) as Dictionary
	if entry.is_empty():
		return
	entry["round_id"] = str(round.get("round_id", ""))
	entry["last_result"] = {
		"winner_hive_id": str(round.get("winner_hive_id", "")),
		"loser_hive_id": str(round.get("loser_hive_id", "")),
		"resolution_reason": str(round.get("resolution_reason", "")),
		"team_a_slot_wins": int(round.get("team_a_slot_wins", 0)),
		"team_b_slot_wins": int(round.get("team_b_slot_wins", 0)),
		"team_a_total_time_ms": int(round.get("team_a_total_time_ms", 0)),
		"team_b_total_time_ms": int(round.get("team_b_total_time_ms", 0)),
		"resolved_at_unix": int(round.get("resolved_at_unix", 0)),
		"forfeited_hive_id": str(round.get("forfeited_hive_id", ""))
	}
	tournament_entries[tournament_id] = entry
	hive["tournament_entries"] = tournament_entries
	_hives_by_id[hive_id] = hive

func _compute_hive_rank_points(hive: Dictionary) -> int:
	return int(_build_hive_rank_breakdown(hive).get("total", 0))

func _build_hive_rank_breakdown(hive: Dictionary) -> Dictionary:
	var member_points: int = 0
	var members: Dictionary = hive.get("members", {}) as Dictionary
	for player_id_any in members.keys():
		member_points += _compute_member_rank_points(str(player_id_any))
	var award_records: Array[Dictionary] = _sanitize_hive_award_records(hive.get("award_records", []))
	var multiplier: float = 1.0
	var award_count: int = 0
	for award in award_records:
		if str(award.get("owner_kind", HIVE_AWARD_OWNER_HIVE)) != HIVE_AWARD_OWNER_HIVE:
			continue
		award_count += 1
		multiplier *= 1.0 + (float(int(award.get("rank_multiplier_bps", 0))) / 10000.0)
	var total_points: int = int(round(float(member_points) * multiplier))
	var permanent_bonus: int = maxi(0, total_points - member_points)
	return {
		"members": member_points,
		"permanent_bonus": permanent_bonus,
		"awards": award_count,
		"multiplier": multiplier,
		"multiplier_pct": maxi(0.0, (multiplier - 1.0) * 100.0),
		"total": total_points
	}

func _compute_avg_member_service_days(hive: Dictionary) -> int:
	var members: Dictionary = hive.get("members", {}) as Dictionary
	if members.is_empty():
		return 0
	var now_unix: int = _now_unix()
	var total_days: int = 0
	var count: int = 0
	for member_any in members.values():
		var member: Dictionary = member_any as Dictionary
		var joined_at_unix: int = int(member.get("joined_at_unix", 0))
		if joined_at_unix <= 0:
			continue
		total_days += int(maxi(0, now_unix - joined_at_unix) / 86400)
		count += 1
	if count <= 0:
		return 0
	return int(round(float(total_days) / float(count)))

func _build_honey_earned_milestones(total_honey: int) -> Array[String]:
	var out: Array[String] = []
	for threshold in [100000, 250000, 500000, 1000000]:
		if total_honey >= threshold:
			out.append("%s earned" % _format_honey_threshold(threshold))
	return out

func _build_honey_spent_milestones(total_honey_spent: int) -> Array[String]:
	var out: Array[String] = []
	for threshold in [50000, 100000, 250000, 500000]:
		if total_honey_spent >= threshold:
			out.append("%s spent" % _format_honey_threshold(threshold))
	return out

func _build_trophy_records(hive: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var award_records: Array[Dictionary] = _sanitize_hive_award_records(hive.get("award_records", []))
	award_records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("awarded_at_unix", 0)) > int(b.get("awarded_at_unix", 0))
	)
	for award in award_records:
		var award_title: String = str(award.get("title", "")).strip_edges()
		if award_title == "":
			continue
		var award_type: String = str(award.get("award_type", HIVE_AWARD_TYPE_TROPHY)).strip_edges().to_lower()
		var award_prefix: String = "NFT" if award_type == HIVE_AWARD_TYPE_NFT else "Trophy"
		var award_detail: String = str(award.get("detail", "")).strip_edges()
		var multiplier_bps: int = int(award.get("rank_multiplier_bps", 0))
		if multiplier_bps > 0:
			var bonus_text: String = "+%0.1f%% rank" % (float(multiplier_bps) / 100.0)
			award_detail = bonus_text if award_detail == "" else "%s | %s" % [award_detail, bonus_text]
		out.append({
			"title": "%s: %s" % [award_prefix, award_title],
			"detail": award_detail,
			"kind": "award"
		})
	var created_at_unix: int = int(hive.get("created_at_unix", 0))
	out.append({
		"title": "Founding Hive",
		"detail": "Founded %s" % _format_calendar_date(created_at_unix),
		"kind": "founding"
	})
	out.append({
		"title": "Member Service",
		"detail": "Avg service %dd" % _compute_avg_member_service_days(hive),
		"kind": "service"
	})
	out.append({
		"title": "Tournament Wins",
		"detail": "%d recorded" % int(hive.get("tournament_wins", 0)),
		"kind": "tournament"
	})
	out.append({
		"title": "Hive Championships",
		"detail": "%d titles" % int(hive.get("hive_championships", 0)),
		"kind": "championship"
	})
	var seasonal_best_finish: int = int(hive.get("seasonal_best_finish", 0))
	out.append({
		"title": "Best Seasonal Finish",
		"detail": "#%d" % seasonal_best_finish if seasonal_best_finish > 0 else "Unplaced",
		"kind": "season"
	})
	var earned_milestones: Array[String] = _build_honey_earned_milestones(int(hive.get("total_honey_contributed", 0)))
	if not earned_milestones.is_empty():
		out.append({
			"title": "Honey Earned",
			"detail": earned_milestones[earned_milestones.size() - 1],
			"kind": "earned"
		})
	var spent_milestones: Array[String] = _build_honey_spent_milestones(int(hive.get("total_honey_spent", 0)))
	if not spent_milestones.is_empty():
		out.append({
			"title": "Honey Spent",
			"detail": spent_milestones[spent_milestones.size() - 1],
			"kind": "spent"
		})
	return out

func _new_hive_award_id() -> String:
	return _next_id(HIVE_AWARD_ID_PREFIX)

func _rank_multiplier_bps_for_tournament(tournament_id: String) -> int:
	if tournament_id == "seasonal_royal_gauntlet":
		return HIVE_RANK_CHAMPIONSHIP_MULTIPLIER_BPS
	return HIVE_RANK_TOURNAMENT_MULTIPLIER_BPS

func _grant_hive_awards_for_tournament_victory(hive: Dictionary, bracket: Dictionary, resolved_round: Dictionary) -> Dictionary:
	var award_records: Array[Dictionary] = _sanitize_hive_award_records(hive.get("award_records", []))
	var now_unix: int = _now_unix()
	var hive_id: String = str(hive.get("hive_id", "")).strip_edges()
	var hive_name: String = str(hive.get("name", "Hive")).strip_edges()
	var tournament_id: String = str(resolved_round.get("tournament_id", "")).strip_edges()
	var title: String = str(resolved_round.get("title", "Hive Tournament")).strip_edges()
	var multiplier_bps: int = _rank_multiplier_bps_for_tournament(tournament_id)
	award_records.append({
		"award_id": _new_hive_award_id(),
		"title": "%s Champion Trophy" % title,
		"detail": "Won %s" % _format_calendar_date(now_unix),
		"award_type": HIVE_AWARD_TYPE_TROPHY,
		"tournament_id": tournament_id,
		"tournament_title": title,
		"rank_multiplier_bps": multiplier_bps,
		"awarded_at_unix": now_unix,
		"owner_kind": HIVE_AWARD_OWNER_HIVE,
		"owner_hive_id": hive_id,
		"owner_hive_name": hive_name,
		"source_hive_id": hive_id,
		"source_hive_name": hive_name,
		"archived_at_unix": 0,
		"bracket_id": str(bracket.get("bracket_id", "")),
		"round_id": str(resolved_round.get("round_id", ""))
	})
	if tournament_id == "seasonal_royal_gauntlet":
		award_records.append({
			"award_id": _new_hive_award_id(),
			"title": "%s Champion NFT" % title,
			"detail": "Vaulted %s" % _format_calendar_date(now_unix),
			"award_type": HIVE_AWARD_TYPE_NFT,
			"tournament_id": tournament_id,
			"tournament_title": title,
			"rank_multiplier_bps": 0,
			"awarded_at_unix": now_unix,
			"owner_kind": HIVE_AWARD_OWNER_HIVE,
			"owner_hive_id": hive_id,
			"owner_hive_name": hive_name,
			"source_hive_id": hive_id,
			"source_hive_name": hive_name,
			"archived_at_unix": 0,
			"bracket_id": str(bracket.get("bracket_id", "")),
			"round_id": str(resolved_round.get("round_id", ""))
		})
	hive["award_records"] = award_records
	return hive

func _archive_hive_awards_to_company_case(hive: Dictionary) -> void:
	if hive.is_empty():
		return
	var award_records: Array[Dictionary] = _sanitize_hive_award_records(hive.get("award_records", []))
	if award_records.is_empty():
		return
	var hive_id: String = str(hive.get("hive_id", "")).strip_edges()
	var hive_name: String = str(hive.get("name", "Hive")).strip_edges()
	var archived_at_unix: int = _now_unix()
	for award in award_records:
		var archived_award: Dictionary = award.duplicate(true)
		archived_award["owner_kind"] = HIVE_AWARD_OWNER_COMPANY
		archived_award["owner_hive_id"] = ""
		archived_award["owner_hive_name"] = "Swarmfront"
		archived_award["source_hive_id"] = hive_id
		archived_award["source_hive_name"] = hive_name
		archived_award["archived_at_unix"] = archived_at_unix
		_company_trophy_case.append(archived_award)

func _retire_hive(hive_id: String) -> void:
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return
	_archive_hive_awards_to_company_case(hive)
	_hives_by_id.erase(hive_id)

func _build_feed_snapshots(hive: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var feed_any: Variant = hive.get("feed_entries", [])
	if typeof(feed_any) != TYPE_ARRAY:
		return out
	for entry_any in feed_any as Array:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		out.append({
			"created_at_unix": int(entry.get("created_at_unix", 0)),
			"message": str(entry.get("message", "")),
			"type": str(entry.get("type", "system"))
		})
	return out

func _format_honey_threshold(amount: int) -> String:
	if amount >= 1000000:
		return "%dM Honey" % int(amount / 1000000)
	if amount >= 1000:
		return "%dK Honey" % int(amount / 1000)
	return "%d Honey" % amount

func _format_calendar_date(unix_time: int) -> String:
	if unix_time <= 0:
		return "Unknown"
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	var year: int = int(dt.get("year", 0))
	var month: int = int(dt.get("month", 0))
	var day: int = int(dt.get("day", 0))
	if year <= 0 or month <= 0 or day <= 0:
		return "Unknown"
	return "%04d-%02d-%02d" % [year, month, day]

func _compute_member_rank_points(player_id: String) -> int:
	var rank_state: Node = _rank_state()
	if rank_state == null:
		return 0
	if not rank_state.has_method("get_player_snapshot") or not rank_state.has_method("get_snapshot"):
		return 0
	var rank_snapshot: Dictionary = rank_state.call("get_snapshot") as Dictionary
	var player_count: int = maxi(0, int(rank_snapshot.get("player_count", 0)))
	if player_count <= 0:
		return 0
	var player_snapshot: Dictionary = rank_state.call("get_player_snapshot", player_id) as Dictionary
	if player_snapshot.is_empty():
		return 0
	var rank_position: int = maxi(0, int(player_snapshot.get("rank_position", 0)))
	if rank_position <= 0:
		return 0
	return maxi(1, player_count - rank_position + 1)

func _new_member(player_id: String, display_name: String, role: String, joined_at_unix: int) -> Dictionary:
	return {
		"player_id": player_id,
		"display_name": display_name,
		"role": _sanitize_role(role),
		"joined_at_unix": joined_at_unix,
		"last_seen_at_unix": joined_at_unix,
		"honey_contributed": 0,
		"honey_balance_snapshot": 0,
		"honey_spent": 0,
		"last_honey_reason": "",
		"last_honey_at_unix": 0
	}

func _member_for_player(hive: Dictionary, player_id: String) -> Dictionary:
	var members: Dictionary = hive.get("members", {}) as Dictionary
	return members.get(player_id, {}) as Dictionary

func _role_for_player(hive: Dictionary, player_id: String) -> String:
	var member: Dictionary = _member_for_player(hive, player_id)
	if member.is_empty():
		return ""
	return str(member.get("role", ROLE_MEMBER))

func _count_role(hive: Dictionary, role: String) -> int:
	var count: int = 0
	var members: Dictionary = hive.get("members", {}) as Dictionary
	for member_any in members.values():
		var member: Dictionary = member_any as Dictionary
		if str(member.get("role", ROLE_MEMBER)) == role:
			count += 1
	return count

func _player_ids_for_role(hive: Dictionary, role: String) -> Array[String]:
	var out: Array[String] = []
	var members: Dictionary = hive.get("members", {}) as Dictionary
	for member_any in members.values():
		var member: Dictionary = member_any as Dictionary
		if str(member.get("role", ROLE_MEMBER)) != role:
			continue
		out.append(str(member.get("player_id", "")))
	out.sort()
	return out

func _first_role_player_id(hive: Dictionary, role: String) -> String:
	var player_ids: Array[String] = _player_ids_for_role(hive, role)
	if player_ids.is_empty():
		return ""
	return player_ids[0]

func _senior_soldier_player_id(hive: Dictionary) -> String:
	var members: Dictionary = hive.get("members", {}) as Dictionary
	var best_player_id: String = ""
	var best_joined_at: int = 0
	var best_honey: int = -1
	for member_any in members.values():
		var member: Dictionary = member_any as Dictionary
		if str(member.get("role", ROLE_MEMBER)) != ROLE_SOLDIER:
			continue
		var joined_at: int = int(member.get("joined_at_unix", 0))
		var honey: int = int(member.get("honey_contributed", 0))
		if best_player_id.is_empty() or (joined_at > 0 and (best_joined_at <= 0 or joined_at < best_joined_at)) or (joined_at == best_joined_at and honey > best_honey):
			best_joined_at = joined_at
			best_honey = honey
			best_player_id = str(member.get("player_id", ""))
	return best_player_id

func _select_inactive_queen_successor_id(hive: Dictionary, queen_id: String) -> String:
	var senior_soldier_id: String = _senior_active_soldier_player_id(hive, queen_id)
	if not senior_soldier_id.is_empty():
		return senior_soldier_id
	return _strongest_active_member_player_id(hive, queen_id)

func _senior_active_soldier_player_id(hive: Dictionary, excluded_player_id: String = "") -> String:
	var members: Dictionary = hive.get("members", {}) as Dictionary
	var best_player_id: String = ""
	var best_joined_at: int = 0
	var best_honey: int = -1
	for member_any in members.values():
		var member: Dictionary = member_any as Dictionary
		var player_id: String = str(member.get("player_id", ""))
		if player_id.is_empty() or player_id == excluded_player_id:
			continue
		if str(member.get("role", ROLE_MEMBER)) != ROLE_SOLDIER:
			continue
		if not _is_player_active_voter(hive, player_id):
			continue
		var joined_at: int = int(member.get("joined_at_unix", 0))
		var honey: int = int(member.get("honey_contributed", 0))
		if best_player_id.is_empty() or (joined_at > 0 and (best_joined_at <= 0 or joined_at < best_joined_at)) or (joined_at == best_joined_at and honey > best_honey):
			best_joined_at = joined_at
			best_honey = honey
			best_player_id = player_id
	return best_player_id

func _strongest_active_member_player_id(hive: Dictionary, excluded_player_id: String = "") -> String:
	var members: Dictionary = hive.get("members", {}) as Dictionary
	var best_player_id: String = ""
	var best_honey: int = -1
	var best_joined_at: int = 0
	for member_any in members.values():
		var member: Dictionary = member_any as Dictionary
		var player_id: String = str(member.get("player_id", ""))
		if player_id.is_empty() or player_id == excluded_player_id:
			continue
		if str(member.get("role", ROLE_MEMBER)) != ROLE_MEMBER:
			continue
		if not _is_player_active_voter(hive, player_id):
			continue
		var honey: int = int(member.get("honey_contributed", 0))
		var joined_at: int = int(member.get("joined_at_unix", 0))
		if best_player_id.is_empty() or honey > best_honey or (honey == best_honey and joined_at > 0 and (best_joined_at <= 0 or joined_at < best_joined_at)):
			best_player_id = player_id
			best_honey = honey
			best_joined_at = joined_at
	return best_player_id

func _find_pending_invite_id(hive_id: String, target_player_id: String) -> String:
	for invite_id_any in _invites_by_id.keys():
		var invite_id: String = str(invite_id_any)
		var invite: Dictionary = _invites_by_id.get(invite_id, {}) as Dictionary
		if str(invite.get("hive_id", "")) != hive_id:
			continue
		if str(invite.get("target_player_id", "")) != target_player_id:
			continue
		if str(invite.get("status", "")) != INVITE_STATUS_PENDING:
			continue
		return invite_id
	return ""

func _find_invite_for_player(hive_id: String, target_player_id: String, status: String) -> Dictionary:
	for invite_any in _invites_by_id.values():
		var invite: Dictionary = invite_any as Dictionary
		if str(invite.get("hive_id", "")) != hive_id:
			continue
		if str(invite.get("target_player_id", "")) != target_player_id:
			continue
		if str(invite.get("status", "")) != status:
			continue
		return _build_invite_snapshot(invite, target_player_id)
	return {}

func _find_pending_application_id(hive_id: String, player_id: String) -> String:
	for application_id_any in _applications_by_id.keys():
		var application_id: String = str(application_id_any)
		var application: Dictionary = _applications_by_id.get(application_id, {}) as Dictionary
		if str(application.get("hive_id", "")) != hive_id:
			continue
		if str(application.get("player_id", "")) != player_id:
			continue
		if str(application.get("status", "")) != APPLICATION_STATUS_PENDING:
			continue
		return application_id
	return ""

func _find_application_for_player(hive_id: String, player_id: String, status: String) -> Dictionary:
	for application_any in _applications_by_id.values():
		var application: Dictionary = application_any as Dictionary
		if str(application.get("hive_id", "")) != hive_id:
			continue
		if str(application.get("player_id", "")) != player_id:
			continue
		if str(application.get("status", "")) != status:
			continue
		return _build_application_snapshot(application)
	return {}

func _can_manage_invites(hive: Dictionary, player_id: String) -> bool:
	var role: String = _role_for_player(hive, player_id)
	return role == ROLE_QUEEN or role == ROLE_SOLDIER

func _build_all_soldier_demotion_vote_snapshots(hive: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var votes: Dictionary = hive.get("soldier_demotion_votes", {}) as Dictionary
	for target_player_id_any in votes.keys():
		var target_player_id: String = str(target_player_id_any)
		if target_player_id.is_empty():
			continue
		out.append(_build_soldier_demotion_vote_snapshot(hive, target_player_id))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("target_player_id", "")) < str(b.get("target_player_id", ""))
	)
	return out

func _build_soldier_demotion_vote_snapshot(hive: Dictionary, target_player_id: String) -> Dictionary:
	var votes: Dictionary = hive.get("soldier_demotion_votes", {}) as Dictionary
	var vote_record: Dictionary = votes.get(target_player_id, {}) as Dictionary
	var votes_by_player_id: Dictionary = vote_record.get("votes_by_player_id", {}) as Dictionary
	var voter_ids: Array[String] = []
	for voter_id_any in votes_by_player_id.keys():
		var voter_id: String = str(voter_id_any)
		if voter_id.is_empty():
			continue
		voter_ids.append(voter_id)
	voter_ids.sort()
	return {
		"target_player_id": target_player_id,
		"applied_by_player_id": _sanitize_player_id(str(vote_record.get("applied_by_player_id", ""))),
		"created_at_unix": int(vote_record.get("created_at_unix", 0)),
		"expires_at_unix": int(vote_record.get("created_at_unix", 0)) + GOVERNANCE_VOTE_WINDOW_SEC if int(vote_record.get("created_at_unix", 0)) > 0 else 0,
		"voter_ids": voter_ids,
		"ready_to_demote": _has_queen_and_supporting_soldier_vote(hive, vote_record, target_player_id)
	}

func _build_queen_removal_vote_snapshot(hive: Dictionary) -> Dictionary:
	var votes_by_player_id: Dictionary = hive.get("queen_removal_vote", {}) as Dictionary
	var voter_ids: Array[String] = []
	for voter_id_any in votes_by_player_id.keys():
		var voter_id: String = str(voter_id_any)
		if voter_id.is_empty():
			continue
		voter_ids.append(voter_id)
	voter_ids.sort()
	var created_at_unix: int = int(hive.get("queen_removal_vote_started_at_unix", 0))
	return {
		"queen_player_id": _first_role_player_id(hive, ROLE_QUEEN),
		"created_at_unix": created_at_unix,
		"expires_at_unix": created_at_unix + GOVERNANCE_VOTE_WINDOW_SEC if created_at_unix > 0 else 0,
		"voter_ids": voter_ids,
		"votes_needed": MAX_SOLDIERS,
		"ready_to_remove": _count_valid_queen_removal_votes(hive) >= MAX_SOLDIERS
	}

func _build_all_leadership_removal_vote_snapshots(hive: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var votes: Dictionary = hive.get("leadership_removal_votes", {}) as Dictionary
	for target_player_id_any in votes.keys():
		var target_player_id: String = str(target_player_id_any)
		if target_player_id.is_empty():
			continue
		out.append(_build_leadership_removal_vote_snapshot(hive, target_player_id))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("target_player_id", "")) < str(b.get("target_player_id", ""))
	)
	return out

func _build_leadership_removal_vote_snapshot(hive: Dictionary, target_player_id: String) -> Dictionary:
	var votes: Dictionary = hive.get("leadership_removal_votes", {}) as Dictionary
	var vote_record: Dictionary = votes.get(target_player_id, {}) as Dictionary
	var votes_by_player_id: Dictionary = vote_record.get("votes_by_player_id", {}) as Dictionary
	var voter_ids: Array[String] = []
	for voter_id_any in votes_by_player_id.keys():
		var voter_id: String = str(voter_id_any)
		if voter_id.is_empty():
			continue
		voter_ids.append(voter_id)
	voter_ids.sort()
	var eligible_voters: Array[String] = _eligible_leadership_removal_voters(hive, target_player_id)
	return {
		"target_player_id": target_player_id,
		"target_role": str(vote_record.get("target_role", "")),
		"created_at_unix": int(vote_record.get("created_at_unix", 0)),
		"expires_at_unix": int(vote_record.get("created_at_unix", 0)) + GOVERNANCE_VOTE_WINDOW_SEC if int(vote_record.get("created_at_unix", 0)) > 0 else 0,
		"voter_ids": voter_ids,
		"votes_needed": maxi(MIN_LEADERSHIP_REMOVAL_VOTES, eligible_voters.size()),
		"ready_to_remove": _has_unanimous_leadership_removal_vote(hive, vote_record, target_player_id)
	}

func _build_all_soldier_promotion_vote_snapshots(hive: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var votes: Dictionary = hive.get("soldier_promotion_votes", {}) as Dictionary
	for target_player_id_any in votes.keys():
		var target_player_id: String = str(target_player_id_any)
		if target_player_id.is_empty():
			continue
		out.append(_build_soldier_promotion_vote_snapshot(hive, target_player_id))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("target_player_id", "")) < str(b.get("target_player_id", ""))
	)
	return out

func _build_soldier_promotion_vote_snapshot(hive: Dictionary, target_player_id: String) -> Dictionary:
	var votes: Dictionary = hive.get("soldier_promotion_votes", {}) as Dictionary
	var vote_record: Dictionary = votes.get(target_player_id, {}) as Dictionary
	var votes_by_player_id: Dictionary = vote_record.get("votes_by_player_id", {}) as Dictionary
	var voter_ids: Array[String] = []
	for voter_id_any in votes_by_player_id.keys():
		var voter_id: String = str(voter_id_any)
		if voter_id.is_empty():
			continue
		voter_ids.append(voter_id)
	voter_ids.sort()
	var eligible_voters: Array[String] = _eligible_promotion_voters(hive, target_player_id)
	return {
		"target_player_id": target_player_id,
		"created_at_unix": int(vote_record.get("created_at_unix", 0)),
		"expires_at_unix": int(vote_record.get("created_at_unix", 0)) + GOVERNANCE_VOTE_WINDOW_SEC if int(vote_record.get("created_at_unix", 0)) > 0 else 0,
		"voter_ids": voter_ids,
		"votes_needed": _promotion_majority_threshold(eligible_voters.size()),
		"ready_to_promote": _has_majority_promotion_vote(hive, vote_record, target_player_id)
	}

func _has_queen_and_supporting_soldier_vote(hive: Dictionary, vote_record: Dictionary, target_player_id: String) -> bool:
	var queen_id: String = _first_role_player_id(hive, ROLE_QUEEN)
	if queen_id.is_empty():
		return false
	var votes_by_player_id: Dictionary = vote_record.get("votes_by_player_id", {}) as Dictionary
	if not bool(votes_by_player_id.get(queen_id, false)):
		return false
	for voter_id_any in votes_by_player_id.keys():
		var voter_id: String = str(voter_id_any)
		if voter_id.is_empty() or voter_id == queen_id or voter_id == target_player_id:
			continue
		if _role_for_player(hive, voter_id) == ROLE_SOLDIER:
			return true
	return false

func _count_valid_queen_removal_votes(hive: Dictionary) -> int:
	var votes_by_player_id: Dictionary = hive.get("queen_removal_vote", {}) as Dictionary
	var count: int = 0
	for voter_id_any in votes_by_player_id.keys():
		var voter_id: String = str(voter_id_any)
		if voter_id.is_empty():
			continue
		if not _is_player_active_voter(hive, voter_id):
			continue
		if _role_for_player(hive, voter_id) == ROLE_SOLDIER:
			count += 1
	return count

func _eligible_leadership_removal_voters(hive: Dictionary, target_player_id: String) -> Array[String]:
	var out: Array[String] = []
	var members: Dictionary = hive.get("members", {}) as Dictionary
	for player_id_any in members.keys():
		var player_id: String = str(player_id_any)
		if player_id.is_empty() or player_id == target_player_id:
			continue
		if not _is_player_active_voter(hive, player_id):
			continue
		out.append(player_id)
	out.sort()
	return out

func _has_unanimous_leadership_removal_vote(hive: Dictionary, vote_record: Dictionary, target_player_id: String) -> bool:
	var eligible_voters: Array[String] = _eligible_leadership_removal_voters(hive, target_player_id)
	if eligible_voters.size() < MIN_LEADERSHIP_REMOVAL_VOTES:
		return false
	var votes_by_player_id: Dictionary = vote_record.get("votes_by_player_id", {}) as Dictionary
	for voter_id in eligible_voters:
		if not bool(votes_by_player_id.get(voter_id, false)):
			return false
	return true

func _eligible_promotion_voters(hive: Dictionary, target_player_id: String) -> Array[String]:
	var out: Array[String] = []
	var members: Dictionary = hive.get("members", {}) as Dictionary
	for player_id_any in members.keys():
		var player_id: String = str(player_id_any)
		if player_id.is_empty() or player_id == target_player_id:
			continue
		if not _is_player_active_voter(hive, player_id):
			continue
		out.append(player_id)
	out.sort()
	return out

func _is_player_active_voter(hive: Dictionary, player_id: String) -> bool:
	var member: Dictionary = _member_for_player(hive, player_id)
	if member.is_empty():
		return false
	var last_seen_at_unix: int = int(member.get("last_seen_at_unix", int(member.get("joined_at_unix", 0))))
	if last_seen_at_unix <= 0:
		return false
	return (_now_unix() - last_seen_at_unix) < VOTE_ABSTAIN_INACTIVE_SEC

func _promotion_majority_threshold(voter_count: int) -> int:
	return int(floor(float(maxi(0, voter_count)) * 0.5)) + 1

func _has_majority_promotion_vote(hive: Dictionary, vote_record: Dictionary, target_player_id: String) -> bool:
	var eligible_voters: Array[String] = _eligible_promotion_voters(hive, target_player_id)
	var threshold: int = _promotion_majority_threshold(eligible_voters.size())
	var votes_by_player_id: Dictionary = vote_record.get("votes_by_player_id", {}) as Dictionary
	var count: int = 0
	for voter_id in eligible_voters:
		if bool(votes_by_player_id.get(voter_id, false)):
			count += 1
	return count >= threshold

func _clear_governance_state_for_player(hive: Dictionary, player_id: String) -> void:
	var target_id: String = _sanitize_player_id(player_id)
	if target_id.is_empty():
		return
	var demotion_votes: Dictionary = hive.get("soldier_demotion_votes", {}) as Dictionary
	demotion_votes.erase(target_id)
	for target_any in demotion_votes.keys():
		var target_key: String = str(target_any)
		var vote_record: Dictionary = demotion_votes.get(target_key, {}) as Dictionary
		var votes_by_player_id: Dictionary = vote_record.get("votes_by_player_id", {}) as Dictionary
		if votes_by_player_id.has(target_id):
			votes_by_player_id.erase(target_id)
			vote_record["votes_by_player_id"] = votes_by_player_id
			demotion_votes[target_key] = vote_record
	hive["soldier_demotion_votes"] = demotion_votes
	var queen_removal_vote: Dictionary = hive.get("queen_removal_vote", {}) as Dictionary
	if queen_removal_vote.has(target_id):
		queen_removal_vote.erase(target_id)
	hive["queen_removal_vote"] = queen_removal_vote
	if queen_removal_vote.is_empty():
		hive["queen_removal_vote_started_at_unix"] = 0
	var leadership_removal_votes: Dictionary = hive.get("leadership_removal_votes", {}) as Dictionary
	leadership_removal_votes.erase(target_id)
	for vote_target_any in leadership_removal_votes.keys():
		var vote_target: String = str(vote_target_any)
		var vote_record: Dictionary = leadership_removal_votes.get(vote_target, {}) as Dictionary
		var votes_by_player_id: Dictionary = vote_record.get("votes_by_player_id", {}) as Dictionary
		if votes_by_player_id.has(target_id):
			votes_by_player_id.erase(target_id)
			vote_record["votes_by_player_id"] = votes_by_player_id
			leadership_removal_votes[vote_target] = vote_record
	hive["leadership_removal_votes"] = leadership_removal_votes
	var soldier_promotion_votes: Dictionary = hive.get("soldier_promotion_votes", {}) as Dictionary
	soldier_promotion_votes.erase(target_id)
	for vote_target_any in soldier_promotion_votes.keys():
		var vote_target: String = str(vote_target_any)
		var vote_record: Dictionary = soldier_promotion_votes.get(vote_target, {}) as Dictionary
		var votes_by_player_id: Dictionary = vote_record.get("votes_by_player_id", {}) as Dictionary
		if votes_by_player_id.has(target_id):
			votes_by_player_id.erase(target_id)
			vote_record["votes_by_player_id"] = votes_by_player_id
			soldier_promotion_votes[vote_target] = vote_record
	hive["soldier_promotion_votes"] = soldier_promotion_votes

func _build_leave_request_snapshot(player_id: String) -> Dictionary:
	var request: Dictionary = _pending_leave_by_player_id.get(player_id, {}) as Dictionary
	if request.is_empty():
		return {}
	return request.duplicate(true)

func _player_has_hive(player_id: String) -> bool:
	return not str(_player_to_hive_id.get(player_id, "")).is_empty()

func _current_hive_member_count(hive: Dictionary) -> int:
	var members: Dictionary = hive.get("members", {}) as Dictionary
	return members.size()

func _pending_invite_count(hive_id: String) -> int:
	var pending_count: int = 0
	for invite_any in _invites_by_id.values():
		var invite: Dictionary = invite_any as Dictionary
		if str(invite.get("hive_id", "")) != hive_id:
			continue
		if str(invite.get("status", "")) != INVITE_STATUS_PENDING:
			continue
		pending_count += 1
	return pending_count

func _close_open_membership_requests_for_player(player_id: String, joined_hive_id: String) -> void:
	for invite_id_any in _invites_by_id.keys():
		var invite_id: String = str(invite_id_any)
		var invite: Dictionary = _invites_by_id.get(invite_id, {}) as Dictionary
		if str(invite.get("target_player_id", "")) != player_id:
			continue
		if str(invite.get("status", "")) != INVITE_STATUS_PENDING:
			continue
		if str(invite.get("hive_id", "")) == joined_hive_id:
			continue
		invite["status"] = INVITE_STATUS_DECLINED
		invite["responded_at_unix"] = _now_unix()
		_invites_by_id[invite_id] = invite
	for application_id_any in _applications_by_id.keys():
		var application_id: String = str(application_id_any)
		var application: Dictionary = _applications_by_id.get(application_id, {}) as Dictionary
		if str(application.get("player_id", "")) != player_id:
			continue
		if str(application.get("status", "")) != APPLICATION_STATUS_PENDING:
			continue
		if str(application.get("hive_id", "")) == joined_hive_id:
			continue
		application["status"] = APPLICATION_STATUS_DECLINED
		application["responded_at_unix"] = _now_unix()
		_applications_by_id[application_id] = application

func _check_hive_create_limit(player_id: String) -> Dictionary:
	var now_unix: int = _now_unix()
	var recent_creations: Array[int] = _recent_hive_creations(player_id, now_unix)
	if recent_creations.size() >= HIVE_CREATE_LIMIT_COUNT:
		var earliest_active: int = recent_creations[0]
		return {
			"ok": false,
			"reason": "hive_create_limit_reached",
			"limit": HIVE_CREATE_LIMIT_COUNT,
			"window_sec": HIVE_CREATE_LIMIT_WINDOW_SEC,
			"retry_at_unix": earliest_active + HIVE_CREATE_LIMIT_WINDOW_SEC
		}
	return {"ok": true}

func _recent_hive_creations(player_id: String, now_unix: int) -> Array[int]:
	var existing_any: Variant = _hive_creation_history_by_player_id.get(player_id, [])
	var out: Array[int] = []
	if typeof(existing_any) == TYPE_ARRAY:
		for stamp_any in existing_any as Array:
			var stamp: int = maxi(0, int(stamp_any))
			if stamp <= 0:
				continue
			if now_unix - stamp >= HIVE_CREATE_LIMIT_WINDOW_SEC:
				continue
			out.append(stamp)
	out.sort()
	_hive_creation_history_by_player_id[player_id] = out
	return out

func _record_hive_creation(player_id: String, created_at_unix: int) -> void:
	var recent_creations: Array[int] = _recent_hive_creations(player_id, created_at_unix)
	recent_creations.append(created_at_unix)
	recent_creations.sort()
	_hive_creation_history_by_player_id[player_id] = recent_creations

func _rejoin_block_until(player_id: String, hive_id: String) -> int:
	var hive_map: Dictionary = _rejoin_cooldowns_by_player_id.get(player_id, {}) as Dictionary
	return maxi(0, int(hive_map.get(hive_id, 0)))

func _refresh_runtime_state() -> void:
	_process_expired_invites()
	_process_pending_leaves()
	_process_expired_governance_votes()
	_process_inactive_vote_abstentions()
	_process_hive_tournament_rounds()

func _process_expired_invites() -> void:
	if _invites_by_id.is_empty():
		return
	var now_unix: int = _now_unix()
	var changed: bool = false
	for invite_id_any in _invites_by_id.keys():
		var invite_id: String = str(invite_id_any)
		var invite: Dictionary = _invites_by_id.get(invite_id, {}) as Dictionary
		if str(invite.get("status", "")) != INVITE_STATUS_PENDING:
			continue
		var expires_at_unix: int = int(invite.get("expires_at_unix", 0))
		if expires_at_unix <= 0 or expires_at_unix > now_unix:
			continue
		invite["status"] = INVITE_STATUS_EXPIRED
		invite["responded_at_unix"] = now_unix
		_invites_by_id[invite_id] = invite
		changed = true
	if changed:
		_save_state()

func _process_pending_leaves() -> void:
	if _pending_leave_by_player_id.is_empty():
		return
	var now_unix: int = _now_unix()
	var completed: Array[String] = []
	for player_id_any in _pending_leave_by_player_id.keys():
		var player_id: String = str(player_id_any)
		var request: Dictionary = _pending_leave_by_player_id.get(player_id, {}) as Dictionary
		if int(request.get("effective_at_unix", 0)) > now_unix:
			continue
		completed.append(player_id)
	if completed.is_empty():
		return
	for player_id in completed:
		_finalize_leave_for_player(player_id, now_unix)
	_save_state()
	_emit_changed()

func _process_expired_governance_votes() -> void:
	if _hives_by_id.is_empty():
		return
	var now_unix: int = _now_unix()
	var changed: bool = false
	for hive_id_any in _hives_by_id.keys():
		var hive_id: String = str(hive_id_any)
		var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
		if hive.is_empty():
			continue
		if _strip_expired_votes_from_hive(hive, now_unix):
			_hives_by_id[hive_id] = hive
			changed = true
	if changed:
		_save_state()

func _strip_expired_votes_from_hive(hive: Dictionary, now_unix: int) -> bool:
	var changed: bool = false
	var queen_removal_vote: Dictionary = hive.get("queen_removal_vote", {}) as Dictionary
	if queen_removal_vote.is_empty():
		if int(hive.get("queen_removal_vote_started_at_unix", 0)) != 0:
			hive["queen_removal_vote_started_at_unix"] = 0
			changed = true
	else:
		var queen_started_at: int = int(hive.get("queen_removal_vote_started_at_unix", 0))
		if queen_started_at <= 0:
			hive["queen_removal_vote_started_at_unix"] = now_unix
			changed = true
		elif queen_started_at + GOVERNANCE_VOTE_WINDOW_SEC <= now_unix:
			hive["queen_removal_vote"] = {}
			hive["queen_removal_vote_started_at_unix"] = 0
			changed = true
	for key in ["soldier_demotion_votes", "leadership_removal_votes", "soldier_promotion_votes"]:
		var vote_map: Dictionary = hive.get(key, {}) as Dictionary
		var remove_targets: Array[String] = []
		for target_any in vote_map.keys():
			var target_id: String = str(target_any)
			var vote_record: Dictionary = vote_map.get(target_id, {}) as Dictionary
			var created_at_unix: int = int(vote_record.get("created_at_unix", 0))
			if created_at_unix <= 0:
				vote_record["created_at_unix"] = now_unix
				vote_map[target_id] = vote_record
				changed = true
			elif created_at_unix + GOVERNANCE_VOTE_WINDOW_SEC <= now_unix:
				remove_targets.append(target_id)
		for target_id in remove_targets:
			vote_map.erase(target_id)
			changed = true
		hive[key] = vote_map
	return changed

func _process_inactive_vote_abstentions() -> void:
	if _hives_by_id.is_empty():
		return
	var changed: bool = false
	for hive_id_any in _hives_by_id.keys():
		var hive_id: String = str(hive_id_any)
		var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
		if hive.is_empty():
			continue
		if _strip_inactive_votes_from_hive(hive):
			_hives_by_id[hive_id] = hive
			changed = true
	if changed:
		_save_state()

func _strip_inactive_votes_from_hive(hive: Dictionary) -> bool:
	var changed: bool = false
	var inactive_voters: Dictionary = {}
	var members: Dictionary = hive.get("members", {}) as Dictionary
	for player_id_any in members.keys():
		var player_id: String = str(player_id_any)
		if player_id.is_empty():
			continue
		if not _is_player_active_voter(hive, player_id):
			inactive_voters[player_id] = true
	if inactive_voters.is_empty():
		return false
	var queen_removal_vote: Dictionary = hive.get("queen_removal_vote", {}) as Dictionary
	for player_id in inactive_voters.keys():
		if queen_removal_vote.has(player_id):
			queen_removal_vote.erase(player_id)
			changed = true
	hive["queen_removal_vote"] = queen_removal_vote
	if queen_removal_vote.is_empty() and int(hive.get("queen_removal_vote_started_at_unix", 0)) != 0:
		hive["queen_removal_vote_started_at_unix"] = 0
		changed = true
	for key in ["soldier_demotion_votes", "leadership_removal_votes", "soldier_promotion_votes"]:
		var vote_map: Dictionary = hive.get(key, {}) as Dictionary
		for target_any in vote_map.keys():
			var target_id: String = str(target_any)
			var vote_record: Dictionary = vote_map.get(target_id, {}) as Dictionary
			var votes_by_player_id: Dictionary = vote_record.get("votes_by_player_id", {}) as Dictionary
			var vote_changed: bool = false
			for player_id in inactive_voters.keys():
				if votes_by_player_id.has(player_id):
					votes_by_player_id.erase(player_id)
					vote_changed = true
			if vote_changed:
				vote_record["votes_by_player_id"] = votes_by_player_id
				vote_map[target_id] = vote_record
				changed = true
		hive[key] = vote_map
	return changed

func _finalize_leave_for_player(player_id: String, now_unix: int) -> void:
	var request: Dictionary = _pending_leave_by_player_id.get(player_id, {}) as Dictionary
	if request.is_empty():
		return
	_pending_leave_by_player_id.erase(player_id)
	var hive_id: String = str(request.get("hive_id", ""))
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return
	var members: Dictionary = hive.get("members", {}) as Dictionary
	members.erase(player_id)
	hive["members"] = members
	_clear_governance_state_for_player(hive, player_id)
	var player_cooldowns: Dictionary = _rejoin_cooldowns_by_player_id.get(player_id, {}) as Dictionary
	player_cooldowns[hive_id] = now_unix + REJOIN_SAME_HIVE_COOLDOWN_SEC
	_rejoin_cooldowns_by_player_id[player_id] = player_cooldowns
	if members.is_empty():
		_retire_hive(hive_id)
	else:
		_ensure_hive_leadership(hive)
		_recompute_hive_metrics(hive)
		_hives_by_id[hive_id] = hive
	_reindex_memberships()
	_emit_event({
		"type": "hive_leave_finalized",
		"player_id": player_id,
		"hive_id": hive_id,
		"rejoin_blocked_until_unix": now_unix + REJOIN_SAME_HIVE_COOLDOWN_SEC
	})

func _ensure_hive_leadership(hive: Dictionary) -> void:
	var members: Dictionary = hive.get("members", {}) as Dictionary
	if members.is_empty():
		return
	if _count_role(hive, ROLE_QUEEN) > 0:
		return
	var promote_player_id: String = _senior_soldier_player_id(hive)
	if promote_player_id.is_empty():
		var best_honey: int = -1
		for member_any in members.values():
			var member: Dictionary = member_any as Dictionary
			var honey: int = int(member.get("honey_contributed", 0))
			if honey > best_honey:
				best_honey = honey
				promote_player_id = str(member.get("player_id", ""))
	if promote_player_id.is_empty():
		return
	var member_to_promote: Dictionary = members.get(promote_player_id, {}) as Dictionary
	if member_to_promote.is_empty():
		return
	member_to_promote["role"] = ROLE_QUEEN
	members[promote_player_id] = member_to_promote
	hive["members"] = members
	_clear_governance_state_for_player(hive, promote_player_id)

func _apply_auto_soldier_assignment(hive: Dictionary, joined_player_id: String) -> void:
	var target_id: String = _sanitize_player_id(joined_player_id)
	if target_id.is_empty():
		return
	var members: Dictionary = hive.get("members", {}) as Dictionary
	if members.size() < 7:
		return
	if _count_role(hive, ROLE_SOLDIER) >= MAX_SOLDIERS:
		return
	var member: Dictionary = members.get(target_id, {}) as Dictionary
	if member.is_empty():
		return
	if str(member.get("role", ROLE_MEMBER)) != ROLE_MEMBER:
		return
	member["role"] = ROLE_SOLDIER
	members[target_id] = member
	hive["members"] = members

func _sanitize_soldier_demotion_votes(raw_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_any) != TYPE_DICTIONARY:
		return out
	var raw: Dictionary = raw_any as Dictionary
	for target_id_any in raw.keys():
		var target_id: String = _sanitize_player_id(str(target_id_any))
		if target_id.is_empty():
			continue
		var vote_record_raw: Dictionary = raw.get(target_id_any, {}) as Dictionary
		out[target_id] = {
			"target_player_id": target_id,
			"applied_by_player_id": _sanitize_player_id(str(vote_record_raw.get("applied_by_player_id", ""))),
			"created_at_unix": maxi(0, int(vote_record_raw.get("created_at_unix", 0))),
			"votes_by_player_id": _sanitize_vote_map(vote_record_raw.get("votes_by_player_id", {}))
		}
	return out

func _sanitize_leadership_removal_votes(raw_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_any) != TYPE_DICTIONARY:
		return out
	var raw: Dictionary = raw_any as Dictionary
	for target_id_any in raw.keys():
		var target_id: String = _sanitize_player_id(str(target_id_any))
		if target_id.is_empty():
			continue
		var vote_record_raw: Dictionary = raw.get(target_id_any, {}) as Dictionary
		out[target_id] = {
			"target_player_id": target_id,
			"target_role": _sanitize_role(str(vote_record_raw.get("target_role", ROLE_MEMBER))),
			"created_at_unix": maxi(0, int(vote_record_raw.get("created_at_unix", 0))),
			"votes_by_player_id": _sanitize_vote_map(vote_record_raw.get("votes_by_player_id", {}))
		}
	return out

func _sanitize_soldier_promotion_votes(raw_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_any) != TYPE_DICTIONARY:
		return out
	var raw: Dictionary = raw_any as Dictionary
	for target_id_any in raw.keys():
		var target_id: String = _sanitize_player_id(str(target_id_any))
		if target_id.is_empty():
			continue
		var vote_record_raw: Dictionary = raw.get(target_id_any, {}) as Dictionary
		out[target_id] = {
			"target_player_id": target_id,
			"created_at_unix": maxi(0, int(vote_record_raw.get("created_at_unix", 0))),
			"votes_by_player_id": _sanitize_vote_map(vote_record_raw.get("votes_by_player_id", {}))
		}
	return out

func _sanitize_vote_map(raw_any: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_any) != TYPE_DICTIONARY:
		return out
	var raw: Dictionary = raw_any as Dictionary
	for player_id_any in raw.keys():
		var player_id: String = _sanitize_player_id(str(player_id_any))
		if player_id.is_empty():
			continue
		if bool(raw.get(player_id_any, false)):
			out[player_id] = true
	return out

func _connect_tree_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var node_added_cb: Callable = Callable(self, "_on_tree_node_added")
	if not tree.node_added.is_connected(node_added_cb):
		tree.node_added.connect(node_added_cb)

func _scan_for_sim_runner() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var root: Node = tree.get_root()
	if root == null:
		return
	var runner: Node = root.find_child("SimRunner", true, false)
	if runner != null:
		_connect_sim_runner(runner)

func _on_tree_node_added(node: Node) -> void:
	if node == null:
		return
	if node.name != "SimRunner" and not node.has_signal("match_ended"):
		return
	_connect_sim_runner(node)

func _connect_sim_runner(node: Node) -> void:
	if node == null or not node.has_signal("match_ended"):
		return
	var callback: Callable = Callable(self, "_on_runtime_match_ended")
	if not node.is_connected("match_ended", callback):
		node.connect("match_ended", callback)

func _on_runtime_match_ended(_winner_id: int, _reason: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if bool(tree.get_meta("hive_tournament_submission_recorded", false)):
		return
	var round_id: String = str(tree.get_meta("hive_tournament_round_id", "")).strip_edges()
	if round_id.is_empty():
		return
	var local_player_id: String = str(tree.get_meta("hive_tournament_player_id", "")).strip_edges()
	if local_player_id.is_empty():
		local_player_id = _local_player_id()
	if local_player_id.is_empty():
		return
	if not _is_final_stage_round(tree):
		return
	var total_time_ms: int = _runtime_stage_total_time_ms(tree)
	if total_time_ms <= 0:
		return
	var round_results: Array = _runtime_stage_round_results(tree)
	var submit_result: Dictionary = intent_record_hive_tournament_submission(round_id, local_player_id, total_time_ms, round_results)
	if not bool(submit_result.get("ok", false)):
		return
	tree.set_meta("hive_tournament_submission_recorded", true)

func _resolve_player_id(player_id: String) -> String:
	var clean_id: String = _sanitize_player_id(player_id)
	if not clean_id.is_empty():
		return clean_id
	return _local_player_id()

func _rank_state() -> Node:
	return get_node_or_null("/root/RankState")

func _profile_manager() -> Node:
	return get_node_or_null("/root/ProfileManager")

func _connect_profile_honey_signal() -> void:
	var profile_manager: Node = _profile_manager()
	if profile_manager == null or not profile_manager.has_signal("honey_balance_changed"):
		return
	var callback: Callable = Callable(self, "_on_profile_honey_balance_changed")
	if not profile_manager.is_connected("honey_balance_changed", callback):
		profile_manager.connect("honey_balance_changed", callback)

func _on_profile_honey_balance_changed(new_value: int, _delta: int, reason: String) -> void:
	var local_id: String = _local_player_id()
	if local_id.is_empty():
		return
	intent_sync_member_honey_balance(local_id, maxi(0, new_value), reason)

func _is_final_stage_round(tree: SceneTree) -> bool:
	var stage_paths_any: Variant = tree.get_meta("vs_stage_map_paths", [])
	if typeof(stage_paths_any) != TYPE_ARRAY:
		return true
	var stage_paths: Array = stage_paths_any as Array
	if stage_paths.size() <= 1:
		return true
	var current_index: int = clampi(int(tree.get_meta("vs_stage_current_index", 0)), 0, stage_paths.size() - 1)
	return current_index + 1 >= stage_paths.size()

func _runtime_stage_round_results(tree: SceneTree) -> Array:
	var results_any: Variant = tree.get_meta("vs_stage_round_results", [])
	var results: Array = results_any.duplicate(true) if typeof(results_any) == TYPE_ARRAY else []
	var current_index: int = maxi(0, int(tree.get_meta("vs_stage_current_index", 0)))
	var ops_state: Node = get_node_or_null("/root/OpsState")
	var already_recorded: bool = false
	for result_any in results:
		if typeof(result_any) != TYPE_DICTIONARY:
			continue
		if int((result_any as Dictionary).get("round_index", -1)) == current_index:
			already_recorded = true
			break
	if not already_recorded:
		results.append({
			"round_index": current_index,
			"elapsed_ms": maxi(0, int(ops_state.get("match_elapsed_ms"))) if ops_state != null else 0,
			"map_path": _runtime_stage_map_path_for_index(tree, current_index)
		})
	return results

func _runtime_stage_total_time_ms(tree: SceneTree) -> int:
	var total_time_ms: int = 0
	for result_any in _runtime_stage_round_results(tree):
		if typeof(result_any) != TYPE_DICTIONARY:
			continue
		total_time_ms += maxi(0, int((result_any as Dictionary).get("elapsed_ms", 0)))
	return total_time_ms

func _runtime_stage_map_path_for_index(tree: SceneTree, round_index: int) -> String:
	var stage_paths_any: Variant = tree.get_meta("vs_stage_map_paths", [])
	if typeof(stage_paths_any) != TYPE_ARRAY:
		return ""
	var stage_paths: Array = stage_paths_any as Array
	if round_index < 0 or round_index >= stage_paths.size():
		return ""
	return str(stage_paths[round_index]).strip_edges()

func _local_player_id() -> String:
	var profile_manager: Node = _profile_manager()
	if profile_manager != null and profile_manager.has_method("get_user_id"):
		return _sanitize_player_id(str(profile_manager.call("get_user_id")))
	return ""

func _display_name_for_player(player_id: String, fallback: String = "") -> String:
	var clean_player_id: String = _sanitize_player_id(player_id)
	var clean_fallback: String = _sanitize_display_name(fallback)
	if clean_player_id.is_empty():
		return clean_fallback
	var profile_manager: Node = _profile_manager()
	if profile_manager != null and profile_manager.has_method("get_user_id"):
		var local_player_id: String = str(profile_manager.call("get_user_id"))
		if clean_player_id == local_player_id and profile_manager.has_method("get_display_name"):
			return _sanitize_display_name(str(profile_manager.call("get_display_name")))
	if not clean_fallback.is_empty():
		return clean_fallback
	var suffix: String = clean_player_id
	if suffix.length() > 4:
		suffix = suffix.substr(suffix.length() - 4, 4)
	return "Player %s" % suffix.to_upper()

func _sanitize_hive_name(name: String) -> String:
	var clean_name: String = name.strip_edges()
	if clean_name.length() > HIVE_NAME_MAX_LEN:
		clean_name = clean_name.substr(0, HIVE_NAME_MAX_LEN)
	return clean_name

func _sanitize_display_name(name: String) -> String:
	return name.strip_edges()

func _sanitize_player_id(player_id: String) -> String:
	return player_id.strip_edges()

func _sanitize_role(role: String) -> String:
	var clean_role: String = role.strip_edges().to_lower()
	match clean_role:
		ROLE_QUEEN, ROLE_SOLDIER:
			return clean_role
		_:
			return ROLE_MEMBER

func _sanitize_invite_status(status: String) -> String:
	var clean_status: String = status.strip_edges().to_lower()
	match clean_status:
		INVITE_STATUS_ACCEPTED, INVITE_STATUS_DECLINED, INVITE_STATUS_EXPIRED:
			return clean_status
		_:
			return INVITE_STATUS_PENDING

func _sanitize_application_status(status: String) -> String:
	var clean_status: String = status.strip_edges().to_lower()
	match clean_status:
		APPLICATION_STATUS_ACCEPTED, APPLICATION_STATUS_DECLINED:
			return clean_status
		_:
			return APPLICATION_STATUS_PENDING

func _next_id(prefix: String) -> String:
	var raw: String = ""
	for i in range(int(ID_HEX_LEN / 2)):
		raw += "%02x" % int(_rng.randi_range(0, 255))
	return "%s%s" % [prefix, raw]

func _role_rank(role: String) -> int:
	match role:
		ROLE_QUEEN:
			return 0
		ROLE_SOLDIER:
			return 1
		_:
			return 2

func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())
