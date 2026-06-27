extends RefCounted

const WAX_MILLIS: int = 1000
const BASIS_POINTS_DENOMINATOR: int = 10000

const MODE_GROUP_STANDARD: String = "STANDARD_COMPETITIVE"
const MODE_GROUP_PROGRESSIVE: String = "PROGRESSIVE"
const MODE_GROUP_ASYNC: String = "ASYNC"
const MODE_GROUP_TOURNAMENT: String = "TOURNAMENT"
const MODE_GROUP_INELIGIBLE: String = "INELIGIBLE"

const STRENGTH_MUCH_WEAKER: String = "much_weaker"
const STRENGTH_SLIGHTLY_WEAKER: String = "slightly_weaker"
const STRENGTH_EQUAL: String = "equal"
const STRENGTH_SLIGHTLY_STRONGER: String = "slightly_stronger"
const STRENGTH_MUCH_STRONGER: String = "much_stronger"

static func default_config() -> Dictionary:
	return {
		"config_version": 1,
		"slightly_stronger_delta": 100.0,
		"much_stronger_delta": 400.0,
		"async_multiplier_bps": 9500,
		"repeated_opponent_soft_count": 2,
		"repeated_opponent_zero_count": 3,
		"close_loss_min_score": 0.8,
		"close_loss_max_margin_ratio": 0.10,
		"minimum_match_duration_sec": 30,
		"standard_win_wax": {
			STRENGTH_MUCH_WEAKER: 1,
			STRENGTH_SLIGHTLY_WEAKER: 2,
			STRENGTH_EQUAL: 3,
			STRENGTH_SLIGHTLY_STRONGER: 4,
			STRENGTH_MUCH_STRONGER: 5
		},
		"standard_loss_wax": {
			STRENGTH_MUCH_WEAKER: -2,
			STRENGTH_SLIGHTLY_WEAKER: -1,
			STRENGTH_EQUAL: 0,
			STRENGTH_SLIGHTLY_STRONGER: 0,
			STRENGTH_MUCH_STRONGER: 0
		},
		"standard_close_loss_wax": {
			STRENGTH_SLIGHTLY_STRONGER: 1,
			STRENGTH_MUCH_STRONGER: 2
		},
		"async_placement_wax": {
			"champion": 5,
			"runner_up": 3,
			"top_25": 1,
			"middle": 0,
			"bottom_quartile": -1
		},
		"tournament_weekly_wax": {
			"champion": 25,
			"runner_up": 15,
			"top_5": 10,
			"top_10": 6,
			"top_25": 3
		},
		"tournament_monthly_wax": {
			"champion": 100,
			"runner_up": 60,
			"top_5": 40,
			"top_10": 25,
			"top_25": 10
		},
		"tournament_seasonal_wax": {
			"champion": 500,
			"runner_up": 300,
			"elite": 150,
			"top_100": 75
		}
	}

static func evaluate_match(payload: Dictionary, config: Dictionary = {}) -> Dictionary:
	var merged_config: Dictionary = default_config()
	for key in config.keys():
		merged_config[key] = config[key]
	var match_id: String = str(payload.get("match_id", "")).strip_edges()
	var player_id: String = str(payload.get("player_id", "")).strip_edges()
	var opponent_id: String = str(payload.get("opponent_id", "")).strip_edges()
	var mode_name: String = str(payload.get("mode_name", payload.get("mode", ""))).strip_edges().to_upper()
	var mode_group: String = classify_mode_group(mode_name)
	var breakdown: Dictionary = {
		"ok": true,
		"match_id": match_id,
		"player_id": player_id,
		"opponent_id": opponent_id,
		"mode_group": mode_group,
		"result": "win" if bool(payload.get("did_win", false)) else "loss",
		"opponent_strength_band": STRENGTH_EQUAL,
		"close_loss_qualified": false,
		"close_loss_score": 0.0,
		"close_loss_reason": "",
		"rating_source": str(payload.get("rating_source", "")).strip_edges(),
		"rating_confidence": float(payload.get("rating_confidence", 0.0)),
		"base_wax_delta": 0,
		"mode_multiplier": 1.0,
		"final_wax_delta": 0,
		"final_wax_delta_millis": 0,
		"validity_status": "eligible",
		"anti_harvest_reason_if_blocked": "",
		"config_version": int(merged_config.get("config_version", 1))
	}
	var blocked_reason: String = _blocked_reason(payload, mode_group)
	if not blocked_reason.is_empty():
		breakdown["ok"] = true
		breakdown["validity_status"] = "held_review" if blocked_reason == "suspicious_wax_hold" else "blocked"
		breakdown["anti_harvest_reason_if_blocked"] = blocked_reason
		return breakdown
	if mode_group == MODE_GROUP_TOURNAMENT:
		return _evaluate_tournament(payload, merged_config, breakdown)
	if mode_group == MODE_GROUP_ASYNC and bool(payload.get("placement_based", false)):
		return _evaluate_async_placement(payload, merged_config, breakdown)
	var strength_band: String = classify_opponent_strength(
		float(payload.get("player_rating", payload.get("player_wax_score", 0.0))),
		float(payload.get("opponent_rating", payload.get("opponent_wax_score", 0.0))),
		merged_config
	)
	breakdown["opponent_strength_band"] = strength_band
	var close_loss: Dictionary = _evaluate_close_loss(payload, strength_band, merged_config)
	breakdown["close_loss_qualified"] = bool(close_loss.get("qualified", false))
	breakdown["close_loss_score"] = float(close_loss.get("score", 0.0))
	breakdown["close_loss_reason"] = str(close_loss.get("reason", ""))
	var base_delta: int = _base_match_delta(strength_band, bool(payload.get("did_win", false)), bool(close_loss.get("qualified", false)), merged_config)
	breakdown["base_wax_delta"] = base_delta
	var multiplier_bps: int = int(merged_config.get("async_multiplier_bps", BASIS_POINTS_DENOMINATOR)) if mode_group == MODE_GROUP_ASYNC else BASIS_POINTS_DENOMINATOR
	var diminished: Dictionary = _apply_repeated_opponent_diminishing(base_delta, int(payload.get("repeated_opponent_count", 0)), merged_config)
	var final_delta: int = int(round(float(int(diminished.get("delta", base_delta))) * float(multiplier_bps) / float(BASIS_POINTS_DENOMINATOR)))
	breakdown["mode_multiplier"] = float(multiplier_bps) / float(BASIS_POINTS_DENOMINATOR)
	breakdown["final_wax_delta"] = final_delta
	breakdown["final_wax_delta_millis"] = final_delta * WAX_MILLIS
	if str(diminished.get("reason", "")).strip_edges() != "":
		breakdown["validity_status"] = "diminished"
		breakdown["anti_harvest_reason_if_blocked"] = str(diminished.get("reason", ""))
	return breakdown

static func classify_mode_group(mode_name: String) -> String:
	var mode: String = mode_name.strip_edges().to_upper()
	if mode in ["CRUCIBLE"]:
		return MODE_GROUP_INELIGIBLE
	if mode in ["STANDARD", "PVP", "MONEY_MATCH", "1V1", "2V2", "3P_FFA", "4P_FFA", "CTF", "HCTF", "HIDDEN_CTF"]:
		return MODE_GROUP_STANDARD
	if mode in ["PROGRESSIVE", "PROGRESSIVE_RUN"]:
		return MODE_GROUP_PROGRESSIVE
	if mode in ["ASYNC", "STAGE_RACE", "TIMED_RACE", "MISS_N_OUT", "WMS"]:
		return MODE_GROUP_ASYNC
	if mode in ["TOURNAMENT", "WEEKLY", "MONTHLY", "SEASONAL", "YEARLY"]:
		return MODE_GROUP_TOURNAMENT
	return MODE_GROUP_INELIGIBLE

static func classify_opponent_strength(player_rating: float, opponent_rating: float, config: Dictionary = {}) -> String:
	var merged_config: Dictionary = default_config()
	for key in config.keys():
		merged_config[key] = config[key]
	var delta: float = opponent_rating - player_rating
	var slight: float = maxf(1.0, float(merged_config.get("slightly_stronger_delta", 100.0)))
	var much: float = maxf(slight + 1.0, float(merged_config.get("much_stronger_delta", 400.0)))
	if delta <= -much:
		return STRENGTH_MUCH_WEAKER
	if delta <= -slight:
		return STRENGTH_SLIGHTLY_WEAKER
	if delta >= much:
		return STRENGTH_MUCH_STRONGER
	if delta >= slight:
		return STRENGTH_SLIGHTLY_STRONGER
	return STRENGTH_EQUAL

static func _blocked_reason(payload: Dictionary, mode_group: String) -> String:
	if mode_group == MODE_GROUP_INELIGIBLE:
		return "ineligible_mode"
	if bool(payload.get("vs_crucible", false)) or str(payload.get("vs_ruleset", "")).strip_edges().to_upper() == "CRUCIBLE":
		return "crucible_no_participation_wax"
	for flag in ["tutorial", "practice", "custom_match", "private_match", "afk", "immediate_surrender", "no_contest", "refunded", "desync", "invalid_result"]:
		if bool(payload.get(flag, false)):
			return flag
	if payload.has("minimum_quality_met") and not bool(payload.get("minimum_quality_met", true)):
		return "minimum_quality_not_met"
	var duration_sec: float = float(payload.get("duration_sec", float(payload.get("match_duration_ms", 0.0)) / 1000.0))
	if duration_sec > 0.0 and duration_sec < float(default_config().get("minimum_match_duration_sec", 30)):
		return "match_too_short"
	for review_flag in ["suspicious_win_trading", "same_account_cluster", "same_device_cluster", "same_ip_cluster", "account_cluster_abuse", "low_effort_farming", "win_trading_signal", "abuse_review_required"]:
		if bool(payload.get(review_flag, false)):
			return "suspicious_wax_hold"
	if str(payload.get("review_status", "")).strip_edges().to_lower() == "held":
		return "suspicious_wax_hold"
	return ""

static func _base_match_delta(strength_band: String, did_win: bool, close_loss: bool, config: Dictionary) -> int:
	if did_win:
		return int((config.get("standard_win_wax", {}) as Dictionary).get(strength_band, 0))
	if close_loss:
		return int((config.get("standard_close_loss_wax", {}) as Dictionary).get(strength_band, 0))
	return int((config.get("standard_loss_wax", {}) as Dictionary).get(strength_band, 0))

static func _evaluate_close_loss(payload: Dictionary, strength_band: String, config: Dictionary) -> Dictionary:
	if bool(payload.get("did_win", false)):
		return {"qualified": false, "score": 0.0, "reason": "win"}
	if not [STRENGTH_SLIGHTLY_STRONGER, STRENGTH_MUCH_STRONGER].has(strength_band):
		return {"qualified": false, "score": 0.0, "reason": "opponent_not_stronger"}
	var metric: Dictionary = _close_loss_metric(payload, config)
	var score: float = clampf(float(metric.get("score", 0.0)), 0.0, 1.0)
	if not bool(metric.get("has_metric", false)):
		return {"qualified": false, "score": score, "reason": "missing_close_loss_metric"}
	var min_score: float = clampf(float(config.get("close_loss_min_score", 0.8)), 0.0, 1.0)
	if score < min_score:
		return {"qualified": false, "score": score, "reason": str(metric.get("reason", "close_loss_score_too_low"))}
	return {"qualified": true, "score": score, "reason": str(metric.get("reason", "qualified"))}

static func _close_loss_metric(payload: Dictionary, config: Dictionary) -> Dictionary:
	if payload.has("close_loss_score"):
		return {"has_metric": true, "score": clampf(float(payload.get("close_loss_score", 0.0)), 0.0, 1.0), "reason": "explicit_score"}
	if payload.has("close_loss_margin_ratio"):
		return _close_loss_score_from_margin_ratio(float(payload.get("close_loss_margin_ratio", 1.0)), config, "margin_ratio")
	if payload.has("score_margin"):
		var score_total: float = maxf(1.0, absf(float(payload.get("player_score", 0.0))) + absf(float(payload.get("opponent_score", 0.0))))
		return _close_loss_score_from_margin_ratio(absf(float(payload.get("score_margin", 0.0))) / score_total, config, "score_margin")
	if payload.has("player_score") and payload.has("opponent_score"):
		var player_score: float = float(payload.get("player_score", 0.0))
		var opponent_score: float = float(payload.get("opponent_score", 0.0))
		var max_score: float = maxf(1.0, maxf(absf(player_score), absf(opponent_score)))
		return _close_loss_score_from_margin_ratio(absf(opponent_score - player_score) / max_score, config, "score_delta")
	if payload.has("time_margin_ms"):
		var elapsed_ms: float = maxf(1.0, float(payload.get("elapsed_ms", payload.get("match_duration_ms", 0.0))))
		return _close_loss_score_from_margin_ratio(absf(float(payload.get("time_margin_ms", 0.0))) / elapsed_ms, config, "time_margin")
	if payload.has("objective_progress_ratio"):
		return {"has_metric": true, "score": clampf(float(payload.get("objective_progress_ratio", 0.0)), 0.0, 1.0), "reason": "objective_progress"}
	if payload.has("survival_ratio"):
		return {"has_metric": true, "score": clampf(float(payload.get("survival_ratio", 0.0)), 0.0, 1.0), "reason": "survival_ratio"}
	return {"has_metric": false, "score": 0.0, "reason": "missing_close_loss_metric"}

static func _close_loss_score_from_margin_ratio(margin_ratio: float, config: Dictionary, reason: String) -> Dictionary:
	var max_margin: float = maxf(0.001, float(config.get("close_loss_max_margin_ratio", 0.10)))
	var safe_margin: float = clampf(absf(margin_ratio), 0.0, 1.0)
	var score: float = 0.0
	if safe_margin <= max_margin:
		score = 1.0 - (safe_margin / max_margin * 0.2)
	else:
		score = maxf(0.0, 0.8 - ((safe_margin - max_margin) / max_margin))
	return {"has_metric": true, "score": clampf(score, 0.0, 1.0), "reason": reason}

static func _apply_repeated_opponent_diminishing(delta: int, repeated_count: int, config: Dictionary) -> Dictionary:
	var zero_count: int = maxi(1, int(config.get("repeated_opponent_zero_count", 3)))
	var soft_count: int = maxi(1, int(config.get("repeated_opponent_soft_count", 2)))
	if repeated_count >= zero_count:
		return {"delta": 0, "reason": "repeated_opponent_zeroed"}
	if repeated_count >= soft_count and delta > 0:
		return {"delta": int(floor(float(delta) * 0.5)), "reason": "repeated_opponent_diminished"}
	return {"delta": delta, "reason": ""}

static func _evaluate_async_placement(payload: Dictionary, config: Dictionary, breakdown: Dictionary) -> Dictionary:
	var placement: int = maxi(1, int(payload.get("placement", 0)))
	var field_size: int = maxi(1, int(payload.get("field_size", 1)))
	var table: Dictionary = config.get("async_placement_wax", {}) as Dictionary
	var delta: int = int(table.get("middle", 0))
	if placement == 1:
		delta = int(table.get("champion", 5))
	elif placement == 2:
		delta = int(table.get("runner_up", 3))
	elif placement <= maxi(1, int(ceil(float(field_size) * 0.25))):
		delta = int(table.get("top_25", 1))
	elif placement > int(floor(float(field_size) * 0.75)):
		delta = int(table.get("bottom_quartile", -1))
	breakdown["base_wax_delta"] = delta
	breakdown["final_wax_delta"] = delta
	breakdown["final_wax_delta_millis"] = delta * WAX_MILLIS
	return breakdown

static func _evaluate_tournament(payload: Dictionary, config: Dictionary, breakdown: Dictionary) -> Dictionary:
	var scope: String = str(payload.get("contest_scope", payload.get("tournament_scope", ""))).strip_edges().to_upper()
	var placement: int = maxi(1, int(payload.get("placement", 0)))
	var field_size: int = maxi(1, int(payload.get("field_size", 1)))
	var table_key: String = "tournament_weekly_wax"
	if scope in ["MONTHLY"]:
		table_key = "tournament_monthly_wax"
	elif scope in ["SEASONAL", "YEARLY", "CHAMPIONSHIP"]:
		table_key = "tournament_seasonal_wax"
	var table: Dictionary = config.get(table_key, {}) as Dictionary
	var percentile: float = float(placement) / float(field_size)
	var delta: int = 0
	if placement == 1:
		delta = int(table.get("champion", 0))
	elif placement == 2:
		delta = int(table.get("runner_up", 0))
	elif table_key == "tournament_seasonal_wax":
		if placement <= maxi(1, int(ceil(float(field_size) * 0.01))):
			delta = int(table.get("elite", 0))
		elif placement <= 100:
			delta = int(table.get("top_100", 0))
	else:
		if percentile <= 0.05:
			delta = int(table.get("top_5", 0))
		elif percentile <= 0.10:
			delta = int(table.get("top_10", 0))
		elif percentile <= 0.25:
			delta = int(table.get("top_25", 0))
	breakdown["base_wax_delta"] = delta
	breakdown["final_wax_delta"] = delta
	breakdown["final_wax_delta_millis"] = delta * WAX_MILLIS
	return breakdown
