extends Node

const SFLog = preload("res://scripts/util/sf_log.gd")
const BattlePassConfigScript = preload("res://scripts/state/battle_pass_config.gd")
const BattlePassRewardsScript = preload("res://scripts/state/battle_pass_rewards.gd")
const CrucibleRulesetPolicyScript = preload("res://scripts/state/crucible_ruleset_policy.gd")
const NectarRewardPolicyScript = preload("res://scripts/state/nectar_reward_policy.gd")
const PlatformEconomyEventSchemaScript = preload("res://scripts/state/platform_economy_event_schema.gd")

signal battle_pass_state_changed(snapshot: Dictionary)
signal battle_pass_event(event: Dictionary)

const CONFIG_PATH: String = "res://data/battle_pass/battle_pass_config.json"
const SAVE_PATH: String = "user://battle_pass_state.json"
const SAVE_SCHEMA_VERSION: int = 3
const TRACK_FREE: String = "free"
const TRACK_PREMIUM: String = "premium"
const TRACK_ELITE: String = "elite"
const REWARD_NONE: String = "none"
const MATCH_DEDUPE_MAX: int = 5000
const OPPONENT_HISTORY_WINDOW_SEC: int = 24 * 60 * 60
const OPPONENT_HISTORY_MAX_PER_OPPONENT: int = 32
const NECTAR_FIXED_POINT_SCALE: int = 1000

var _config: BattlePassConfigScript = BattlePassConfigScript.new(CONFIG_PATH)
var _rewards: BattlePassRewardsScript = BattlePassRewardsScript.new()

var _save_schema_version: int = SAVE_SCHEMA_VERSION
var _current_season_id: String = ""
var _battle_pass_xp: int = 0
var _battle_pass_level: int = 1
var _nectar_fractional_milli: int = 0

var _premium_owned: bool = false
var _elite_owned: bool = false

var _claimed_rewards: Dictionary = {}
var _scarcity_claims_by_level: Dictionary = {}
var _scarcity_feature_enabled: bool = false
var _season_prestige_base_slots: int = 0
var _season_prestige_caps_by_level: Dictionary = {}

var _veteran_start_applied: bool = false
var _veteran_rewards_unlocked: bool = true
var _veteran_start_level: int = 1
var _veteran_unlock_level: int = 10

var _wallet: Dictionary = {}
var _inventory: Dictionary = {}

var _awarded_match_ids: Dictionary = {}
var _awarded_match_order: Array[String] = []
var _first_win_bonus_by_day_player: Dictionary = {}
var _nectar_earned_by_day: Dictionary = {}
var _opponent_award_times: Dictionary = {}
var _ad_free_until_unix: int = 0
var _redemption_receipts: Dictionary = {}

var _quest_progress: Dictionary = {}
var _quest_claimed: Dictionary = {}
var _quest_bonus_claimed: Dictionary = {}
var _daily_cycle_key: String = ""
var _daily_challenge_progress: Dictionary = {}
var _daily_challenge_claimed: Dictionary = {}
var _weekly_cycle_key: String = ""
var _weekly_challenge_progress: Dictionary = {}
var _weekly_challenge_claimed: Dictionary = {}
var _weekly_completion_bonus_claimed: bool = false
var _access_ticket_entry_claims: Dictionary = {}
var _exclusive_event_prize_claims: Dictionary = {}

func _ready() -> void:
	SFLog.allow_tag("BATTLE_PASS_EVENT")
	SFLog.allow_tag("BATTLE_PASS_STATE")
	_config.load_from_path(CONFIG_PATH)
	_veteran_unlock_level = _config.get_veteran_unlock_level()
	_scarcity_feature_enabled = _config.get_scarcity_feature_default_enabled()
	_wallet = _rewards.normalize_wallet({})
	_inventory = _rewards.normalize_inventory({})
	_load_state()
	_refresh_entitlements_from_profile()
	_roll_season_if_needed()
	_roll_daily_weekly_cycles_if_needed()
	_ensure_prestige_state_initialized()
	_ensure_quest_state_initialized()
	_ensure_daily_challenge_state_initialized()
	_ensure_weekly_challenge_state_initialized()
	_recalculate_level_from_xp()
	_refresh_veteran_unlock_state()
	_emit_state_changed()

func get_snapshot() -> Dictionary:
	var total_levels: int = _config.get_total_levels()
	var visible_cap: int = _config.get_visible_cap_for_entitlements(_premium_owned, _elite_owned)
	var side_quest_paths: int = _available_quest_path_count()
	var next_level: int = mini(total_levels, _battle_pass_level + 1)
	var current_level_start_xp: int = _config.get_xp_required_to_reach_level(_battle_pass_level)
	var current_level_xp_cost: int = _config.get_level_xp_required(_battle_pass_level)
	var xp_into_level: int = maxi(0, _battle_pass_xp - current_level_start_xp)
	var progress_ratio: float = 1.0
	if _battle_pass_level < total_levels:
		progress_ratio = clampf(float(xp_into_level) / float(maxi(1, current_level_xp_cost)), 0.0, 1.0)
	var veteran_lock_active: bool = _is_veteran_pregrant_lock_active()
	var veteran_notice: String = ""
	if veteran_lock_active:
		veteran_notice = "Veteran start unlocked — reach Level %d to claim your starting rewards." % _veteran_unlock_level
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"season_id": _current_season_id,
		"season_start_unix": _config.get_season_start_unix(),
		"season_end_unix": _config.get_season_end_unix(),
		"product_ids": _config.get_product_ids(),
		"season_seconds_remaining": maxi(0, _config.get_season_end_unix() - int(Time.get_unix_time_from_system())),
		"battle_pass_xp": _battle_pass_xp,
		"nectar_xp": _battle_pass_xp,
		"nectar_fractional_milli": _nectar_fractional_milli,
		"battle_pass_level": _battle_pass_level,
		"next_level": next_level,
		"xp_into_level": xp_into_level,
		"xp_for_level": current_level_xp_cost,
		"progress_ratio": progress_ratio,
		"total_levels": total_levels,
		"visible_level_cap": visible_cap,
		"side_quest_paths_available": side_quest_paths,
		"premium_owned": _premium_owned,
		"elite_owned": _elite_owned,
		"veteran_start_applied": _veteran_start_applied,
		"veteran_start_level": _veteran_start_level,
		"veteran_rewards_unlocked": _veteran_rewards_unlocked,
		"veteran_unlock_level": _veteran_unlock_level,
		"veteran_lock_active": veteran_lock_active,
		"veteran_lock_notice": veteran_notice,
		"scarcity_feature_enabled": _scarcity_feature_enabled,
		"prestige_pool_base_slots": _season_prestige_base_slots,
		"prestige_projection": _config.get_prestige_projection_details(),
		"reward_summary": _config.get_reward_summary(),
		"reward_targets": _config.get_reward_targets(),
		"quest_reward_summary": _config.get_quest_reward_summary(),
		"progression_sink_summary": _config.get_progression_sink_summary(),
		"rows": _build_level_rows(visible_cap),
		"honey_balance": _canonical_honey_balance(),
		"inventory": _inventory.duplicate(true),
		"ad_free_until_unix": _ad_free_until_unix,
		"ad_free_active": _ad_free_until_unix > int(Time.get_unix_time_from_system()),
		"access_ticket_entry_claim_count": _access_ticket_entry_claims.size(),
		"exclusive_event_prize_claim_count": _exclusive_event_prize_claims.size(),
		"first_win_bonus_claims": _first_win_bonus_by_day_player.duplicate(true),
		"quests": _build_quest_rows(),
		"quest_bonuses": _build_quest_bonus_rows(),
		"daily_cycle_key": _daily_cycle_key,
		"daily_challenges": _build_daily_challenge_rows(),
		"weekly_cycle_key": _weekly_cycle_key,
		"weekly_challenges": _build_weekly_challenge_rows(),
		"weekly_completion_bonus_claimed": _weekly_completion_bonus_claimed
	}

func sync_entitlements_from_profile() -> Dictionary:
	var changed: bool = _refresh_entitlements_from_profile()
	if changed:
		_save_state()
		_emit_state_changed()
	return {"ok": true, "premium_owned": _premium_owned, "elite_owned": _elite_owned, "changed": changed}

func intent_set_pass_entitlements(premium_owned: bool, elite_owned: bool) -> Dictionary:
	var next_elite: bool = elite_owned
	var next_premium: bool = premium_owned or next_elite
	var changed: bool = next_premium != _premium_owned or next_elite != _elite_owned
	_premium_owned = next_premium
	_elite_owned = next_elite
	if changed:
		_save_state()
		_emit_event("entitlements_updated", {"premium_owned": _premium_owned, "elite_owned": _elite_owned})
		_emit_state_changed()
	return {"ok": true, "premium_owned": _premium_owned, "elite_owned": _elite_owned}

func intent_set_scarcity_feature_enabled(enabled: bool) -> Dictionary:
	if _scarcity_feature_enabled == enabled:
		return {"ok": true, "enabled": _scarcity_feature_enabled}
	_scarcity_feature_enabled = enabled
	_save_state()
	_emit_event("scarcity_feature_toggled", {"enabled": _scarcity_feature_enabled})
	_emit_state_changed()
	return {"ok": true, "enabled": _scarcity_feature_enabled}

func intent_apply_veteran_start(flags: Dictionary, opt_out: bool = false) -> Dictionary:
	if _veteran_start_applied:
		return {"ok": false, "reason": "veteran_start_already_applied"}
	_veteran_start_applied = true
	if opt_out:
		_veteran_start_level = 1
		_veteran_rewards_unlocked = true
		_save_state()
		_emit_event("veteran_start_opted_out", {})
		_emit_state_changed()
		return {"ok": true, "opted_out": true, "battle_pass_level": _battle_pass_level}
	var grant_xp: int = _config.compute_veteran_start_grant(flags)
	_battle_pass_xp = maxi(0, _battle_pass_xp + grant_xp)
	_recalculate_level_from_xp()
	_veteran_start_level = _battle_pass_level
	_veteran_rewards_unlocked = _veteran_start_level <= 1
	_refresh_veteran_unlock_state()
	_save_state()
	_emit_event("veteran_start_applied", {
		"grant_xp": grant_xp,
		"start_level": _veteran_start_level,
		"unlock_level": _veteran_unlock_level
	})
	_emit_state_changed()
	return {
		"ok": true,
		"grant_xp": grant_xp,
		"battle_pass_level": _battle_pass_level,
		"veteran_rewards_unlocked": _veteran_rewards_unlocked
	}

func intent_award_nectar_xp(source_name: String, nectar_xp: int, metadata: Dictionary = {}) -> Dictionary:
	if not _season_is_active():
		return {"ok": true, "suppressed": true, "reason": "season_inactive", "xp_awarded": 0}
	var safe_xp: int = maxi(0, nectar_xp)
	if safe_xp <= 0:
		return {"ok": false, "reason": "xp_zero"}
	var blocked_reason: String = _nectar_blocked_reason(source_name, metadata)
	if not blocked_reason.is_empty():
		_emit_nectar_blocked(blocked_reason, metadata)
		return {"ok": true, "suppressed": true, "reason": blocked_reason, "xp_awarded": 0}
	return _apply_nectar_xp_award(source_name, safe_xp, metadata, true)

func intent_record_async_completion(mode_id: String, map_count: int, paid_entry: bool, metadata: Dictionary = {}) -> Dictionary:
	if _metadata_is_crucible(metadata):
		_emit_nectar_blocked("crucible_no_nectar", metadata)
		return {"ok": true, "suppressed": true, "reason": "crucible_no_nectar", "xp_awarded": 0}
	var event_id: String = str(metadata.get("event_id", "")).strip_edges()
	if event_id.is_empty():
		return {"ok": false, "reason": "event_id_missing"}
	var safe_map_count: int = maxi(1, map_count)
	_roll_daily_weekly_cycles_if_needed()
	var did_win: bool = _metadata_did_win(metadata)
	var policy: Dictionary = _evaluate_nectar_policy(mode_id, paid_entry, 0, did_win, event_id, metadata)
	if str(policy.get("validity_status", "")) == "blocked":
		var reason: String = str(policy.get("anti_harvest_reason_if_blocked", "blocked"))
		_emit_nectar_blocked(reason, metadata)
		return {"ok": true, "suppressed": true, "reason": reason, "xp_awarded": 0}
	var xp_total: int = int(policy.get("final_nectar", _config.get_async_match_xp(safe_map_count, paid_entry, did_win)))
	if xp_total <= 0:
		return {"ok": false, "reason": "xp_zero", "event_id": event_id}
	var reserved: Dictionary = _reserve_award_event(event_id)
	if not bool(reserved.get("ok", false)):
		return reserved
	var xp_meta: Dictionary = metadata.duplicate(true)
	xp_meta["mode_id"] = mode_id.strip_edges().to_upper()
	xp_meta["map_count"] = safe_map_count
	xp_meta["paid_entry"] = paid_entry
	xp_meta["did_win"] = did_win
	xp_meta["event_id"] = event_id
	xp_meta["nectar_breakdown"] = policy.duplicate(true)
	var changed: bool = _apply_quest_progress("async_match_completed", 1, xp_meta)
	if paid_entry:
		changed = _apply_quest_progress("money_async_played", 1, xp_meta) or changed
	changed = _apply_daily_challenge_progress(_daily_events_for_result(did_win), xp_meta) or changed
	changed = _apply_weekly_challenge_progress(_weekly_events_for_result(NectarRewardPolicyScript.MODE_GROUP_ASYNC, paid_entry, did_win), xp_meta) or changed
	var xp_result: Dictionary = _apply_nectar_xp_award("async_completion", xp_total, xp_meta, true)
	if not bool(xp_result.get("ok", false)):
		return xp_result
	_record_opponent_award(xp_meta)
	_save_state()
	if changed:
		_save_state()
		_emit_state_changed()
	return {
		"ok": true,
		"event_id": event_id,
		"xp_awarded": int(xp_result.get("xp_awarded", 0)),
		"base_xp": int(xp_result.get("base_xp", xp_total)),
		"xp_multiplier": float(xp_result.get("xp_multiplier", 1.0)),
		"nectar_breakdown": policy.duplicate(true),
		"battle_pass_level": _battle_pass_level
	}

func intent_record_pvp_completion(pvp_mode_id: String, paid_entry: bool, money_tier: int = 0, did_win: bool = false, metadata: Dictionary = {}) -> Dictionary:
	if _metadata_is_crucible(metadata):
		_emit_nectar_blocked("crucible_no_nectar", metadata)
		return {"ok": true, "suppressed": true, "reason": "crucible_no_nectar", "xp_awarded": 0}
	var event_id: String = str(metadata.get("event_id", "")).strip_edges()
	if event_id.is_empty():
		return {"ok": false, "reason": "event_id_missing"}
	_roll_daily_weekly_cycles_if_needed()
	var policy: Dictionary = _evaluate_nectar_policy(pvp_mode_id, paid_entry, money_tier, did_win, event_id, metadata)
	if str(policy.get("validity_status", "")) == "blocked":
		var reason: String = str(policy.get("anti_harvest_reason_if_blocked", "blocked"))
		_emit_nectar_blocked(reason, metadata)
		return {"ok": true, "suppressed": true, "reason": reason, "xp_awarded": 0}
	var xp_total: int = int(policy.get("final_nectar", _config.get_pvp_completion_xp(paid_entry, money_tier, did_win)))
	if xp_total <= 0:
		return {"ok": false, "reason": "xp_zero", "event_id": event_id}
	var reserved: Dictionary = _reserve_award_event(event_id)
	if not bool(reserved.get("ok", false)):
		return reserved
	var xp_meta: Dictionary = metadata.duplicate(true)
	xp_meta["mode_id"] = pvp_mode_id.strip_edges().to_upper()
	xp_meta["paid_entry"] = paid_entry
	xp_meta["money_tier"] = money_tier
	xp_meta["did_win"] = did_win
	xp_meta["event_id"] = event_id
	xp_meta["nectar_breakdown"] = policy.duplicate(true)
	var mode_group: String = str(policy.get("mode_group", NectarRewardPolicyScript.MODE_GROUP_STANDARD))
	var changed: bool = _apply_quest_progress("pvp_match_completed", 1, xp_meta)
	if paid_entry:
		changed = _apply_quest_progress("money_match_played", 1, xp_meta) or changed
	if did_win:
		changed = _apply_quest_progress("pvp_win", 1, xp_meta) or changed
		var first_win_bonus: Dictionary = _reserve_first_win_bonus(xp_meta)
		if bool(first_win_bonus.get("awarded", false)):
			xp_total += maxi(0, int(first_win_bonus.get("xp", 0)))
			xp_meta["first_win_bonus_nectar"] = int(first_win_bonus.get("xp", 0))
			policy["first_win_bonus_nectar"] = int(first_win_bonus.get("xp", 0))
			policy["final_nectar"] = int(policy.get("final_nectar", 0)) + int(first_win_bonus.get("xp", 0))
			_emit_event("nectar_first_win_awarded", {
				"player_id": str(first_win_bonus.get("player_id", "")),
				"day_key": str(first_win_bonus.get("day_key", "")),
				"xp": int(first_win_bonus.get("xp", 0))
			})
	changed = _apply_daily_challenge_progress(_daily_events_for_result(did_win), xp_meta) or changed
	changed = _apply_weekly_challenge_progress(_weekly_events_for_result(mode_group, paid_entry, did_win), xp_meta) or changed
	var xp_result: Dictionary = _apply_nectar_xp_award("pvp_completion", xp_total, xp_meta, true)
	if not bool(xp_result.get("ok", false)):
		return xp_result
	_record_opponent_award(xp_meta)
	_save_state()
	if changed:
		_save_state()
		_emit_state_changed()
	return {
		"ok": true,
		"event_id": event_id,
		"xp_awarded": int(xp_result.get("xp_awarded", 0)),
		"base_xp": int(xp_result.get("base_xp", xp_total)),
		"xp_multiplier": float(xp_result.get("xp_multiplier", 1.0)),
		"nectar_breakdown": policy.duplicate(true),
		"battle_pass_level": _battle_pass_level
	}

func intent_record_tournament_participation(metadata: Dictionary = {}) -> Dictionary:
	return intent_record_tournament_match_result(false, metadata)

func intent_record_tournament_match_result(did_win: bool, metadata: Dictionary = {}) -> Dictionary:
	if _metadata_is_crucible(metadata):
		_emit_nectar_blocked("crucible_no_nectar", metadata)
		return {"ok": true, "suppressed": true, "reason": "crucible_no_nectar", "xp_awarded": 0}
	var event_id: String = str(metadata.get("event_id", "")).strip_edges()
	if event_id.is_empty():
		return {"ok": false, "reason": "event_id_missing"}
	_roll_daily_weekly_cycles_if_needed()
	var paid_entry: bool = bool(metadata.get("paid_entry", metadata.get("is_money_match", metadata.get("is_money", false))))
	var policy: Dictionary = _evaluate_nectar_policy("TOURNAMENT", paid_entry, 0, did_win, event_id, metadata)
	if str(policy.get("validity_status", "")) == "blocked":
		var reason: String = str(policy.get("anti_harvest_reason_if_blocked", "blocked"))
		_emit_nectar_blocked(reason, metadata)
		return {"ok": true, "suppressed": true, "reason": reason, "xp_awarded": 0}
	var xp_total: int = int(policy.get("final_nectar", _config.get_tournament_match_xp(did_win)))
	if xp_total <= 0:
		return {"ok": false, "reason": "xp_zero", "event_id": event_id}
	var reserved: Dictionary = _reserve_award_event(event_id)
	if not bool(reserved.get("ok", false)):
		return reserved
	var xp_meta: Dictionary = metadata.duplicate(true)
	xp_meta["event_id"] = event_id
	xp_meta["did_win"] = did_win
	xp_meta["paid_entry"] = paid_entry
	xp_meta["nectar_breakdown"] = policy.duplicate(true)
	var changed: bool = _apply_quest_progress("tournament_played", 1, xp_meta)
	changed = _apply_daily_challenge_progress(_daily_events_for_result(did_win), xp_meta) or changed
	changed = _apply_weekly_challenge_progress(_weekly_events_for_result(NectarRewardPolicyScript.MODE_GROUP_TOURNAMENT, paid_entry, did_win), xp_meta) or changed
	var xp_result: Dictionary = _apply_nectar_xp_award("tournament_match", xp_total, xp_meta, true)
	if not bool(xp_result.get("ok", false)):
		return xp_result
	_record_opponent_award(xp_meta)
	_save_state()
	if changed:
		_save_state()
		_emit_state_changed()
	return {
		"ok": true,
		"event_id": event_id,
		"xp_awarded": int(xp_result.get("xp_awarded", 0)),
		"base_xp": int(xp_result.get("base_xp", xp_total)),
		"xp_multiplier": float(xp_result.get("xp_multiplier", 1.0)),
		"nectar_breakdown": policy.duplicate(true),
		"battle_pass_level": _battle_pass_level
	}

func intent_record_tournament_placement(placement: int, metadata: Dictionary = {}) -> Dictionary:
	var event_id: String = str(metadata.get("event_id", "")).strip_edges()
	if event_id.is_empty():
		return {"ok": false, "reason": "event_id_missing"}
	var safe_placement: int = maxi(1, placement)
	var xp_total: int = _config.get_tournament_placement_xp(safe_placement)
	if xp_total <= 0:
		return {"ok": false, "reason": "xp_zero", "event_id": event_id}
	var reserved: Dictionary = _reserve_award_event(event_id)
	if not bool(reserved.get("ok", false)):
		return reserved
	var xp_meta: Dictionary = metadata.duplicate(true)
	xp_meta["placement"] = safe_placement
	xp_meta["event_id"] = event_id
	var changed: bool = false
	if safe_placement <= 3:
		changed = _apply_quest_progress("tournament_top3", 1, xp_meta)
	var xp_result: Dictionary = _apply_nectar_xp_award("tournament_placement", xp_total, xp_meta, true)
	if not bool(xp_result.get("ok", false)):
		return xp_result
	if changed:
		_save_state()
		_emit_state_changed()
	return {
		"ok": true,
		"event_id": event_id,
		"xp_awarded": int(xp_result.get("xp_awarded", 0)),
		"battle_pass_level": _battle_pass_level
	}

func intent_record_contest_result(scope: String, placement: int, metadata: Dictionary = {}) -> Dictionary:
	var event_id: String = str(metadata.get("event_id", "")).strip_edges()
	if event_id.is_empty():
		return {"ok": false, "reason": "event_id_missing"}
	var clean_scope: String = scope.strip_edges().to_upper()
	var safe_placement: int = maxi(1, placement)
	var xp_total: int = _config.get_contest_result_xp(clean_scope, safe_placement)
	if xp_total <= 0:
		return {"ok": false, "reason": "xp_zero", "event_id": event_id}
	var reserved: Dictionary = _reserve_award_event(event_id)
	if not bool(reserved.get("ok", false)):
		return reserved
	var xp_meta: Dictionary = metadata.duplicate(true)
	xp_meta["scope"] = clean_scope
	xp_meta["placement"] = safe_placement
	xp_meta["event_id"] = event_id
	var changed: bool = false
	if safe_placement <= 3:
		changed = _apply_quest_progress("contest_top3", 1, xp_meta)
	var xp_result: Dictionary = _apply_nectar_xp_award("contest_result", xp_total, xp_meta, true)
	if not bool(xp_result.get("ok", false)):
		return xp_result
	if changed:
		_save_state()
		_emit_state_changed()
	return {
		"ok": true,
		"event_id": event_id,
		"xp_awarded": int(xp_result.get("xp_awarded", 0)),
		"battle_pass_level": _battle_pass_level
	}

func get_access_ticket_balance() -> int:
	return maxi(0, int(_inventory.get("access_tickets", 0)))

func intent_grant_analytics_credit(package_id: String, quantity: int = 1, source_key: String = "") -> Dictionary:
	var clean_package_id: String = package_id.strip_edges()
	if clean_package_id.is_empty():
		return {"ok": false, "reason": "missing_package_id"}
	var safe_quantity: int = maxi(1, quantity)
	var clean_source: String = source_key.strip_edges()
	if clean_source.is_empty():
		clean_source = "analytics_credit:%s" % clean_package_id
	var claim_key: String = "analytics_credit|%s|%s" % [clean_package_id, clean_source]
	if _exclusive_event_prize_claims.has(claim_key):
		return {
			"ok": true,
			"already_claimed": true,
			"package_id": clean_package_id,
			"inventory": _inventory.duplicate(true)
		}
	var grant_result: Dictionary = _grant_reward({
		"reward_type": "analytics_credit",
		"package_id": clean_package_id,
		"quantity": safe_quantity
	}, clean_source)
	if not bool(grant_result.get("ok", false)):
		return grant_result
	_exclusive_event_prize_claims[claim_key] = {
		"entry_kind": "analytics_credit",
		"entry_id": clean_package_id,
		"source_key": clean_source,
		"reward_count": 1,
		"claimed_at_unix": int(Time.get_unix_time_from_system()),
		"metadata": {"package_id": clean_package_id, "quantity": safe_quantity}
	}
	_save_state()
	_emit_event("analytics_credit_granted", {
		"package_id": clean_package_id,
		"quantity": safe_quantity,
		"source_key": clean_source
	})
	_emit_state_changed()
	return {
		"ok": true,
		"package_id": clean_package_id,
		"quantity": safe_quantity,
		"inventory": _inventory.duplicate(true)
	}

func intent_consume_analytics_credit(package_id: String, usage_id: String) -> Dictionary:
	var clean_package: String = package_id.strip_edges()
	var clean_usage: String = usage_id.strip_edges()
	if clean_package.is_empty() or clean_usage.is_empty():
		return {"ok": false, "reason": "analytics_redemption_key_missing"}
	var receipt_key: String = "analytics:%s:%s" % [clean_package, clean_usage]
	if _redemption_receipts.has(receipt_key):
		return {"ok": true, "already_redeemed": true, "receipt": (_redemption_receipts.get(receipt_key, {}) as Dictionary).duplicate(true)}
	var credits: Dictionary = _inventory.get("analytics_credits", {}) as Dictionary
	var balance: int = maxi(0, int(credits.get(clean_package, 0)))
	if balance <= 0:
		return {"ok": false, "reason": "insufficient_analytics_credit", "package_id": clean_package}
	credits[clean_package] = balance - 1
	_inventory["analytics_credits"] = credits
	return _record_redemption(receipt_key, "analytics_credit", clean_package, clean_usage)

func intent_redeem_bundle_token(bundle_id: String, redemption_id: String) -> Dictionary:
	var clean_bundle: String = bundle_id.strip_edges()
	var clean_redemption: String = redemption_id.strip_edges()
	if clean_bundle.is_empty() or clean_redemption.is_empty():
		return {"ok": false, "reason": "bundle_redemption_key_missing"}
	var receipt_key: String = "bundle:%s:%s" % [clean_bundle, clean_redemption]
	if _redemption_receipts.has(receipt_key):
		return {"ok": true, "already_redeemed": true, "receipt": (_redemption_receipts.get(receipt_key, {}) as Dictionary).duplicate(true)}
	var tokens: Dictionary = _inventory.get("bundle_tokens", {}) as Dictionary
	var balance: int = maxi(0, int(tokens.get(clean_bundle, 0)))
	if balance <= 0:
		return {"ok": false, "reason": "insufficient_bundle_token", "bundle_id": clean_bundle}
	tokens[clean_bundle] = balance - 1
	_inventory["bundle_tokens"] = tokens
	return _record_redemption(receipt_key, "bundle_token", clean_bundle, clean_redemption)

func has_active_ad_free_reward() -> bool:
	return _ad_free_until_unix > int(Time.get_unix_time_from_system())

func get_ad_free_until_unix() -> int:
	return _ad_free_until_unix

func _record_redemption(receipt_key: String, reward_type: String, item_id: String, redemption_id: String) -> Dictionary:
	var receipt: Dictionary = {
		"receipt_id": receipt_key.sha256_text(),
		"reward_type": reward_type,
		"item_id": item_id,
		"redemption_id": redemption_id,
		"redeemed_at_unix": int(Time.get_unix_time_from_system())
	}
	_redemption_receipts[receipt_key] = receipt
	_save_state()
	_emit_event("battle_path_reward_redeemed", receipt)
	_emit_state_changed()
	return {"ok": true, "receipt": receipt.duplicate(true), "inventory": _inventory.duplicate(true)}

func preview_access_ticket_entry(entry_kind: String, entry_id: String, quantity: int = 1) -> Dictionary:
	var clean_kind: String = entry_kind.strip_edges().to_lower()
	var clean_id: String = entry_id.strip_edges()
	var safe_quantity: int = maxi(1, quantity)
	if clean_kind.is_empty() or clean_id.is_empty():
		return {"ok": false, "reason": "entry_key_missing"}
	var balance: int = get_access_ticket_balance()
	var key: String = _access_ticket_entry_key(clean_kind, clean_id)
	var already_authorized: bool = _access_ticket_entry_claims.has(key)
	return {
		"ok": true,
		"entry_kind": clean_kind,
		"entry_id": clean_id,
		"ticket_cost": safe_quantity,
		"ticket_balance": balance,
		"already_authorized": already_authorized,
		"can_authorize": already_authorized or balance >= safe_quantity
	}

func preview_exclusive_event_entry(entry_kind: String, entry_id: String, quantity: int = 1, prize_rewards: Array = []) -> Dictionary:
	var preview: Dictionary = preview_access_ticket_entry(entry_kind, entry_id, quantity)
	if not bool(preview.get("ok", false)):
		return preview
	preview["prize_rewards"] = _normalize_reward_array(prize_rewards)
	return preview

func intent_authorize_access_ticket_entry(entry_kind: String, entry_id: String, quantity: int = 1, metadata: Dictionary = {}) -> Dictionary:
	var preview: Dictionary = preview_access_ticket_entry(entry_kind, entry_id, quantity)
	if not bool(preview.get("ok", false)):
		return preview
	var clean_kind: String = str(preview.get("entry_kind", ""))
	var clean_id: String = str(preview.get("entry_id", ""))
	var safe_quantity: int = int(preview.get("ticket_cost", 1))
	var key: String = _access_ticket_entry_key(clean_kind, clean_id)
	if bool(preview.get("already_authorized", false)):
		return {
			"ok": true,
			"entry_kind": clean_kind,
			"entry_id": clean_id,
			"ticket_cost": safe_quantity,
			"already_authorized": true,
			"ticket_balance": get_access_ticket_balance()
		}
	if not bool(preview.get("can_authorize", false)):
		return {
			"ok": false,
			"reason": "insufficient_access_tickets",
			"ticket_cost": safe_quantity,
			"ticket_balance": int(preview.get("ticket_balance", 0))
		}
	_inventory["access_tickets"] = get_access_ticket_balance() - safe_quantity
	_access_ticket_entry_claims[key] = {
		"entry_kind": clean_kind,
		"entry_id": clean_id,
		"ticket_cost": safe_quantity,
		"authorized_at_unix": int(Time.get_unix_time_from_system()),
		"metadata": metadata.duplicate(true)
	}
	_save_state()
	_emit_event("access_ticket_entry_authorized", {
		"entry_kind": clean_kind,
		"entry_id": clean_id,
		"ticket_cost": safe_quantity
	})
	_emit_state_changed()
	return {
		"ok": true,
		"entry_kind": clean_kind,
		"entry_id": clean_id,
		"ticket_cost": safe_quantity,
		"ticket_balance": get_access_ticket_balance()
	}

func intent_authorize_exclusive_event_entry(entry_kind: String, entry_id: String, quantity: int = 1, metadata: Dictionary = {}) -> Dictionary:
	return intent_authorize_access_ticket_entry(entry_kind, entry_id, quantity, metadata)

func intent_refund_access_ticket_entry(entry_kind: String, entry_id: String, reason: String = "entry_refund") -> Dictionary:
	var clean_kind: String = entry_kind.strip_edges().to_lower()
	var clean_id: String = entry_id.strip_edges()
	if clean_kind.is_empty() or clean_id.is_empty():
		return {"ok": false, "reason": "entry_key_missing"}
	var key: String = _access_ticket_entry_key(clean_kind, clean_id)
	if not _access_ticket_entry_claims.has(key):
		return {"ok": false, "reason": "entry_not_authorized"}
	var claim: Dictionary = _access_ticket_entry_claims.get(key, {}) as Dictionary
	var ticket_cost: int = maxi(1, int(claim.get("ticket_cost", 1)))
	_access_ticket_entry_claims.erase(key)
	_inventory["access_tickets"] = get_access_ticket_balance() + ticket_cost
	_save_state()
	_emit_event("access_ticket_entry_refunded", {
		"entry_kind": clean_kind,
		"entry_id": clean_id,
		"ticket_cost": ticket_cost,
		"reason": reason
	})
	_emit_state_changed()
	return {
		"ok": true,
		"entry_kind": clean_kind,
		"entry_id": clean_id,
		"ticket_cost": ticket_cost,
		"ticket_balance": get_access_ticket_balance()
	}

func intent_refund_exclusive_event_entry(entry_kind: String, entry_id: String, reason: String = "entry_refund") -> Dictionary:
	return intent_refund_access_ticket_entry(entry_kind, entry_id, reason)

func intent_claim_exclusive_event_prizes(entry_kind: String, entry_id: String, prize_rewards: Array, metadata: Dictionary = {}) -> Dictionary:
	var clean_kind: String = entry_kind.strip_edges().to_lower()
	var clean_id: String = entry_id.strip_edges()
	if clean_kind.is_empty() or clean_id.is_empty():
		return {"ok": false, "reason": "entry_key_missing"}
	var normalized_rewards: Array[Dictionary] = _normalize_reward_array(prize_rewards)
	if normalized_rewards.is_empty():
		return {"ok": false, "reason": "no_prize_rewards"}
	var key: String = _exclusive_event_prize_key(clean_kind, clean_id)
	if _exclusive_event_prize_claims.has(key):
		return {
			"ok": true,
			"entry_kind": clean_kind,
			"entry_id": clean_id,
			"already_claimed": true,
			"wallet": _wallet.duplicate(true),
			"inventory": _inventory.duplicate(true)
		}
	var grant_result: Dictionary = _grant_reward_batch(normalized_rewards, "exclusive:%s" % key)
	if not bool(grant_result.get("ok", false)):
		return {"ok": false, "reason": "reward_batch_failed", "grant_result": grant_result}
	_wallet = (grant_result.get("wallet", _wallet) as Dictionary).duplicate(true)
	_inventory = (grant_result.get("inventory", _inventory) as Dictionary).duplicate(true)
	_exclusive_event_prize_claims[key] = {
		"entry_kind": clean_kind,
		"entry_id": clean_id,
		"reward_count": normalized_rewards.size(),
		"claimed_at_unix": int(Time.get_unix_time_from_system()),
		"metadata": metadata.duplicate(true)
	}
	_save_state()
	_emit_event("exclusive_event_prizes_claimed", {
		"entry_kind": clean_kind,
		"entry_id": clean_id,
		"reward_count": normalized_rewards.size()
	})
	_emit_state_changed()
	return {
		"ok": true,
		"entry_kind": clean_kind,
		"entry_id": clean_id,
		"grants": (grant_result.get("grants", []) as Array).duplicate(true),
		"wallet": _wallet.duplicate(true),
		"inventory": _inventory.duplicate(true)
	}

func intent_award_match_completion(match_id: String, won: bool, is_money_match: bool, metadata: Dictionary = {}) -> Dictionary:
	var clean_match_id: String = match_id.strip_edges()
	if clean_match_id.is_empty():
		return {"ok": false, "reason": "match_id_missing"}
	var xp_meta: Dictionary = metadata.duplicate(true)
	xp_meta["event_id"] = clean_match_id
	var money_tier: int = maxi(0, int(xp_meta.get("money_tier", 1 if is_money_match else 0)))
	var mode_id: String = str(xp_meta.get("mode_id", xp_meta.get("pvp_mode_id", "1V1"))).strip_edges()
	return intent_record_pvp_completion(mode_id, is_money_match, money_tier, won, xp_meta)

func intent_record_quest_progress(event_key: String, amount: int = 1, metadata: Dictionary = {}) -> Dictionary:
	var clean_event: String = event_key.strip_edges().to_lower()
	var safe_amount: int = maxi(0, amount)
	if clean_event.is_empty() or safe_amount <= 0:
		return {"ok": false, "reason": "invalid_event_or_amount"}
	var changed: bool = _apply_quest_progress(clean_event, safe_amount, metadata)
	var xp_bonus: int = _config.get_xp_award(clean_event)
	if xp_bonus > 0:
		var total_bonus: int = xp_bonus * safe_amount
		intent_award_nectar_xp(clean_event, total_bonus, metadata)
		changed = true
	_claim_ready_quest_bonuses()
	if changed:
		_save_state()
		_emit_state_changed()
	return {"ok": true, "changed": changed}

func intent_claim_quest_reward(quest_id: String) -> Dictionary:
	var clean_id: String = quest_id.strip_edges()
	if clean_id.is_empty():
		return {"ok": false, "reason": "quest_id_missing"}
	var quest_def: Dictionary = _config.get_quest_definition(clean_id)
	if quest_def.is_empty():
		return {"ok": false, "reason": "quest_missing"}
	if not _quest_path_available(quest_def):
		return {"ok": false, "reason": "quest_path_locked"}
	if bool(_quest_claimed.get(clean_id, false)):
		return {"ok": false, "reason": "quest_already_claimed"}
	var target: int = maxi(1, int(quest_def.get("target", 1)))
	var current_progress: int = maxi(0, int(_quest_progress.get(clean_id, 0)))
	if current_progress < target:
		return {"ok": false, "reason": "quest_incomplete", "progress": current_progress, "target": target}
	var reward_def_any: Variant = quest_def.get("reward", {})
	var reward_grant: Dictionary = {}
	if typeof(reward_def_any) == TYPE_DICTIONARY:
		reward_grant = _grant_reward(reward_def_any as Dictionary, "quest:%s:%s" % [_current_season_id, clean_id])
		if not bool(reward_grant.get("ok", false)):
			return {"ok": false, "reason": "reward_grant_failed", "grant_result": reward_grant}
	var xp_reward: int = maxi(0, int(quest_def.get("xp_reward", 0)))
	if xp_reward > 0:
		intent_award_nectar_xp("quest_claim:%s" % clean_id, xp_reward, {"quest_id": clean_id})
	_quest_claimed[clean_id] = true
	_claim_ready_quest_bonuses()
	_save_state()
	_emit_event("quest_claimed", {"quest_id": clean_id, "xp_reward": xp_reward})
	_emit_state_changed()
	return {
		"ok": true,
		"quest_id": clean_id,
		"xp_reward": xp_reward,
		"reward_grant": reward_grant
	}

func intent_claim_daily_challenge(challenge_id: String) -> Dictionary:
	_roll_daily_weekly_cycles_if_needed()
	var clean_id: String = challenge_id.strip_edges()
	if clean_id.is_empty():
		return {"ok": false, "reason": "challenge_id_missing"}
	var challenge: Dictionary = _daily_challenge_definition(clean_id)
	if challenge.is_empty():
		return {"ok": false, "reason": "challenge_missing"}
	if bool(_daily_challenge_claimed.get(clean_id, false)):
		return {"ok": false, "reason": "challenge_already_claimed"}
	var target: int = maxi(1, int(challenge.get("target", 1)))
	var progress: int = maxi(0, int(_daily_challenge_progress.get(clean_id, 0)))
	if progress < target:
		return {"ok": false, "reason": "challenge_incomplete", "progress": progress, "target": target}
	_daily_challenge_claimed[clean_id] = true
	var xp_reward: int = maxi(0, int(challenge.get("xp_reward", 0)))
	var xp_result: Dictionary = {}
	if xp_reward > 0:
		xp_result = intent_award_nectar_xp("daily_challenge:%s" % clean_id, xp_reward, {"challenge_id": clean_id, "daily_cycle_key": _daily_cycle_key})
	_save_state()
	_emit_event("nectar_daily_challenge_completed", {
		"challenge_id": clean_id,
		"xp_reward": xp_reward,
		"daily_cycle_key": _daily_cycle_key
	})
	_emit_state_changed()
	return {
		"ok": true,
		"challenge_id": clean_id,
		"xp_reward": xp_reward,
		"xp_awarded": int(xp_result.get("xp_awarded", 0)),
		"daily_cycle_key": _daily_cycle_key
	}

func intent_claim_reward(level: int, track_slot: String) -> Dictionary:
	var validation: Dictionary = _validate_claim(level, track_slot, false)
	if not bool(validation.get("ok", false)):
		return validation
	var reward_def: Dictionary = _config.get_reward_slot(level, track_slot)
	var grant_result: Dictionary = _grant_reward(reward_def, "level:%s:%d:%s" % [_current_season_id, level, track_slot])
	if not bool(grant_result.get("ok", false)):
		return {"ok": false, "reason": "reward_grant_failed", "grant_result": grant_result}
	_mark_claimed(level, track_slot)
	if _config.is_post_100_level(level) and _scarcity_feature_enabled and track_slot != TRACK_FREE:
		var level_key: String = str(level)
		var used: int = maxi(0, int(_scarcity_claims_by_level.get(level_key, 0)))
		_scarcity_claims_by_level[level_key] = used + 1
	_save_state()
	_emit_event("reward_claimed", {
		"level": level,
		"track_slot": track_slot,
		"reward_type": str(reward_def.get("reward_type", REWARD_NONE))
	})
	_emit_state_changed()
	return {
		"ok": true,
		"level": level,
		"track_slot": track_slot,
		"reward": reward_def,
		"grant": grant_result
	}

func intent_claim_all_available() -> Dictionary:
	var visible_cap: int = _config.get_visible_cap_for_entitlements(_premium_owned, _elite_owned)
	var claimed: Array = []
	var skipped: Array = []
	for level in range(1, visible_cap + 1):
		for track_slot in [TRACK_FREE, TRACK_PREMIUM, TRACK_ELITE]:
			var preview: Dictionary = _validate_claim(level, track_slot, true)
			if not bool(preview.get("ok", false)):
				continue
			var claim_result: Dictionary = intent_claim_reward(level, track_slot)
			if bool(claim_result.get("ok", false)):
				claimed.append({"level": level, "track_slot": track_slot})
			else:
				skipped.append({"level": level, "track_slot": track_slot, "reason": str(claim_result.get("reason", "blocked"))})
	return {"ok": true, "claimed": claimed, "skipped": skipped}

func _validate_claim(level: int, track_slot: String, preview: bool) -> Dictionary:
	var clean_track: String = track_slot.strip_edges().to_lower()
	if clean_track != TRACK_FREE and clean_track != TRACK_PREMIUM and clean_track != TRACK_ELITE:
		return {"ok": false, "reason": "track_invalid"}
	var level_def: Dictionary = _config.get_level(level)
	if level_def.is_empty():
		return {"ok": false, "reason": "level_missing"}
	var reward_def: Dictionary = _config.get_reward_slot(level, clean_track)
	var reward_type: String = str(reward_def.get("reward_type", REWARD_NONE)).strip_edges().to_lower()
	if reward_type == REWARD_NONE or reward_def.is_empty():
		return {"ok": false, "reason": "no_reward_for_track"}
	if _is_claimed(level, clean_track):
		return {"ok": false, "reason": "already_claimed"}
	if level > _battle_pass_level:
		return {"ok": false, "reason": "level_locked"}
	if clean_track == TRACK_PREMIUM and not (_premium_owned or _elite_owned):
		return {"ok": false, "reason": "premium_required"}
	if clean_track == TRACK_ELITE and not _elite_owned:
		return {"ok": false, "reason": "elite_required"}
	if _config.is_post_100_level(level):
		if clean_track == TRACK_PREMIUM and level > 110:
			return {"ok": false, "reason": "premium_level_cap"}
		if clean_track == TRACK_ELITE and level > 120:
			return {"ok": false, "reason": "elite_level_cap"}
		if clean_track == TRACK_FREE:
			return {"ok": false, "reason": "free_post100_disabled"}
	if _is_veteran_reward_locked(level):
		return {"ok": false, "reason": "veteran_lock_active", "unlock_level": _veteran_unlock_level}
	if _config.is_post_100_level(level) and _scarcity_feature_enabled and clean_track != TRACK_FREE:
		var level_key: String = str(level)
		var cap: int = _prestige_cap_for_level(level)
		var used: int = maxi(0, int(_scarcity_claims_by_level.get(level_key, 0)))
		var remaining: int = cap - used
		if cap >= 0 and remaining <= 0:
			return {"ok": false, "reason": "scarcity_full", "scarcity_cap": cap, "scarcity_remaining": 0}
		if preview:
			return {"ok": true, "scarcity_cap": cap, "scarcity_remaining": maxi(0, remaining)}
	return {"ok": true}

func _build_level_rows(visible_cap: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for level in range(1, visible_cap + 1):
		var level_def: Dictionary = _config.get_level(level)
		if level_def.is_empty():
			continue
		rows.append({
			"level": level,
			"unlocked": level <= _battle_pass_level,
			"is_post_100": _config.is_post_100_level(level),
			"xp_required": _config.get_level_xp_required(level),
			"scarcity_cap": _prestige_cap_for_level(level),
			"scarcity_remaining": _scarcity_remaining(level),
			"tracks": {
				TRACK_FREE: _build_track_state(level, TRACK_FREE),
				TRACK_PREMIUM: _build_track_state(level, TRACK_PREMIUM),
				TRACK_ELITE: _build_track_state(level, TRACK_ELITE)
			}
		})
	return rows

func _build_track_state(level: int, track_slot: String) -> Dictionary:
	var reward_def: Dictionary = _config.get_reward_slot(level, track_slot)
	var reward_type: String = str(reward_def.get("reward_type", REWARD_NONE)).strip_edges().to_lower()
	var claimed: bool = _is_claimed(level, track_slot)
	var validation: Dictionary = _validate_claim(level, track_slot, true)
	return {
		"track_slot": track_slot,
		"reward": reward_def,
		"reward_type": reward_type,
		"claimed": claimed,
		"claimable": bool(validation.get("ok", false)) and not claimed,
		"locked_reason": "" if bool(validation.get("ok", false)) else str(validation.get("reason", "")),
		"scarcity_remaining": int(validation.get("scarcity_remaining", _scarcity_remaining(level)))
	}

func _scarcity_remaining(level: int) -> int:
	var cap: int = _prestige_cap_for_level(level)
	if cap < 0:
		return -1
	var used: int = maxi(0, int(_scarcity_claims_by_level.get(str(level), 0)))
	return maxi(0, cap - used)

func _build_quest_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var quest_defs: Array = _config.get_quest_definitions()
	for quest_any in quest_defs:
		if typeof(quest_any) != TYPE_DICTIONARY:
			continue
		var quest_def: Dictionary = quest_any as Dictionary
		if not _quest_path_available(quest_def):
			continue
		var quest_id: String = str(quest_def.get("id", "")).strip_edges()
		if quest_id.is_empty():
			continue
		var target: int = maxi(1, int(quest_def.get("target", 1)))
		var progress: int = maxi(0, int(_quest_progress.get(quest_id, 0)))
		rows.append({
			"id": quest_id,
			"path_index": _quest_path_index(quest_def),
			"event_key": str(quest_def.get("event_key", "")),
			"target": target,
			"progress": mini(target, progress),
			"claimed": bool(_quest_claimed.get(quest_id, false)),
			"xp_reward": maxi(0, int(quest_def.get("xp_reward", 0))),
			"ready_to_claim": progress >= target and not bool(_quest_claimed.get(quest_id, false))
		})
	return rows

func _build_quest_bonus_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var bonus_defs: Array = _config.get_quest_bonus_definitions()
	for bonus_any in bonus_defs:
		if typeof(bonus_any) != TYPE_DICTIONARY:
			continue
		var bonus_def: Dictionary = bonus_any as Dictionary
		if not _quest_path_available(bonus_def):
			continue
		var bonus_id: String = str(bonus_def.get("id", "")).strip_edges()
		if bonus_id.is_empty():
			continue
		var required_any: Variant = bonus_def.get("required_quests", [])
		var required: Array = required_any as Array if typeof(required_any) == TYPE_ARRAY else []
		var all_complete: bool = true
		for quest_id_any in required:
			var quest_id: String = str(quest_id_any)
			if not bool(_quest_claimed.get(quest_id, false)):
				all_complete = false
				break
		rows.append({
			"id": bonus_id,
			"path_index": _quest_path_index(bonus_def),
			"required_quests": required.duplicate(true),
			"claimed": bool(_quest_bonus_claimed.get(bonus_id, false)),
			"ready_to_claim": all_complete and not bool(_quest_bonus_claimed.get(bonus_id, false))
		})
	return rows

func _build_daily_challenge_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for challenge_any in _config.get_daily_challenge_definitions():
		if typeof(challenge_any) != TYPE_DICTIONARY:
			continue
		var challenge: Dictionary = challenge_any as Dictionary
		var challenge_id: String = str(challenge.get("id", "")).strip_edges()
		if challenge_id.is_empty():
			continue
		var target: int = maxi(1, int(challenge.get("target", 1)))
		var progress: int = maxi(0, int(_daily_challenge_progress.get(challenge_id, 0)))
		rows.append({
			"id": challenge_id,
			"event_key": str(challenge.get("event_key", "")),
			"difficulty": str(challenge.get("difficulty", "")),
			"target": target,
			"progress": mini(target, progress),
			"xp_reward": maxi(0, int(challenge.get("xp_reward", 0))),
			"claimed": bool(_daily_challenge_claimed.get(challenge_id, false)),
			"ready_to_claim": progress >= target and not bool(_daily_challenge_claimed.get(challenge_id, false))
		})
	return rows

func _build_weekly_challenge_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for challenge_any in _config.get_weekly_challenge_definitions():
		if typeof(challenge_any) != TYPE_DICTIONARY:
			continue
		var challenge: Dictionary = challenge_any as Dictionary
		var challenge_id: String = str(challenge.get("id", "")).strip_edges()
		if challenge_id.is_empty():
			continue
		var target: int = maxi(1, int(challenge.get("target", 1)))
		var progress: int = maxi(0, int(_weekly_challenge_progress.get(challenge_id, 0)))
		rows.append({
			"id": challenge_id,
			"event_key": str(challenge.get("event_key", "")),
			"target": target,
			"progress": mini(target, progress),
			"xp_reward": maxi(0, int(challenge.get("xp_reward", 0))),
			"claimed": bool(_weekly_challenge_claimed.get(challenge_id, false)),
			"completed": progress >= target
		})
	return rows

func _apply_quest_progress(event_key: String, amount: int, metadata: Dictionary = {}) -> bool:
	var changed: bool = false
	var safe_amount: int = maxi(0, amount)
	if safe_amount <= 0:
		return false
	var quest_defs: Array = _config.get_quest_definitions()
	for quest_any in quest_defs:
		if typeof(quest_any) != TYPE_DICTIONARY:
			continue
		var quest_def: Dictionary = quest_any as Dictionary
		var quest_event: String = str(quest_def.get("event_key", "")).strip_edges().to_lower()
		if quest_event != event_key:
			continue
		var quest_id: String = str(quest_def.get("id", "")).strip_edges()
		if quest_id.is_empty():
			continue
		var target: int = maxi(1, int(quest_def.get("target", 1)))
		var current: int = maxi(0, int(_quest_progress.get(quest_id, 0)))
		var next: int = mini(target, current + safe_amount)
		if next == current:
			continue
		_quest_progress[quest_id] = next
		changed = true
		_emit_event("quest_progress", {
			"quest_id": quest_id,
			"event_key": event_key,
			"progress": next,
			"target": target,
			"metadata": metadata
		})
	return changed

func _apply_daily_challenge_progress(event_keys: Array[String], metadata: Dictionary = {}) -> bool:
	if event_keys.is_empty():
		return false
	_ensure_daily_challenge_state_initialized()
	var changed: bool = false
	for challenge_any in _config.get_daily_challenge_definitions():
		if typeof(challenge_any) != TYPE_DICTIONARY:
			continue
		var challenge: Dictionary = challenge_any as Dictionary
		var event_key: String = str(challenge.get("event_key", "")).strip_edges().to_lower()
		if event_key.is_empty() or not event_keys.has(event_key):
			continue
		var challenge_id: String = str(challenge.get("id", "")).strip_edges()
		if challenge_id.is_empty():
			continue
		var target: int = maxi(1, int(challenge.get("target", 1)))
		var current: int = maxi(0, int(_daily_challenge_progress.get(challenge_id, 0)))
		var next: int = mini(target, current + 1)
		if next == current:
			continue
		_daily_challenge_progress[challenge_id] = next
		changed = true
		_emit_event("nectar_daily_challenge_progress", {
			"challenge_id": challenge_id,
			"event_key": event_key,
			"progress": next,
			"target": target,
			"ready_to_claim": next >= target,
			"daily_cycle_key": _daily_cycle_key,
			"metadata": metadata
		})
	return changed

func _apply_weekly_challenge_progress(event_keys: Array[String], metadata: Dictionary = {}) -> bool:
	if event_keys.is_empty():
		return false
	_ensure_weekly_challenge_state_initialized()
	var changed: bool = false
	var completed_this_update: bool = false
	for challenge_any in _config.get_weekly_challenge_definitions():
		if typeof(challenge_any) != TYPE_DICTIONARY:
			continue
		var challenge: Dictionary = challenge_any as Dictionary
		var event_key: String = str(challenge.get("event_key", "")).strip_edges().to_lower()
		if event_key.is_empty() or not event_keys.has(event_key):
			continue
		var challenge_id: String = str(challenge.get("id", "")).strip_edges()
		if challenge_id.is_empty():
			continue
		var target: int = maxi(1, int(challenge.get("target", 1)))
		var current: int = maxi(0, int(_weekly_challenge_progress.get(challenge_id, 0)))
		var next: int = mini(target, current + 1)
		if next != current:
			_weekly_challenge_progress[challenge_id] = next
			changed = true
			_emit_event("nectar_weekly_challenge_progress", {
				"challenge_id": challenge_id,
				"event_key": event_key,
				"progress": next,
				"target": target,
				"metadata": metadata
			})
		if next >= target and not bool(_weekly_challenge_claimed.get(challenge_id, false)):
			_weekly_challenge_claimed[challenge_id] = true
			completed_this_update = true
			var reward_xp: int = maxi(0, int(challenge.get("xp_reward", 0)))
			if reward_xp > 0:
				var reward_meta: Dictionary = metadata.duplicate(true)
				reward_meta["challenge_id"] = challenge_id
				intent_award_nectar_xp("weekly_challenge:%s" % challenge_id, reward_xp, reward_meta)
			_emit_event("nectar_weekly_challenge_completed", {
				"challenge_id": challenge_id,
				"event_key": event_key,
				"xp_reward": reward_xp
			})
	if completed_this_update:
		changed = _apply_weekly_completion_bonus(metadata) or changed
	return changed

func _apply_weekly_completion_bonus(metadata: Dictionary = {}) -> bool:
	if _weekly_completion_bonus_claimed:
		return false
	var defs: Array = _config.get_weekly_challenge_definitions()
	if defs.is_empty():
		return false
	for challenge_any in defs:
		if typeof(challenge_any) != TYPE_DICTIONARY:
			continue
		var challenge: Dictionary = challenge_any as Dictionary
		var challenge_id: String = str(challenge.get("id", "")).strip_edges()
		if challenge_id.is_empty() or not bool(_weekly_challenge_claimed.get(challenge_id, false)):
			return false
	var bonus_xp: int = _config.get_weekly_completion_bonus_xp()
	if bonus_xp <= 0:
		return false
	_weekly_completion_bonus_claimed = true
	var reward_meta: Dictionary = metadata.duplicate(true)
	reward_meta["weekly_completion_bonus"] = true
	intent_award_nectar_xp("weekly_completion_bonus", bonus_xp, reward_meta)
	_emit_event("nectar_weekly_challenge_completed", {
		"challenge_id": "weekly_completion_bonus",
		"xp_reward": bonus_xp
	})
	return true

func _daily_events_for_result(did_win: bool) -> Array[String]:
	var events: Array[String] = ["daily_complete_match", "daily_play_match"]
	if did_win:
		events.append("daily_win_match")
	return events

func _weekly_events_for_result(mode_group: String, paid_entry: bool, did_win: bool) -> Array[String]:
	var events: Array[String] = []
	match mode_group:
		NectarRewardPolicyScript.MODE_GROUP_STANDARD:
			events.append("weekly_play_standard_pvp")
			if did_win:
				events.append("weekly_win_standard_pvp")
		NectarRewardPolicyScript.MODE_GROUP_PROGRESSIVE:
			events.append("weekly_play_progressive")
			if did_win:
				events.append("weekly_win_progressive")
		NectarRewardPolicyScript.MODE_GROUP_ASYNC:
			events.append("weekly_play_async")
			if did_win:
				events.append("weekly_win_async")
		NectarRewardPolicyScript.MODE_GROUP_TOURNAMENT:
			events.append("weekly_play_tournament")
			if did_win:
				events.append("weekly_win_tournament")
	if paid_entry:
		events.append("weekly_play_money")
		if did_win:
			events.append("weekly_win_money")
	return events

func _claim_ready_quest_bonuses() -> void:
	var bonus_defs: Array = _config.get_quest_bonus_definitions()
	for bonus_any in bonus_defs:
		if typeof(bonus_any) != TYPE_DICTIONARY:
			continue
		var bonus_def: Dictionary = bonus_any as Dictionary
		if not _quest_path_available(bonus_def):
			continue
		var bonus_id: String = str(bonus_def.get("id", "")).strip_edges()
		if bonus_id.is_empty():
			continue
		if bool(_quest_bonus_claimed.get(bonus_id, false)):
			continue
		var required_any: Variant = bonus_def.get("required_quests", [])
		var required: Array = required_any as Array if typeof(required_any) == TYPE_ARRAY else []
		var all_ready: bool = true
		for quest_id_any in required:
			var quest_id: String = str(quest_id_any)
			if not bool(_quest_claimed.get(quest_id, false)):
				all_ready = false
				break
		if not all_ready:
			continue
		var reward_any: Variant = bonus_def.get("reward", {})
		if typeof(reward_any) == TYPE_DICTIONARY:
			var reward_result: Dictionary = _grant_reward(reward_any as Dictionary, "quest_bonus:%s:%s" % [_current_season_id, bonus_id])
			if not bool(reward_result.get("ok", false)):
				_emit_event("quest_bonus_deferred", {"bonus_id": bonus_id, "reason": str(reward_result.get("reason", "reward_failed"))})
				continue
		var xp_reward: int = maxi(0, int(bonus_def.get("xp_reward", 0)))
		if xp_reward > 0:
			intent_award_nectar_xp("quest_bonus:%s" % bonus_id, xp_reward, {"bonus_id": bonus_id})
		_quest_bonus_claimed[bonus_id] = true
		_emit_event("quest_bonus_claimed", {"bonus_id": bonus_id})

func _grant_reward(reward_def: Dictionary, award_context: String = "") -> Dictionary:
	var reward_type: String = str(reward_def.get("reward_type", REWARD_NONE)).strip_edges().to_lower()
	if reward_type == "honey":
		var honey_state: Node = get_node_or_null("/root/HoneyProgressionState")
		if honey_state == null or not honey_state.has_method("intent_grant_player_honey"):
			return {"ok": false, "reason": "honey_authority_missing"}
		var event_id: String = "battle_path_honey:%s" % award_context.strip_edges().sha256_text()
		var metadata: Dictionary = {
			"event_id": event_id,
			"season_id": _current_season_id,
			"award_context": award_context
		}
		return honey_state.call(
			"intent_grant_player_honey",
			maxi(0, int(reward_def.get("quantity", 0))),
			"battle_path_reward",
			metadata
		) as Dictionary
	if reward_type == "ad_free_days":
		var days: int = maxi(1, int(reward_def.get("quantity", 1)))
		var now_unix: int = int(Time.get_unix_time_from_system())
		_ad_free_until_unix = maxi(now_unix, _ad_free_until_unix) + days * 86400
		return {
			"ok": true,
			"reward_type": reward_type,
			"quantity": days,
			"ad_free_until_unix": _ad_free_until_unix,
			"inventory": _inventory.duplicate(true),
			"wallet": {}
		}
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	var grant_result: Dictionary = _rewards.grant_reward(reward_def, _wallet, _inventory, profile_manager)
	if not bool(grant_result.get("ok", false)):
		return grant_result
	var wallet_any: Variant = grant_result.get("wallet", _wallet)
	var inventory_any: Variant = grant_result.get("inventory", _inventory)
	if typeof(wallet_any) == TYPE_DICTIONARY:
		_wallet = _rewards.normalize_wallet(wallet_any as Dictionary)
	if typeof(inventory_any) == TYPE_DICTIONARY:
		_inventory = _rewards.normalize_inventory(inventory_any as Dictionary)
	return grant_result

func _grant_reward_batch(reward_defs: Array[Dictionary], award_context: String) -> Dictionary:
	var grants: Array[Dictionary] = []
	for index in range(reward_defs.size()):
		var result: Dictionary = _grant_reward(reward_defs[index], "%s:%d" % [award_context, index])
		if not bool(result.get("ok", false)):
			return {
				"ok": false,
				"reason": "reward_batch_failed",
				"failed_index": index,
				"grant_result": result,
				"grants": grants
			}
		grants.append(result.duplicate(true))
	return {
		"ok": true,
		"grants": grants,
		"wallet": {},
		"inventory": _inventory.duplicate(true)
	}

func _is_claimed(level: int, track_slot: String) -> bool:
	return _claimed_rewards.has(_claim_key(level, track_slot))

func _mark_claimed(level: int, track_slot: String) -> void:
	_claimed_rewards[_claim_key(level, track_slot)] = true

func _claim_key(level: int, track_slot: String) -> String:
	return "%s|%d|%s" % [_current_season_id, level, track_slot]

func _access_ticket_entry_key(entry_kind: String, entry_id: String) -> String:
	return "%s|%s|%s" % [_current_season_id, entry_kind, entry_id]

func _exclusive_event_prize_key(entry_kind: String, entry_id: String) -> String:
	return "%s|%s|%s" % [_current_season_id, entry_kind, entry_id]

func _normalize_reward_array(reward_defs: Array) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for reward_any in reward_defs:
		if typeof(reward_any) != TYPE_DICTIONARY:
			continue
		normalized.append((reward_any as Dictionary).duplicate(true))
	return normalized

func _is_veteran_pregrant_lock_active() -> bool:
	return _is_veteran_reward_locked(_veteran_start_level)

func _is_veteran_reward_locked(level: int) -> bool:
	if not _veteran_start_applied:
		return false
	if _veteran_start_level <= 1:
		return false
	if _veteran_rewards_unlocked:
		return false
	if _battle_pass_level >= _veteran_unlock_level:
		return false
	return level <= _veteran_start_level

func _refresh_veteran_unlock_state() -> void:
	if not _veteran_start_applied:
		_veteran_rewards_unlocked = true
		return
	if _veteran_start_level <= 1:
		_veteran_rewards_unlocked = true
		return
	if _battle_pass_level >= _veteran_unlock_level:
		if not _veteran_rewards_unlocked:
			_emit_event("veteran_rewards_unlocked", {"unlock_level": _veteran_unlock_level})
		_veteran_rewards_unlocked = true
	else:
		_veteran_rewards_unlocked = false

func _recalculate_level_from_xp() -> void:
	var next_level: int = _config.level_for_xp(_battle_pass_xp)
	_battle_pass_level = clampi(next_level, 1, _config.get_total_levels())

func _ensure_quest_state_initialized() -> void:
	var quest_defs: Array = _config.get_quest_definitions()
	for quest_any in quest_defs:
		if typeof(quest_any) != TYPE_DICTIONARY:
			continue
		var quest_def: Dictionary = quest_any as Dictionary
		var quest_id: String = str(quest_def.get("id", "")).strip_edges()
		if quest_id.is_empty():
			continue
		if not _quest_progress.has(quest_id):
			_quest_progress[quest_id] = 0
		if not _quest_claimed.has(quest_id):
			_quest_claimed[quest_id] = false

func _ensure_daily_challenge_state_initialized() -> void:
	for challenge_any in _config.get_daily_challenge_definitions():
		if typeof(challenge_any) != TYPE_DICTIONARY:
			continue
		var challenge: Dictionary = challenge_any as Dictionary
		var challenge_id: String = str(challenge.get("id", "")).strip_edges()
		if challenge_id.is_empty():
			continue
		if not _daily_challenge_progress.has(challenge_id):
			_daily_challenge_progress[challenge_id] = 0
		if not _daily_challenge_claimed.has(challenge_id):
			_daily_challenge_claimed[challenge_id] = false

func _ensure_weekly_challenge_state_initialized() -> void:
	for challenge_any in _config.get_weekly_challenge_definitions():
		if typeof(challenge_any) != TYPE_DICTIONARY:
			continue
		var challenge: Dictionary = challenge_any as Dictionary
		var challenge_id: String = str(challenge.get("id", "")).strip_edges()
		if challenge_id.is_empty():
			continue
		if not _weekly_challenge_progress.has(challenge_id):
			_weekly_challenge_progress[challenge_id] = 0
		if not _weekly_challenge_claimed.has(challenge_id):
			_weekly_challenge_claimed[challenge_id] = false

func _daily_challenge_definition(challenge_id: String) -> Dictionary:
	var clean_id: String = challenge_id.strip_edges()
	if clean_id.is_empty():
		return {}
	for challenge_any in _config.get_daily_challenge_definitions():
		if typeof(challenge_any) != TYPE_DICTIONARY:
			continue
		var challenge: Dictionary = challenge_any as Dictionary
		if str(challenge.get("id", "")).strip_edges() == clean_id:
			return challenge.duplicate(true)
	return {}

func _roll_daily_weekly_cycles_if_needed() -> void:
	var changed: bool = false
	var live_daily: String = _current_daily_cycle_key()
	if _daily_cycle_key != live_daily:
		_daily_cycle_key = live_daily
		_nectar_earned_by_day.clear()
		_daily_challenge_progress.clear()
		_daily_challenge_claimed.clear()
		_ensure_daily_challenge_state_initialized()
		changed = true
	var live_weekly: String = _current_weekly_cycle_key()
	if _weekly_cycle_key != live_weekly:
		_weekly_cycle_key = live_weekly
		_weekly_challenge_progress.clear()
		_weekly_challenge_claimed.clear()
		_weekly_completion_bonus_claimed = false
		_ensure_weekly_challenge_state_initialized()
		changed = true
	if changed:
		_save_state()

func _current_daily_cycle_key() -> String:
	var date: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [
		int(date.get("year", 1970)),
		int(date.get("month", 1)),
		int(date.get("day", 1))
	]

func _current_weekly_cycle_key() -> String:
	var unix_day: int = int(floor(Time.get_unix_time_from_system() / 86400.0))
	return "week_%d" % int(floor(float(unix_day) / 7.0))

func _evaluate_nectar_policy(mode_id: String, paid_entry: bool, money_tier: int, did_win: bool, event_id: String, metadata: Dictionary) -> Dictionary:
	var payload: Dictionary = metadata.duplicate(true)
	payload["mode_id"] = mode_id.strip_edges().to_upper()
	payload["paid_entry"] = paid_entry
	payload["is_money_match"] = paid_entry
	payload["money_tier"] = money_tier
	payload["did_win"] = did_win
	payload["event_id"] = event_id
	payload["match_id"] = event_id
	payload["multiplier"] = _config.get_nectar_multiplier_for_entitlements(_premium_owned, _elite_owned)
	payload["pass_tier"] = TRACK_ELITE if _elite_owned else TRACK_PREMIUM if _premium_owned else TRACK_FREE
	payload["season_active"] = _season_is_active()
	payload["require_match_duration"] = true
	payload["daily_nectar_earned"] = maxi(0, int(_nectar_earned_by_day.get(_current_daily_cycle_key(), 0)))
	payload["repeated_opponent_count"] = _recent_opponent_award_count(str(metadata.get("opponent_id", "")))
	_emit_event("nectar_award_attempt", {
		"event_id": event_id,
		"mode_id": payload["mode_id"],
		"paid_entry": paid_entry,
		"did_win": did_win
	})
	return NectarRewardPolicyScript.evaluate_match(payload, _config.get_nectar_policy_config())

func _recent_opponent_award_count(opponent_id: String) -> int:
	var clean_id: String = opponent_id.strip_edges()
	if clean_id.is_empty():
		return 0
	var now_unix: int = int(Time.get_unix_time_from_system())
	var cutoff: int = now_unix - OPPONENT_HISTORY_WINDOW_SEC
	var recent: Array = []
	var history_any: Variant = _opponent_award_times.get(clean_id, [])
	if typeof(history_any) == TYPE_ARRAY:
		for timestamp_any in history_any as Array:
			var timestamp: int = int(timestamp_any)
			if timestamp >= cutoff and timestamp <= now_unix + 60:
				recent.append(timestamp)
	if recent.size() > OPPONENT_HISTORY_MAX_PER_OPPONENT:
		recent = recent.slice(recent.size() - OPPONENT_HISTORY_MAX_PER_OPPONENT)
	if recent.is_empty():
		_opponent_award_times.erase(clean_id)
	else:
		_opponent_award_times[clean_id] = recent
	return recent.size()

func _record_opponent_award(metadata: Dictionary) -> void:
	var clean_id: String = str(metadata.get("opponent_id", "")).strip_edges()
	if clean_id.is_empty():
		return
	_recent_opponent_award_count(clean_id)
	var history: Array = _opponent_award_times.get(clean_id, []) as Array
	history.append(int(Time.get_unix_time_from_system()))
	if history.size() > OPPONENT_HISTORY_MAX_PER_OPPONENT:
		history = history.slice(history.size() - OPPONENT_HISTORY_MAX_PER_OPPONENT)
	_opponent_award_times[clean_id] = history

func _nectar_blocked_reason(source_name: String, metadata: Dictionary) -> String:
	var payload: Dictionary = metadata.duplicate(true)
	if metadata.has("mode_id") or metadata.has("pvp_mode_id") or metadata.has("vs_mode"):
		payload["mode_id"] = str(metadata.get("mode_id", metadata.get("pvp_mode_id", metadata.get("vs_mode", "")))).strip_edges().to_upper()
	else:
		payload["mode_id"] = "STANDARD"
	return NectarRewardPolicyScript.blocked_reason_for_payload(payload)

func _metadata_did_win(metadata: Dictionary) -> bool:
	if metadata.has("did_win"):
		return bool(metadata.get("did_win", false))
	if metadata.has("won"):
		return bool(metadata.get("won", false))
	if metadata.has("placement"):
		return int(metadata.get("placement", 0)) == 1
	if metadata.has("rank"):
		return int(metadata.get("rank", 0)) == 1
	return false

func _emit_nectar_blocked(reason: String, metadata: Dictionary) -> void:
	var event_type: String = "nectar_blocked_crucible" if reason == "crucible_no_nectar" else "nectar_blocked_antiharvest"
	_emit_event(event_type, {
		"reason": reason,
		"metadata": metadata
	})

func _prune_award_dedupe() -> void:
	while _awarded_match_order.size() > MATCH_DEDUPE_MAX:
		var drop_id: String = _awarded_match_order[0]
		_awarded_match_order.remove_at(0)
		_awarded_match_ids.erase(drop_id)

func _roll_season_if_needed() -> void:
	var live_season: String = _config.get_season_id()
	if _current_season_id == live_season:
		return
	_current_season_id = live_season
	_battle_pass_xp = 0
	_battle_pass_level = 1
	_nectar_fractional_milli = 0
	_premium_owned = false
	_elite_owned = false
	_claimed_rewards.clear()
	_scarcity_claims_by_level.clear()
	_season_prestige_base_slots = _config.compute_projected_prestige_pool_base()
	_season_prestige_caps_by_level = _config.build_prestige_caps(_season_prestige_base_slots)
	_veteran_start_applied = false
	_veteran_rewards_unlocked = true
	_veteran_start_level = 1
	_awarded_match_ids.clear()
	_awarded_match_order.clear()
	_first_win_bonus_by_day_player.clear()
	_nectar_earned_by_day.clear()
	_opponent_award_times.clear()
	_quest_progress.clear()
	_quest_claimed.clear()
	_quest_bonus_claimed.clear()
	_daily_cycle_key = _current_daily_cycle_key()
	_daily_challenge_progress.clear()
	_daily_challenge_claimed.clear()
	_weekly_cycle_key = _current_weekly_cycle_key()
	_weekly_challenge_progress.clear()
	_weekly_challenge_claimed.clear()
	_weekly_completion_bonus_claimed = false
	_ensure_quest_state_initialized()
	_ensure_daily_challenge_state_initialized()
	_ensure_weekly_challenge_state_initialized()
	_save_state()
	_emit_event("season_reset", {"season_id": _current_season_id, "prestige_pool_base_slots": _season_prestige_base_slots})

func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_current_season_id = _config.get_season_id()
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_current_season_id = _config.get_season_id()
		return
	var text: String = file.get_as_text()
	var parsed_any: Variant = JSON.parse_string(text)
	if typeof(parsed_any) != TYPE_DICTIONARY:
		_current_season_id = _config.get_season_id()
		return
	var migrated: Dictionary = _migrate_loaded_state(parsed_any as Dictionary)
	_apply_loaded_state(migrated)

func _migrate_loaded_state(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"schema_version": SAVE_SCHEMA_VERSION,
		"current_season_id": str(raw.get("current_season_id", _config.get_season_id())),
		"battle_pass_xp": maxi(0, int(raw.get("battle_pass_xp", 0))),
		"battle_pass_level": maxi(1, int(raw.get("battle_pass_level", 1))),
		"nectar_fractional_milli": clampi(int(raw.get("nectar_fractional_milli", 0)), 0, NECTAR_FIXED_POINT_SCALE - 1),
		"premium_owned": bool(raw.get("premium_owned", false)),
		"elite_owned": bool(raw.get("elite_owned", false)),
		"claimed_rewards": {},
		"scarcity_claims_by_level": {},
		"scarcity_feature_enabled": bool(raw.get("scarcity_feature_enabled", _config.get_scarcity_feature_default_enabled())),
		"season_prestige_base_slots": maxi(0, int(raw.get("season_prestige_base_slots", 0))),
		"season_prestige_caps_by_level": {},
		"veteran_start_applied": bool(raw.get("veteran_start_applied", false)),
		"veteran_rewards_unlocked": bool(raw.get("veteran_rewards_unlocked", true)),
		"veteran_start_level": maxi(1, int(raw.get("veteran_start_level", 1))),
		"veteran_unlock_level": maxi(1, int(raw.get("veteran_unlock_level", _config.get_veteran_unlock_level()))),
		"wallet": {},
		"inventory": {},
		"awarded_match_ids": {},
		"awarded_match_order": [],
		"first_win_bonus_by_day_player": {},
		"nectar_earned_by_day": {},
		"opponent_award_times": {},
		"ad_free_until_unix": maxi(0, int(raw.get("ad_free_until_unix", 0))),
		"redemption_receipts": {},
		"quest_progress": {},
		"quest_claimed": {},
		"quest_bonus_claimed": {},
		"daily_cycle_key": str(raw.get("daily_cycle_key", "")),
		"daily_challenge_progress": {},
		"daily_challenge_claimed": {},
		"weekly_cycle_key": str(raw.get("weekly_cycle_key", "")),
		"weekly_challenge_progress": {},
		"weekly_challenge_claimed": {},
		"weekly_completion_bonus_claimed": bool(raw.get("weekly_completion_bonus_claimed", false)),
		"access_ticket_entry_claims": {},
		"exclusive_event_prize_claims": {}
	}
	var claimed_any: Variant = raw.get("claimed_rewards", {})
	if typeof(claimed_any) == TYPE_DICTIONARY:
		out["claimed_rewards"] = (claimed_any as Dictionary).duplicate(true)
	var scarcity_any: Variant = raw.get("scarcity_claims_by_level", {})
	if typeof(scarcity_any) == TYPE_DICTIONARY:
		out["scarcity_claims_by_level"] = (scarcity_any as Dictionary).duplicate(true)
	var prestige_caps_any: Variant = raw.get("season_prestige_caps_by_level", {})
	if typeof(prestige_caps_any) == TYPE_DICTIONARY:
		out["season_prestige_caps_by_level"] = (prestige_caps_any as Dictionary).duplicate(true)
	var wallet_any: Variant = raw.get("wallet", {})
	if typeof(wallet_any) == TYPE_DICTIONARY:
		out["wallet"] = (wallet_any as Dictionary).duplicate(true)
	var inventory_any: Variant = raw.get("inventory", {})
	if typeof(inventory_any) == TYPE_DICTIONARY:
		out["inventory"] = (inventory_any as Dictionary).duplicate(true)
	var award_ids_any: Variant = raw.get("awarded_match_ids", {})
	if typeof(award_ids_any) == TYPE_DICTIONARY:
		out["awarded_match_ids"] = (award_ids_any as Dictionary).duplicate(true)
	var award_order_any: Variant = raw.get("awarded_match_order", [])
	if typeof(award_order_any) == TYPE_ARRAY:
		out["awarded_match_order"] = (award_order_any as Array).duplicate(true)
	var first_win_any: Variant = raw.get("first_win_bonus_by_day_player", {})
	if typeof(first_win_any) == TYPE_DICTIONARY:
		out["first_win_bonus_by_day_player"] = (first_win_any as Dictionary).duplicate(true)
	var nectar_daily_any: Variant = raw.get("nectar_earned_by_day", {})
	if typeof(nectar_daily_any) == TYPE_DICTIONARY:
		out["nectar_earned_by_day"] = (nectar_daily_any as Dictionary).duplicate(true)
	var opponent_history_any: Variant = raw.get("opponent_award_times", {})
	if typeof(opponent_history_any) == TYPE_DICTIONARY:
		out["opponent_award_times"] = (opponent_history_any as Dictionary).duplicate(true)
	var receipts_any: Variant = raw.get("redemption_receipts", {})
	if typeof(receipts_any) == TYPE_DICTIONARY:
		out["redemption_receipts"] = (receipts_any as Dictionary).duplicate(true)
	var quest_progress_any: Variant = raw.get("quest_progress", {})
	if typeof(quest_progress_any) == TYPE_DICTIONARY:
		out["quest_progress"] = (quest_progress_any as Dictionary).duplicate(true)
	var quest_claimed_any: Variant = raw.get("quest_claimed", {})
	if typeof(quest_claimed_any) == TYPE_DICTIONARY:
		out["quest_claimed"] = (quest_claimed_any as Dictionary).duplicate(true)
	var quest_bonus_any: Variant = raw.get("quest_bonus_claimed", {})
	if typeof(quest_bonus_any) == TYPE_DICTIONARY:
		out["quest_bonus_claimed"] = (quest_bonus_any as Dictionary).duplicate(true)
	var daily_progress_any: Variant = raw.get("daily_challenge_progress", {})
	if typeof(daily_progress_any) == TYPE_DICTIONARY:
		out["daily_challenge_progress"] = (daily_progress_any as Dictionary).duplicate(true)
	var daily_claimed_any: Variant = raw.get("daily_challenge_claimed", {})
	if typeof(daily_claimed_any) == TYPE_DICTIONARY:
		out["daily_challenge_claimed"] = (daily_claimed_any as Dictionary).duplicate(true)
	var weekly_progress_any: Variant = raw.get("weekly_challenge_progress", {})
	if typeof(weekly_progress_any) == TYPE_DICTIONARY:
		out["weekly_challenge_progress"] = (weekly_progress_any as Dictionary).duplicate(true)
	var weekly_claimed_any: Variant = raw.get("weekly_challenge_claimed", {})
	if typeof(weekly_claimed_any) == TYPE_DICTIONARY:
		out["weekly_challenge_claimed"] = (weekly_claimed_any as Dictionary).duplicate(true)
	var ticket_claims_any: Variant = raw.get("access_ticket_entry_claims", {})
	if typeof(ticket_claims_any) == TYPE_DICTIONARY:
		out["access_ticket_entry_claims"] = (ticket_claims_any as Dictionary).duplicate(true)
	var prize_claims_any: Variant = raw.get("exclusive_event_prize_claims", {})
	if typeof(prize_claims_any) == TYPE_DICTIONARY:
		out["exclusive_event_prize_claims"] = (prize_claims_any as Dictionary).duplicate(true)
	return out

func _apply_loaded_state(state: Dictionary) -> void:
	_save_schema_version = maxi(1, int(state.get("schema_version", SAVE_SCHEMA_VERSION)))
	_current_season_id = str(state.get("current_season_id", _config.get_season_id()))
	_battle_pass_xp = maxi(0, int(state.get("battle_pass_xp", 0)))
	_battle_pass_level = maxi(1, int(state.get("battle_pass_level", 1)))
	_nectar_fractional_milli = clampi(int(state.get("nectar_fractional_milli", 0)), 0, NECTAR_FIXED_POINT_SCALE - 1)
	_premium_owned = bool(state.get("premium_owned", false))
	_elite_owned = bool(state.get("elite_owned", false))
	var claimed_any: Variant = state.get("claimed_rewards", {})
	_claimed_rewards = (claimed_any as Dictionary).duplicate(true) if typeof(claimed_any) == TYPE_DICTIONARY else {}
	var scarcity_any: Variant = state.get("scarcity_claims_by_level", {})
	_scarcity_claims_by_level = (scarcity_any as Dictionary).duplicate(true) if typeof(scarcity_any) == TYPE_DICTIONARY else {}
	_scarcity_feature_enabled = bool(state.get("scarcity_feature_enabled", _config.get_scarcity_feature_default_enabled()))
	_season_prestige_base_slots = maxi(0, int(state.get("season_prestige_base_slots", 0)))
	var prestige_caps_any: Variant = state.get("season_prestige_caps_by_level", {})
	_season_prestige_caps_by_level = (prestige_caps_any as Dictionary).duplicate(true) if typeof(prestige_caps_any) == TYPE_DICTIONARY else {}
	_veteran_start_applied = bool(state.get("veteran_start_applied", false))
	_veteran_rewards_unlocked = bool(state.get("veteran_rewards_unlocked", true))
	_veteran_start_level = maxi(1, int(state.get("veteran_start_level", 1)))
	_veteran_unlock_level = maxi(1, int(state.get("veteran_unlock_level", _config.get_veteran_unlock_level())))
	var wallet_any: Variant = state.get("wallet", {})
	var inventory_any: Variant = state.get("inventory", {})
	_wallet = _rewards.normalize_wallet(wallet_any as Dictionary if typeof(wallet_any) == TYPE_DICTIONARY else {})
	_inventory = _rewards.normalize_inventory(inventory_any as Dictionary if typeof(inventory_any) == TYPE_DICTIONARY else {})
	var awarded_ids_any: Variant = state.get("awarded_match_ids", {})
	_awarded_match_ids = (awarded_ids_any as Dictionary).duplicate(true) if typeof(awarded_ids_any) == TYPE_DICTIONARY else {}
	var first_win_any: Variant = state.get("first_win_bonus_by_day_player", {})
	_first_win_bonus_by_day_player = (first_win_any as Dictionary).duplicate(true) if typeof(first_win_any) == TYPE_DICTIONARY else {}
	var nectar_daily_any: Variant = state.get("nectar_earned_by_day", {})
	_nectar_earned_by_day = (nectar_daily_any as Dictionary).duplicate(true) if typeof(nectar_daily_any) == TYPE_DICTIONARY else {}
	var opponent_history_any: Variant = state.get("opponent_award_times", {})
	_opponent_award_times = (opponent_history_any as Dictionary).duplicate(true) if typeof(opponent_history_any) == TYPE_DICTIONARY else {}
	_ad_free_until_unix = maxi(0, int(state.get("ad_free_until_unix", 0)))
	var receipts_any: Variant = state.get("redemption_receipts", {})
	_redemption_receipts = (receipts_any as Dictionary).duplicate(true) if typeof(receipts_any) == TYPE_DICTIONARY else {}
	var awarded_order_any: Variant = state.get("awarded_match_order", [])
	if typeof(awarded_order_any) == TYPE_ARRAY:
		_awarded_match_order.clear()
		for id_any in awarded_order_any as Array:
			var clean_id: String = str(id_any).strip_edges()
			if clean_id.is_empty():
				continue
			_awarded_match_order.append(clean_id)
	else:
		_awarded_match_order.clear()
	_quest_progress = {}
	var quest_progress_any: Variant = state.get("quest_progress", {})
	if typeof(quest_progress_any) == TYPE_DICTIONARY:
		_quest_progress = (quest_progress_any as Dictionary).duplicate(true)
	_quest_claimed = {}
	var quest_claimed_any: Variant = state.get("quest_claimed", {})
	if typeof(quest_claimed_any) == TYPE_DICTIONARY:
		_quest_claimed = (quest_claimed_any as Dictionary).duplicate(true)
	_quest_bonus_claimed = {}
	var quest_bonus_any: Variant = state.get("quest_bonus_claimed", {})
	if typeof(quest_bonus_any) == TYPE_DICTIONARY:
		_quest_bonus_claimed = (quest_bonus_any as Dictionary).duplicate(true)
	_daily_cycle_key = str(state.get("daily_cycle_key", ""))
	_daily_challenge_progress = {}
	var daily_progress_any: Variant = state.get("daily_challenge_progress", {})
	if typeof(daily_progress_any) == TYPE_DICTIONARY:
		_daily_challenge_progress = (daily_progress_any as Dictionary).duplicate(true)
	_daily_challenge_claimed = {}
	var daily_claimed_any: Variant = state.get("daily_challenge_claimed", {})
	if typeof(daily_claimed_any) == TYPE_DICTIONARY:
		_daily_challenge_claimed = (daily_claimed_any as Dictionary).duplicate(true)
	_weekly_cycle_key = str(state.get("weekly_cycle_key", ""))
	_weekly_challenge_progress = {}
	var weekly_progress_any: Variant = state.get("weekly_challenge_progress", {})
	if typeof(weekly_progress_any) == TYPE_DICTIONARY:
		_weekly_challenge_progress = (weekly_progress_any as Dictionary).duplicate(true)
	_weekly_challenge_claimed = {}
	var weekly_claimed_any: Variant = state.get("weekly_challenge_claimed", {})
	if typeof(weekly_claimed_any) == TYPE_DICTIONARY:
		_weekly_challenge_claimed = (weekly_claimed_any as Dictionary).duplicate(true)
	_weekly_completion_bonus_claimed = bool(state.get("weekly_completion_bonus_claimed", false))
	_roll_daily_weekly_cycles_if_needed()
	_ensure_daily_challenge_state_initialized()
	_ensure_weekly_challenge_state_initialized()
	var ticket_claims_any: Variant = state.get("access_ticket_entry_claims", {})
	_access_ticket_entry_claims = (ticket_claims_any as Dictionary).duplicate(true) if typeof(ticket_claims_any) == TYPE_DICTIONARY else {}
	var prize_claims_any: Variant = state.get("exclusive_event_prize_claims", {})
	_exclusive_event_prize_claims = (prize_claims_any as Dictionary).duplicate(true) if typeof(prize_claims_any) == TYPE_DICTIONARY else {}
	_prune_award_dedupe()

func _save_state() -> void:
	var payload: Dictionary = {
		"schema_version": SAVE_SCHEMA_VERSION,
		"current_season_id": _current_season_id,
		"battle_pass_xp": _battle_pass_xp,
		"battle_pass_level": _battle_pass_level,
		"nectar_fractional_milli": _nectar_fractional_milli,
		"premium_owned": _premium_owned,
		"elite_owned": _elite_owned,
		"claimed_rewards": _claimed_rewards,
		"scarcity_claims_by_level": _scarcity_claims_by_level,
		"scarcity_feature_enabled": _scarcity_feature_enabled,
		"season_prestige_base_slots": _season_prestige_base_slots,
		"season_prestige_caps_by_level": _season_prestige_caps_by_level,
		"veteran_start_applied": _veteran_start_applied,
		"veteran_rewards_unlocked": _veteran_rewards_unlocked,
		"veteran_start_level": _veteran_start_level,
		"veteran_unlock_level": _veteran_unlock_level,
		"inventory": _inventory,
		"awarded_match_ids": _awarded_match_ids,
		"awarded_match_order": _awarded_match_order,
		"first_win_bonus_by_day_player": _first_win_bonus_by_day_player,
		"nectar_earned_by_day": _nectar_earned_by_day,
		"opponent_award_times": _opponent_award_times,
		"ad_free_until_unix": _ad_free_until_unix,
		"redemption_receipts": _redemption_receipts,
		"quest_progress": _quest_progress,
		"quest_claimed": _quest_claimed,
		"quest_bonus_claimed": _quest_bonus_claimed,
		"daily_cycle_key": _daily_cycle_key,
		"daily_challenge_progress": _daily_challenge_progress,
		"daily_challenge_claimed": _daily_challenge_claimed,
		"weekly_cycle_key": _weekly_cycle_key,
		"weekly_challenge_progress": _weekly_challenge_progress,
		"weekly_challenge_claimed": _weekly_challenge_claimed,
		"weekly_completion_bonus_claimed": _weekly_completion_bonus_claimed,
		"access_ticket_entry_claims": _access_ticket_entry_claims,
		"exclusive_event_prize_claims": _exclusive_event_prize_claims
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))

func _emit_state_changed() -> void:
	_ensure_bp_level_achievements()
	var snapshot: Dictionary = get_snapshot()
	battle_pass_state_changed.emit(snapshot)
	SFLog.info("BATTLE_PASS_STATE", {
		"season_id": _current_season_id,
		"level": _battle_pass_level,
		"xp": _battle_pass_xp
	})

func _metadata_is_crucible(metadata: Dictionary) -> bool:
	return CrucibleRulesetPolicyScript.is_crucible_ruleset(str(metadata.get("ruleset", metadata.get("vs_ruleset", ""))))

func _emit_event(event_type: String, payload: Dictionary) -> void:
	var event: Dictionary = payload.duplicate(true)
	event["type"] = event_type
	if event_type == "nectar_awarded":
		event["platform_economy_event"] = _build_platform_nectar_event(event)
	battle_pass_event.emit(event)
	SFLog.info("BATTLE_PASS_EVENT", event)

func _build_platform_nectar_event(event: Dictionary) -> Dictionary:
	var metadata: Dictionary = event.get("metadata", {}) as Dictionary if typeof(event.get("metadata", {})) == TYPE_DICTIONARY else {}
	var event_id: String = str(metadata.get("event_id", "")).strip_edges()
	if event_id.is_empty():
		event_id = "%s:%s:%s" % [
			str(event.get("source", "")).strip_edges(),
			str(metadata.get("challenge_id", metadata.get("quest_id", ""))).strip_edges(),
			str(metadata.get("daily_cycle_key", metadata.get("weekly_cycle_key", ""))).strip_edges()
		]
	return PlatformEconomyEventSchemaScript.build_award_event(
		"nectar",
		"xp",
		"award",
		event_id,
		str(metadata.get("player_id", metadata.get("uid", ""))).strip_edges(),
		int(event.get("xp_awarded", 0)),
		_battle_pass_xp,
		str(event.get("source", "")),
		metadata,
		{
			"base_xp": int(event.get("base_xp", 0)),
			"xp_multiplier": float(event.get("xp_multiplier", 1.0)),
			"battle_pass_level": _battle_pass_level
		}
	)

func debug_reset_state() -> void:
	_current_season_id = _config.get_season_id()
	_battle_pass_xp = 0
	_battle_pass_level = 1
	_nectar_fractional_milli = 0
	_premium_owned = false
	_elite_owned = false
	_claimed_rewards.clear()
	_scarcity_claims_by_level.clear()
	_season_prestige_base_slots = _config.compute_projected_prestige_pool_base()
	_season_prestige_caps_by_level = _config.build_prestige_caps(_season_prestige_base_slots)
	_veteran_start_applied = false
	_veteran_rewards_unlocked = true
	_veteran_start_level = 1
	_veteran_unlock_level = _config.get_veteran_unlock_level()
	_wallet = _rewards.normalize_wallet({})
	_inventory = _rewards.normalize_inventory({})
	_awarded_match_ids.clear()
	_awarded_match_order.clear()
	_first_win_bonus_by_day_player.clear()
	_nectar_earned_by_day.clear()
	_opponent_award_times.clear()
	_ad_free_until_unix = 0
	_redemption_receipts.clear()
	_quest_progress.clear()
	_quest_claimed.clear()
	_quest_bonus_claimed.clear()
	_daily_cycle_key = _current_daily_cycle_key()
	_daily_challenge_progress.clear()
	_daily_challenge_claimed.clear()
	_weekly_cycle_key = _current_weekly_cycle_key()
	_weekly_challenge_progress.clear()
	_weekly_challenge_claimed.clear()
	_weekly_completion_bonus_claimed = false
	_access_ticket_entry_claims.clear()
	_exclusive_event_prize_claims.clear()
	_ensure_quest_state_initialized()
	_ensure_daily_challenge_state_initialized()
	_ensure_weekly_challenge_state_initialized()
	_save_state()
	_emit_state_changed()

func _apply_nectar_xp_award(source_name: String, nectar_xp: int, metadata: Dictionary, apply_entitlement_bonus: bool) -> Dictionary:
	var safe_xp: int = maxi(0, nectar_xp)
	if safe_xp <= 0:
		return {"ok": false, "reason": "xp_zero"}
	var previous_level: int = _battle_pass_level
	var multiplier: float = 1.0
	if apply_entitlement_bonus:
		multiplier = _config.get_nectar_multiplier_for_entitlements(_premium_owned, _elite_owned)
	var multiplier_milli: int = maxi(0, int(round(multiplier * float(NECTAR_FIXED_POINT_SCALE))))
	var scaled_milli: int = safe_xp * multiplier_milli + _nectar_fractional_milli
	var final_xp: int = int(scaled_milli / NECTAR_FIXED_POINT_SCALE)
	_nectar_fractional_milli = scaled_milli % NECTAR_FIXED_POINT_SCALE
	if final_xp <= 0:
		_save_state()
		return {
			"ok": true,
			"xp_awarded": 0,
			"base_xp": safe_xp,
			"xp_multiplier": multiplier,
			"nectar_fractional_milli": _nectar_fractional_milli,
			"battle_pass_level": _battle_pass_level,
			"gained_levels": 0
		}
	if apply_entitlement_bonus and absf(multiplier - 1.0) > 0.001:
		_emit_event("nectar_multiplier_applied", {
			"source": source_name,
			"base_xp": safe_xp,
			"xp_multiplier": multiplier,
			"final_xp": final_xp
		})
	_battle_pass_xp = maxi(0, _battle_pass_xp + final_xp)
	var day_key: String = _current_daily_cycle_key()
	_nectar_earned_by_day[day_key] = maxi(0, int(_nectar_earned_by_day.get(day_key, 0))) + final_xp
	_recalculate_level_from_xp()
	var gained_levels: int = maxi(0, _battle_pass_level - previous_level)
	if gained_levels > 0:
		var quest_meta: Dictionary = metadata.duplicate(true)
		quest_meta["source"] = source_name
		_apply_quest_progress("level_gain", gained_levels, quest_meta)
	_refresh_veteran_unlock_state()
	_claim_ready_quest_bonuses()
	_save_state()
	_emit_event("xp_awarded", {
		"source": source_name,
		"xp_awarded": final_xp,
		"base_xp": safe_xp,
		"xp_multiplier": multiplier,
		"previous_level": previous_level,
		"current_level": _battle_pass_level,
		"metadata": metadata
	})
	_emit_event("nectar_awarded", {
		"source": source_name,
		"xp_awarded": final_xp,
		"base_xp": safe_xp,
		"xp_multiplier": multiplier,
		"metadata": metadata
	})
	_emit_state_changed()
	return {
		"ok": true,
		"xp_awarded": final_xp,
		"base_xp": safe_xp,
		"xp_multiplier": multiplier,
		"battle_pass_level": _battle_pass_level,
		"gained_levels": gained_levels
	}

func _reserve_award_event(event_id: String) -> Dictionary:
	if not _season_is_active():
		return {"ok": false, "reason": "season_inactive"}
	var clean_event_id: String = event_id.strip_edges()
	if clean_event_id.is_empty():
		return {"ok": false, "reason": "event_id_missing"}
	if _awarded_match_ids.has(clean_event_id):
		_emit_event("nectar_duplicate_award_ignored", {"event_id": clean_event_id})
		return {"ok": false, "reason": "event_already_awarded", "event_id": clean_event_id}
	_awarded_match_ids[clean_event_id] = true
	_awarded_match_order.append(clean_event_id)
	_prune_award_dedupe()
	return {"ok": true, "event_id": clean_event_id}

func _season_is_active() -> bool:
	var now_unix: int = int(Time.get_unix_time_from_system())
	return now_unix >= _config.get_season_start_unix() and now_unix < _config.get_season_end_unix()

func _reserve_first_win_bonus(metadata: Dictionary) -> Dictionary:
	var player_id: String = str(metadata.get("player_id", metadata.get("uid", "local_player"))).strip_edges()
	if player_id.is_empty():
		player_id = "local_player"
	var day_key: String = str(metadata.get("day_key", "")).strip_edges()
	if day_key.is_empty():
		var now: Dictionary = Time.get_datetime_dict_from_system()
		day_key = "%04d-%02d-%02d" % [int(now.get("year", 1970)), int(now.get("month", 1)), int(now.get("day", 1))]
	var claim_key: String = "%s:%s" % [day_key, player_id]
	if _first_win_bonus_by_day_player.has(claim_key):
		return {"awarded": false, "player_id": player_id, "day_key": day_key, "xp": 0}
	var xp: int = _config.get_first_win_of_day_xp()
	if xp <= 0:
		return {"awarded": false, "player_id": player_id, "day_key": day_key, "xp": 0}
	_first_win_bonus_by_day_player[claim_key] = true
	return {"awarded": true, "player_id": player_id, "day_key": day_key, "xp": xp}

func _refresh_entitlements_from_profile() -> bool:
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager == null or not profile_manager.has_method("get_store_entitlements"):
		return false
	var entitlements_any: Variant = profile_manager.call("get_store_entitlements")
	if typeof(entitlements_any) != TYPE_DICTIONARY:
		return false
	var entitlements: Dictionary = entitlements_any as Dictionary
	var next_elite: bool = bool(entitlements.get("battle_pass_elite", false))
	var next_premium: bool = bool(entitlements.get("battle_pass_premium", false)) or next_elite
	var changed: bool = next_premium != _premium_owned or next_elite != _elite_owned
	_premium_owned = next_premium
	_elite_owned = next_elite
	return changed

func _canonical_honey_balance() -> int:
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager != null and profile_manager.has_method("get_honey_balance"):
		return maxi(0, int(profile_manager.call("get_honey_balance")))
	return 0

func _ensure_prestige_state_initialized() -> void:
	if _season_prestige_base_slots > 0 and not _season_prestige_caps_by_level.is_empty():
		return
	_season_prestige_base_slots = _config.compute_projected_prestige_pool_base()
	_season_prestige_caps_by_level = _config.build_prestige_caps(_season_prestige_base_slots)

func _prestige_cap_for_level(level: int) -> int:
	if not _config.is_post_100_level(level):
		return -1
	var level_key: String = str(level)
	if _season_prestige_caps_by_level.has(level_key):
		return maxi(1, int(_season_prestige_caps_by_level.get(level_key, -1)))
	if _season_prestige_base_slots <= 0:
		_ensure_prestige_state_initialized()
	if _season_prestige_caps_by_level.has(level_key):
		return maxi(1, int(_season_prestige_caps_by_level.get(level_key, -1)))
	return _config.get_scarcity_cap(level)

func _available_quest_path_count() -> int:
	return _config.get_side_quest_path_count_for_entitlements(_premium_owned, _elite_owned)

func _quest_path_index(definition: Dictionary) -> int:
	return maxi(0, int(definition.get("path_index", 0)))

func _quest_path_available(definition: Dictionary) -> bool:
	return _quest_path_index(definition) < _available_quest_path_count()

func _ensure_bp_level_achievements() -> void:
	var achievement_service: Node = get_node_or_null("/root/AchievementService")
	if achievement_service == null:
		return
	if not achievement_service.has_method("ensure_bp_level_achievements"):
		return
	achievement_service.call("ensure_bp_level_achievements", _battle_pass_level)
