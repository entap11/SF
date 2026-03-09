extends Node

const SFLog = preload("res://scripts/util/sf_log.gd")
const BattlePassConfigScript = preload("res://scripts/state/battle_pass_config.gd")
const BattlePassRewardsScript = preload("res://scripts/state/battle_pass_rewards.gd")

signal battle_pass_state_changed(snapshot: Dictionary)
signal battle_pass_event(event: Dictionary)

const CONFIG_PATH: String = "res://data/battle_pass/battle_pass_config.json"
const SAVE_PATH: String = "user://battle_pass_state.json"
const SAVE_SCHEMA_VERSION: int = 2
const TRACK_FREE: String = "free"
const TRACK_PREMIUM: String = "premium"
const TRACK_ELITE: String = "elite"
const REWARD_NONE: String = "none"
const MATCH_DEDUPE_MAX: int = 5000

var _config: BattlePassConfigScript = BattlePassConfigScript.new(CONFIG_PATH)
var _rewards: BattlePassRewardsScript = BattlePassRewardsScript.new()

var _save_schema_version: int = SAVE_SCHEMA_VERSION
var _current_season_id: String = ""
var _battle_pass_xp: int = 0
var _battle_pass_level: int = 1

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

var _quest_progress: Dictionary = {}
var _quest_claimed: Dictionary = {}
var _quest_bonus_claimed: Dictionary = {}
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
	_ensure_prestige_state_initialized()
	_ensure_quest_state_initialized()
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
		"season_seconds_remaining": maxi(0, _config.get_season_end_unix() - int(Time.get_unix_time_from_system())),
		"battle_pass_xp": _battle_pass_xp,
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
		"wallet": _wallet.duplicate(true),
		"inventory": _inventory.duplicate(true),
		"access_ticket_entry_claim_count": _access_ticket_entry_claims.size(),
		"exclusive_event_prize_claim_count": _exclusive_event_prize_claims.size(),
		"quests": _build_quest_rows(),
		"quest_bonuses": _build_quest_bonus_rows()
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
	var safe_xp: int = maxi(0, nectar_xp)
	if safe_xp <= 0:
		return {"ok": false, "reason": "xp_zero"}
	return _apply_nectar_xp_award(source_name, safe_xp, metadata, true)

func intent_record_async_completion(mode_id: String, map_count: int, paid_entry: bool, metadata: Dictionary = {}) -> Dictionary:
	var event_id: String = str(metadata.get("event_id", "")).strip_edges()
	if event_id.is_empty():
		return {"ok": false, "reason": "event_id_missing"}
	var safe_map_count: int = maxi(1, map_count)
	var xp_total: int = _config.get_async_completion_xp(safe_map_count, paid_entry)
	if xp_total <= 0:
		return {"ok": false, "reason": "xp_zero", "event_id": event_id}
	var reserved: Dictionary = _reserve_award_event(event_id)
	if not bool(reserved.get("ok", false)):
		return reserved
	var xp_meta: Dictionary = metadata.duplicate(true)
	xp_meta["mode_id"] = mode_id.strip_edges().to_upper()
	xp_meta["map_count"] = safe_map_count
	xp_meta["paid_entry"] = paid_entry
	xp_meta["event_id"] = event_id
	var changed: bool = _apply_quest_progress("async_match_completed", 1, xp_meta)
	if paid_entry:
		changed = _apply_quest_progress("money_async_played", 1, xp_meta) or changed
	var xp_result: Dictionary = _apply_nectar_xp_award("async_completion", xp_total, xp_meta, true)
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

func intent_record_pvp_completion(pvp_mode_id: String, paid_entry: bool, money_tier: int = 0, did_win: bool = false, metadata: Dictionary = {}) -> Dictionary:
	var event_id: String = str(metadata.get("event_id", "")).strip_edges()
	if event_id.is_empty():
		return {"ok": false, "reason": "event_id_missing"}
	var xp_total: int = _config.get_pvp_completion_xp(paid_entry, money_tier, did_win)
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
	var changed: bool = _apply_quest_progress("pvp_match_completed", 1, xp_meta)
	if paid_entry:
		changed = _apply_quest_progress("money_match_played", 1, xp_meta) or changed
	if did_win:
		changed = _apply_quest_progress("pvp_win", 1, xp_meta) or changed
	var xp_result: Dictionary = _apply_nectar_xp_award("pvp_completion", xp_total, xp_meta, true)
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

func intent_record_tournament_participation(metadata: Dictionary = {}) -> Dictionary:
	var event_id: String = str(metadata.get("event_id", "")).strip_edges()
	if event_id.is_empty():
		return {"ok": false, "reason": "event_id_missing"}
	var xp_total: int = _config.get_tournament_participation_xp()
	if xp_total <= 0:
		return {"ok": false, "reason": "xp_zero", "event_id": event_id}
	var reserved: Dictionary = _reserve_award_event(event_id)
	if not bool(reserved.get("ok", false)):
		return reserved
	var xp_meta: Dictionary = metadata.duplicate(true)
	xp_meta["event_id"] = event_id
	var changed: bool = _apply_quest_progress("tournament_played", 1, xp_meta)
	var xp_result: Dictionary = _apply_nectar_xp_award("tournament_participation", xp_total, xp_meta, true)
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
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	var grant_result: Dictionary = _rewards.grant_rewards(normalized_rewards, _wallet, _inventory, profile_manager)
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
	_quest_claimed[clean_id] = true
	var xp_reward: int = maxi(0, int(quest_def.get("xp_reward", 0)))
	if xp_reward > 0:
		intent_award_nectar_xp("quest_claim:%s" % clean_id, xp_reward, {"quest_id": clean_id})
	var reward_def_any: Variant = quest_def.get("reward", {})
	var reward_grant: Dictionary = {}
	if typeof(reward_def_any) == TYPE_DICTIONARY:
		reward_grant = _grant_reward(reward_def_any as Dictionary)
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

func intent_claim_reward(level: int, track_slot: String) -> Dictionary:
	var validation: Dictionary = _validate_claim(level, track_slot, false)
	if not bool(validation.get("ok", false)):
		return validation
	var reward_def: Dictionary = _config.get_reward_slot(level, track_slot)
	var grant_result: Dictionary = _grant_reward(reward_def)
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
		_quest_bonus_claimed[bonus_id] = true
		var xp_reward: int = maxi(0, int(bonus_def.get("xp_reward", 0)))
		if xp_reward > 0:
			intent_award_nectar_xp("quest_bonus:%s" % bonus_id, xp_reward, {"bonus_id": bonus_id})
		var reward_any: Variant = bonus_def.get("reward", {})
		if typeof(reward_any) == TYPE_DICTIONARY:
			_grant_reward(reward_any as Dictionary)
		_emit_event("quest_bonus_claimed", {"bonus_id": bonus_id})

func _grant_reward(reward_def: Dictionary) -> Dictionary:
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
	_quest_progress.clear()
	_quest_claimed.clear()
	_quest_bonus_claimed.clear()
	_ensure_quest_state_initialized()
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
		"quest_progress": {},
		"quest_claimed": {},
		"quest_bonus_claimed": {},
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
	var quest_progress_any: Variant = raw.get("quest_progress", {})
	if typeof(quest_progress_any) == TYPE_DICTIONARY:
		out["quest_progress"] = (quest_progress_any as Dictionary).duplicate(true)
	var quest_claimed_any: Variant = raw.get("quest_claimed", {})
	if typeof(quest_claimed_any) == TYPE_DICTIONARY:
		out["quest_claimed"] = (quest_claimed_any as Dictionary).duplicate(true)
	var quest_bonus_any: Variant = raw.get("quest_bonus_claimed", {})
	if typeof(quest_bonus_any) == TYPE_DICTIONARY:
		out["quest_bonus_claimed"] = (quest_bonus_any as Dictionary).duplicate(true)
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
		"wallet": _wallet,
		"inventory": _inventory,
		"awarded_match_ids": _awarded_match_ids,
		"awarded_match_order": _awarded_match_order,
		"quest_progress": _quest_progress,
		"quest_claimed": _quest_claimed,
		"quest_bonus_claimed": _quest_bonus_claimed,
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

func _emit_event(event_type: String, payload: Dictionary) -> void:
	var event: Dictionary = payload.duplicate(true)
	event["type"] = event_type
	battle_pass_event.emit(event)
	SFLog.info("BATTLE_PASS_EVENT", event)

func debug_reset_state() -> void:
	_current_season_id = _config.get_season_id()
	_battle_pass_xp = 0
	_battle_pass_level = 1
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
	_quest_progress.clear()
	_quest_claimed.clear()
	_quest_bonus_claimed.clear()
	_access_ticket_entry_claims.clear()
	_exclusive_event_prize_claims.clear()
	_ensure_quest_state_initialized()
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
	var final_xp: int = maxi(1, int(round(float(safe_xp) * multiplier)))
	_battle_pass_xp = maxi(0, _battle_pass_xp + final_xp)
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
	var clean_event_id: String = event_id.strip_edges()
	if clean_event_id.is_empty():
		return {"ok": false, "reason": "event_id_missing"}
	if _awarded_match_ids.has(clean_event_id):
		return {"ok": false, "reason": "event_already_awarded", "event_id": clean_event_id}
	_awarded_match_ids[clean_event_id] = true
	_awarded_match_order.append(clean_event_id)
	_prune_award_dedupe()
	return {"ok": true, "event_id": clean_event_id}

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
