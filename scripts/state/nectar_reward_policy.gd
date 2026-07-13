extends RefCounted

const MODE_GROUP_STANDARD: String = "standard_competitive"
const MODE_GROUP_PROGRESSIVE: String = "progressive"
const MODE_GROUP_ASYNC: String = "async"
const MODE_GROUP_TOURNAMENT: String = "tournament"
const MODE_GROUP_INELIGIBLE: String = "ineligible"

static func evaluate_match(payload: Dictionary, config: Dictionary = {}) -> Dictionary:
	var resolved_payload: Dictionary = payload.duplicate(true)
	var anti_harvest: Dictionary = _anti_harvest_settings(config)
	if not resolved_payload.has("minimum_duration_sec") and anti_harvest.has("minimum_duration_sec"):
		resolved_payload["minimum_duration_sec"] = float(anti_harvest.get("minimum_duration_sec", 0.0))
	var mode_id: String = str(resolved_payload.get("mode_id", resolved_payload.get("mode", ""))).strip_edges().to_upper()
	var mode_group: String = classify_mode_group(mode_id)
	var is_money_match: bool = bool(resolved_payload.get("is_money_match", resolved_payload.get("paid_entry", false)))
	var did_win: bool = bool(resolved_payload.get("did_win", resolved_payload.get("won", false)))
	var breakdown: Dictionary = {
		"ok": true,
		"match_id": str(resolved_payload.get("match_id", resolved_payload.get("event_id", ""))).strip_edges(),
		"player_id": str(resolved_payload.get("player_id", resolved_payload.get("uid", ""))).strip_edges(),
		"mode_id": mode_id,
		"mode_group": mode_group,
		"is_money_match": is_money_match,
		"pass_tier": str(resolved_payload.get("pass_tier", "classic")).strip_edges().to_lower(),
		"participation_nectar": 0,
		"win_bonus_nectar": 0,
		"first_win_bonus_nectar": 0,
		"daily_challenge_nectar": 0,
		"weekly_challenge_nectar": 0,
		"multiplier": float(resolved_payload.get("multiplier", 1.0)),
		"diminish_multiplier": 1.0,
		"diminish_reasons": [],
		"final_nectar": 0,
		"validity_status": "eligible",
		"anti_harvest_reason_if_blocked": ""
	}
	var blocked_reason: String = blocked_reason_for_payload(resolved_payload, mode_group)
	if not blocked_reason.is_empty():
		breakdown["validity_status"] = "blocked"
		breakdown["anti_harvest_reason_if_blocked"] = blocked_reason
		return breakdown
	var awards: Dictionary = _award_table_for(mode_group, is_money_match, int(resolved_payload.get("money_tier", 0)), config)
	breakdown["participation_nectar"] = maxi(0, int(awards.get("completion", 0)))
	if did_win:
		breakdown["win_bonus_nectar"] = maxi(0, int(awards.get("win_bonus", 0)))
	var base_total: int = int(breakdown.get("participation_nectar", 0)) + int(breakdown.get("win_bonus_nectar", 0))
	var diminish: Dictionary = _diminish_for_payload(resolved_payload, anti_harvest)
	var diminish_multiplier: float = clampf(float(diminish.get("multiplier", 1.0)), 0.0, 1.0)
	if diminish_multiplier < 0.999:
		breakdown["validity_status"] = "diminished"
		breakdown["diminish_multiplier"] = diminish_multiplier
		breakdown["diminish_reasons"] = diminish.get("reasons", [])
		breakdown["final_nectar"] = maxi(1, int(round(float(base_total) * diminish_multiplier))) if base_total > 0 else 0
	else:
		breakdown["final_nectar"] = base_total
	return breakdown

static func classify_mode_group(mode_id: String) -> String:
	var clean: String = mode_id.strip_edges().to_upper()
	if clean in ["CRUCIBLE"]:
		return MODE_GROUP_INELIGIBLE
	if clean in ["TUTORIAL", "PRACTICE", "CUSTOM", "PRIVATE"]:
		return MODE_GROUP_INELIGIBLE
	if clean in ["STANDARD", "PVP", "MONEY_MATCH", "1V1", "2V2", "3P_FFA", "4P_FFA", "CTF", "HCTF", "HIDDEN_CTF", "CAPTURE_FLAG", "HIDDEN_CAPTURE_FLAG"]:
		return MODE_GROUP_STANDARD
	if clean in ["PROGRESSIVE", "PROGRESSIVE_RUN"]:
		return MODE_GROUP_PROGRESSIVE
	if clean in ["ASYNC", "STAGE_RACE", "TIMED_RACE", "MISS_N_OUT", "WMS"]:
		return MODE_GROUP_ASYNC
	if clean in ["TOURNAMENT", "WEEKLY", "MONTHLY", "SEASONAL", "YEARLY"]:
		return MODE_GROUP_TOURNAMENT
	return MODE_GROUP_INELIGIBLE

static func blocked_reason_for_payload(payload: Dictionary, mode_group: String = "") -> String:
	var resolved_group: String = mode_group
	if resolved_group.is_empty():
		resolved_group = classify_mode_group(str(payload.get("mode_id", payload.get("mode", ""))))
	if resolved_group == MODE_GROUP_INELIGIBLE:
		return "ineligible_mode"
	if payload.has("season_active") and not bool(payload.get("season_active", false)):
		return "season_inactive"
	if bool(payload.get("vs_crucible", false)) or str(payload.get("ruleset", payload.get("vs_ruleset", ""))).strip_edges().to_upper() == "CRUCIBLE":
		return "crucible_no_nectar"
	for flag in ["tutorial", "practice", "custom_match", "private_match", "no_contest", "refunded", "duplicate", "immediate_surrender", "early_quit", "afk", "insufficient_input", "insufficient_participation", "desync", "invalid_result"]:
		if bool(payload.get(flag, false)):
			return flag
	if payload.has("completed") and not bool(payload.get("completed", true)):
		return "match_not_completed"
	if payload.has("minimum_quality_met") and not bool(payload.get("minimum_quality_met", true)):
		return "minimum_quality_not_met"
	var duration_sec: float = float(payload.get("duration_sec", float(payload.get("match_duration_ms", 0.0)) / 1000.0))
	var min_duration: float = float(payload.get("minimum_duration_sec", 0.0))
	if bool(payload.get("require_match_duration", false)) and duration_sec <= 0.0:
		return "match_duration_missing"
	if min_duration > 0.0 and duration_sec > 0.0 and duration_sec < min_duration:
		return "match_too_short"
	return ""

static func _award_table_for(mode_group: String, is_money_match: bool, money_tier: int, config: Dictionary) -> Dictionary:
	var mode_xp: Dictionary = config.get("mode_xp", {}) as Dictionary if typeof(config.get("mode_xp", {})) == TYPE_DICTIONARY else {}
	match mode_group:
		MODE_GROUP_STANDARD, MODE_GROUP_PROGRESSIVE:
			return _pvp_awards(mode_xp, is_money_match, money_tier)
		MODE_GROUP_ASYNC:
			return _async_awards(mode_xp, is_money_match)
		MODE_GROUP_TOURNAMENT:
			var tournament: Dictionary = mode_xp.get("tournament", {}) as Dictionary if typeof(mode_xp.get("tournament", {})) == TYPE_DICTIONARY else {}
			return {
				"completion": maxi(0, int(tournament.get("participation", 0))),
				"win_bonus": maxi(0, int(tournament.get("win_bonus", 0)))
			}
	return {}

static func _pvp_awards(mode_xp: Dictionary, is_money_match: bool, money_tier: int) -> Dictionary:
	var pvp: Dictionary = mode_xp.get("pvp", {}) as Dictionary if typeof(mode_xp.get("pvp", {})) == TYPE_DICTIONARY else {}
	if not is_money_match:
		return pvp.get("free", {}) as Dictionary if typeof(pvp.get("free", {})) == TYPE_DICTIONARY else {}
	var money: Dictionary = pvp.get("money", {}) as Dictionary if typeof(pvp.get("money", {})) == TYPE_DICTIONARY else {}
	var tier_key: String = str(maxi(1, money_tier))
	if money.has(tier_key) and typeof(money.get(tier_key)) == TYPE_DICTIONARY:
		return money.get(tier_key, {}) as Dictionary
	if money.has("default") and typeof(money.get("default")) == TYPE_DICTIONARY:
		return money.get("default", {}) as Dictionary
	return {}

static func _async_awards(mode_xp: Dictionary, is_money_match: bool) -> Dictionary:
	var async: Dictionary = mode_xp.get("async_completion", {}) as Dictionary if typeof(mode_xp.get("async_completion", {})) == TYPE_DICTIONARY else {}
	var branch_key: String = "paid" if is_money_match else "free"
	var branch: Dictionary = async.get(branch_key, {}) as Dictionary if typeof(async.get(branch_key, {})) == TYPE_DICTIONARY else {}
	var default_any: Variant = branch.get("default", {})
	if typeof(default_any) == TYPE_DICTIONARY:
		return default_any as Dictionary
	if typeof(default_any) == TYPE_INT or typeof(default_any) == TYPE_FLOAT:
		return {"completion": maxi(0, int(default_any)), "win_bonus": 0}
	for value_any in branch.values():
		if typeof(value_any) == TYPE_DICTIONARY:
			return value_any as Dictionary
		if typeof(value_any) == TYPE_INT or typeof(value_any) == TYPE_FLOAT:
			return {"completion": maxi(0, int(value_any)), "win_bonus": 0}
	return {}

static func _anti_harvest_settings(config: Dictionary) -> Dictionary:
	var anti_any: Variant = config.get("anti_harvest", {})
	if typeof(anti_any) != TYPE_DICTIONARY:
		return {}
	return anti_any as Dictionary

static func _diminish_for_payload(payload: Dictionary, anti_harvest: Dictionary) -> Dictionary:
	var multiplier: float = 1.0
	var reasons: Array[String] = []
	var soft_count: int = maxi(0, int(anti_harvest.get("repeated_opponent_soft_count", 0)))
	var repeated_count: int = maxi(0, int(payload.get("repeated_opponent_count", payload.get("same_opponent_matches_today", 0))))
	if soft_count > 0 and repeated_count > soft_count:
		var step: float = maxf(0.0, float(anti_harvest.get("repeated_opponent_step_multiplier", 0.0)))
		var min_multiplier: float = clampf(float(anti_harvest.get("repeated_opponent_min_multiplier", 1.0)), 0.0, 1.0)
		var repeated_multiplier: float = maxf(min_multiplier, 1.0 - (float(repeated_count - soft_count) * step))
		multiplier = minf(multiplier, repeated_multiplier)
		reasons.append("repeated_opponent")
	var daily_cap: int = maxi(0, int(anti_harvest.get("daily_soft_cap_xp", 0)))
	var daily_earned: int = maxi(0, int(payload.get("daily_nectar_earned", payload.get("daily_nectar_xp", 0))))
	if daily_cap > 0 and daily_earned >= daily_cap:
		var cap_multiplier: float = clampf(float(anti_harvest.get("daily_soft_cap_multiplier", 1.0)), 0.0, 1.0)
		multiplier = minf(multiplier, cap_multiplier)
		reasons.append("daily_soft_cap")
	return {"multiplier": multiplier, "reasons": reasons}
