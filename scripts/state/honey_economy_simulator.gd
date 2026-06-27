extends RefCounted

const CENTI_PER_HONEY: int = 100

static func default_reward_table() -> Dictionary:
	return {
		"purchase_bundle": {
			"1": 25,
			"5": 100,
			"10": 200,
			"25": 400,
			"50": 900,
			"100": 2000
		},
		"battle_pass": {
			"premium": 200,
			"elite": 400
		},
		"referral": {
			"signup": 25,
			"onboarding": 50,
			"active_7d": 100,
			"active_30d": 250,
			"active_60d": 400
		},
		"match_completion": {
			"async_free": 5,
			"async_money": 10,
			"tournament_free": 8,
			"tournament_money": 15,
			"live_free": 5,
			"live_money": 10
		},
		"objectives": {
			"daily_all": 25,
			"weekly_all": 100,
			"weekly_all_modes": 100
		},
		"engagement": {
			"daily_login": 10,
			"streak_7d": 50,
			"streak_30d": 200,
			"community_challenge": 50,
			"featured_contribution": 100
		}
	}

static func default_profiles() -> Array[Dictionary]:
	return [
		{"id": "casual", "hours_per_day": 0.35, "live_free_per_day": 1, "async_free_per_day": 0.4, "daily_objective_rate": 0.15, "weekly_objective_rate": 0.15, "login_rate": 0.70},
		{"id": "average", "hours_per_day": 0.8, "live_free_per_day": 2, "async_free_per_day": 1, "daily_objective_rate": 0.35, "weekly_objective_rate": 0.35, "login_rate": 0.85},
		{"id": "competitive", "hours_per_day": 1.6, "live_free_per_day": 4, "async_free_per_day": 2, "tournament_free_per_week": 4, "daily_objective_rate": 0.55, "weekly_objective_rate": 0.65, "all_modes_weekly_rate": 0.35, "login_rate": 0.95},
		{"id": "hardcore", "hours_per_day": 3.0, "live_free_per_day": 7, "async_free_per_day": 4, "tournament_free_per_week": 7, "daily_objective_rate": 0.80, "weekly_objective_rate": 0.85, "all_modes_weekly_rate": 0.65, "login_rate": 1.0},
		{"id": "paying", "hours_per_day": 1.4, "live_money_per_day": 1, "async_money_per_day": 1, "live_free_per_day": 2, "purchase_bundles": {"10": 1, "25": 1}, "battle_pass": "premium", "daily_objective_rate": 0.45, "weekly_objective_rate": 0.50, "login_rate": 0.90},
		{"id": "referrer", "hours_per_day": 0.9, "live_free_per_day": 2, "async_free_per_day": 1, "referrals": {"signup": 8, "onboarding": 5, "active_7d": 4, "active_30d": 2, "active_60d": 1}, "daily_objective_rate": 0.35, "weekly_objective_rate": 0.35, "login_rate": 0.90},
		{"id": "hive_leader", "hours_per_day": 1.8, "live_free_per_day": 4, "async_free_per_day": 2, "community_challenges_per_month": 2, "featured_contributions": 1, "daily_objective_rate": 0.65, "weekly_objective_rate": 0.75, "all_modes_weekly_rate": 0.50, "login_rate": 0.95},
		{"id": "abuse_farmer", "hours_per_day": 2.0, "live_free_per_day": 16, "async_free_per_day": 8, "daily_objective_rate": 0.10, "weekly_objective_rate": 0.10, "login_rate": 1.0, "farming_penalty_bps": 2500}
	]

static func simulate(days: int = 90, reward_table: Dictionary = {}, profiles: Array[Dictionary] = []) -> Dictionary:
	var table: Dictionary = default_reward_table()
	for key in reward_table.keys():
		table[key] = reward_table[key]
	var profile_rows: Array[Dictionary] = []
	var source_totals: Dictionary = {}
	var selected_profiles: Array[Dictionary] = profiles if not profiles.is_empty() else default_profiles()
	for profile in selected_profiles:
		var row: Dictionary = _simulate_profile(profile, days, table)
		profile_rows.append(row)
		source_totals[str(profile.get("id", ""))] = row.get("source_breakdown", {})
	return {
		"ok": true,
		"days": days,
		"precision": "centi_honey",
		"reward_table": table,
		"profiles": profile_rows,
		"hive_examples": _simulate_hives(profile_rows),
		"source_totals": source_totals
	}

static func _simulate_profile(profile: Dictionary, days: int, table: Dictionary) -> Dictionary:
	var total: int = 0
	var source_breakdown: Dictionary = {}
	var matches_completed: float = 0.0
	var hours: float = float(profile.get("hours_per_day", 0.0)) * float(days)
	for day in range(1, days + 1):
		var daily: Dictionary = {}
		_add_source(daily, "live_free", int(round(float(profile.get("live_free_per_day", 0.0)) * int((table.get("match_completion", {}) as Dictionary).get("live_free", 0)))))
		_add_source(daily, "live_money", int(round(float(profile.get("live_money_per_day", 0.0)) * int((table.get("match_completion", {}) as Dictionary).get("live_money", 0)))))
		_add_source(daily, "async_free", int(round(float(profile.get("async_free_per_day", 0.0)) * int((table.get("match_completion", {}) as Dictionary).get("async_free", 0)))))
		_add_source(daily, "async_money", int(round(float(profile.get("async_money_per_day", 0.0)) * int((table.get("match_completion", {}) as Dictionary).get("async_money", 0)))))
		_add_source(daily, "daily_objectives", int(round(float(profile.get("daily_objective_rate", 0.0)) * int((table.get("objectives", {}) as Dictionary).get("daily_all", 0)))))
		_add_source(daily, "daily_login", int(round(float(profile.get("login_rate", 0.0)) * int((table.get("engagement", {}) as Dictionary).get("daily_login", 0)))))
		if day % 7 == 0:
			_add_source(daily, "weekly_objectives", int(round(float(profile.get("weekly_objective_rate", 0.0)) * int((table.get("objectives", {}) as Dictionary).get("weekly_all", 0)))))
			_add_source(daily, "weekly_all_modes", int(round(float(profile.get("all_modes_weekly_rate", 0.0)) * int((table.get("objectives", {}) as Dictionary).get("weekly_all_modes", 0)))))
			_add_source(daily, "tournament_free", int(round(float(profile.get("tournament_free_per_week", 0.0)) * int((table.get("match_completion", {}) as Dictionary).get("tournament_free", 0)))))
		if day % 7 == 0:
			_add_source(daily, "streak_7d", int((table.get("engagement", {}) as Dictionary).get("streak_7d", 0)))
		if day % 30 == 0:
			_add_source(daily, "streak_30d", int((table.get("engagement", {}) as Dictionary).get("streak_30d", 0)))
			_add_source(daily, "community_challenge", int(profile.get("community_challenges_per_month", 0)) * int((table.get("engagement", {}) as Dictionary).get("community_challenge", 0)))
		matches_completed += float(profile.get("live_free_per_day", 0.0)) + float(profile.get("live_money_per_day", 0.0)) + float(profile.get("async_free_per_day", 0.0)) + float(profile.get("async_money_per_day", 0.0))
		var penalty_bps: int = int(profile.get("farming_penalty_bps", 10000))
		for source in daily.keys():
			var amount: int = int(round(float(int(daily[source])) * float(penalty_bps) / 10000.0))
			total += amount
			_add_source(source_breakdown, str(source), amount)
		if day == 1:
			total += _one_time_sources(profile, table, source_breakdown)
	var milestones: Dictionary = {}
	for target in [10, 25, 50, 100]:
		var target_centi: int = target * CENTI_PER_HONEY
		milestones[str(target)] = int(ceil(float(target_centi) / maxf(1.0, float(total) / float(maxi(1, days))))) if total > 0 else -1
	return {
		"profile_id": str(profile.get("id", "")),
		"total_honey": float(total) / float(CENTI_PER_HONEY),
		"whole_honey_visible": int(total / CENTI_PER_HONEY),
		"source_breakdown": _format_source_breakdown(source_breakdown),
		"hours_played": hours,
		"matches_completed": int(round(matches_completed)),
		"honey_per_hour": float(total) / float(CENTI_PER_HONEY) / maxf(1.0, hours),
		"time_to_honey_days": milestones
	}

static func _one_time_sources(profile: Dictionary, table: Dictionary, source_breakdown: Dictionary) -> int:
	var total: int = 0
	var purchases: Dictionary = profile.get("purchase_bundles", {}) as Dictionary
	for price in purchases.keys():
		var amount: int = int((table.get("purchase_bundle", {}) as Dictionary).get(str(price), 0)) * int(purchases[price])
		total += amount
		_add_source(source_breakdown, "purchases", amount)
	var pass_tier: String = str(profile.get("battle_pass", "")).strip_edges().to_lower()
	if not pass_tier.is_empty():
		var pass_amount: int = int((table.get("battle_pass", {}) as Dictionary).get(pass_tier, 0))
		total += pass_amount
		_add_source(source_breakdown, "battle_pass", pass_amount)
	var referrals: Dictionary = profile.get("referrals", {}) as Dictionary
	for key in referrals.keys():
		var referral_amount: int = int((table.get("referral", {}) as Dictionary).get(str(key), 0)) * int(referrals[key])
		total += referral_amount
		_add_source(source_breakdown, "referrals", referral_amount)
	var featured: int = int(profile.get("featured_contributions", 0)) * int((table.get("engagement", {}) as Dictionary).get("featured_contribution", 0))
	total += featured
	_add_source(source_breakdown, "featured_contribution", featured)
	return total

static func _simulate_hives(profile_rows: Array[Dictionary]) -> Dictionary:
	var by_id: Dictionary = {}
	for row in profile_rows:
		by_id[str(row.get("profile_id", ""))] = row
	var compositions: Dictionary = {
		"mixed": {"casual": 5, "average": 5, "competitive": 3, "hive_leader": 1},
		"high_performing": {"competitive": 8, "hardcore": 4, "hive_leader": 2},
		"paying_heavy": {"paying": 8, "average": 4, "competitive": 2},
		"free_only": {"casual": 6, "average": 6, "competitive": 2}
	}
	var out: Dictionary = {}
	for hive_id in compositions.keys():
		var total: float = 0.0
		var composition: Dictionary = compositions[hive_id] as Dictionary
		for profile_id in composition.keys():
			var row: Dictionary = by_id.get(str(profile_id), {}) as Dictionary
			total += float(row.get("total_honey", 0.0)) * int(composition[profile_id])
		out[hive_id] = {
			"total_honey_90d": total,
			"total_honey_60d_est": total * (60.0 / 90.0),
			"total_honey_30d_est": total * (30.0 / 90.0),
			"can_afford": {
				"25": total >= 25.0,
				"50": total >= 50.0,
				"100": total >= 100.0,
				"250": total >= 250.0
			}
		}
	return out

static func _add_source(target: Dictionary, source: String, amount: int) -> void:
	if amount == 0:
		return
	target[source] = int(target.get(source, 0)) + amount

static func _format_source_breakdown(source_breakdown: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in source_breakdown.keys():
		out[key] = float(int(source_breakdown[key])) / float(CENTI_PER_HONEY)
	return out
