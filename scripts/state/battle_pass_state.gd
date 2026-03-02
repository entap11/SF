extends Node

const SFLog = preload("res://scripts/util/sf_log.gd")
const BattlePassConfigScript = preload("res://scripts/state/battle_pass_config.gd")
const BattlePassRewardsScript = preload("res://scripts/state/battle_pass_rewards.gd")

signal battle_pass_state_changed(snapshot: Dictionary)
signal battle_pass_event(event: Dictionary)

const CONFIG_PATH: String = "res://data/battle_pass/battle_pass_config.json"
const SAVE_PATH: String = "user://battle_pass_state.json"
const SAVE_SCHEMA_VERSION: int = 1
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

func _ready() -> void:
	SFLog.allow_tag("BATTLE_PASS_EVENT")
	SFLog.allow_tag("BATTLE_PASS_STATE")
	_config.load_from_path(CONFIG_PATH)
	_veteran_unlock_level = _config.get_veteran_unlock_level()
	_scarcity_feature_enabled = _config.get_scarcity_feature_default_enabled()
	_wallet = _rewards.normalize_wallet({})
	_inventory = _rewards.normalize_inventory({})
	_load_state()
	_roll_season_if_needed()
	_ensure_quest_state_initialized()
	_recalculate_level_from_xp()
	_refresh_veteran_unlock_state()
	_emit_state_changed()

func get_snapshot() -> Dictionary:
	var total_levels: int = _config.get_total_levels()
	var visible_cap: int = _config.get_visible_cap_for_entitlements(_premium_owned, _elite_owned)
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
		"premium_owned": _premium_owned,
		"elite_owned": _elite_owned,
		"veteran_start_applied": _veteran_start_applied,
		"veteran_start_level": _veteran_start_level,
		"veteran_rewards_unlocked": _veteran_rewards_unlocked,
		"veteran_unlock_level": _veteran_unlock_level,
		"veteran_lock_active": veteran_lock_active,
		"veteran_lock_notice": veteran_notice,
		"scarcity_feature_enabled": _scarcity_feature_enabled,
		"rows": _build_level_rows(visible_cap),
		"wallet": _wallet.duplicate(true),
		"inventory": _inventory.duplicate(true),
		"quests": _build_quest_rows(),
		"quest_bonuses": _build_quest_bonus_rows()
	}

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
	var previous_level: int = _battle_pass_level
	_battle_pass_xp = maxi(0, _battle_pass_xp + safe_xp)
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
		"xp_awarded": safe_xp,
		"previous_level": previous_level,
		"current_level": _battle_pass_level,
		"metadata": metadata
	})
	_emit_state_changed()
	return {
		"ok": true,
		"xp_awarded": safe_xp,
		"battle_pass_level": _battle_pass_level,
		"gained_levels": gained_levels
	}

func intent_award_match_completion(match_id: String, won: bool, is_money_match: bool, metadata: Dictionary = {}) -> Dictionary:
	var clean_match_id: String = match_id.strip_edges()
	if clean_match_id.is_empty():
		return {"ok": false, "reason": "match_id_missing"}
	if _awarded_match_ids.has(clean_match_id):
		return {"ok": false, "reason": "match_already_awarded", "match_id": clean_match_id}
	_awarded_match_ids[clean_match_id] = true
	_awarded_match_order.append(clean_match_id)
	_prune_award_dedupe()
	var xp_total: int = _config.get_xp_award("match_completion")
	if won:
		xp_total += _config.get_xp_award("win_bonus")
	if is_money_match:
		xp_total += _config.get_xp_award("money_match_bonus")
	var xp_meta: Dictionary = metadata.duplicate(true)
	xp_meta["match_id"] = clean_match_id
	xp_meta["won"] = won
	xp_meta["money_match"] = is_money_match
	var xp_result: Dictionary = intent_award_nectar_xp("match_completion", xp_total, xp_meta)
	if not bool(xp_result.get("ok", false)):
		return xp_result
	if is_money_match:
		_apply_quest_progress("money_match_played", 1, xp_meta)
	_save_state()
	_emit_state_changed()
	return {
		"ok": true,
		"match_id": clean_match_id,
		"xp_awarded": xp_total,
		"battle_pass_level": _battle_pass_level
	}

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
		var cap: int = _config.get_scarcity_cap(level)
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
		var row: Dictionary = {
			"level": level,
			"unlocked": level <= _battle_pass_level,
			"is_post_100": _config.is_post_100_level(level),
			"xp_required": _config.get_level_xp_required(level),
			"scarcity_cap": _config.get_scarcity_cap(level),
			"scarcity_remaining": _scarcity_remaining(level),
			"tracks": {
				TRACK_FREE: _build_track_state(level, TRACK_FREE),
				TRACK_PREMIUM: _build_track_state(level, TRACK_PREMIUM),
				TRACK_ELITE: _build_track_state(level, TRACK_ELITE)
			}
		}
		rows.append(row)
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
	var cap: int = _config.get_scarcity_cap(level)
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
		var quest_id: String = str(quest_def.get("id", "")).strip_edges()
		if quest_id.is_empty():
			continue
		var target: int = maxi(1, int(quest_def.get("target", 1)))
		var progress: int = maxi(0, int(_quest_progress.get(quest_id, 0)))
		rows.append({
			"id": quest_id,
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
	_emit_event("season_reset", {"season_id": _current_season_id})

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
		"quest_bonus_claimed": {}
	}
	var claimed_any: Variant = raw.get("claimed_rewards", {})
	if typeof(claimed_any) == TYPE_DICTIONARY:
		out["claimed_rewards"] = (claimed_any as Dictionary).duplicate(true)
	var scarcity_any: Variant = raw.get("scarcity_claims_by_level", {})
	if typeof(scarcity_any) == TYPE_DICTIONARY:
		out["scarcity_claims_by_level"] = (scarcity_any as Dictionary).duplicate(true)
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
		"quest_bonus_claimed": _quest_bonus_claimed
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

func _ensure_bp_level_achievements() -> void:
	var achievement_service: Node = get_node_or_null("/root/AchievementService")
	if achievement_service == null:
		return
	if not achievement_service.has_method("ensure_bp_level_achievements"):
		return
	achievement_service.call("ensure_bp_level_achievements", _battle_pass_level)
