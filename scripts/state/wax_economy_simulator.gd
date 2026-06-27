extends RefCounted

const WaxRewardPolicy = preload("res://scripts/state/wax_reward_policy.gd")

static func simulate(days: int = 90) -> Dictionary:
	var safe_days: int = maxi(1, days)
	var profiles: Array[Dictionary] = []
	for profile in _profile_inputs():
		profiles.append(_simulate_profile(profile, safe_days))
	var farmer: Dictionary = _find_profile(profiles, "abuse_farmer")
	var competitive: Dictionary = _find_profile(profiles, "competitive")
	var average: Dictionary = _find_profile(profiles, "average")
	var recommendations: Array[String] = []
	if float(farmer.get("wax_per_hour", 0.0)) >= float(average.get("wax_per_hour", 0.0)):
		recommendations.append("Tighten repeated-opponent and minimum-quality gates; farmer profile is too efficient.")
	if float(competitive.get("total_wax", 0.0)) > 400.0:
		recommendations.append("Competitive 90-day Wax is high; review live/tournament multipliers before launch.")
	if recommendations.is_empty():
		recommendations.append("First-pass Wax rates keep farming below normal competitive play.")
	return {
		"ok": true,
		"days": safe_days,
		"profiles": profiles,
		"farmer_beats_average": float(farmer.get("wax_per_hour", 0.0)) >= float(average.get("wax_per_hour", 0.0)),
		"recommendations": recommendations
	}

static func _profile_inputs() -> Array[Dictionary]:
	return [
		{"profile_id": "casual", "hours_per_week": 3.0, "live_per_week": 4, "win_rate": 0.45, "async_per_week": 2, "tournaments_per_month": 0, "rating": 1000.0},
		{"profile_id": "average", "hours_per_week": 7.0, "live_per_week": 12, "win_rate": 0.50, "async_per_week": 5, "tournaments_per_month": 1, "rating": 1100.0},
		{"profile_id": "competitive", "hours_per_week": 14.0, "live_per_week": 28, "win_rate": 0.58, "async_per_week": 8, "tournaments_per_month": 2, "rating": 1350.0},
		{"profile_id": "hardcore", "hours_per_week": 28.0, "live_per_week": 60, "win_rate": 0.55, "async_per_week": 20, "tournaments_per_month": 3, "rating": 1500.0},
		{"profile_id": "paying_competitor", "hours_per_week": 10.0, "live_per_week": 18, "win_rate": 0.54, "async_per_week": 8, "tournaments_per_month": 2, "rating": 1250.0},
		{"profile_id": "async_specialist", "hours_per_week": 9.0, "live_per_week": 4, "win_rate": 0.50, "async_per_week": 18, "tournaments_per_month": 1, "rating": 1125.0},
		{"profile_id": "hive_champion", "hours_per_week": 12.0, "live_per_week": 14, "win_rate": 0.56, "async_per_week": 8, "tournaments_per_month": 3, "hive_weekly_wins_per_month": 1, "rating": 1300.0},
		{"profile_id": "abuse_farmer", "hours_per_week": 12.0, "live_per_week": 80, "win_rate": 0.90, "async_per_week": 0, "tournaments_per_month": 0, "rating": 900.0, "repeated_opponent_count": 4, "minimum_quality_met": false}
	]

static func _simulate_profile(profile: Dictionary, days: int) -> Dictionary:
	var weeks: float = float(days) / 7.0
	var months: float = float(days) / 30.0
	var total_wax: float = 0.0
	var matches: int = 0
	var breakdown: Dictionary = {"live": 0.0, "async": 0.0, "tournament": 0.0, "hive": 0.0}
	var live_matches: int = int(round(float(profile.get("live_per_week", 0)) * weeks))
	var wins: int = int(round(float(live_matches) * float(profile.get("win_rate", 0.5))))
	var losses: int = maxi(0, live_matches - wins)
	for i in range(wins):
		var award: Dictionary = WaxRewardPolicy.evaluate_match(_match_payload(profile, true, i))
		breakdown["live"] = float(breakdown.get("live", 0.0)) + float(award.get("final_wax_delta", 0))
	for i in range(losses):
		var loss_payload: Dictionary = _match_payload(profile, false, i)
		if i % 5 == 0:
			loss_payload["close_loss_margin_ratio"] = 0.05
		var loss: Dictionary = WaxRewardPolicy.evaluate_match(loss_payload)
		breakdown["live"] = float(breakdown.get("live", 0.0)) + float(loss.get("final_wax_delta", 0))
	matches += live_matches
	var async_events: int = int(round(float(profile.get("async_per_week", 0)) * weeks))
	for i in range(async_events):
		var placement: int = 1 + (i % 6)
		var async_result: Dictionary = WaxRewardPolicy.evaluate_match({
			"mode_name": "ASYNC",
			"placement_based": true,
			"placement": placement,
			"field_size": 12,
			"did_win": placement == 1
		})
		breakdown["async"] = float(breakdown.get("async", 0.0)) + float(async_result.get("final_wax_delta", 0))
	matches += async_events
	var tournaments: int = int(round(float(profile.get("tournaments_per_month", 0)) * months))
	for i in range(tournaments):
		var placement_t: int = 1 + (i % 8)
		var tournament: Dictionary = WaxRewardPolicy.evaluate_match({
			"mode_name": "TOURNAMENT",
			"contest_scope": "WEEKLY",
			"placement": placement_t,
			"field_size": 64,
			"did_win": placement_t == 1
		})
		breakdown["tournament"] = float(breakdown.get("tournament", 0.0)) + float(tournament.get("final_wax_delta", 0))
	var hive_wins: int = int(round(float(profile.get("hive_weekly_wins_per_month", 0)) * months))
	breakdown["hive"] = float(hive_wins * 25)
	total_wax = float(breakdown.get("live", 0.0)) + float(breakdown.get("async", 0.0)) + float(breakdown.get("tournament", 0.0)) + float(breakdown.get("hive", 0.0))
	var hours: float = float(profile.get("hours_per_week", 0.0)) * weeks
	return {
		"profile_id": str(profile.get("profile_id", "")),
		"total_wax": total_wax,
		"hours_played": hours,
		"matches_completed": matches,
		"wax_per_hour": total_wax / maxf(1.0, hours),
		"source_breakdown": breakdown
	}

static func _match_payload(profile: Dictionary, did_win: bool, index: int) -> Dictionary:
	var player_rating: float = float(profile.get("rating", 1000.0))
	var opponent_rating: float = player_rating + (125.0 if index % 3 == 0 else 0.0)
	return {
		"mode_name": "1V1",
		"did_win": did_win,
		"player_rating": player_rating,
		"opponent_rating": opponent_rating,
		"duration_sec": 240,
		"repeated_opponent_count": int(profile.get("repeated_opponent_count", 0)),
		"minimum_quality_met": bool(profile.get("minimum_quality_met", true))
	}

static func _find_profile(profiles: Array[Dictionary], profile_id: String) -> Dictionary:
	for profile in profiles:
		if str(profile.get("profile_id", "")) == profile_id:
			return profile
	return {}
