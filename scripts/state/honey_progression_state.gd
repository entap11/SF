extends Node

const SFLog = preload("res://scripts/util/sf_log.gd")
const CrucibleRulesetPolicyScript = preload("res://scripts/state/crucible_ruleset_policy.gd")
const RewardMatchContextScript = preload("res://scripts/state/reward_match_context.gd")
const PlatformEconomyEventSchemaScript = preload("res://scripts/state/platform_economy_event_schema.gd")
const EconomyEpochScript = preload("res://scripts/state/economy_epoch.gd")

signal honey_progression_changed(snapshot: Dictionary)
signal honey_event(event: Dictionary)

const SAVE_PATH: String = "user://honey_progression_state.json"
const SAVE_SCHEMA_VERSION: int = 2
const CENTI_PER_HONEY: int = 100
const EVENT_DEDUPE_MAX: int = 5000
const RECENT_EVENT_MAX: int = 64
const MINIMUM_MATCH_DURATION_SEC: float = 30.0
const COMMUNITY_BASE_CENTI: int = 100
const ENGAGEMENT_BASE_CENTI: int = 200
const COMPETITIVE_PARTICIPATION_BASE_CENTI: int = 400
const COMPETITIVE_SUCCESS_BASE_CENTI: int = 800
const PLATFORM_GROWTH_BASE_CENTI: int = 1600
const ASYNC_FREE_CENTI: int = COMPETITIVE_PARTICIPATION_BASE_CENTI
const ASYNC_MONEY_CENTI: int = 600
const LIVE_FREE_CENTI: int = COMPETITIVE_PARTICIPATION_BASE_CENTI
const LIVE_MONEY_CENTI: int = 600
const TOURNAMENT_FREE_CENTI: int = COMPETITIVE_PARTICIPATION_BASE_CENTI
const TOURNAMENT_MONEY_CENTI: int = 600
const DAILY_OBJECTIVES_CENTI: int = ENGAGEMENT_BASE_CENTI
const WEEKLY_OBJECTIVES_CENTI: int = COMPETITIVE_PARTICIPATION_BASE_CENTI
const WEEKLY_ALL_MODES_CENTI: int = COMPETITIVE_PARTICIPATION_BASE_CENTI
const DAILY_LOGIN_CENTI: int = ENGAGEMENT_BASE_CENTI
const STREAK_7D_CENTI: int = COMPETITIVE_PARTICIPATION_BASE_CENTI
const STREAK_30D_CENTI: int = COMPETITIVE_SUCCESS_BASE_CENTI
const COMMUNITY_CHALLENGE_CENTI: int = COMMUNITY_BASE_CENTI
const FEATURED_CONTRIBUTION_CENTI: int = ENGAGEMENT_BASE_CENTI

const WEEKLY_BONUS_SPECS: Dictionary = {
	"free_pvp_variety": {
		"amount": WEEKLY_ALL_MODES_CENTI,
		"group": "free_pvp",
		"required": ["1V1", "2V2", "3P_FFA", "4P_FFA"]
	},
	"money_pvp_variety": {
		"amount": WEEKLY_ALL_MODES_CENTI,
		"group": "money_pvp",
		"required": ["1V1", "2V2", "3P_FFA", "4P_FFA"]
	},
	"free_async_variety": {
		"amount": WEEKLY_ALL_MODES_CENTI,
		"group": "free_async_modes",
		"required": ["STAGE_RACE", "TIMED_RACE", "MISS_N_OUT"]
	},
	"async_3_map_variety": {
		"amount": WEEKLY_ALL_MODES_CENTI,
		"group": "async_3_map",
		"required": ["STAGE_RACE_3", "TIMED_RACE_3", "MISS_N_OUT_3"]
	},
	"async_5_map_variety": {
		"amount": WEEKLY_ALL_MODES_CENTI,
		"group": "async_5_map",
		"required": ["STAGE_RACE_5", "TIMED_RACE_5", "MISS_N_OUT_5"]
	}
}

const PURCHASE_BUNDLE_REWARDS_CENTI: Dictionary = {
	1: 400,
	5: 800,
	10: 1200,
	25: 1600,
	50: 2400,
	100: 3200
}

const WARPATH_REWARDS_CENTI: Dictionary = {
	"premium": 1600,
	"elite": 2400
}

const REFERRAL_REWARDS_CENTI: Dictionary = {
	"signup": 400,
	"onboarding": 800,
	"active_7d": 1200,
	"active_30d": 1600,
	"active_60d": 2400
}

var _save_schema_version: int = SAVE_SCHEMA_VERSION
var _economy_epoch: String = EconomyEpochScript.CURRENT
var _total_honey_centi_awarded: int = 0
var _pending_profile_honey_centi: int = 0
var _awarded_event_ids: Dictionary = {}
var _awarded_event_order: Array[String] = []
var _weekly_cycle_key: String = ""
var _weekly_progress: Dictionary = {}
var _weekly_claimed: Dictionary = {}
var _recent_events: Array[Dictionary] = []

func _ready() -> void:
	SFLog.allow_tag("HONEY_STATE")
	SFLog.allow_tag("HONEY_EVENT")
	_load_state()
	_roll_week_if_needed()
	_flush_pending_profile_honey("honey_progression_boot")
	_connect_tree_signals()
	call_deferred("_scan_for_sim_runner")
	SFLog.info("HONEY_STATE", {
		"weekly_cycle_key": _weekly_cycle_key,
		"pending_profile_centi": _pending_profile_honey_centi,
		"total_honey_centi_awarded": _total_honey_centi_awarded
	})
	_emit_changed()

func get_snapshot() -> Dictionary:
	return {
		"schema_version": _save_schema_version,
		"economy_epoch": _economy_epoch,
		"precision": "centi_honey",
		"reward_ladder": {
			"community": COMMUNITY_BASE_CENTI,
			"engagement": ENGAGEMENT_BASE_CENTI,
			"competitive_participation": COMPETITIVE_PARTICIPATION_BASE_CENTI,
			"competitive_success": COMPETITIVE_SUCCESS_BASE_CENTI,
			"platform_growth": PLATFORM_GROWTH_BASE_CENTI
		},
		"profile_honey_balance": _profile_honey_balance(),
		"pending_profile_honey_centi": _pending_profile_honey_centi,
		"pending_profile_honey_progress": float(_pending_profile_honey_centi) / float(CENTI_PER_HONEY),
		"total_honey_centi_awarded": _total_honey_centi_awarded,
		"total_honey_visible": int(_total_honey_centi_awarded / CENTI_PER_HONEY),
		"weekly_cycle_key": _weekly_cycle_key,
		"weekly_progress": _weekly_progress.duplicate(true),
		"weekly_claimed": _weekly_claimed.duplicate(true),
		"recent_events": _recent_events.duplicate(true)
	}

func intent_record_async_completion(mode_id: String, map_count: int, paid_entry: bool, metadata: Dictionary = {}) -> Dictionary:
	if _metadata_is_crucible(metadata):
		return {"ok": true, "suppressed": true, "reason": "crucible_no_honey", "honey_centi_awarded": 0}
	var blocked_reason: String = _match_reward_blocked_reason(metadata)
	if not blocked_reason.is_empty():
		return {"ok": true, "suppressed": true, "reason": blocked_reason, "honey_centi_awarded": 0}
	var normalized_mode: String = _normalize_async_mode(mode_id)
	if normalized_mode.is_empty():
		return {"ok": false, "reason": "invalid_async_mode", "mode_id": mode_id}
	var resolved_map_count: int = maxi(1, map_count)
	var updates: Array[Dictionary] = []
	updates.append({"group": "free_async_modes", "entry": normalized_mode})
	if resolved_map_count == 3:
		updates.append({"group": "async_3_map", "entry": "%s_3" % normalized_mode})
	elif resolved_map_count == 5:
		updates.append({"group": "async_5_map", "entry": "%s_5" % normalized_mode})
	var amount: int = ASYNC_MONEY_CENTI if paid_entry else ASYNC_FREE_CENTI
	var meta: Dictionary = metadata.duplicate(true)
	meta["mode_id"] = normalized_mode
	meta["map_count"] = resolved_map_count
	meta["paid_entry"] = paid_entry
	return _award_honey_centi("async_completion", amount, meta, updates)

func intent_record_async_final_placement(mode_id: String, map_count: int, placement: int, paid_entry: bool, contest_scope: String = "", metadata: Dictionary = {}) -> Dictionary:
	if _metadata_is_crucible(metadata):
		return {"ok": true, "suppressed": true, "reason": "crucible_no_honey", "honey_centi_awarded": 0}
	var normalized_mode: String = _normalize_async_mode(mode_id)
	if normalized_mode.is_empty():
		return {"ok": false, "reason": "invalid_async_mode", "mode_id": mode_id}
	var amount: int = _placement_bonus_centi(placement, paid_entry)
	if amount <= 0:
		return {"ok": false, "reason": "placement_not_rewarded", "placement": placement}
	var meta: Dictionary = metadata.duplicate(true)
	meta["mode_id"] = normalized_mode
	meta["map_count"] = maxi(1, map_count)
	meta["placement"] = maxi(1, placement)
	meta["paid_entry"] = paid_entry
	meta["contest_scope"] = contest_scope.strip_edges().to_upper()
	return _award_honey_centi("async_final_placement", amount, meta, [])

func intent_record_pvp_completion(pvp_mode_id: String, paid_entry: bool, money_tier: int = 0, did_win: bool = false, metadata: Dictionary = {}) -> Dictionary:
	if _metadata_is_crucible(metadata):
		return {"ok": true, "suppressed": true, "reason": "crucible_no_honey", "honey_centi_awarded": 0}
	var blocked_reason: String = _match_reward_blocked_reason(metadata)
	if not blocked_reason.is_empty():
		return {"ok": true, "suppressed": true, "reason": blocked_reason, "honey_centi_awarded": 0}
	var normalized_mode: String = _normalize_pvp_mode(pvp_mode_id)
	if normalized_mode.is_empty():
		return {"ok": false, "reason": "invalid_pvp_mode", "mode_id": pvp_mode_id}
	var amount: int = 0
	if paid_entry:
		amount = LIVE_MONEY_CENTI
		if amount <= 0:
			return {"ok": false, "reason": "invalid_money_tier", "money_tier": money_tier}
	else:
		amount = LIVE_FREE_CENTI
	var updates: Array[Dictionary] = [{
		"group": "money_pvp" if paid_entry else "free_pvp",
		"entry": normalized_mode
	}]
	var meta: Dictionary = metadata.duplicate(true)
	meta["mode_id"] = normalized_mode
	meta["paid_entry"] = paid_entry
	meta["money_tier"] = money_tier
	meta["did_win"] = did_win
	return _award_honey_centi("pvp_completion", amount, meta, updates)

func intent_record_tournament_participation(metadata: Dictionary = {}) -> Dictionary:
	if _metadata_is_crucible(metadata):
		return {"ok": true, "suppressed": true, "reason": "crucible_no_honey", "honey_centi_awarded": 0}
	var blocked_reason: String = _match_reward_blocked_reason(metadata)
	if not blocked_reason.is_empty():
		return {"ok": true, "suppressed": true, "reason": blocked_reason, "honey_centi_awarded": 0}
	var paid_entry: bool = bool(metadata.get("paid_entry", metadata.get("is_money", false)))
	return _award_honey_centi("tournament_participation", TOURNAMENT_MONEY_CENTI if paid_entry else TOURNAMENT_FREE_CENTI, metadata.duplicate(true), [])

func intent_grant_player_honey(whole_honey: int, source_name: String, metadata: Dictionary = {}) -> Dictionary:
	var amount: int = maxi(0, whole_honey)
	var source: String = source_name.strip_edges().to_lower()
	var event_id: String = str(metadata.get("event_id", "")).strip_edges()
	if amount <= 0:
		return {"ok": false, "reason": "invalid_amount"}
	if source.is_empty():
		return {"ok": false, "reason": "missing_source"}
	if event_id.is_empty():
		return {"ok": false, "reason": "event_id_missing"}
	return _award_honey_centi(source, amount * CENTI_PER_HONEY, metadata.duplicate(true), [])

func intent_spend_player_honey(whole_honey: int, source_name: String, metadata: Dictionary = {}) -> Dictionary:
	var amount: int = maxi(0, whole_honey)
	var source: String = source_name.strip_edges().to_lower()
	var event_id: String = str(metadata.get("event_id", "")).strip_edges()
	if amount <= 0:
		return {"ok": false, "reason": "invalid_amount", "honey_balance": _profile_honey_balance()}
	if source.is_empty():
		return {"ok": false, "reason": "missing_source", "honey_balance": _profile_honey_balance()}
	if event_id.is_empty():
		return {"ok": false, "reason": "event_id_missing", "honey_balance": _profile_honey_balance()}
	if _awarded_event_ids.has(event_id):
		return {"ok": true, "already_processed": true, "event_id": event_id, "honey_balance": _profile_honey_balance()}
	var amount_centi: int = amount * CENTI_PER_HONEY
	var backend: Node = _honey_backend()
	var profile_manager: Node = _profile_manager()
	var backend_online: bool = backend != null and backend.has_method("is_authoritative_transport_online") and bool(backend.call("is_authoritative_transport_online"))
	if backend_online:
		var player_id: String = str(profile_manager.call("get_user_id")).strip_edges() if profile_manager != null and profile_manager.has_method("get_user_id") else ""
		if player_id.is_empty() or not backend.has_method("debit_honey"):
			return {"ok": false, "reason": "honey_authority_unavailable", "honey_balance": _profile_honey_balance()}
		var backend_result: Dictionary = backend.call("debit_honey", player_id, amount_centi, source, metadata, "honey_debit:%s:%s" % [player_id, event_id]) as Dictionary
		if not bool(backend_result.get("ok", false)):
			return {"ok": false, "reason": str(backend_result.get("err", "honey_debit_failed")), "backend_result": backend_result, "honey_balance": _profile_honey_balance()}
		_sync_profile_to_authoritative_honey(maxi(0, int(backend_result.get("balance_centi", 0))), "backend_debit:%s" % event_id)
	else:
		if not _local_honey_rewards_enabled():
			return {"ok": false, "reason": "honey_authority_unavailable", "honey_balance": _profile_honey_balance()}
		if profile_manager == null or not profile_manager.has_method("spend_honey"):
			return {"ok": false, "reason": "profile_unavailable", "honey_balance": _profile_honey_balance()}
		var local_result: Dictionary = profile_manager.call("spend_honey", amount, source) as Dictionary
		if not bool(local_result.get("ok", false)):
			return local_result
		_sync_hive_honey_balance_snapshot(int(local_result.get("honey_balance", _profile_honey_balance())), source)
	_awarded_event_ids[event_id] = true
	_awarded_event_order.append(event_id)
	_prune_awarded_event_dedupe()
	var event: Dictionary = {
		"type": "honey_spent",
		"source": source,
		"event_id": event_id,
		"honey_spent": amount,
		"profile_honey_balance": _profile_honey_balance(),
		"metadata": metadata.duplicate(true)
	}
	_append_recent_event(event)
	_save_state()
	honey_event.emit(event)
	SFLog.info("HONEY_EVENT", event)
	_emit_changed()
	return {"ok": true, "event_id": event_id, "honey_spent": amount, "honey_balance": _profile_honey_balance()}

func intent_record_tournament_placement(placement: int, metadata: Dictionary = {}) -> Dictionary:
	var amount: int = _placement_bonus_centi(placement, false)
	if amount <= 0:
		return {"ok": false, "reason": "placement_not_rewarded", "placement": placement}
	var meta: Dictionary = metadata.duplicate(true)
	meta["placement"] = maxi(1, placement)
	return _award_honey_centi("tournament_placement", amount, meta, [])

func intent_record_contest_winner(scope: String, metadata: Dictionary = {}) -> Dictionary:
	var normalized_scope: String = scope.strip_edges().to_upper()
	var amount: int = _contest_winner_bonus_centi(normalized_scope)
	if amount <= 0:
		return {"ok": false, "reason": "invalid_scope", "scope": scope}
	var meta: Dictionary = metadata.duplicate(true)
	meta["scope"] = normalized_scope
	return _award_honey_centi("contest_winner", amount, meta, [])

func intent_record_purchase_bundle(bundle_usd: int, metadata: Dictionary = {}) -> Dictionary:
	var clean_usd: int = maxi(0, bundle_usd)
	if not PURCHASE_BUNDLE_REWARDS_CENTI.has(clean_usd):
		return {"ok": false, "reason": "unsupported_bundle", "bundle_usd": bundle_usd}
	var meta: Dictionary = metadata.duplicate(true)
	meta["bundle_usd"] = clean_usd
	return _award_honey_centi("purchase_bundle", int(PURCHASE_BUNDLE_REWARDS_CENTI[clean_usd]), meta, [])

func intent_record_warpath_purchase(tier: String, metadata: Dictionary = {}) -> Dictionary:
	var clean_tier: String = tier.strip_edges().to_lower()
	if not WARPATH_REWARDS_CENTI.has(clean_tier):
		return {"ok": false, "reason": "unsupported_warpath_tier", "tier": tier}
	var meta: Dictionary = metadata.duplicate(true)
	meta["tier"] = clean_tier
	return _award_honey_centi("warpath_purchase", int(WARPATH_REWARDS_CENTI[clean_tier]), meta, [])

func intent_record_referral(stage: String, metadata: Dictionary = {}) -> Dictionary:
	var clean_stage: String = stage.strip_edges().to_lower()
	if not REFERRAL_REWARDS_CENTI.has(clean_stage):
		return {"ok": false, "reason": "unsupported_referral_stage", "stage": stage}
	var meta: Dictionary = metadata.duplicate(true)
	meta["stage"] = clean_stage
	return _award_honey_centi("referral", int(REFERRAL_REWARDS_CENTI[clean_stage]), meta, [])

func intent_record_daily_login(metadata: Dictionary = {}) -> Dictionary:
	return _award_honey_centi("daily_login", DAILY_LOGIN_CENTI, metadata.duplicate(true), [])

func intent_record_login_streak(days: int, metadata: Dictionary = {}) -> Dictionary:
	var safe_days: int = maxi(0, days)
	var amount: int = STREAK_30D_CENTI if safe_days >= 30 else STREAK_7D_CENTI if safe_days >= 7 else 0
	if amount <= 0:
		return {"ok": false, "reason": "unsupported_streak", "days": days}
	var meta: Dictionary = metadata.duplicate(true)
	meta["days"] = safe_days
	return _award_honey_centi("login_streak", amount, meta, [])

func intent_record_objective_completion(objective_type: String, metadata: Dictionary = {}) -> Dictionary:
	var clean_type: String = objective_type.strip_edges().to_lower()
	var amount: int = 0
	match clean_type:
		"daily_all":
			amount = DAILY_OBJECTIVES_CENTI
		"weekly_all":
			amount = WEEKLY_OBJECTIVES_CENTI
		"weekly_all_modes":
			amount = WEEKLY_ALL_MODES_CENTI
		_:
			return {"ok": false, "reason": "unsupported_objective_type", "objective_type": objective_type}
	var meta: Dictionary = metadata.duplicate(true)
	meta["objective_type"] = clean_type
	return _award_honey_centi("objective_completion", amount, meta, [])

func intent_record_community_contribution(contribution_type: String, metadata: Dictionary = {}) -> Dictionary:
	var clean_type: String = contribution_type.strip_edges().to_lower()
	var amount: int = 0
	match clean_type:
		"community_challenge":
			amount = COMMUNITY_CHALLENGE_CENTI
		"featured_contribution":
			amount = FEATURED_CONTRIBUTION_CENTI
		_:
			return {"ok": false, "reason": "unsupported_contribution_type", "contribution_type": contribution_type}
	var meta: Dictionary = metadata.duplicate(true)
	meta["contribution_type"] = clean_type
	return _award_honey_centi("community_contribution", amount, meta, [])

func debug_reset_state() -> void:
	_economy_epoch = EconomyEpochScript.CURRENT
	_total_honey_centi_awarded = 0
	_pending_profile_honey_centi = 0
	_awarded_event_ids.clear()
	_awarded_event_order.clear()
	_weekly_cycle_key = _current_week_cycle_key()
	_weekly_progress.clear()
	_weekly_claimed.clear()
	_recent_events.clear()
	_save_state()
	_emit_changed()

func _award_honey_centi(source_name: String, honey_centi: int, metadata: Dictionary, weekly_updates: Array[Dictionary]) -> Dictionary:
	var safe_amount: int = maxi(0, honey_centi)
	if safe_amount <= 0:
		return {"ok": false, "reason": "no_honey"}
	if not _honey_rewards_enabled():
		return {
			"ok": true,
			"awarded": false,
			"reason": "honey_rewards_disabled",
			"honey_centi_awarded": 0,
			"whole_honey_granted": 0,
			"profile_honey_balance": _profile_honey_balance(),
			"claimed_weekly_bonuses": []
		}
	_roll_week_if_needed()
	var event_id: String = str(metadata.get("event_id", "")).strip_edges()
	if event_id.is_empty():
		return {"ok": false, "reason": "event_id_missing"}
	if _awarded_event_ids.has(event_id):
		return {
			"ok": false,
			"reason": "event_already_awarded",
			"event_id": event_id,
			"profile_honey_balance": _profile_honey_balance()
		}
	var grant_result: Dictionary = _grant_authoritative_centi(source_name, safe_amount, metadata, event_id)
	if not bool(grant_result.get("ok", false)):
		return grant_result
	_awarded_event_ids[event_id] = true
	_awarded_event_order.append(event_id)
	_prune_awarded_event_dedupe()
	_apply_weekly_updates(weekly_updates)
	var claimed_bonuses: Array[Dictionary] = _claim_ready_weekly_bonuses(metadata)
	var event: Dictionary = {
		"type": "honey_awarded",
		"source": source_name,
		"event_id": event_id,
		"honey_centi_awarded": int(grant_result.get("honey_centi_awarded", safe_amount)),
		"whole_honey_granted": int(grant_result.get("whole_honey_granted", 0)),
		"profile_honey_balance": _profile_honey_balance(),
		"metadata": metadata.duplicate(true),
		"backend_result": (grant_result.get("backend_result", {}) as Dictionary).duplicate(true),
		"claimed_weekly_bonuses": claimed_bonuses.duplicate(true)
	}
	event["platform_economy_event"] = _build_platform_honey_event(event)
	_append_recent_event(event)
	_store_latest_honey_award_on_tree(event)
	_save_state()
	honey_event.emit(event)
	SFLog.info("HONEY_EVENT", event)
	_emit_changed()
	return {
		"ok": true,
		"event_id": event_id,
		"awarded": bool(grant_result.get("awarded", true)),
		"honey_centi_awarded": int(grant_result.get("honey_centi_awarded", safe_amount)),
		"whole_honey_granted": int(grant_result.get("whole_honey_granted", 0)),
		"profile_honey_balance": _profile_honey_balance(),
		"backend_result": (grant_result.get("backend_result", {}) as Dictionary).duplicate(true),
		"claimed_weekly_bonuses": claimed_bonuses.duplicate(true)
	}

func _grant_authoritative_centi(source_name: String, honey_centi: int, metadata: Dictionary, event_id: String) -> Dictionary:
	var safe_amount: int = maxi(0, honey_centi)
	if safe_amount <= 0:
		return {"ok": false, "reason": "no_honey"}
	var backend: Node = _honey_backend()
	var backend_online: bool = backend != null and backend.has_method("is_authoritative_transport_online") and bool(backend.call("is_authoritative_transport_online"))
	if backend_online:
		var backend_result: Dictionary = _post_honey_grant_to_backend(source_name, safe_amount, metadata, event_id)
		if not bool(backend_result.get("ok", false)):
			return {
				"ok": false,
				"reason": "honey_authority_unavailable",
				"backend_result": backend_result.duplicate(true)
			}
		var awarded_centi: int = maxi(0, int(backend_result.get("amount_centi", 0)))
		var balance_centi: int = maxi(0, int(backend_result.get("balance_centi", 0)))
		_sync_profile_to_authoritative_honey(balance_centi, "backend:%s:%s" % [source_name, event_id])
		_total_honey_centi_awarded += awarded_centi
		return {
			"ok": true,
			"awarded": bool(backend_result.get("awarded", awarded_centi > 0)),
			"honey_centi_awarded": awarded_centi,
			"whole_honey_granted": int(awarded_centi / CENTI_PER_HONEY),
			"profile_honey_balance": _profile_honey_balance(),
			"backend_result": backend_result.duplicate(true)
		}
	if not _local_honey_rewards_enabled():
		return {"ok": false, "reason": "honey_authority_unavailable"}
	var local_result: Dictionary = _grant_centi_to_profile(safe_amount, "%s:%s" % [source_name, event_id])
	local_result["ok"] = true
	local_result["awarded"] = true
	local_result["honey_centi_awarded"] = safe_amount
	local_result["backend_result"] = {"handled": false, "reason": "local_development_authority"}
	return local_result

func _sync_profile_to_authoritative_honey(balance_centi: int, reason: String) -> void:
	var profile_manager: Node = _profile_manager()
	if profile_manager == null or not profile_manager.has_method("set_honey_balance"):
		return
	var safe_balance: int = maxi(0, balance_centi)
	profile_manager.call("set_honey_balance", int(safe_balance / CENTI_PER_HONEY))
	_pending_profile_honey_centi = safe_balance % CENTI_PER_HONEY
	_sync_hive_honey_balance_snapshot(int(safe_balance / CENTI_PER_HONEY), reason)

func _build_platform_honey_event(event: Dictionary) -> Dictionary:
	var metadata: Dictionary = event.get("metadata", {}) as Dictionary if typeof(event.get("metadata", {})) == TYPE_DICTIONARY else {}
	return PlatformEconomyEventSchemaScript.build_award_event(
		"honey",
		"centi_honey",
		"award",
		str(event.get("event_id", "")),
		str(metadata.get("player_id", metadata.get("uid", ""))).strip_edges(),
		int(event.get("honey_centi_awarded", 0)),
		int(event.get("profile_honey_balance", 0)) * CENTI_PER_HONEY + _pending_profile_honey_centi,
		str(event.get("source", "")),
		metadata,
		{
			"whole_honey_granted": int(event.get("whole_honey_granted", 0)),
			"claimed_weekly_bonus_count": (event.get("claimed_weekly_bonuses", []) as Array).size() if typeof(event.get("claimed_weekly_bonuses", [])) == TYPE_ARRAY else 0
		}
	)

func _store_latest_honey_award_on_tree(event: Dictionary) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.set_meta("honey_latest_award", event.duplicate(true))
	tree.set_meta("honey_latest_awarded_centi", maxi(0, int(event.get("honey_centi_awarded", 0))))

func _grant_centi_to_profile(honey_centi: int, reason: String) -> Dictionary:
	var safe_amount: int = maxi(0, honey_centi)
	if safe_amount <= 0:
		return {"whole_honey_granted": 0}
	_total_honey_centi_awarded += safe_amount
	_pending_profile_honey_centi += safe_amount
	return _flush_pending_profile_honey(reason)

func _flush_pending_profile_honey(reason: String) -> Dictionary:
	var whole_honey_ready: int = int(_pending_profile_honey_centi / CENTI_PER_HONEY)
	if whole_honey_ready <= 0:
		return {"whole_honey_granted": 0}
	var profile_manager: Node = _profile_manager()
	if profile_manager == null or not profile_manager.has_method("add_honey"):
		return {"whole_honey_granted": 0}
	var result_any: Variant = profile_manager.call("add_honey", whole_honey_ready, reason)
	if typeof(result_any) != TYPE_DICTIONARY:
		return {"whole_honey_granted": 0}
	var result: Dictionary = result_any as Dictionary
	if not bool(result.get("ok", false)):
		return {"whole_honey_granted": 0}
	_pending_profile_honey_centi = _pending_profile_honey_centi % CENTI_PER_HONEY
	_sync_hive_honey_balance_snapshot(int(result.get("honey_balance", _profile_honey_balance())), reason)
	return {
		"whole_honey_granted": whole_honey_ready,
		"profile_honey_balance": int(result.get("honey_balance", _profile_honey_balance()))
	}

func _apply_weekly_updates(weekly_updates: Array[Dictionary]) -> void:
	for update_any in weekly_updates:
		if typeof(update_any) != TYPE_DICTIONARY:
			continue
		var update: Dictionary = update_any as Dictionary
		var group_id: String = str(update.get("group", "")).strip_edges()
		var entry_id: String = str(update.get("entry", "")).strip_edges().to_upper()
		if group_id.is_empty() or entry_id.is_empty():
			continue
		var group_progress: Dictionary = _weekly_progress.get(group_id, {})
		group_progress[entry_id] = true
		_weekly_progress[group_id] = group_progress

func _claim_ready_weekly_bonuses(metadata: Dictionary) -> Array[Dictionary]:
	var claimed: Array[Dictionary] = []
	for bonus_id_any in WEEKLY_BONUS_SPECS.keys():
		var bonus_id: String = str(bonus_id_any)
		if bool(_weekly_claimed.get(bonus_id, false)):
			continue
		var spec: Dictionary = WEEKLY_BONUS_SPECS.get(bonus_id, {})
		if not _weekly_bonus_ready(spec):
			continue
		var amount: int = maxi(0, int(spec.get("amount", 0)))
		var bonus_event_id: String = "weekly_bonus:%s:%s" % [_weekly_cycle_key, bonus_id]
		var bonus_metadata: Dictionary = metadata.duplicate(true)
		bonus_metadata["event_id"] = bonus_event_id
		bonus_metadata["weekly_cycle_key"] = _weekly_cycle_key
		bonus_metadata["bonus_id"] = bonus_id
		var grant_result: Dictionary = _grant_authoritative_centi("weekly_honey_bonus", amount, bonus_metadata, bonus_event_id)
		if not bool(grant_result.get("ok", false)):
			continue
		_weekly_claimed[bonus_id] = true
		var event: Dictionary = {
			"type": "weekly_honey_bonus_awarded",
			"bonus_id": bonus_id,
			"weekly_cycle_key": _weekly_cycle_key,
			"honey_centi_awarded": int(grant_result.get("honey_centi_awarded", amount)),
			"whole_honey_granted": int(grant_result.get("whole_honey_granted", 0)),
			"profile_honey_balance": _profile_honey_balance(),
			"metadata": metadata.duplicate(true)
		}
		_append_recent_event(event)
		honey_event.emit(event)
		SFLog.info("HONEY_EVENT", event)
		claimed.append(event)
	return claimed

func _weekly_bonus_ready(spec: Dictionary) -> bool:
	var group_id: String = str(spec.get("group", "")).strip_edges()
	if group_id.is_empty():
		return false
	var progress: Dictionary = _weekly_progress.get(group_id, {})
	var required_any: Variant = spec.get("required", [])
	if typeof(required_any) != TYPE_ARRAY:
		return false
	for required_id_any in required_any as Array:
		var required_id: String = str(required_id_any).strip_edges().to_upper()
		if required_id.is_empty():
			continue
		if not bool(progress.get(required_id, false)):
			return false
	return true

func _placement_bonus_centi(placement: int, paid_entry: bool) -> int:
	var safe_place: int = maxi(1, placement)
	var max_weekly: int = COMPETITIVE_SUCCESS_BASE_CENTI
	var min_weekly: int = COMMUNITY_BASE_CENTI
	var payout_depth: int = 10
	if safe_place > payout_depth:
		return 0
	var span: int = maxi(1, payout_depth - 1)
	var weekly_amount: int = int(round(lerpf(float(max_weekly), float(min_weekly), float(safe_place - 1) / float(span))))
	return weekly_amount * (2 if paid_entry else 1)

func _contest_winner_bonus_centi(scope: String) -> int:
	match scope:
		"DAILY":
			return COMPETITIVE_PARTICIPATION_BASE_CENTI
		"WEEKLY":
			return COMPETITIVE_SUCCESS_BASE_CENTI
		"MONTHLY":
			return PLATFORM_GROWTH_BASE_CENTI
		"SEASONAL":
			return PLATFORM_GROWTH_BASE_CENTI * 2
		_:
			return 0

func _normalize_async_mode(mode_id: String) -> String:
	var clean: String = mode_id.strip_edges().to_upper()
	match clean:
		"STAGE_RACE", "TIMED_RACE", "MISS_N_OUT":
			return clean
		_:
			return ""

func _normalize_pvp_mode(mode_id: String) -> String:
	var clean: String = mode_id.strip_edges().to_upper()
	match clean:
		"1V1", "2V2":
			return clean
		"3P FFA", "3P_FFA":
			return "3P_FFA"
		"4P FFA", "4P_FFA":
			return "4P_FFA"
		_:
			return ""

func _current_week_cycle_key() -> String:
	return "wk_%d" % int(floor(Time.get_unix_time_from_system() / 604800.0))

func _roll_week_if_needed() -> void:
	var current_key: String = _current_week_cycle_key()
	if current_key == _weekly_cycle_key:
		return
	_weekly_cycle_key = current_key
	_weekly_progress = {}
	_weekly_claimed = {}
	_save_state()

func _append_recent_event(event: Dictionary) -> void:
	_recent_events.append(event.duplicate(true))
	while _recent_events.size() > RECENT_EVENT_MAX:
		_recent_events.remove_at(0)

func _prune_awarded_event_dedupe() -> void:
	while _awarded_event_order.size() > EVENT_DEDUPE_MAX:
		var removed_id: String = _awarded_event_order[0]
		_awarded_event_order.remove_at(0)
		_awarded_event_ids.erase(removed_id)

func _profile_manager() -> Node:
	return get_node_or_null("/root/ProfileManager")

func _profile_honey_balance() -> int:
	var profile_manager: Node = _profile_manager()
	if profile_manager != null and profile_manager.has_method("get_honey_balance"):
		return maxi(0, int(profile_manager.call("get_honey_balance")))
	return 0

func _sync_hive_honey_balance_snapshot(balance: int, reason: String) -> void:
	var profile_manager: Node = _profile_manager()
	var hive_state: Node = get_node_or_null("/root/HiveClanState")
	if profile_manager == null or hive_state == null:
		return
	if not profile_manager.has_method("get_user_id") or not hive_state.has_method("intent_sync_member_honey_balance"):
		return
	var player_id: String = str(profile_manager.call("get_user_id")).strip_edges()
	if player_id.is_empty():
		return
	hive_state.call("intent_sync_member_honey_balance", player_id, maxi(0, balance), reason)

func _honey_backend() -> Node:
	return get_node_or_null("/root/VsHandshake")

func _post_honey_grant_to_backend(source_name: String, amount_centi: int, metadata: Dictionary, event_id: String) -> Dictionary:
	var backend: Node = _honey_backend()
	if backend == null or not backend.has_method("grant_honey"):
		return {"handled": false, "reason": "backend_unavailable"}
	var profile_manager: Node = _profile_manager()
	if profile_manager == null or not profile_manager.has_method("get_user_id"):
		return {"handled": false, "reason": "profile_unavailable"}
	var player_id: String = str(profile_manager.call("get_user_id")).strip_edges()
	if player_id.is_empty():
		return {"handled": false, "reason": "missing_player_id"}
	var enriched: Dictionary = metadata.duplicate(true)
	enriched["entap_title"] = str(enriched.get("entap_title", "Swarmfront"))
	enriched["source_name"] = source_name
	enriched["event_id"] = event_id
	var idempotency_key: String = "honey:%s:%s" % [player_id, event_id]
	if backend.has_method("record_honey_activity"):
		var activity_key: String = _backend_activity_key(source_name, metadata)
		if not activity_key.is_empty():
			var activity_result: Dictionary = backend.call("record_honey_activity", player_id, activity_key, enriched, idempotency_key) as Dictionary
			activity_result["handled"] = bool(activity_result.get("handled", true))
			if bool(activity_result.get("handled", false)) and str(activity_result.get("err", "")) != "transport_not_configured":
				return activity_result
	var result: Dictionary = backend.call("grant_honey", player_id, amount_centi, source_name, enriched, idempotency_key) as Dictionary
	result["handled"] = bool(result.get("handled", true))
	return result

func _backend_activity_key(source_name: String, metadata: Dictionary) -> String:
	var source: String = source_name.strip_edges().to_lower()
	var paid_entry: bool = bool(metadata.get("paid_entry", metadata.get("is_money", false)))
	match source:
		"async_completion":
			return "competitive.async_money" if paid_entry else "competitive.async_free"
		"pvp_completion":
			return "competitive.live_money" if paid_entry else "competitive.live_free"
		"tournament_participation":
			return "competitive.tournament_money" if paid_entry else "competitive.tournament_free"
		"async_final_placement", "tournament_placement", "contest_winner":
			var scope: String = str(metadata.get("contest_scope", metadata.get("scope", "WEEKLY"))).strip_edges().to_upper()
			if scope == "SEASONAL":
				return "competitive.placement_seasonal"
			if scope == "MONTHLY":
				return "competitive.placement_monthly"
			return "competitive.placement_weekly"
		"purchase_bundle":
			return "platform.purchase_bundle"
		"warpath_purchase":
			return "platform.warpath_purchase"
		"referral":
			return "platform.referral_retained"
		"daily_login":
			return "engagement.daily_login"
		"login_streak":
			return "engagement.weekly_objectives"
		"objective_completion":
			var objective_type: String = str(metadata.get("objective_type", "")).strip_edges().to_lower()
			if objective_type == "weekly_all":
				return "engagement.weekly_objectives"
			if objective_type == "weekly_all_modes":
				return "engagement.weekly_all_modes"
			return "engagement.daily_objectives"
		"community_contribution":
			var contribution_type: String = str(metadata.get("contribution_type", "")).strip_edges().to_lower()
			return "community.featured_contribution" if contribution_type == "featured_contribution" else "community.challenge"
		_:
			return ""

func _honey_rewards_enabled() -> bool:
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config != null and ops_config.has_method("honey_rewards_enabled"):
		return bool(ops_config.call("honey_rewards_enabled"))
	return false

func _local_honey_rewards_enabled() -> bool:
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config != null and ops_config.has_method("local_honey_rewards_enabled"):
		return bool(ops_config.call("local_honey_rewards_enabled"))
	return false

func _match_reward_blocked_reason(metadata: Dictionary) -> String:
	if str(metadata.get("event_id", "")).strip_edges().is_empty():
		return "event_id_missing"
	for flag in ["tutorial", "practice", "custom_match", "private_match", "no_contest", "refunded", "immediate_surrender", "afk", "insufficient_input", "insufficient_participation", "desync", "invalid_result", "early_quit"]:
		if bool(metadata.get(flag, false)):
			return flag
	if metadata.has("completed") and not bool(metadata.get("completed", false)):
		return "match_not_completed"
	if metadata.has("minimum_quality_met") and not bool(metadata.get("minimum_quality_met", false)):
		return "minimum_quality_not_met"
	var duration_sec: float = float(metadata.get("duration_sec", float(metadata.get("match_duration_ms", 0.0)) / 1000.0))
	if duration_sec <= 0.0:
		return "match_duration_missing"
	if duration_sec < MINIMUM_MATCH_DURATION_SEC:
		return "match_too_short"
	return ""

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

func _on_runtime_match_ended(winner_id: int, reason: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or not tree.has_meta("vs_mode"):
		return
	if CrucibleRulesetPolicyScript.is_crucible_tree(tree):
		return
	var mode_id: String = str(tree.get_meta("vs_mode", "")).strip_edges()
	if mode_id.is_empty():
		return
	var metadata: Dictionary = RewardMatchContextScript.enrich(tree, {
		"event_id": _runtime_event_id(tree, mode_id, reason),
		"contest_id": str(tree.get_meta("contest_id", "")).strip_edges(),
		"contest_scope": str(tree.get_meta("contest_scope", "")).strip_edges().to_upper(),
		"entry_usd": maxi(0, int(tree.get_meta("vs_price_usd", 0)))
	}, winner_id, reason, get_node_or_null("/root/OpsState"))
	var is_sync_pvp: bool = bool(tree.get_meta("vs_sync_start", false))
	var free_roll: bool = bool(tree.get_meta("vs_free_roll", false))
	if is_sync_pvp:
		var local_owner_id: int = _resolve_local_pvp_owner_id(tree)
		if local_owner_id <= 0:
			return
		var money_tier: int = 0 if free_roll else _money_tier_from_entry_usd(int(metadata.get("entry_usd", 0)))
		intent_record_pvp_completion(
			mode_id,
			not free_roll,
			money_tier,
			winner_id > 0 and winner_id == local_owner_id,
			metadata
		)
		return
	var normalized_mode: String = _normalize_async_mode(mode_id)
	if normalized_mode.is_empty():
		return
	if normalized_mode == "STAGE_RACE" and not _is_final_stage_round(tree):
		return
	intent_record_async_completion(
		normalized_mode,
		_resolve_async_map_count(tree),
		not free_roll,
		metadata
	)

func _runtime_event_id(tree: SceneTree, mode_id: String, reason: String) -> String:
	var nonce_key: String = "honey_runtime_nonce"
	var nonce_scene_key: String = "honey_runtime_nonce_scene_id"
	var nonce: String = str(tree.get_meta(nonce_key, "")).strip_edges()
	var scene_id: int = 0
	if tree.current_scene != null:
		scene_id = int(tree.current_scene.get_instance_id())
	var nonce_scene_id: int = int(tree.get_meta(nonce_scene_key, -1))
	if nonce.is_empty() or nonce_scene_id != scene_id:
		nonce = "h_%d_%d" % [int(round(Time.get_unix_time_from_system() * 1000.0)), scene_id]
		tree.set_meta(nonce_key, nonce)
		tree.set_meta(nonce_scene_key, scene_id)
	var round_index: int = maxi(0, int(tree.get_meta("vs_stage_current_index", 0)))
	return "%s:%s:%s:%d" % [nonce, mode_id.strip_edges().to_upper(), reason.strip_edges().to_lower(), round_index]

func _metadata_is_crucible(metadata: Dictionary) -> bool:
	return CrucibleRulesetPolicyScript.is_crucible_ruleset(str(metadata.get("ruleset", metadata.get("vs_ruleset", ""))))

func _resolve_local_pvp_owner_id(tree: SceneTree) -> int:
	var runtime: Node = get_node_or_null("/root/VsPvpRuntime")
	if runtime != null and runtime.has_method("is_active") and bool(runtime.call("is_active")):
		if runtime.has_method("get_local_seat"):
			return clampi(int(runtime.call("get_local_seat")), 1, 4)
	var local_uid: String = ""
	var local_profile_any: Variant = tree.get_meta("vs_local_profile", {})
	if typeof(local_profile_any) == TYPE_DICTIONARY:
		local_uid = str((local_profile_any as Dictionary).get("uid", "")).strip_edges()
	if local_uid.is_empty():
		var profile_manager: Node = _profile_manager()
		if profile_manager != null and profile_manager.has_method("get_user_id"):
			local_uid = str(profile_manager.call("get_user_id")).strip_edges()
	var roster_any: Variant = tree.get_meta("vs_assigned_players", [])
	if typeof(roster_any) == TYPE_ARRAY:
		for entry_any in roster_any as Array:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any as Dictionary
			if str(entry.get("uid", "")).strip_edges() != local_uid:
				continue
			return clampi(int(entry.get("seat", 0)), 1, 4)
	var role: String = str(tree.get_meta("vs_handshake_role", "host")).strip_edges().to_lower()
	return 2 if role == "guest" else 1

func _resolve_async_map_count(tree: SceneTree) -> int:
	var stage_paths_any: Variant = tree.get_meta("vs_stage_map_paths", [])
	if typeof(stage_paths_any) == TYPE_ARRAY:
		var stage_paths: Array = stage_paths_any as Array
		if not stage_paths.is_empty():
			return maxi(1, stage_paths.size())
	var map_ids_any: Variant = tree.get_meta("map_ids", [])
	if typeof(map_ids_any) == TYPE_ARRAY:
		var map_ids: Array = map_ids_any as Array
		if not map_ids.is_empty():
			return maxi(1, map_ids.size())
	return 1

func _is_final_stage_round(tree: SceneTree) -> bool:
	var stage_paths_any: Variant = tree.get_meta("vs_stage_map_paths", [])
	if typeof(stage_paths_any) != TYPE_ARRAY:
		return true
	var stage_paths: Array = stage_paths_any as Array
	if stage_paths.size() <= 1:
		return true
	var current_index: int = clampi(int(tree.get_meta("vs_stage_current_index", 0)), 0, stage_paths.size() - 1)
	return current_index + 1 >= stage_paths.size()

func _money_tier_from_entry_usd(entry_usd: int) -> int:
	var safe_usd: int = maxi(0, entry_usd)
	if safe_usd <= 3:
		return 1
	if safe_usd <= 10:
		return 2
	return 3

func _load_state() -> void:
	_economy_epoch = EconomyEpochScript.CURRENT
	_total_honey_centi_awarded = 0
	_pending_profile_honey_centi = 0
	_awarded_event_ids.clear()
	_awarded_event_order.clear()
	_weekly_cycle_key = ""
	_weekly_progress.clear()
	_weekly_claimed.clear()
	_recent_events.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return
	if typeof(parser.data) != TYPE_DICTIONARY:
		return
	var raw: Dictionary = parser.data as Dictionary
	var stored_epoch: String = str(raw.get("economy_epoch", "")).strip_edges()
	if stored_epoch != EconomyEpochScript.CURRENT:
		SFLog.info("HONEY_ECONOMY_EPOCH_RESET", {
			"previous_epoch": stored_epoch,
			"economy_epoch": EconomyEpochScript.CURRENT
		})
		_save_state()
		return
	_save_schema_version = maxi(1, int(raw.get("schema_version", SAVE_SCHEMA_VERSION)))
	if _save_schema_version < 2:
		_total_honey_centi_awarded = maxi(0, int(raw.get("total_honey_tenths_awarded", 0))) * 10
		_pending_profile_honey_centi = maxi(0, int(raw.get("pending_profile_honey_tenths", 0))) * 10
	else:
		_total_honey_centi_awarded = maxi(0, int(raw.get("total_honey_centi_awarded", 0)))
		_pending_profile_honey_centi = maxi(0, int(raw.get("pending_profile_honey_centi", 0)))
	_save_schema_version = SAVE_SCHEMA_VERSION
	_weekly_cycle_key = str(raw.get("weekly_cycle_key", "")).strip_edges()
	var awarded_ids_any: Variant = raw.get("awarded_event_ids", {})
	if typeof(awarded_ids_any) == TYPE_DICTIONARY:
		_awarded_event_ids = (awarded_ids_any as Dictionary).duplicate(true)
	var awarded_order_any: Variant = raw.get("awarded_event_order", [])
	if typeof(awarded_order_any) == TYPE_ARRAY:
		for event_id_any in awarded_order_any as Array:
			var event_id: String = str(event_id_any).strip_edges()
			if event_id.is_empty():
				continue
			_awarded_event_order.append(event_id)
	var weekly_progress_any: Variant = raw.get("weekly_progress", {})
	if typeof(weekly_progress_any) == TYPE_DICTIONARY:
		_weekly_progress = (weekly_progress_any as Dictionary).duplicate(true)
	var weekly_claimed_any: Variant = raw.get("weekly_claimed", {})
	if typeof(weekly_claimed_any) == TYPE_DICTIONARY:
		_weekly_claimed = (weekly_claimed_any as Dictionary).duplicate(true)
	var recent_events_any: Variant = raw.get("recent_events", [])
	if typeof(recent_events_any) == TYPE_ARRAY:
		for event_any in recent_events_any as Array:
			if typeof(event_any) != TYPE_DICTIONARY:
				continue
			_recent_events.append((event_any as Dictionary).duplicate(true))

func _save_state() -> void:
	var payload: Dictionary = {
		"schema_version": SAVE_SCHEMA_VERSION,
		"economy_epoch": _economy_epoch,
		"precision": "centi_honey",
		"total_honey_centi_awarded": _total_honey_centi_awarded,
		"pending_profile_honey_centi": _pending_profile_honey_centi,
		"awarded_event_ids": _awarded_event_ids.duplicate(true),
		"awarded_event_order": _awarded_event_order.duplicate(),
		"weekly_cycle_key": _weekly_cycle_key,
		"weekly_progress": _weekly_progress.duplicate(true),
		"weekly_claimed": _weekly_claimed.duplicate(true),
		"recent_events": _recent_events.duplicate(true)
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))

func _emit_changed() -> void:
	honey_progression_changed.emit(get_snapshot())
