class_name RankDecaySystem
extends RefCounted

const RankConfigScript = preload("res://scripts/state/rank_config.gd")

const DAY_SECONDS: int = 86400

var _config: RankConfigScript = null

func configure(config: RankConfigScript) -> void:
	_config = config

func apply_decay(player_record: Dictionary, now_unix: int) -> Dictionary:
	if _config == null:
		return {"applied": false, "days": 0, "wax_before": 0.0, "wax_after": 0.0}
	if now_unix <= 0:
		return {"applied": false, "days": 0, "wax_before": 0.0, "wax_after": 0.0}
	var last_active_unix: int = int(player_record.get("last_active_unix", now_unix))
	if last_active_unix <= 0:
		last_active_unix = now_unix
		player_record["last_active_unix"] = now_unix
	var day_now: int = int(floor(float(now_unix) / float(DAY_SECONDS)))
	var last_active_day: int = int(floor(float(last_active_unix) / float(DAY_SECONDS)))
	var grace_end_day: int = last_active_day + maxi(0, _config.inactivity_grace_days)
	if day_now <= grace_end_day:
		return {
			"applied": false,
			"days": 0,
			"wax_before": float(player_record.get("wax_score", 0.0)),
			"wax_after": float(player_record.get("wax_score", 0.0))
		}
	var last_decay_day: int = int(player_record.get("last_decay_day", -1))
	var start_day: int = maxi(grace_end_day + 1, last_decay_day + 1)
	if start_day > day_now:
		return {
			"applied": false,
			"days": 0,
			"wax_before": float(player_record.get("wax_score", 0.0)),
			"wax_after": float(player_record.get("wax_score", 0.0))
		}
	var decay_days: int = day_now - start_day + 1
	var wax_before: float = maxf(0.0, float(player_record.get("wax_score", 0.0)))
	var retention: float = pow(maxf(0.0, 1.0 - _config.daily_decay_rate), float(decay_days))
	var wax_after: float = maxf(_config.wax_floor, wax_before * retention)
	player_record["wax_score"] = wax_after
	player_record["last_decay_day"] = day_now
	return {
		"applied": true,
		"days": decay_days,
		"wax_before": wax_before,
		"wax_after": wax_after
	}
