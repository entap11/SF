extends Node

const SFLog = preload("res://scripts/util/sf_log.gd")

signal hive_clan_state_changed(snapshot: Dictionary)
signal hive_clan_event(event: Dictionary)

const SAVE_PATH: String = "user://hive_clan_state.json"
const SAVE_SCHEMA_VERSION: int = 1
const ROLE_QUEEN: String = "queen"
const ROLE_SOLDIER: String = "soldier"
const ROLE_MEMBER: String = "member"
const INVITE_STATUS_PENDING: String = "pending"
const INVITE_STATUS_ACCEPTED: String = "accepted"
const INVITE_STATUS_DECLINED: String = "declined"
const HIVE_ID_PREFIX: String = "h_"
const INVITE_ID_PREFIX: String = "hi_"
const ID_HEX_LEN: int = 10
const HIVE_NAME_MAX_LEN: int = 24
const MAX_SOLDIERS: int = 2
const MAX_HIVE_MEMBERS: int = 14
const HIVE_CREATE_LIMIT_COUNT: int = 1
const HIVE_CREATE_LIMIT_WINDOW_SEC: int = 7 * 24 * 60 * 60
const LEAVE_DELAY_SEC: int = 24 * 60 * 60
const REJOIN_SAME_HIVE_COOLDOWN_SEC: int = 48 * 60 * 60

var _save_schema_version: int = SAVE_SCHEMA_VERSION
var _hives_by_id: Dictionary = {}
var _invites_by_id: Dictionary = {}
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
	_process_pending_leaves()
	_bootstrap_local_profile()
	_emit_changed()

func get_snapshot() -> Dictionary:
	_process_pending_leaves()
	var local_player_id: String = _local_player_id()
	return {
		"schema_version": _save_schema_version,
		"transport_mode": "local",
		"local_player_id": local_player_id,
		"local_membership": get_player_membership(local_player_id),
		"hives": _sorted_hive_snapshots(),
		"pending_invites": get_pending_invites_for_player(local_player_id)
	}

func get_hive_snapshot(hive_id: String) -> Dictionary:
	_process_pending_leaves()
	var hive: Dictionary = _hives_by_id.get(hive_id, {}) as Dictionary
	if hive.is_empty():
		return {}
	return _build_hive_snapshot(hive)

func get_player_membership(player_id: String = "") -> Dictionary:
	_process_pending_leaves()
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
	_process_pending_leaves()
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

func intent_create_hive(hive_name: String) -> Dictionary:
	_process_pending_leaves()
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
	_process_pending_leaves()
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
	return {"ok": true, "invite": _build_invite_snapshot(invite)}

func intent_accept_invite(invite_id: String, player_id: String = "", display_name: String = "") -> Dictionary:
	_process_pending_leaves()
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
	_recompute_hive_metrics(hive)
	_hives_by_id[hive_id] = hive
	invite["status"] = INVITE_STATUS_ACCEPTED
	invite["responded_at_unix"] = now_unix
	_invites_by_id[invite_id] = invite
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
	_process_pending_leaves()
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
	_process_pending_leaves()
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
		member["role"] = ROLE_MEMBER
	members[target_id] = member
	hive["members"] = members
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

func intent_record_hive_honey(hive_id: String, player_id: String, honey_amount: int, reason: String = "", metadata: Dictionary = {}) -> Dictionary:
	_process_pending_leaves()
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
	_process_pending_leaves()
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
	_process_pending_leaves()
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
	_pending_leave_by_player_id = _sanitize_leave_requests(payload.get("pending_leave_by_player_id", {}))
	_rejoin_cooldowns_by_player_id = _sanitize_rejoin_cooldowns(payload.get("rejoin_cooldowns_by_player_id", {}))
	_hive_creation_history_by_player_id = _sanitize_creation_history(payload.get("hive_creation_history_by_player_id", {}))
	_reindex_memberships()

func _save_state() -> void:
	var payload: Dictionary = {
		"schema_version": SAVE_SCHEMA_VERSION,
		"hives_by_id": _hives_by_id,
		"invites_by_id": _invites_by_id,
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
		members_out.append({
			"player_id": str(member.get("player_id", "")),
			"display_name": str(member.get("display_name", "")),
			"role": str(member.get("role", ROLE_MEMBER)),
			"joined_at_unix": int(member.get("joined_at_unix", 0)),
			"honey_contributed": int(member.get("honey_contributed", 0))
		})
	members_out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var role_a: String = str(a.get("role", ROLE_MEMBER))
		var role_b: String = str(b.get("role", ROLE_MEMBER))
		if role_a != role_b:
			return _role_rank(role_a) < _role_rank(role_b)
		return int(a.get("honey_contributed", 0)) > int(b.get("honey_contributed", 0))
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
		"total_honey_contributed": int(hive.get("total_honey_contributed", 0)),
		"hive_honey_strength": int(hive.get("hive_honey_strength", 0)),
		"rank_points": _compute_hive_rank_points(hive)
	}

func _build_invite_snapshot(invite: Dictionary) -> Dictionary:
	return {
		"invite_id": str(invite.get("invite_id", "")),
		"hive_id": str(invite.get("hive_id", "")),
		"target_player_id": str(invite.get("target_player_id", "")),
		"target_display_name": str(invite.get("target_display_name", "")),
		"created_by_player_id": str(invite.get("created_by_player_id", "")),
		"created_by_display_name": str(invite.get("created_by_display_name", "")),
		"role": str(invite.get("role", ROLE_MEMBER)),
		"status": str(invite.get("status", INVITE_STATUS_PENDING)),
		"created_at_unix": int(invite.get("created_at_unix", 0)),
		"responded_at_unix": int(invite.get("responded_at_unix", 0))
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
	return {
		"invite_id": str(raw.get("invite_id", "")).strip_edges(),
		"hive_id": str(raw.get("hive_id", "")).strip_edges(),
		"target_player_id": _sanitize_player_id(str(raw.get("target_player_id", ""))),
		"target_display_name": _sanitize_display_name(str(raw.get("target_display_name", ""))),
		"created_by_player_id": _sanitize_player_id(str(raw.get("created_by_player_id", ""))),
		"created_by_display_name": _sanitize_display_name(str(raw.get("created_by_display_name", ""))),
		"role": _sanitize_role(str(raw.get("role", ROLE_MEMBER))),
		"status": _sanitize_invite_status(str(raw.get("status", INVITE_STATUS_PENDING))),
		"created_at_unix": maxi(0, int(raw.get("created_at_unix", 0))),
		"responded_at_unix": maxi(0, int(raw.get("responded_at_unix", 0)))
	}

func _sanitize_member(raw: Dictionary) -> Dictionary:
	var player_id: String = _sanitize_player_id(str(raw.get("player_id", "")))
	return {
		"player_id": player_id,
		"display_name": _display_name_for_player(player_id, str(raw.get("display_name", ""))),
		"role": _sanitize_role(str(raw.get("role", ROLE_MEMBER))),
		"joined_at_unix": maxi(0, int(raw.get("joined_at_unix", 0))),
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

func _can_manage_invites(hive: Dictionary, player_id: String) -> bool:
	var role: String = _role_for_player(hive, player_id)
	return role == ROLE_QUEEN or role == ROLE_SOLDIER

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
		INVITE_STATUS_ACCEPTED, INVITE_STATUS_DECLINED:
			return clean_status
		_:
			return INVITE_STATUS_PENDING

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
