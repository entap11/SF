extends Node

const SFLog = preload("res://scripts/util/sf_log.gd")

signal hive_clan_state_changed(snapshot: Dictionary)
signal hive_clan_event(event: Dictionary)

const SAVE_PATH: String = "user://hive_clan_state.json"
const SAVE_SCHEMA_VERSION: int = 3
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
const VOTE_ABSTAIN_INACTIVE_SEC: int = 7 * 24 * 60 * 60
const HIVE_CREATE_LIMIT_COUNT: int = 1
const HIVE_CREATE_LIMIT_WINDOW_SEC: int = 7 * 24 * 60 * 60
const INVITE_EXPIRY_SEC: int = 48 * 60 * 60
const LEAVE_DELAY_SEC: int = 24 * 60 * 60
const REJOIN_SAME_HIVE_COOLDOWN_SEC: int = 7 * 24 * 60 * 60
const APPLICATION_STATUS_PENDING: String = "pending"
const APPLICATION_STATUS_ACCEPTED: String = "accepted"
const APPLICATION_STATUS_DECLINED: String = "declined"

var _save_schema_version: int = SAVE_SCHEMA_VERSION
var _hives_by_id: Dictionary = {}
var _invites_by_id: Dictionary = {}
var _applications_by_id: Dictionary = {}
var _player_to_hive_id: Dictionary = {}
var _pending_leave_by_player_id: Dictionary = {}
var _rejoin_cooldowns_by_player_id: Dictionary = {}
var _hive_creation_history_by_player_id: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	SFLog.allow_tag("HIVE_CLAN_STATE")
	SFLog.allow_tag("HIVE_CLAN_EVENT")
	_rng.randomize()
	_load_state()
	_refresh_runtime_state()
	_bootstrap_local_profile()
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
		"pending_governance_actions": get_pending_governance_actions_for_player(local_player_id)
	}

func get_hive_snapshot(hive_id: String) -> Dictionary:
	_refresh_runtime_state()
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {}
	return _build_hive_snapshot(hive)

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
	if RankState == null or not RankState.has_method("get_leaderboard_snapshot"):
		return out
	var local_player_id: String = _local_player_id()
	var board: Dictionary = RankState.call("get_leaderboard_snapshot", local_player_id, "GLOBAL", maxi(limit * 4, 100)) as Dictionary
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
		"soldier_demotion_votes": {},
		"queen_removal_vote": {},
		"leadership_removal_votes": {},
		"soldier_promotion_votes": {},
		"tournament_wins": 0,
		"hive_championships": 0,
		"seasonal_best_finish": 0,
		"total_honey_spent": 0,
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

func intent_invite_player(hive_id: String, target_player_id: String, target_display_name: String = "", role: String = ROLE_MEMBER, invited_by_player_id: String = "") -> Dictionary:
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
		"responded_at_unix": 0
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
	votes_by_player_id[actor_id] = true
	hive["queen_removal_vote"] = votes_by_player_id
	if _count_valid_queen_removal_votes(hive) >= MAX_SOLDIERS:
		var members: Dictionary = hive.get("members", {}) as Dictionary
		var queen_member: Dictionary = members.get(queen_id, {}) as Dictionary
		if queen_member.is_empty():
			return {"ok": false, "reason": "queen_not_found"}
		queen_member["role"] = ROLE_MEMBER
		members[queen_id] = queen_member
		var new_queen_id: String = _highest_honey_soldier_player_id(hive)
		if new_queen_id.is_empty():
			new_queen_id = actor_id
		var new_queen_member: Dictionary = members.get(new_queen_id, {}) as Dictionary
		if new_queen_member.is_empty():
			return {"ok": false, "reason": "new_queen_not_found"}
		new_queen_member["role"] = ROLE_QUEEN
		members[new_queen_id] = new_queen_member
		hive["members"] = members
		hive["queen_removal_vote"] = {}
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
		_hives_by_id.erase(hive_id)
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
	_save_state()
	_emit_changed()

func _emit_changed() -> void:
	hive_clan_state_changed.emit(get_snapshot())

func _emit_event(event: Dictionary) -> void:
	hive_clan_event.emit(event)
	SFLog.info("HIVE_CLAN_EVENT", event)
	_emit_changed()

func _load_state() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
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
	_reindex_memberships()

func _save_state() -> void:
	var payload: Dictionary = {
		"schema_version": SAVE_SCHEMA_VERSION,
		"hives_by_id": _hives_by_id,
		"invites_by_id": _invites_by_id,
		"applications_by_id": _applications_by_id,
		"pending_leave_by_player_id": _pending_leave_by_player_id,
		"rejoin_cooldowns_by_player_id": _rejoin_cooldowns_by_player_id,
		"hive_creation_history_by_player_id": _hive_creation_history_by_player_id
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
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
		return int(a.get("total_honey_contributed", 0)) > int(b.get("total_honey_contributed", 0))
	)
	return out

func _build_hive_snapshot(hive: Dictionary) -> Dictionary:
	var members_out: Array[Dictionary] = []
	var members: Dictionary = hive.get("members", {}) as Dictionary
	for member_any in members.values():
		var member: Dictionary = member_any as Dictionary
		var player_id: String = str(member.get("player_id", ""))
		var player_snapshot: Dictionary = RankState.call("get_player_snapshot", player_id) as Dictionary if RankState != null and RankState.has_method("get_player_snapshot") else {}
		members_out.append({
			"player_id": player_id,
			"display_name": str(member.get("display_name", "")),
			"role": str(member.get("role", ROLE_MEMBER)),
			"joined_at_unix": int(member.get("joined_at_unix", 0)),
			"last_seen_at_unix": int(member.get("last_seen_at_unix", int(member.get("joined_at_unix", 0)))),
			"honey_contributed": int(member.get("honey_contributed", 0)),
			"rank_position": int(player_snapshot.get("rank_position", 0)),
			"tier_id": str(player_snapshot.get("tier_id", "DRONE"))
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
		"honey_earned_milestones": _build_honey_earned_milestones(int(hive.get("total_honey_contributed", 0))),
		"honey_spent_milestones": _build_honey_spent_milestones(int(hive.get("total_honey_spent", 0))),
		"total_honey_contributed": int(hive.get("total_honey_contributed", 0)),
		"total_honey_spent": int(hive.get("total_honey_spent", 0)),
		"hive_honey_strength": int(hive.get("hive_honey_strength", 0)),
		"rank_points": _compute_hive_rank_points(hive)
	}

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
		"responded_at_unix": int(invite.get("responded_at_unix", 0))
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
		"soldier_demotion_votes": _sanitize_soldier_demotion_votes(raw.get("soldier_demotion_votes", {})),
		"queen_removal_vote": _sanitize_vote_map(raw.get("queen_removal_vote", {})),
		"leadership_removal_votes": _sanitize_leadership_removal_votes(raw.get("leadership_removal_votes", {})),
		"soldier_promotion_votes": _sanitize_soldier_promotion_votes(raw.get("soldier_promotion_votes", {})),
		"tournament_wins": maxi(0, int(raw.get("tournament_wins", 0))),
		"hive_championships": maxi(0, int(raw.get("hive_championships", 0))),
		"seasonal_best_finish": maxi(0, int(raw.get("seasonal_best_finish", 0))),
		"total_honey_spent": maxi(0, int(raw.get("total_honey_spent", 0))),
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
		"responded_at_unix": maxi(0, int(raw.get("responded_at_unix", 0)))
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
		"last_honey_reason": str(raw.get("last_honey_reason", "")),
		"last_honey_at_unix": maxi(0, int(raw.get("last_honey_at_unix", 0)))
	}

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
	var total_honey: int = 0
	for member_any in members.values():
		var member: Dictionary = member_any as Dictionary
		total_honey += maxi(0, int(member.get("honey_contributed", 0)))
	hive["total_honey_contributed"] = total_honey
	hive["hive_honey_strength"] = total_honey

func _compute_hive_rank_points(hive: Dictionary) -> int:
	var total_points: int = 0
	var members: Dictionary = hive.get("members", {}) as Dictionary
	for player_id_any in members.keys():
		total_points += _compute_member_rank_points(str(player_id_any))
	return total_points

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

func _format_honey_threshold(amount: int) -> String:
	if amount >= 1000000:
		return "%dM Honey" % int(amount / 1000000)
	if amount >= 1000:
		return "%dK Honey" % int(amount / 1000)
	return "%d Honey" % amount

func _compute_member_rank_points(player_id: String) -> int:
	if RankState == null:
		return 0
	if not RankState.has_method("get_player_snapshot") or not RankState.has_method("get_snapshot"):
		return 0
	var rank_snapshot: Dictionary = RankState.call("get_snapshot") as Dictionary
	var player_count: int = maxi(0, int(rank_snapshot.get("player_count", 0)))
	if player_count <= 0:
		return 0
	var player_snapshot: Dictionary = RankState.call("get_player_snapshot", player_id) as Dictionary
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

func _highest_honey_soldier_player_id(hive: Dictionary) -> String:
	var members: Dictionary = hive.get("members", {}) as Dictionary
	var best_player_id: String = ""
	var best_honey: int = -1
	for member_any in members.values():
		var member: Dictionary = member_any as Dictionary
		if str(member.get("role", ROLE_MEMBER)) != ROLE_SOLDIER:
			continue
		var honey: int = int(member.get("honey_contributed", 0))
		if honey > best_honey:
			best_honey = honey
			best_player_id = str(member.get("player_id", ""))
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
		"created_at_unix": int(vote_record.get("created_at_unix", 0)),
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
	return {
		"queen_player_id": _first_role_player_id(hive, ROLE_QUEEN),
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
	_process_inactive_vote_abstentions()

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
		_hives_by_id.erase(hive_id)
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
	var promote_player_id: String = _first_role_player_id(hive, ROLE_SOLDIER)
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

func _resolve_player_id(player_id: String) -> String:
	var clean_id: String = _sanitize_player_id(player_id)
	if not clean_id.is_empty():
		return clean_id
	return _local_player_id()

func _local_player_id() -> String:
	if ProfileManager != null and ProfileManager.has_method("get_user_id"):
		return _sanitize_player_id(str(ProfileManager.call("get_user_id")))
	return ""

func _display_name_for_player(player_id: String, fallback: String = "") -> String:
	var clean_player_id: String = _sanitize_player_id(player_id)
	var clean_fallback: String = _sanitize_display_name(fallback)
	if clean_player_id.is_empty():
		return clean_fallback
	if ProfileManager != null and ProfileManager.has_method("get_user_id"):
		var local_player_id: String = str(ProfileManager.call("get_user_id"))
		if clean_player_id == local_player_id and ProfileManager.has_method("get_display_name"):
			return _sanitize_display_name(str(ProfileManager.call("get_display_name")))
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
