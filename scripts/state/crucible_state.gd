extends Node

const SFLog = preload("res://scripts/util/sf_log.gd")
const CrucibleConfigScript = preload("res://scripts/state/crucible_config.gd")
const CrucibleStakeCalculatorScript = preload("res://scripts/state/crucible_stake_calculator.gd")
const CrucibleRulesetPolicyScript = preload("res://scripts/state/crucible_ruleset_policy.gd")
const WaxRewardPolicyScript = preload("res://scripts/state/wax_reward_policy.gd")

signal crucible_state_changed(snapshot: Dictionary)
signal crucible_event(event: Dictionary)

const CONFIG_PATH: String = "res://data/crucible/crucible_config.tres"
const SAVE_PATH_DEFAULT: String = "user://crucible_state.json"

const STATUS_ESCROWED: String = "ESCROWED"
const STATUS_SETTLED: String = "SETTLED"
const STATUS_REFUNDED: String = "REFUNDED"
const STATUS_NO_CONTEST: String = "NO_CONTEST"
const STATUS_HELD_REVIEW: String = "HELD_REVIEW"
const STATUS_FAILED: String = "FAILED"

const LEDGER_ESCROW_DEBIT: String = "ESCROW_DEBIT"
const LEDGER_ESCROW_REFUND: String = "ESCROW_REFUND"
const LEDGER_BURN: String = "BURN"
const LEDGER_WINNER_PAYOUT: String = "WINNER_PAYOUT"
const LEDGER_COMPETITIVE_WAX_AWARD: String = "COMPETITIVE_WAX_AWARD"
const LEDGER_COMPETITIVE_WAX_LOSS: String = "COMPETITIVE_WAX_LOSS"

var save_path: String = SAVE_PATH_DEFAULT

var _config: CrucibleConfigScript = null
var _balances_by_player: Dictionary = {}
var _escrows_by_id: Dictionary = {}
var _escrow_by_match_id: Dictionary = {}
var _settlements_by_match_id: Dictionary = {}
var _review_records_by_match_id: Dictionary = {}
var _competitive_wax_awards_by_event: Dictionary = {}
var _wax_stats_by_player: Dictionary = {}
var _ledger_entries: Array = []
var _audit_records: Array = []
var _anti_collusion_observations: Array = []

func _ready() -> void:
	SFLog.allow_tag("CRUCIBLE_EVENT")
	_load_config()
	_load_state()
	_emit_changed()

func get_config_snapshot() -> Dictionary:
	_ensure_config()
	return {
		"enabled": _config.enabled,
		"queue_enabled": _config.queue_enabled,
		"wagering_enabled": _config.wagering_enabled,
		"ads_enabled": _config.ads_enabled,
		"capacity_cap_enabled": _config.capacity_cap_enabled,
		"settlement_enabled": _config.settlement_enabled,
		"earn_path_buttons_enabled": _config.earn_path_buttons_enabled,
		"config_version": _config.config_version,
		"config_hash": _config.config_hash(),
		"capacity_max": _config.capacity_max,
		"reserved_slots": _config.reserved_slots,
		"priority_access_enabled": _config.priority_access_enabled,
		"pre_ad_seconds": _config.pre_ad_seconds,
		"post_ad_seconds": _config.post_ad_seconds,
		"banner_ads_enabled": _config.banner_ads_enabled,
		"ticker_ads_enabled": _config.ticker_ads_enabled,
		"stake_bps": _config.stake_bps,
		"burn_bps": _config.burn_bps,
		"minimum_stake_millis": _config.minimum_stake_millis,
		"rounding_mode": _config.normalized_rounding_mode(),
		"starting_crucible_wax_millis": _config.starting_crucible_wax_millis,
		"launch_grant_enabled": _config.launch_grant_enabled,
		"launch_grant_millis": _config.launch_grant_millis,
		"standard_pvp_win_earn_millis": _config.standard_pvp_win_earn_millis,
		"standard_pvp_loss_earn_millis": _config.standard_pvp_loss_earn_millis,
		"tournament_placement_earn_millis": _config.tournament_placement_earn_millis,
		"challenge_earn_millis": _config.challenge_earn_millis,
		"event_earn_millis": _config.event_earn_millis,
		"server_authoritative_settlement_required": _config.server_authoritative_settlement_required,
		"local_dev_settlement_enabled": _config.local_dev_settlement_enabled
	}

func get_snapshot() -> Dictionary:
	return {
		"config": get_config_snapshot(),
		"balances_by_player": _balances_by_player.duplicate(true),
		"escrows_by_id": _escrows_by_id.duplicate(true),
		"settlements_by_match_id": _settlements_by_match_id.duplicate(true),
		"review_records_by_match_id": _review_records_by_match_id.duplicate(true),
		"competitive_wax_awards_by_event": _competitive_wax_awards_by_event.duplicate(true),
		"wax_stats_by_player": _wax_stats_by_player.duplicate(true),
		"ledger_entries": _ledger_entries.duplicate(true),
		"audit_records": _audit_records.duplicate(true),
		"anti_collusion_observations": _anti_collusion_observations.duplicate(true)
	}

func intent_update_config(patch: Dictionary, actor_id: String = "ops") -> Dictionary:
	if _server_authoritative_enabled():
		var backend: Node = _handshake_backend()
		if backend == null or not backend.has_method("update_crucible_config"):
			return _error("transport_not_configured", "Crucible backend is not configured.")
		var remote_result: Dictionary = backend.call("update_crucible_config", patch, actor_id) as Dictionary
		if bool(remote_result.get("ok", false)):
			_apply_config_patch(_safe_dictionary(remote_result.get("config", patch)))
			_emit_changed()
		return remote_result
	_apply_config_patch(patch)
	_emit_event("crucible_config_updated", {"actor_id": actor_id, "config": get_config_snapshot()})
	_emit_changed()
	return {"ok": true, "config": get_config_snapshot()}

func apply_remote_config_snapshot(snapshot: Dictionary) -> Dictionary:
	var patch: Dictionary = snapshot.duplicate(true)
	if patch.has("config_hash"):
		patch.erase("config_hash")
	_apply_config_patch(patch)
	_emit_event("crucible_config_refreshed", {"config": get_config_snapshot()})
	_emit_changed()
	return {"ok": true, "config": get_config_snapshot()}

func get_balance_millis(player_id: String) -> int:
	var clean_id: String = player_id.strip_edges()
	if clean_id.is_empty():
		return 0
	_ensure_player(clean_id)
	return maxi(0, int(_balances_by_player.get(clean_id, 0)))

func intent_set_balance_millis(player_id: String, balance_millis: int) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id.is_empty():
		return _error("missing_player_id", "Player id is required.")
	_balances_by_player[clean_id] = maxi(0, balance_millis)
	_save_state()
	_emit_changed()
	return {"ok": true, "player_id": clean_id, "balance_millis": int(_balances_by_player.get(clean_id, 0))}

func preview_match(player_a_id: String, player_b_id: String) -> Dictionary:
	var a: String = player_a_id.strip_edges()
	var b: String = player_b_id.strip_edges()
	if a.is_empty() or b.is_empty():
		return _error("missing_player_ids", "Both player ids are required.")
	if a == b:
		return _error("same_player_ids", "Crucible requires two distinct players.")
	_ensure_player(a)
	_ensure_player(b)
	return CrucibleStakeCalculatorScript.preview_stake(get_balance_millis(a), get_balance_millis(b), _runtime_config())

func preview_player_stake(player_id: String) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id.is_empty():
		return _error("missing_player_id", "Player id is required.")
	_ensure_player(clean_id)
	return CrucibleStakeCalculatorScript.preview_stake(get_balance_millis(clean_id), get_balance_millis(clean_id), _runtime_config())

func preview_entry_status(player_id: String, active_crucible_count: int = 0, has_priority_access: bool = false) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id.is_empty():
		return _error("missing_player_id", "Player id is required.")
	if _server_authoritative_enabled():
		var backend: Node = _handshake_backend()
		if backend == null or not backend.has_method("preview_crucible_entry"):
			return _error("transport_not_configured", "Crucible backend is not configured.")
		return backend.call("preview_crucible_entry", clean_id, get_balance_millis(clean_id), active_crucible_count, has_priority_access) as Dictionary
	_emit_event("crucible_enter_attempt", {"player_id": clean_id})
	var config: CrucibleConfigScript = _runtime_config()
	if not config.enabled or not config.queue_enabled:
		return _entry_blocked(clean_id, "queue_disabled", "Crucible queue is disabled.")
	if config.capacity_cap_enabled and not has_priority_access:
		var usable_capacity: int = maxi(0, config.capacity_max - maxi(0, config.reserved_slots))
		if active_crucible_count >= usable_capacity:
			return _entry_blocked(clean_id, "capacity", "Crucible at capacity.")
	_ensure_player(clean_id)
	if get_balance_millis(clean_id) < maxi(1, config.minimum_stake_millis):
		return _entry_blocked(clean_id, "no_wax", "Your Wax Has Melted.")
	return {
		"ok": true,
		"player_id": clean_id,
		"balance_millis": get_balance_millis(clean_id),
		"capacity_checked": config.capacity_cap_enabled,
		"active_crucible_count": maxi(0, active_crucible_count)
	}

func record_anti_collusion_observation(match_id: String, player_a_id: String, player_b_id: String, signals: Dictionary = {}) -> Dictionary:
	var clean_match_id: String = match_id.strip_edges()
	var a: String = player_a_id.strip_edges()
	var b: String = player_b_id.strip_edges()
	if clean_match_id.is_empty() or a.is_empty() or b.is_empty():
		return _error("missing_observation_fields", "Match and player ids are required.")
	var event: Dictionary = {
		"match_id": clean_match_id,
		"player_a_id": a,
		"player_b_id": b,
		"repeated_same_opponent": bool(signals.get("repeated_same_opponent", false)),
		"unusual_win_trading": bool(signals.get("unusual_win_trading", false)),
		"same_device_cluster": bool(signals.get("same_device_cluster", false)),
		"same_ip_pattern": bool(signals.get("same_ip_pattern", false)),
		"suspicious_forfeit": bool(signals.get("suspicious_forfeit", false)),
		"high_stakes_repeated_transfer": bool(signals.get("high_stakes_repeated_transfer", false)),
		"signals": signals.duplicate(true)
	}
	_anti_collusion_observations.append(event.duplicate(true))
	_emit_event("crucible_anti_collusion_observation", event)
	_save_state()
	_emit_changed()
	return {"ok": true, "event": event}

func intent_open_escrow(match_id: String, player_a_id: String, player_b_id: String, metadata: Dictionary = {}) -> Dictionary:
	var clean_match_id: String = match_id.strip_edges()
	var a: String = player_a_id.strip_edges()
	var b: String = player_b_id.strip_edges()
	if clean_match_id.is_empty():
		return _error("missing_match_id", "Match id is required.")
	if a.is_empty() or b.is_empty():
		return _error("missing_player_ids", "Both player ids are required.")
	if a == b:
		return _error("same_player_ids", "Crucible requires two distinct players.")
	if _server_authoritative_enabled():
		return _open_remote_escrow(clean_match_id, a, b, metadata)
	if _escrow_by_match_id.has(clean_match_id):
		var existing_id: String = str(_escrow_by_match_id.get(clean_match_id, ""))
		return {"ok": true, "escrow": (_escrows_by_id.get(existing_id, {}) as Dictionary).duplicate(true), "idempotent": true}
	if not _runtime_config().settlement_enabled:
		return _error("settlement_disabled", "Crucible settlement is disabled.")
	var preview: Dictionary = preview_match(a, b)
	if not bool(preview.get("ok", false)):
		return preview
	var stake_each: int = int(preview.get("stake_each", 0))
	_balances_by_player[a] = get_balance_millis(a) - stake_each
	_balances_by_player[b] = get_balance_millis(b) - stake_each
	var escrow_id: String = str(metadata.get("escrow_id", "")).strip_edges()
	if escrow_id.is_empty():
		escrow_id = "ce_%s_%d" % [clean_match_id.sha256_text().substr(0, 12), Time.get_ticks_msec()]
	var now_unix: int = _now_unix()
	var escrow: Dictionary = {
		"escrow_id": escrow_id,
		"match_id": clean_match_id,
		"ruleset": CrucibleRulesetPolicyScript.RULESET_CRUCIBLE,
		"player_a_id": a,
		"player_b_id": b,
		"stake_each": stake_each,
		"stake_unit": "wax_millis",
		"pot": int(preview.get("pot", 0)),
		"burn": int(preview.get("burn", 0)),
		"winner_payout": int(preview.get("winner_payout", 0)),
		"config_version": int(preview.get("config_version", _runtime_config().config_version)),
		"config_hash": str(preview.get("config_hash", _runtime_config().config_hash())),
		"settlement_status": STATUS_ESCROWED,
		"created_at": now_unix,
		"metadata": metadata.duplicate(true)
	}
	_escrows_by_id[escrow_id] = escrow
	_escrow_by_match_id[clean_match_id] = escrow_id
	_append_ledger(LEDGER_ESCROW_DEBIT, clean_match_id, a, -stake_each, escrow_id, {"side": "A"})
	_append_ledger(LEDGER_ESCROW_DEBIT, clean_match_id, b, -stake_each, escrow_id, {"side": "B"})
	_emit_event("crucible_wax_staked", {"match_id": clean_match_id, "escrow_id": escrow_id, "stake_each": stake_each})
	record_anti_collusion_observation(clean_match_id, a, b, _safe_dictionary(metadata.get("anti_collusion_signals", {})))
	_save_state()
	_emit_changed()
	return {"ok": true, "escrow": escrow.duplicate(true)}

func intent_settle_match(match_id: String, winner_id: String, result_source: String, reason: String = "", metadata: Dictionary = {}) -> Dictionary:
	var clean_match_id: String = match_id.strip_edges()
	if clean_match_id.is_empty():
		return _error("missing_match_id", "Match id is required.")
	if _server_authoritative_enabled():
		return _settle_remote_match(clean_match_id, winner_id.strip_edges(), result_source, reason, metadata)
	if _settlements_by_match_id.has(clean_match_id):
		return {
			"ok": true,
			"settlement": (_settlements_by_match_id.get(clean_match_id, {}) as Dictionary).duplicate(true),
			"idempotent": true
		}
	var escrow: Dictionary = _escrow_for_match(clean_match_id)
	if escrow.is_empty():
		return _error("escrow_not_found", "Crucible escrow was not found.")
	var clean_source: String = result_source.strip_edges().to_upper()
	if _runtime_config().server_authoritative_settlement_required and clean_source != CrucibleRulesetPolicyScript.RESULT_SOURCE_SERVER_MATCH_RESULT:
		return _no_contest_from_escrow(escrow, clean_source, "server_authoritative_settlement_required", metadata)
	if not CrucibleRulesetPolicyScript.result_source_allowed(clean_source, _runtime_config().local_dev_settlement_enabled):
		return _no_contest_from_escrow(escrow, clean_source, "invalid_result_source", metadata)
	var clean_winner: String = winner_id.strip_edges()
	var player_a: String = str(escrow.get("player_a_id", ""))
	var player_b: String = str(escrow.get("player_b_id", ""))
	if clean_winner.is_empty() or clean_winner == "0" or (clean_winner != player_a and clean_winner != player_b):
		return _no_contest_from_escrow(escrow, clean_source, reason if not reason.is_empty() else "no_winner", metadata)
	var loser: String = player_b if clean_winner == player_a else player_a
	var burn: int = maxi(0, int(escrow.get("burn", 0)))
	var payout: int = maxi(0, int(escrow.get("winner_payout", 0)))
	var risk: Dictionary = _risk_assessment(escrow, metadata)
	if bool(risk.get("hold", false)):
		var held: Dictionary = _settlement_record(escrow, STATUS_HELD_REVIEW, clean_winner, loser, clean_source, reason if not reason.is_empty() else "held_for_review", metadata)
		held["burn"] = 0
		held["winner_payout"] = 0
		held["review_status"] = "held"
		held["review_reasons"] = risk.get("reasons", [])
		_settlements_by_match_id[clean_match_id] = held
		_review_records_by_match_id[clean_match_id] = held.duplicate(true)
		_update_escrow_status(str(escrow.get("escrow_id", "")), STATUS_HELD_REVIEW)
		_audit_records.append(held.duplicate(true))
		_emit_event("crucible_settlement_held", held)
		_save_state()
		_emit_changed()
		return {"ok": true, "settlement": held.duplicate(true)}
	_balances_by_player[clean_winner] = get_balance_millis(clean_winner) + payout
	var settlement: Dictionary = _settlement_record(escrow, STATUS_SETTLED, clean_winner, loser, clean_source, reason, metadata)
	_settlements_by_match_id[clean_match_id] = settlement
	_update_escrow_status(str(escrow.get("escrow_id", "")), STATUS_SETTLED)
	if burn > 0:
		_append_ledger(LEDGER_BURN, clean_match_id, "", -burn, str(escrow.get("escrow_id", "")), {})
		_emit_event("crucible_wax_burned", {"match_id": clean_match_id, "burn": burn})
	if payout > 0:
		_append_ledger(LEDGER_WINNER_PAYOUT, clean_match_id, clean_winner, payout, str(escrow.get("escrow_id", "")), {})
		_emit_event("crucible_wax_awarded", {"match_id": clean_match_id, "winner_id": clean_winner, "winner_payout": payout})
	var loser_burn_share: int = int(floor(float(burn) / 2.0))
	var winner_burn_share: int = maxi(0, burn - loser_burn_share)
	_apply_wax_stats(clean_winner, payout, winner_burn_share)
	_apply_wax_stats(loser, -maxi(0, int(escrow.get("stake_each", 0))), loser_burn_share)
	_audit_records.append(settlement.duplicate(true))
	_emit_event("crucible_match_completed", settlement)
	_save_state()
	_emit_changed()
	return {"ok": true, "settlement": settlement.duplicate(true)}

func intent_resolve_review(match_id: String, action: String, actor_id: String = "ops", metadata: Dictionary = {}) -> Dictionary:
	var clean_match_id: String = match_id.strip_edges()
	var clean_action: String = action.strip_edges().to_lower()
	if clean_match_id.is_empty():
		return _error("missing_match_id", "Match id is required.")
	if _server_authoritative_enabled():
		var backend: Node = _handshake_backend()
		if backend == null or not backend.has_method("resolve_crucible_review"):
			return _error("transport_not_configured", "Crucible backend is not configured.")
		var remote_result: Dictionary = backend.call("resolve_crucible_review", clean_match_id, clean_action, actor_id, metadata, "review:%s:%s" % [clean_match_id, clean_action]) as Dictionary
		if bool(remote_result.get("ok", false)):
			_mirror_remote_settlement(remote_result.get("settlement", {}) as Dictionary)
		return remote_result
	var held: Dictionary = _safe_dictionary(_review_records_by_match_id.get(clean_match_id, {}))
	if held.is_empty() or str(held.get("settlement_status", "")) != STATUS_HELD_REVIEW:
		return _error("review_not_found", "No held Crucible settlement was found for this match.")
	var escrow: Dictionary = _escrow_for_match(clean_match_id)
	if escrow.is_empty():
		return _error("escrow_not_found", "Crucible escrow was not found.")
	if clean_action == "approve" or clean_action == "release":
		var winner_id: String = str(held.get("winner_id", "")).strip_edges()
		return _release_held_settlement(escrow, winner_id, actor_id, metadata)
	if clean_action == "refund" or clean_action == "void":
		return _refund_held_settlement(escrow, clean_action, actor_id, metadata)
	return _error("unknown_review_action", "Review action must be approve or refund.")

func intent_refund_match(match_id: String, reason: String = "refund") -> Dictionary:
	if _server_authoritative_enabled():
		var clean_match_id: String = match_id.strip_edges()
		var backend: Node = _handshake_backend()
		if backend == null or not backend.has_method("refund_crucible_match"):
			return _error("transport_not_configured", "Crucible backend is not configured.")
		var remote_result: Dictionary = backend.call("refund_crucible_match", clean_match_id, reason, {}, "refund:%s:%s" % [clean_match_id, reason]) as Dictionary
		if bool(remote_result.get("ok", false)):
			_mirror_remote_settlement(remote_result.get("settlement", {}) as Dictionary)
		return remote_result
	var escrow: Dictionary = _escrow_for_match(match_id.strip_edges())
	if escrow.is_empty():
		return _error("escrow_not_found", "Crucible escrow was not found.")
	return _refund_from_escrow(escrow, reason, {})

func intent_record_lifecycle(match_id: String, event_type: String, player_id: String = "", metadata: Dictionary = {}) -> Dictionary:
	var clean_match_id: String = match_id.strip_edges()
	var clean_event: String = event_type.strip_edges().to_lower()
	if clean_match_id.is_empty() or clean_event.is_empty():
		return _error("missing_lifecycle_fields", "Match id and lifecycle event are required.")
	if _server_authoritative_enabled():
		var backend: Node = _handshake_backend()
		if backend == null or not backend.has_method("record_crucible_lifecycle"):
			return _error("transport_not_configured", "Crucible backend is not configured.")
		var remote_result: Dictionary = backend.call("record_crucible_lifecycle", clean_match_id, clean_event, player_id, metadata) as Dictionary
		if bool(remote_result.get("ok", false)):
			_mirror_remote_settlement(remote_result.get("settlement", {}) as Dictionary)
		return remote_result
	if ["cancel_before_first_tick", "desync", "no_contest"].has(clean_event) or bool(metadata.get("server_fault", false)):
		var escrow: Dictionary = _escrow_for_match(clean_match_id)
		if escrow.is_empty():
			return _error("escrow_not_found", "Crucible escrow was not found.")
		return _no_contest_from_escrow(escrow, CrucibleRulesetPolicyScript.RESULT_SOURCE_AUTHORITATIVE_SIM, clean_event, metadata)
	if ["voluntary_quit", "disconnect_after_start", "forfeit"].has(clean_event):
		var escrow_for_forfeit: Dictionary = _escrow_for_match(clean_match_id)
		if escrow_for_forfeit.is_empty():
			return _error("escrow_not_found", "Crucible escrow was not found.")
		var loser_id: String = player_id.strip_edges()
		var player_a: String = str(escrow_for_forfeit.get("player_a_id", ""))
		var player_b: String = str(escrow_for_forfeit.get("player_b_id", ""))
		var winner_id: String = player_b if loser_id == player_a else player_a if loser_id == player_b else ""
		return intent_settle_match(clean_match_id, winner_id, CrucibleRulesetPolicyScript.RESULT_SOURCE_AUTHORITATIVE_SIM, clean_event, metadata)
	return _error("unknown_lifecycle_event", "Unknown Crucible lifecycle event.")

func intent_award_earn_path(player_id: String, earn_path: String, metadata: Dictionary = {}) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	var path: String = earn_path.strip_edges().to_upper()
	if clean_id.is_empty():
		return _error("missing_player_id", "Player id is required.")
	var amount: int = _earn_amount_for_path(path, metadata)
	if amount <= 0:
		return {"ok": true, "awarded": false, "player_id": clean_id, "earn_path": path, "amount_millis": 0}
	if _server_authoritative_enabled():
		var backend: Node = _handshake_backend()
		if backend == null or not backend.has_method("award_crucible_wax"):
			return _error("transport_not_configured", "Crucible backend is not configured.")
		var remote_result: Dictionary = backend.call("award_crucible_wax", clean_id, amount, path, metadata) as Dictionary
		if bool(remote_result.get("ok", false)) and remote_result.has("balance_millis"):
			_balances_by_player[clean_id] = maxi(0, int(remote_result.get("balance_millis", 0)))
			_save_state()
			_emit_changed()
		return remote_result
	_balances_by_player[clean_id] = get_balance_millis(clean_id) + amount
	_append_ledger("EARN", str(metadata.get("match_id", "")), clean_id, amount, "", {"earn_path": path, "metadata": metadata.duplicate(true)})
	_emit_event("crucible_wax_earned", {"player_id": clean_id, "earn_path": path, "amount_millis": amount})
	_save_state()
	_emit_changed()
	return {"ok": true, "awarded": true, "player_id": clean_id, "earn_path": path, "amount_millis": amount, "balance_millis": get_balance_millis(clean_id)}

func intent_apply_competitive_wax_result(match_id: String, player_id: String, opponent_id: String, did_win: bool, mode_name: String, metadata: Dictionary = {}) -> Dictionary:
	var clean_match_id: String = match_id.strip_edges()
	var clean_player: String = player_id.strip_edges()
	var clean_opponent: String = opponent_id.strip_edges()
	if clean_match_id.is_empty() or clean_player.is_empty():
		return _error("missing_wax_award_fields", "Match id and player id are required.")
	var event_id: String = str(metadata.get("event_id", "competitive_wax:%s:%s" % [clean_match_id, clean_player])).strip_edges()
	if _competitive_wax_awards_by_event.has(event_id):
		var existing: Dictionary = _safe_dictionary(_competitive_wax_awards_by_event.get(event_id, {}))
		_emit_event("wax_duplicate_ignored", existing)
		return {"ok": true, "awarded": false, "duplicate": true, "event_id": event_id, "award": existing.duplicate(true)}
	var payload: Dictionary = metadata.duplicate(true)
	payload["match_id"] = clean_match_id
	payload["player_id"] = clean_player
	payload["opponent_id"] = clean_opponent
	payload["did_win"] = did_win
	payload["mode_name"] = mode_name
	var breakdown: Dictionary = WaxRewardPolicyScript.evaluate_match(payload)
	breakdown["event_id"] = event_id
	_competitive_wax_awards_by_event[event_id] = breakdown.duplicate(true)
	var status: String = str(breakdown.get("validity_status", "eligible"))
	var delta_millis: int = int(breakdown.get("final_wax_delta_millis", 0))
	if status == "blocked" or delta_millis == 0:
		_emit_event("wax_blocked_antiharvest" if status == "blocked" else "wax_award_attempt", breakdown)
		_save_state()
		_emit_changed()
		return {"ok": true, "awarded": false, "event_id": event_id, "breakdown": breakdown, "balance_millis": get_balance_millis(clean_player)}
	_ensure_player(clean_player)
	var applied_delta: int = delta_millis
	if delta_millis < 0:
		applied_delta = -mini(get_balance_millis(clean_player), absi(delta_millis))
	_balances_by_player[clean_player] = maxi(0, get_balance_millis(clean_player) + applied_delta)
	_apply_wax_stats(clean_player, applied_delta, 0)
	var entry_type: String = LEDGER_COMPETITIVE_WAX_AWARD if applied_delta > 0 else LEDGER_COMPETITIVE_WAX_LOSS
	var ledger_entry: Dictionary = _append_ledger(entry_type, clean_match_id, clean_player, applied_delta, "", {
		"event_id": event_id,
		"opponent_id": clean_opponent,
		"breakdown": breakdown.duplicate(true)
	})
	var event_type: String = "wax_awarded" if applied_delta > 0 else "wax_subtracted"
	if bool(breakdown.get("close_loss_qualified", false)) and applied_delta > 0 and not did_win:
		event_type = "wax_close_loss_awarded"
	elif str(breakdown.get("validity_status", "")) == "diminished":
		event_type = "wax_repeated_opponent_diminished"
	breakdown["applied_wax_delta_millis"] = applied_delta
	breakdown["balance_millis"] = get_balance_millis(clean_player)
	breakdown["ledger_entry_id"] = str(ledger_entry.get("entry_id", ""))
	_competitive_wax_awards_by_event[event_id] = breakdown.duplicate(true)
	_emit_event(event_type, breakdown)
	_save_state()
	_emit_changed()
	return {
		"ok": true,
		"awarded": applied_delta > 0,
		"subtracted": applied_delta < 0,
		"event_id": event_id,
		"breakdown": breakdown,
		"balance_millis": get_balance_millis(clean_player)
	}

func validate_purity(payload: Dictionary = {}) -> Dictionary:
	var violations: Array[String] = []
	if bool(payload.get("buffs_selected", false)):
		violations.append("buffs_selected")
	if bool(payload.get("active_buff_effects", false)):
		violations.append("active_buff_effects")
	if bool(payload.get("consumables_selected", false)):
		violations.append("consumables_selected")
	if bool(payload.get("paid_modifiers_enabled", false)):
		violations.append("paid_modifiers_enabled")
	if bool(payload.get("battle_pass_gameplay_modifiers_enabled", false)):
		violations.append("battle_pass_gameplay_modifiers_enabled")
	if bool(payload.get("honey_rewards_enabled", false)):
		violations.append("honey_rewards_enabled")
	if bool(payload.get("nectar_rewards_enabled", false)):
		violations.append("nectar_rewards_enabled")
	if bool(payload.get("normal_rank_wax_payout_enabled", false)):
		violations.append("normal_rank_wax_payout_enabled")
	if violations.is_empty():
		return {"ok": true}
	var event: Dictionary = {"violations": violations, "payload": payload.duplicate(true)}
	_emit_event("crucible_purity_validation_failed", event)
	return {"ok": false, "code": "purity_violation", "violations": violations}

func debug_reset_state() -> void:
	_balances_by_player.clear()
	_escrows_by_id.clear()
	_escrow_by_match_id.clear()
	_settlements_by_match_id.clear()
	_review_records_by_match_id.clear()
	_competitive_wax_awards_by_event.clear()
	_wax_stats_by_player.clear()
	_ledger_entries.clear()
	_audit_records.clear()
	_anti_collusion_observations.clear()
	_save_state()
	_emit_changed()

func _open_remote_escrow(match_id: String, player_a_id: String, player_b_id: String, metadata: Dictionary) -> Dictionary:
	var backend: Node = _handshake_backend()
	if backend == null or not backend.has_method("open_crucible_escrow"):
		return _error("transport_not_configured", "Crucible backend is not configured.")
	var remote_metadata: Dictionary = metadata.duplicate(true)
	var config_version: int = _runtime_config().config_version
	var config_hash: String = _runtime_config().config_hash()
	if backend.has_method("get_crucible_config"):
		var remote_config: Dictionary = backend.call("get_crucible_config") as Dictionary
		if bool(remote_config.get("ok", false)):
			var remote_snapshot: Dictionary = _safe_dictionary(remote_config.get("config", remote_config))
			config_version = int(remote_snapshot.get("config_version", config_version))
			config_hash = str(remote_snapshot.get("config_hash", config_hash)).strip_edges()
	remote_metadata["expected_config_version"] = config_version
	if not config_hash.is_empty():
		remote_metadata["expected_config_hash"] = config_hash
	remote_metadata["player_balance_millis_by_id"] = {
		player_a_id: get_balance_millis(player_a_id),
		player_b_id: get_balance_millis(player_b_id)
	}
	var remote_result: Dictionary = backend.call(
		"open_crucible_escrow",
		match_id,
		player_a_id,
		player_b_id,
		remote_metadata,
		"open:%s" % match_id
	) as Dictionary
	if bool(remote_result.get("ok", false)):
		_mirror_remote_escrow(_safe_dictionary(remote_result.get("escrow", {})))
	return remote_result

func _settle_remote_match(match_id: String, winner_id: String, result_source: String, reason: String, metadata: Dictionary) -> Dictionary:
	var backend: Node = _handshake_backend()
	if backend == null or not backend.has_method("settle_crucible_match"):
		return _error("transport_not_configured", "Crucible backend is not configured.")
	var remote_result: Dictionary = backend.call(
		"settle_crucible_match",
		match_id,
		winner_id,
		result_source,
		reason,
		metadata,
		"settle:%s:%s:%s" % [match_id, winner_id if not winner_id.is_empty() else "none", result_source.strip_edges().to_upper()]
	) as Dictionary
	if bool(remote_result.get("ok", false)):
		_mirror_remote_settlement(_safe_dictionary(remote_result.get("settlement", {})))
	return remote_result

func _mirror_remote_escrow(escrow: Dictionary) -> void:
	var escrow_id: String = str(escrow.get("escrow_id", "")).strip_edges()
	var match_id: String = str(escrow.get("match_id", "")).strip_edges()
	if escrow_id.is_empty() or match_id.is_empty():
		return
	_escrows_by_id[escrow_id] = escrow.duplicate(true)
	_escrow_by_match_id[match_id] = escrow_id
	_save_state()
	_emit_changed()

func _mirror_remote_settlement(settlement: Dictionary) -> void:
	var match_id: String = str(settlement.get("match_id", "")).strip_edges()
	if match_id.is_empty():
		return
	_settlements_by_match_id[match_id] = settlement.duplicate(true)
	if str(settlement.get("settlement_status", "")) == STATUS_HELD_REVIEW or str(settlement.get("review_status", "")).strip_edges() != "":
		_review_records_by_match_id[match_id] = settlement.duplicate(true)
	var escrow_id: String = str(settlement.get("escrow_id", "")).strip_edges()
	if not escrow_id.is_empty() and _escrows_by_id.has(escrow_id):
		_update_escrow_status(escrow_id, str(settlement.get("settlement_status", STATUS_SETTLED)))
	_audit_records.append(settlement.duplicate(true))
	_save_state()
	_emit_changed()

func _server_authoritative_enabled() -> bool:
	return _runtime_config().server_authoritative_settlement_required

func _handshake_backend() -> Node:
	return get_node_or_null("/root/VsHandshake")

func _apply_config_patch(patch: Dictionary) -> void:
	_ensure_config()
	for key in patch.keys():
		match str(key):
			"enabled":
				_config.enabled = bool(patch[key])
			"queue_enabled":
				_config.queue_enabled = bool(patch[key])
			"wagering_enabled":
				_config.wagering_enabled = bool(patch[key])
			"ads_enabled":
				_config.ads_enabled = bool(patch[key])
			"capacity_cap_enabled":
				_config.capacity_cap_enabled = bool(patch[key])
			"settlement_enabled":
				_config.settlement_enabled = bool(patch[key])
			"earn_path_buttons_enabled":
				_config.earn_path_buttons_enabled = bool(patch[key])
			"config_version":
				_config.config_version = maxi(1, int(patch[key]))
			"capacity_max":
				_config.capacity_max = maxi(0, int(patch[key]))
			"reserved_slots":
				_config.reserved_slots = maxi(0, int(patch[key]))
			"stake_bps":
				_config.stake_bps = clampi(int(patch[key]), 0, 10000)
			"burn_bps":
				_config.burn_bps = clampi(int(patch[key]), 0, 10000)
			"minimum_stake_millis":
				_config.minimum_stake_millis = maxi(1, int(patch[key]))
			"starting_crucible_wax_millis":
				_config.starting_crucible_wax_millis = maxi(0, int(patch[key]))
			"launch_grant_enabled":
				_config.launch_grant_enabled = bool(patch[key])
			"launch_grant_millis":
				_config.launch_grant_millis = maxi(0, int(patch[key]))
			"standard_pvp_win_earn_millis":
				_config.standard_pvp_win_earn_millis = maxi(0, int(patch[key]))
			"standard_pvp_loss_earn_millis":
				_config.standard_pvp_loss_earn_millis = maxi(0, int(patch[key]))
			"tournament_placement_earn_millis":
				_config.tournament_placement_earn_millis = maxi(0, int(patch[key]))
			"challenge_earn_millis":
				_config.challenge_earn_millis = maxi(0, int(patch[key]))
			"event_earn_millis":
				_config.event_earn_millis = maxi(0, int(patch[key]))
			"server_authoritative_settlement_required":
				_config.server_authoritative_settlement_required = bool(patch[key])
			"local_dev_settlement_enabled":
				_config.local_dev_settlement_enabled = bool(patch[key])
			"rounding_mode":
				_config.rounding_mode = str(patch[key]).strip_edges().to_upper()

func _no_contest_from_escrow(escrow: Dictionary, result_source: String, reason: String, metadata: Dictionary) -> Dictionary:
	var refund_result: Dictionary = _refund_from_escrow(escrow, reason if not reason.is_empty() else "no_contest", metadata, STATUS_NO_CONTEST, result_source)
	_emit_event("crucible_match_no_contest", refund_result.get("settlement", {}) as Dictionary)
	return refund_result

func _refund_from_escrow(
		escrow: Dictionary,
		reason: String,
		metadata: Dictionary = {},
		status: String = STATUS_REFUNDED,
		result_source: String = ""
	) -> Dictionary:
	var match_id: String = str(escrow.get("match_id", ""))
	if _settlements_by_match_id.has(match_id):
		return {
			"ok": true,
			"settlement": (_settlements_by_match_id.get(match_id, {}) as Dictionary).duplicate(true),
			"idempotent": true
		}
	var stake_each: int = maxi(0, int(escrow.get("stake_each", 0)))
	var player_a: String = str(escrow.get("player_a_id", ""))
	var player_b: String = str(escrow.get("player_b_id", ""))
	_balances_by_player[player_a] = get_balance_millis(player_a) + stake_each
	_balances_by_player[player_b] = get_balance_millis(player_b) + stake_each
	var settlement: Dictionary = _settlement_record(escrow, status, "", "", result_source, reason, metadata)
	settlement["burn"] = 0
	settlement["winner_payout"] = 0
	_settlements_by_match_id[match_id] = settlement
	_update_escrow_status(str(escrow.get("escrow_id", "")), status)
	_append_ledger(LEDGER_ESCROW_REFUND, match_id, player_a, stake_each, str(escrow.get("escrow_id", "")), {"side": "A"})
	_append_ledger(LEDGER_ESCROW_REFUND, match_id, player_b, stake_each, str(escrow.get("escrow_id", "")), {"side": "B"})
	_audit_records.append(settlement.duplicate(true))
	_emit_event("crucible_escrow_refunded", settlement)
	_save_state()
	_emit_changed()
	return {"ok": true, "settlement": settlement.duplicate(true)}

func _release_held_settlement(escrow: Dictionary, winner_id: String, actor_id: String, metadata: Dictionary) -> Dictionary:
	var match_id: String = str(escrow.get("match_id", ""))
	var player_a: String = str(escrow.get("player_a_id", ""))
	var player_b: String = str(escrow.get("player_b_id", ""))
	if winner_id.is_empty() or (winner_id != player_a and winner_id != player_b):
		return _error("missing_held_winner", "Held settlement does not contain a valid winner.")
	var loser_id: String = player_b if winner_id == player_a else player_a
	var burn: int = maxi(0, int(escrow.get("burn", 0)))
	var payout: int = maxi(0, int(escrow.get("winner_payout", 0)))
	_balances_by_player[winner_id] = get_balance_millis(winner_id) + payout
	var settlement_metadata: Dictionary = metadata.duplicate(true)
	settlement_metadata["reviewed_by"] = actor_id
	var settlement: Dictionary = _settlement_record(escrow, STATUS_SETTLED, winner_id, loser_id, "ADMIN_REVIEW", "review_release", settlement_metadata)
	settlement["review_status"] = "approved"
	_settlements_by_match_id[match_id] = settlement
	_review_records_by_match_id[match_id] = settlement.duplicate(true)
	_update_escrow_status(str(escrow.get("escrow_id", "")), STATUS_SETTLED)
	if burn > 0:
		_append_ledger(LEDGER_BURN, match_id, "", -burn, str(escrow.get("escrow_id", "")), {"review_release": true, "actor_id": actor_id})
	if payout > 0:
		_append_ledger(LEDGER_WINNER_PAYOUT, match_id, winner_id, payout, str(escrow.get("escrow_id", "")), {"review_release": true, "actor_id": actor_id})
	var loser_burn_share: int = int(floor(float(burn) / 2.0))
	var winner_burn_share: int = maxi(0, burn - loser_burn_share)
	_apply_wax_stats(winner_id, payout, winner_burn_share)
	_apply_wax_stats(loser_id, -maxi(0, int(escrow.get("stake_each", 0))), loser_burn_share)
	_audit_records.append(settlement.duplicate(true))
	_emit_event("crucible_review_approved", settlement)
	_save_state()
	_emit_changed()
	return {"ok": true, "settlement": settlement.duplicate(true)}

func _refund_held_settlement(escrow: Dictionary, action: String, actor_id: String, metadata: Dictionary) -> Dictionary:
	var match_id: String = str(escrow.get("match_id", ""))
	var stake_each: int = maxi(0, int(escrow.get("stake_each", 0)))
	var player_a: String = str(escrow.get("player_a_id", ""))
	var player_b: String = str(escrow.get("player_b_id", ""))
	_balances_by_player[player_a] = get_balance_millis(player_a) + stake_each
	_balances_by_player[player_b] = get_balance_millis(player_b) + stake_each
	var settlement_metadata: Dictionary = metadata.duplicate(true)
	settlement_metadata["reviewed_by"] = actor_id
	var settlement: Dictionary = _settlement_record(escrow, STATUS_REFUNDED, "", "", "ADMIN_REVIEW", action if not action.is_empty() else "review_refund", settlement_metadata)
	settlement["burn"] = 0
	settlement["winner_payout"] = 0
	settlement["review_status"] = "refunded"
	_settlements_by_match_id[match_id] = settlement
	_review_records_by_match_id[match_id] = settlement.duplicate(true)
	_update_escrow_status(str(escrow.get("escrow_id", "")), STATUS_REFUNDED)
	_append_ledger(LEDGER_ESCROW_REFUND, match_id, player_a, stake_each, str(escrow.get("escrow_id", "")), {"review_refund": true, "actor_id": actor_id, "side": "A"})
	_append_ledger(LEDGER_ESCROW_REFUND, match_id, player_b, stake_each, str(escrow.get("escrow_id", "")), {"review_refund": true, "actor_id": actor_id, "side": "B"})
	_audit_records.append(settlement.duplicate(true))
	_emit_event("crucible_review_refunded", settlement)
	_save_state()
	_emit_changed()
	return {"ok": true, "settlement": settlement.duplicate(true)}

func _settlement_record(
		escrow: Dictionary,
		status: String,
		winner_id: String,
		loser_id: String,
		result_source: String,
		reason: String,
		metadata: Dictionary
	) -> Dictionary:
	var now_unix: int = _now_unix()
	var match_id: String = str(escrow.get("match_id", ""))
	return {
		"settlement_id": "cs_%s_%d" % [match_id.sha256_text().substr(0, 12), Time.get_ticks_msec()],
		"escrow_id": str(escrow.get("escrow_id", "")),
		"match_id": match_id,
		"ruleset": CrucibleRulesetPolicyScript.RULESET_CRUCIBLE,
		"player_a_id": str(escrow.get("player_a_id", "")),
		"player_b_id": str(escrow.get("player_b_id", "")),
		"stake_each": maxi(0, int(escrow.get("stake_each", 0))),
		"stake_unit": str(escrow.get("stake_unit", "wax_millis")),
		"pot": maxi(0, int(escrow.get("pot", 0))),
		"burn": maxi(0, int(escrow.get("burn", 0))),
		"winner_payout": maxi(0, int(escrow.get("winner_payout", 0))),
		"winner_id": winner_id,
		"loser_id": loser_id,
		"result_source": result_source,
		"settlement_mode": "LOCAL_DEV" if _runtime_config().local_dev_settlement_enabled else "SERVER",
		"config_version": int(escrow.get("config_version", _runtime_config().config_version)),
		"config_hash": str(escrow.get("config_hash", _runtime_config().config_hash())),
		"settlement_status": status,
		"idempotency_key": "settle:%s:%s" % [match_id, status],
		"reason": reason,
		"created_at": now_unix,
		"metadata": metadata.duplicate(true)
	}

func _append_ledger(entry_type: String, match_id: String, player_id: String, amount_millis: int, escrow_id: String, metadata: Dictionary) -> Dictionary:
	var entry: Dictionary = {
		"entry_id": "cle_%d_%d" % [Time.get_ticks_msec(), _ledger_entries.size()],
		"entry_type": entry_type,
		"match_id": match_id,
		"escrow_id": escrow_id,
		"player_id": player_id,
		"amount_millis": amount_millis,
		"created_at": _now_unix(),
		"metadata": metadata.duplicate(true)
	}
	_ledger_entries.append(entry)
	return entry

func _escrow_for_match(match_id: String) -> Dictionary:
	var escrow_id: String = str(_escrow_by_match_id.get(match_id, ""))
	if escrow_id.is_empty():
		return {}
	var escrow_any: Variant = _escrows_by_id.get(escrow_id, {})
	if typeof(escrow_any) != TYPE_DICTIONARY:
		return {}
	return (escrow_any as Dictionary).duplicate(true)

func _update_escrow_status(escrow_id: String, status: String) -> void:
	if escrow_id.is_empty() or not _escrows_by_id.has(escrow_id):
		return
	var escrow: Dictionary = _escrows_by_id.get(escrow_id, {}) as Dictionary
	escrow["settlement_status"] = status
	_escrows_by_id[escrow_id] = escrow

func _risk_assessment(escrow: Dictionary, settlement_metadata: Dictionary) -> Dictionary:
	var reasons: Array[String] = []
	var escrow_metadata: Dictionary = _safe_dictionary(escrow.get("metadata", {}))
	var signals: Dictionary = _safe_dictionary(escrow_metadata.get("anti_collusion_signals", {}))
	var settlement_signals: Dictionary = _safe_dictionary(settlement_metadata.get("anti_collusion_signals", {}))
	for key in settlement_signals.keys():
		signals[key] = settlement_signals[key]
	for key in settlement_metadata.keys():
		if typeof(settlement_metadata[key]) == TYPE_BOOL:
			signals[key] = settlement_metadata[key]
	for flag in [
		"unusual_win_trading",
		"same_device_cluster",
		"same_ip_pattern",
		"suspicious_forfeit",
		"high_stakes_repeated_transfer"
	]:
		if bool(signals.get(flag, false)):
			reasons.append(flag)
	if bool(signals.get("repeated_same_opponent", false)) and int(escrow.get("stake_each", 0)) >= maxi(1, _runtime_config().minimum_stake_millis * 5):
		reasons.append("repeated_same_opponent_high_stake")
	return {"hold": not reasons.is_empty(), "reasons": reasons}

func _ensure_player(player_id: String) -> void:
	if _balances_by_player.has(player_id):
		return
	var starting: int = maxi(0, _runtime_config().starting_crucible_wax_millis)
	if _runtime_config().launch_grant_enabled:
		starting += maxi(0, _runtime_config().launch_grant_millis)
	_balances_by_player[player_id] = starting

func _apply_wax_stats(player_id: String, delta_millis: int, burned_millis: int = 0) -> void:
	var clean_id: String = player_id.strip_edges()
	if clean_id.is_empty():
		return
	var stats: Dictionary = _safe_dictionary(_wax_stats_by_player.get(clean_id, {}))
	stats["competitive_wax_balance"] = get_balance_millis(clean_id)
	stats["lifetime_wax_won"] = maxi(0, int(stats.get("lifetime_wax_won", 0))) + maxi(0, delta_millis)
	stats["lifetime_wax_lost"] = maxi(0, int(stats.get("lifetime_wax_lost", 0))) + absi(mini(0, delta_millis))
	stats["lifetime_wax_burned"] = maxi(0, int(stats.get("lifetime_wax_burned", 0))) + maxi(0, burned_millis)
	stats["lifetime_wax_net"] = int(stats.get("lifetime_wax_net", 0)) + delta_millis - maxi(0, burned_millis)
	stats["largest_wax_award"] = maxi(maxi(0, int(stats.get("largest_wax_award", 0))), maxi(0, delta_millis))
	stats["largest_wax_loss"] = maxi(maxi(0, int(stats.get("largest_wax_loss", 0))), absi(mini(0, delta_millis)))
	_wax_stats_by_player[clean_id] = stats

func _emit_event(event_type: String, payload: Dictionary) -> void:
	var event: Dictionary = payload.duplicate(true)
	event["type"] = event_type
	event["created_at"] = _now_unix()
	crucible_event.emit(event)
	SFLog.info("CRUCIBLE_EVENT", event)

func _emit_changed() -> void:
	crucible_state_changed.emit(get_snapshot())

func _error(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}

func _entry_blocked(player_id: String, code: String, message: String) -> Dictionary:
	var event_type: String = "crucible_enter_blocked_capacity" if code == "capacity" else "crucible_enter_blocked_no_wax" if code == "no_wax" else "crucible_enter_blocked"
	_emit_event(event_type, {
		"player_id": player_id,
		"code": code,
		"message": message
	})
	return {"ok": false, "code": code, "message": message}

func _runtime_config() -> CrucibleConfigScript:
	_ensure_config()
	return _config

func _earn_amount_for_path(path: String, metadata: Dictionary) -> int:
	match path:
		"STANDARD_PVP_WIN":
			return maxi(0, _runtime_config().standard_pvp_win_earn_millis)
		"STANDARD_PVP_LOSS", "STANDARD_PVP_PARTICIPATION":
			return maxi(0, _runtime_config().standard_pvp_loss_earn_millis)
		"TOURNAMENT_PLACEMENT":
			var placement: int = maxi(1, int(metadata.get("placement", 1)))
			return maxi(0, int(round(float(_runtime_config().tournament_placement_earn_millis) / float(placement))))
		"CHALLENGE":
			return maxi(0, _runtime_config().challenge_earn_millis)
		"EVENT":
			return maxi(0, _runtime_config().event_earn_millis)
		_:
			return maxi(0, int(metadata.get("amount_millis", 0)))

func _ensure_config() -> void:
	if _config != null:
		return
	_load_config()

func _load_config() -> void:
	var config_any: Variant = load(CONFIG_PATH)
	if config_any is CrucibleConfigScript:
		_config = config_any as CrucibleConfigScript
	else:
		_config = CrucibleConfigScript.new()

func _load_state() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed_any: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed_any) != TYPE_DICTIONARY:
		return
	var parsed: Dictionary = parsed_any as Dictionary
	_balances_by_player = _safe_dictionary(parsed.get("balances_by_player", {}))
	_escrows_by_id = _safe_dictionary(parsed.get("escrows_by_id", {}))
	_escrow_by_match_id = _safe_dictionary(parsed.get("escrow_by_match_id", {}))
	_settlements_by_match_id = _safe_dictionary(parsed.get("settlements_by_match_id", {}))
	_review_records_by_match_id = _safe_dictionary(parsed.get("review_records_by_match_id", {}))
	_competitive_wax_awards_by_event = _safe_dictionary(parsed.get("competitive_wax_awards_by_event", {}))
	_wax_stats_by_player = _safe_dictionary(parsed.get("wax_stats_by_player", {}))
	_ledger_entries = _safe_array(parsed.get("ledger_entries", []))
	_audit_records = _safe_array(parsed.get("audit_records", []))
	_anti_collusion_observations = _safe_array(parsed.get("anti_collusion_observations", []))

func _save_state() -> void:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"balances_by_player": _balances_by_player,
		"escrows_by_id": _escrows_by_id,
		"escrow_by_match_id": _escrow_by_match_id,
		"settlements_by_match_id": _settlements_by_match_id,
		"review_records_by_match_id": _review_records_by_match_id,
		"competitive_wax_awards_by_event": _competitive_wax_awards_by_event,
		"wax_stats_by_player": _wax_stats_by_player,
		"ledger_entries": _ledger_entries,
		"audit_records": _audit_records,
		"anti_collusion_observations": _anti_collusion_observations
	}, "\t"))
	file.close()

func _safe_dictionary(raw: Variant) -> Dictionary:
	return (raw as Dictionary).duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}

func _safe_array(raw: Variant) -> Array:
	return (raw as Array).duplicate(true) if typeof(raw) == TYPE_ARRAY else []

func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())
