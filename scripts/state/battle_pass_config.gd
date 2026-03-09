class_name BattlePassConfig
extends RefCounted

const DEFAULT_CONFIG_PATH: String = "res://data/battle_pass/battle_pass_config.json"
const SCHEMA_VERSION_CURRENT: int = 2

const TRACK_FREE: String = "free"
const TRACK_PREMIUM: String = "premium"
const TRACK_ELITE: String = "elite"

const REWARD_NONE: String = "none"
const REWARD_HONEY: String = "honey"
const REWARD_BUFF: String = "buff"
const REWARD_COSMETIC: String = "cosmetic"
const REWARD_ACCESS_TICKET: String = "access_ticket"
const REWARD_ANALYTICS_CREDIT: String = "analytics_credit"
const REWARD_BUNDLE_TOKEN: String = "bundle_token"
const REWARD_AD_FREE_DAYS: String = "ad_free_days"

const BASE_VISIBLE_MAX_LEVEL: int = 100
const POST_100_PREMIUM_MAX_LEVEL: int = 110
const POST_100_ELITE_MAX_LEVEL: int = 120
const PRESTIGE_START_LEVEL: int = BASE_VISIBLE_MAX_LEVEL + 1

var _config: Dictionary = {}
var _levels_by_number: Dictionary = {}
var _quests_by_id: Dictionary = {}

func _init(config_path: String = DEFAULT_CONFIG_PATH) -> void:
	load_from_path(config_path)

func load_from_path(config_path: String = DEFAULT_CONFIG_PATH) -> void:
	var loaded: Dictionary = _load_json_config(config_path)
	if loaded.is_empty():
		loaded = _build_default_config()
	_config = _normalize_config(loaded)
	_reindex_levels()
	_reindex_quests()

func get_schema_version() -> int:
	return int(_config.get("schema_version", SCHEMA_VERSION_CURRENT))

func get_season_id() -> String:
	return str(_config.get("season_id", "tf_s0"))

func get_season_start_unix() -> int:
	return int(_config.get("start_time_unix", 0))

func get_season_end_unix() -> int:
	return int(_config.get("end_time_unix", 0))

func get_total_levels() -> int:
	return int(_config.get("total_levels", POST_100_ELITE_MAX_LEVEL))

func get_level(level: int) -> Dictionary:
	var level_key: String = str(level)
	if _levels_by_number.has(level_key):
		return (_levels_by_number.get(level_key, {}) as Dictionary).duplicate(true)
	return {}

func get_levels() -> Array:
	var levels_any: Variant = _config.get("levels", [])
	if typeof(levels_any) != TYPE_ARRAY:
		return []
	return (levels_any as Array).duplicate(true)

func get_reward_slot(level: int, track_slot: String) -> Dictionary:
	var level_def: Dictionary = get_level(level)
	if level_def.is_empty():
		return {}
	var tracks_any: Variant = level_def.get("tracks", {})
	if typeof(tracks_any) != TYPE_DICTIONARY:
		return {}
	var tracks: Dictionary = tracks_any as Dictionary
	if not tracks.has(track_slot):
		return {}
	var reward_any: Variant = tracks.get(track_slot, {})
	if typeof(reward_any) != TYPE_DICTIONARY:
		return {}
	return (reward_any as Dictionary).duplicate(true)

func get_level_xp_required(level: int) -> int:
	var level_def: Dictionary = get_level(level)
	if level_def.is_empty():
		return 100
	return maxi(1, int(level_def.get("xp_required", 100)))

func get_xp_required_to_reach_level(target_level: int) -> int:
	var max_level: int = get_total_levels()
	var clamped_target: int = clampi(target_level, 1, max_level)
	var total: int = 0
	var cursor: int = 1
	while cursor < clamped_target:
		total += get_level_xp_required(cursor)
		cursor += 1
	return total

func level_for_xp(total_xp: int) -> int:
	var xp_left: int = maxi(0, total_xp)
	var level: int = 1
	var max_level: int = get_total_levels()
	while level < max_level:
		var req: int = get_level_xp_required(level)
		if xp_left < req:
			break
		xp_left -= req
		level += 1
	return level

func get_veteran_unlock_level() -> int:
	var veteran_any: Variant = _config.get("veteran_start", {})
	if typeof(veteran_any) != TYPE_DICTIONARY:
		return 10
	var veteran: Dictionary = veteran_any as Dictionary
	return clampi(int(veteran.get("claim_unlock_level", 10)), 1, get_total_levels())

func compute_veteran_start_grant(flags: Dictionary) -> int:
	var veteran_any: Variant = _config.get("veteran_start", {})
	if typeof(veteran_any) != TYPE_DICTIONARY:
		return 0
	var veteran: Dictionary = veteran_any as Dictionary
	var grants_any: Variant = veteran.get("grants", {})
	if typeof(grants_any) != TYPE_DICTIONARY:
		return 0
	var grants: Dictionary = grants_any as Dictionary
	var total: int = 0
	for key_any in grants.keys():
		var key: String = str(key_any)
		if not bool(flags.get(key, false)):
			continue
		total += maxi(0, int(grants.get(key, 0)))
	return total

func get_scarcity_feature_default_enabled() -> bool:
	return bool(_config.get("scarcity_feature_default_enabled", true))

func is_post_100_level(level: int) -> bool:
	return level > BASE_VISIBLE_MAX_LEVEL

func get_scarcity_cap(level: int) -> int:
	var level_def: Dictionary = get_level(level)
	if level_def.is_empty():
		return -1
	return int(level_def.get("scarcity_cap", -1))

func get_visible_cap_for_entitlements(premium_owned: bool, elite_owned: bool) -> int:
	if elite_owned:
		return POST_100_ELITE_MAX_LEVEL
	if premium_owned:
		return POST_100_PREMIUM_MAX_LEVEL
	return BASE_VISIBLE_MAX_LEVEL

func get_nectar_multiplier_for_entitlements(premium_owned: bool, elite_owned: bool) -> float:
	var progression: Dictionary = _progression_settings()
	var ent_any: Variant = progression.get("entitlement_multipliers", {})
	if typeof(ent_any) != TYPE_DICTIONARY:
		return 1.0
	var ent: Dictionary = ent_any as Dictionary
	if elite_owned:
		return maxf(1.0, float(ent.get(TRACK_ELITE, 1.30)))
	if premium_owned:
		return maxf(1.0, float(ent.get(TRACK_PREMIUM, 1.20)))
	return maxf(1.0, float(ent.get(TRACK_FREE, 1.0)))

func get_side_quest_path_count_for_entitlements(premium_owned: bool, elite_owned: bool) -> int:
	var progression: Dictionary = _progression_settings()
	var paths_any: Variant = progression.get("side_quest_paths", {})
	if typeof(paths_any) != TYPE_DICTIONARY:
		return 1
	var paths: Dictionary = paths_any as Dictionary
	if elite_owned:
		return maxi(1, int(paths.get(TRACK_ELITE, 3)))
	if premium_owned:
		return maxi(1, int(paths.get(TRACK_PREMIUM, 2)))
	return maxi(1, int(paths.get(TRACK_FREE, 1)))

func get_xp_award(source_name: String) -> int:
	var xp_awards_any: Variant = _config.get("xp_awards", {})
	if typeof(xp_awards_any) != TYPE_DICTIONARY:
		return 0
	var xp_awards: Dictionary = xp_awards_any as Dictionary
	var key: String = source_name.strip_edges().to_lower()
	return maxi(0, int(xp_awards.get(key, 0)))

func get_async_completion_xp(map_count: int, paid_entry: bool) -> int:
	var mode_xp: Dictionary = _mode_xp_settings()
	var async_any: Variant = mode_xp.get("async_completion", {})
	if typeof(async_any) != TYPE_DICTIONARY:
		return 0
	var async_xp: Dictionary = async_any as Dictionary
	var branch_key: String = "paid" if paid_entry else "free"
	var branch_any: Variant = async_xp.get(branch_key, {})
	if typeof(branch_any) != TYPE_DICTIONARY:
		return 0
	var branch: Dictionary = branch_any as Dictionary
	var key: String = str(maxi(1, map_count))
	if branch.has(key):
		return maxi(0, int(branch.get(key, 0)))
	return maxi(0, int(branch.get("default", 0)))

func get_pvp_completion_xp(paid_entry: bool, money_tier: int, did_win: bool) -> int:
	var mode_xp: Dictionary = _mode_xp_settings()
	var pvp_any: Variant = mode_xp.get("pvp", {})
	if typeof(pvp_any) != TYPE_DICTIONARY:
		return 0
	var pvp: Dictionary = pvp_any as Dictionary
	if not paid_entry:
		var free_any: Variant = pvp.get("free", {})
		if typeof(free_any) != TYPE_DICTIONARY:
			return 0
		var free: Dictionary = free_any as Dictionary
		var total: int = maxi(0, int(free.get("completion", 0)))
		if did_win:
			total += maxi(0, int(free.get("win_bonus", 0)))
		return total
	var money_any: Variant = pvp.get("money", {})
	if typeof(money_any) != TYPE_DICTIONARY:
		return 0
	var money: Dictionary = money_any as Dictionary
	var tier_any: Variant = money.get(str(maxi(1, money_tier)), {})
	if typeof(tier_any) != TYPE_DICTIONARY:
		return 0
	var tier: Dictionary = tier_any as Dictionary
	var xp_total: int = maxi(0, int(tier.get("completion", 0)))
	if did_win:
		xp_total += maxi(0, int(tier.get("win_bonus", 0)))
	return xp_total

func get_tournament_participation_xp() -> int:
	var tournament: Dictionary = _tournament_settings()
	return maxi(0, int(tournament.get("participation", 0)))

func get_tournament_placement_xp(placement: int) -> int:
	var tournament: Dictionary = _tournament_settings()
	var placements_any: Variant = tournament.get("placement", {})
	if typeof(placements_any) != TYPE_DICTIONARY:
		return 0
	return maxi(0, int((placements_any as Dictionary).get(str(maxi(1, placement)), 0)))

func get_contest_result_xp(scope: String, placement: int) -> int:
	var mode_xp: Dictionary = _mode_xp_settings()
	var contest_any: Variant = mode_xp.get("contest", {})
	if typeof(contest_any) != TYPE_DICTIONARY:
		return 0
	var contest: Dictionary = contest_any as Dictionary
	var clean_scope: String = scope.strip_edges().to_lower()
	var scope_any: Variant = contest.get(clean_scope, contest.get("default", {}))
	if typeof(scope_any) != TYPE_DICTIONARY:
		return 0
	return maxi(0, int((scope_any as Dictionary).get(str(maxi(1, placement)), 0)))

func get_dau_access_ticket_rate(dau: int) -> float:
	var tier: Dictionary = get_dau_tier(dau)
	return maxf(0.0, float(tier.get("access_ticket_rate", 0.0)))

func get_dau_tier(dau: int) -> Dictionary:
	var scaling_any: Variant = _config.get("dau_scaling", {})
	if typeof(scaling_any) != TYPE_DICTIONARY:
		return {}
	var scaling: Dictionary = scaling_any as Dictionary
	var tiers_any: Variant = scaling.get("tiers", [])
	if typeof(tiers_any) != TYPE_ARRAY:
		return {}
	var tiers: Array = tiers_any as Array
	var dau_value: int = maxi(0, dau)
	var best: Dictionary = {}
	for tier_any in tiers:
		if typeof(tier_any) != TYPE_DICTIONARY:
			continue
		var tier: Dictionary = tier_any as Dictionary
		var min_dau: int = maxi(0, int(tier.get("min_dau", 0)))
		if dau_value < min_dau:
			continue
		best = tier
	return best.duplicate(true)

func get_quest_definitions() -> Array:
	var quests_any: Variant = _config.get("quests", [])
	if typeof(quests_any) != TYPE_ARRAY:
		return []
	return (quests_any as Array).duplicate(true)

func get_quest_definition(quest_id: String) -> Dictionary:
	if _quests_by_id.has(quest_id):
		return (_quests_by_id.get(quest_id, {}) as Dictionary).duplicate(true)
	return {}

func get_quest_bonus_definitions() -> Array:
	var bonuses_any: Variant = _config.get("quest_bonuses", [])
	if typeof(bonuses_any) != TYPE_ARRAY:
		return []
	return (bonuses_any as Array).duplicate(true)

func get_prestige_pool_settings() -> Dictionary:
	var progression: Dictionary = _progression_settings()
	var prestige_any: Variant = progression.get("prestige_pool", {})
	if typeof(prestige_any) != TYPE_DICTIONARY:
		return {}
	return (prestige_any as Dictionary).duplicate(true)

func get_prestige_projection_details() -> Dictionary:
	var settings: Dictionary = get_prestige_pool_settings()
	if settings.is_empty():
		return {}
	var seed_base: int = maxi(1, int(settings.get("seed_base_slots", 500)))
	var previous_finishers: int = maxi(0, int(settings.get("previous_level_100_finishers", 0)))
	var previous_active: float = maxf(0.0, float(settings.get("previous_season_starting_active", 0)))
	var projected_active: float = maxf(0.0, float(settings.get("projected_season_starting_active", 0)))
	var growth_factor: float = maxf(0.1, float(settings.get("growth_multiplier_override", 1.0)))
	if previous_active > 0.0 and projected_active > 0.0:
		growth_factor = maxf(0.1, projected_active / previous_active)
	var entry_rate: float = clampf(float(settings.get("entry_rate", 0.40)), 0.01, 1.0)
	var projected_qualified: int = previous_finishers
	if previous_finishers > 0:
		projected_qualified = maxi(1, int(round(float(previous_finishers) * growth_factor)))
	var base_slots: int = compute_projected_prestige_pool_base()
	return {
		"seed_base_slots": seed_base,
		"previous_level_100_finishers": previous_finishers,
		"previous_season_starting_active": int(previous_active),
		"projected_season_starting_active": int(projected_active),
		"growth_factor": growth_factor,
		"entry_rate": entry_rate,
		"projected_level_100_finishers": projected_qualified,
		"projected_prestige_pool_base": base_slots
	}

func get_reward_summary() -> Dictionary:
	return {
		TRACK_FREE: _summarize_track_rewards(TRACK_FREE, BASE_VISIBLE_MAX_LEVEL),
		TRACK_PREMIUM: _summarize_track_rewards(TRACK_PREMIUM, POST_100_PREMIUM_MAX_LEVEL),
		TRACK_ELITE: _summarize_track_rewards(TRACK_ELITE, POST_100_ELITE_MAX_LEVEL)
	}

func get_reward_targets() -> Dictionary:
	var economy: Dictionary = _economy_targets()
	var targets_any: Variant = economy.get("reward_targets", {})
	if typeof(targets_any) != TYPE_DICTIONARY:
		return {}
	return (targets_any as Dictionary).duplicate(true)

func get_quest_reward_summary() -> Dictionary:
	var summary: Dictionary = {
		TRACK_FREE: _empty_reward_summary_bucket(),
		TRACK_PREMIUM: _empty_reward_summary_bucket(),
		TRACK_ELITE: _empty_reward_summary_bucket()
	}
	for quest_any in get_quest_definitions():
		if typeof(quest_any) != TYPE_DICTIONARY:
			continue
		var quest_def: Dictionary = quest_any as Dictionary
		_accumulate_reward_summary(summary, _track_for_path_index(int(quest_def.get("path_index", 0))), quest_def.get("reward", {}))
	for bonus_any in get_quest_bonus_definitions():
		if typeof(bonus_any) != TYPE_DICTIONARY:
			continue
		var bonus_def: Dictionary = bonus_any as Dictionary
		_accumulate_reward_summary(summary, _track_for_path_index(int(bonus_def.get("path_index", 0))), bonus_def.get("reward", {}))
	return summary.duplicate(true)

func get_progression_sink_summary() -> Dictionary:
	var economy: Dictionary = _economy_targets()
	var baseline_action_xp: int = maxi(1, int(economy.get("baseline_action_xp", 20)))
	var milestone_levels_any: Variant = economy.get("sink_milestone_levels", [10, 50, 90, 100, 110, 120])
	var levels: Array = milestone_levels_any as Array if typeof(milestone_levels_any) == TYPE_ARRAY else []
	var out: Array[Dictionary] = []
	for level_any in levels:
		var level: int = clampi(int(level_any), 1, get_total_levels())
		var total_xp: int = get_xp_required_to_reach_level(level)
		out.append({
			"level": level,
			"xp_required": total_xp,
			"baseline_action_xp": baseline_action_xp,
			"baseline_actions": int(ceil(float(total_xp) / float(baseline_action_xp)))
		})
	return {
		"baseline_action_xp": baseline_action_xp,
		"milestones": out
	}

func compute_projected_prestige_pool_base() -> int:
	var settings: Dictionary = get_prestige_pool_settings()
	if settings.is_empty():
		return 500
	var seed_base: int = maxi(1, int(settings.get("seed_base_slots", 500)))
	var previous_finishers: int = maxi(0, int(settings.get("previous_level_100_finishers", 0)))
	if previous_finishers <= 0:
		return seed_base
	var growth_factor: float = maxf(0.1, float(settings.get("growth_multiplier_override", 1.0)))
	var previous_active: float = maxf(0.0, float(settings.get("previous_season_starting_active", 0)))
	var projected_active: float = maxf(0.0, float(settings.get("projected_season_starting_active", 0)))
	if previous_active > 0.0 and projected_active > 0.0:
		growth_factor = maxf(0.1, projected_active / previous_active)
	var entry_rate: float = clampf(float(settings.get("entry_rate", 0.40)), 0.01, 1.0)
	var projected: int = int(round(float(previous_finishers) * growth_factor * entry_rate))
	var min_slots: int = maxi(1, int(settings.get("min_slots_per_level", 10)))
	return maxi(min_slots, projected)

func _economy_targets() -> Dictionary:
	var economy_any: Variant = _config.get("economy_targets", {})
	if typeof(economy_any) != TYPE_DICTIONARY:
		return {}
	return economy_any as Dictionary

func _summarize_track_rewards(track_slot: String, max_level: int) -> Dictionary:
	var summary: Dictionary = _empty_reward_summary_bucket()
	summary["levels"] = 0
	summary["empty_levels"] = 0
	for level in range(1, max_level + 1):
		var reward_def: Dictionary = get_reward_slot(level, track_slot)
		var reward_type: String = str(reward_def.get("reward_type", REWARD_NONE)).strip_edges().to_lower()
		summary["levels"] = int(summary.get("levels", 0)) + 1
		match reward_type:
			REWARD_HONEY:
				summary["honey"] = int(summary.get("honey", 0)) + maxi(0, int(reward_def.get("quantity", 0)))
			REWARD_ACCESS_TICKET:
				summary["access_tickets"] = int(summary.get("access_tickets", 0)) + maxi(0, int(reward_def.get("quantity", 0)))
			REWARD_COSMETIC:
				summary["cosmetics"] = int(summary.get("cosmetics", 0)) + 1
			_:
				summary["empty_levels"] = int(summary.get("empty_levels", 0)) + 1
	return summary

func _empty_reward_summary_bucket() -> Dictionary:
	return {
		"honey": 0,
		"access_tickets": 0,
		"cosmetics": 0
	}

func _accumulate_reward_summary(summary: Dictionary, track_slot: String, reward_def_any: Variant) -> void:
	if typeof(reward_def_any) != TYPE_DICTIONARY:
		return
	if not summary.has(track_slot):
		summary[track_slot] = _empty_reward_summary_bucket()
	var bucket: Dictionary = summary.get(track_slot, {}) as Dictionary
	var reward_def: Dictionary = reward_def_any as Dictionary
	var reward_type: String = str(reward_def.get("reward_type", REWARD_NONE)).strip_edges().to_lower()
	match reward_type:
		REWARD_HONEY:
			bucket["honey"] = int(bucket.get("honey", 0)) + maxi(0, int(reward_def.get("quantity", 0)))
		REWARD_ACCESS_TICKET:
			bucket["access_tickets"] = int(bucket.get("access_tickets", 0)) + maxi(0, int(reward_def.get("quantity", 0)))
		REWARD_COSMETIC:
			bucket["cosmetics"] = int(bucket.get("cosmetics", 0)) + 1
		_:
			pass
	summary[track_slot] = bucket

func _track_for_path_index(path_index: int) -> String:
	match path_index:
		1:
			return TRACK_PREMIUM
		2:
			return TRACK_ELITE
		_:
			return TRACK_FREE

func build_prestige_caps(base_slots: int) -> Dictionary:
	var caps: Dictionary = {}
	for level in range(BASE_VISIBLE_MAX_LEVEL + 1, POST_100_ELITE_MAX_LEVEL + 1):
		caps[str(level)] = compute_prestige_cap_for_level(level, base_slots)
	return caps

func compute_prestige_cap_for_level(level: int, base_slots: int) -> int:
	if not is_post_100_level(level):
		return -1
	var settings: Dictionary = get_prestige_pool_settings()
	var safe_base: int = maxi(1, base_slots)
	var decay: float = clampf(float(settings.get("decay", 0.90)), 0.10, 0.99)
	var min_slots: int = maxi(1, int(settings.get("min_slots_per_level", 10)))
	var post_offset: int = level - (BASE_VISIBLE_MAX_LEVEL + 1)
	return maxi(min_slots, int(round(float(safe_base) * pow(decay, float(post_offset)))))

func _load_json_config(config_path: String) -> Dictionary:
	if not FileAccess.file_exists(config_path):
		return {}
	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	var parsed_any: Variant = JSON.parse_string(text)
	if typeof(parsed_any) != TYPE_DICTIONARY:
		return {}
	return parsed_any as Dictionary

func _normalize_config(raw: Dictionary) -> Dictionary:
	var defaults: Dictionary = _build_default_config()
	return _merge_dict_recursive(defaults, raw)

func _merge_dict_recursive(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var merged: Dictionary = base.duplicate(true)
	for key_any in overlay.keys():
		var key: String = str(key_any)
		var overlay_value: Variant = overlay.get(key)
		if typeof(overlay_value) == TYPE_DICTIONARY and typeof(merged.get(key, null)) == TYPE_DICTIONARY:
			var base_value: Dictionary = merged.get(key, {}) as Dictionary
			merged[key] = _merge_dict_recursive(base_value, overlay_value as Dictionary)
			continue
		merged[key] = overlay_value
	return merged

func _reindex_levels() -> void:
	_levels_by_number.clear()
	var levels_any: Variant = _config.get("levels", [])
	if typeof(levels_any) != TYPE_ARRAY:
		return
	var levels: Array = levels_any as Array
	for level_any in levels:
		if typeof(level_any) != TYPE_DICTIONARY:
			continue
		var level_def: Dictionary = level_any as Dictionary
		var level_num: int = int(level_def.get("level", -1))
		if level_num <= 0:
			continue
		_levels_by_number[str(level_num)] = level_def.duplicate(true)

func _reindex_quests() -> void:
	_quests_by_id.clear()
	var quests_any: Variant = _config.get("quests", [])
	if typeof(quests_any) != TYPE_ARRAY:
		return
	var quests: Array = quests_any as Array
	for quest_any in quests:
		if typeof(quest_any) != TYPE_DICTIONARY:
			continue
		var quest_def: Dictionary = quest_any as Dictionary
		var quest_id: String = str(quest_def.get("id", "")).strip_edges()
		if quest_id.is_empty():
			continue
		_quests_by_id[quest_id] = quest_def.duplicate(true)

func _progression_settings() -> Dictionary:
	var progression_any: Variant = _config.get("progression", {})
	if typeof(progression_any) != TYPE_DICTIONARY:
		return {}
	return progression_any as Dictionary

func _mode_xp_settings() -> Dictionary:
	var progression: Dictionary = _progression_settings()
	var mode_any: Variant = progression.get("mode_xp", {})
	if typeof(mode_any) != TYPE_DICTIONARY:
		return {}
	return mode_any as Dictionary

func _tournament_settings() -> Dictionary:
	var mode_xp: Dictionary = _mode_xp_settings()
	var tournament_any: Variant = mode_xp.get("tournament", {})
	if typeof(tournament_any) != TYPE_DICTIONARY:
		return {}
	return tournament_any as Dictionary

func _build_default_config() -> Dictionary:
	var now_unix: int = int(Time.get_unix_time_from_system())
	var season_start_unix: int = now_unix
	var season_end_unix: int = season_start_unix + (60 * 60 * 24 * 90)
	var progression: Dictionary = {
		"xp_curve": {
			"bands": [
				{"from": 1, "to": 10, "xp_required": 50},
				{"from": 11, "to": 25, "xp_required": 65},
				{"from": 26, "to": 50, "xp_required": 80},
				{"from": 51, "to": 75, "xp_required": 100},
				{"from": 76, "to": 90, "xp_required": 125},
				{"from": 91, "to": 100, "xp_required": 220},
				{"from": 101, "to": 110, "xp_required": 250},
				{"from": 111, "to": 120, "xp_required": 275}
			]
		},
		"entitlement_multipliers": {
			TRACK_FREE: 1.0,
			TRACK_PREMIUM: 1.20,
			TRACK_ELITE: 1.30
		},
		"side_quest_paths": {
			TRACK_FREE: 1,
			TRACK_PREMIUM: 2,
			TRACK_ELITE: 3
		},
		"mode_xp": {
			"async_completion": {
				"free": {"3": 18, "5": 22, "default": 18},
				"paid": {"3": 24, "5": 30, "default": 24}
			},
			"pvp": {
				"free": {"completion": 20, "win_bonus": 4},
				"money": {
					"1": {"completion": 24, "win_bonus": 4},
					"2": {"completion": 30, "win_bonus": 5},
					"3": {"completion": 36, "win_bonus": 6}
				}
			},
			"tournament": {
				"participation": 35,
				"placement": {"1": 25, "2": 12, "3": 6}
			},
			"contest": {
				"daily": {"1": 15, "2": 8, "3": 4},
				"weekly": {"1": 30, "2": 15, "3": 8},
				"monthly": {"1": 60, "2": 30, "3": 15},
				"default": {"1": 25, "2": 12, "3": 6}
			}
		},
		"prestige_pool": {
			"seed_base_slots": 500,
			"entry_rate": 0.40,
			"decay": 0.90,
			"min_slots_per_level": 10,
			"previous_level_100_finishers": 1250,
			"previous_season_starting_active": 5000,
			"projected_season_starting_active": 5000,
			"growth_multiplier_override": 1.0
		}
	}
	var levels: Array = []
	for level in range(1, POST_100_ELITE_MAX_LEVEL + 1):
		levels.append(_build_default_level(level, progression))
	var config: Dictionary = {
		"schema_version": SCHEMA_VERSION_CURRENT,
		"season_id": "tf_beta_s1",
		"start_time_unix": season_start_unix,
		"end_time_unix": season_end_unix,
		"total_levels": POST_100_ELITE_MAX_LEVEL,
		"scarcity_feature_default_enabled": true,
		"progression": progression,
		"economy_targets": {
			"baseline_action_xp": 20,
			"sink_milestone_levels": [10, 50, 90, 100, 110, 120],
			"reward_targets": {
				TRACK_FREE: {"honey": 328, "access_tickets": 5, "cosmetics": 6},
				TRACK_PREMIUM: {"honey": 506, "access_tickets": 13, "cosmetics": 19},
				TRACK_ELITE: {"honey": 826, "access_tickets": 26, "cosmetics": 26}
			}
		},
		"levels": levels,
		"veteran_start": {
			"claim_unlock_level": 10,
			"opt_out_allowed": true,
			"grants": {
				"member_this_season": 40,
				"member_last_season": 40,
				"played_every_mode_last_season": 50,
				"money_async_last_season": 35,
				"money_vs_last_season": 35
			}
		},
		"dau_scaling": {
			"tiers": [
				{"min_dau": 0, "label": "low", "access_ticket_rate": 0.02, "weekly_ticket_cap": 2},
				{"min_dau": 5000, "label": "mid", "access_ticket_rate": 0.07, "weekly_ticket_cap": 8},
				{"min_dau": 500000, "label": "high", "access_ticket_rate": 0.20, "weekly_ticket_cap": 50}
			]
		},
		"xp_awards": {
			"capture_tower": 3
		},
		"quests": [
			{"id": "weekly_gain_5_levels", "path_index": 0, "event_key": "level_gain", "target": 5, "xp_reward": 120, "reward": {"reward_type": REWARD_NONE}},
			{"id": "weekly_play_3_pvp_matches", "path_index": 0, "event_key": "pvp_match_completed", "target": 3, "xp_reward": 90, "reward": {"reward_type": REWARD_NONE}},
			{"id": "weekly_play_1_money_match", "path_index": 0, "event_key": "money_match_played", "target": 1, "xp_reward": 90, "reward": {"reward_type": REWARD_NONE}},
			{"id": "weekly_capture_15_towers", "path_index": 0, "event_key": "capture_tower", "target": 15, "xp_reward": 110, "reward": {"reward_type": REWARD_NONE}},
			{"id": "premium_path_complete_5_async", "path_index": 1, "event_key": "async_match_completed", "target": 5, "xp_reward": 95, "reward": {"reward_type": REWARD_HONEY, "quantity": 25}},
			{"id": "premium_path_win_3_pvp", "path_index": 1, "event_key": "pvp_win", "target": 3, "xp_reward": 105, "reward": {"reward_type": REWARD_ACCESS_TICKET, "quantity": 1}},
			{"id": "elite_path_play_2_money_async", "path_index": 2, "event_key": "money_async_played", "target": 2, "xp_reward": 120, "reward": {"reward_type": REWARD_HONEY, "quantity": 40}},
			{"id": "elite_path_place_top3_contest", "path_index": 2, "event_key": "contest_top3", "target": 1, "xp_reward": 130, "reward": {"reward_type": REWARD_COSMETIC, "cosmetic_id": "bp_elite_contest_crown", "quantity": 1}}
		],
		"quest_bonuses": [
			{
				"id": "weekly_combo_bonus",
				"path_index": 0,
				"required_quests": ["weekly_gain_5_levels", "weekly_play_1_money_match", "weekly_capture_15_towers"],
				"reward": {"reward_type": REWARD_COSMETIC, "cosmetic_id": "bp_weekly_combo_badge", "quantity": 1},
				"xp_reward": 80
			},
			{
				"id": "premium_side_path_bonus",
				"path_index": 1,
				"required_quests": ["premium_path_complete_5_async", "premium_path_win_3_pvp"],
				"reward": {"reward_type": REWARD_COSMETIC, "cosmetic_id": "bp_premium_side_path_mark", "quantity": 1},
				"xp_reward": 70
			},
			{
				"id": "elite_side_path_bonus",
				"path_index": 2,
				"required_quests": ["elite_path_play_2_money_async", "elite_path_place_top3_contest"],
				"reward": {"reward_type": REWARD_ACCESS_TICKET, "quantity": 2},
				"xp_reward": 90
			}
		]
	}
	return config

func _build_default_level(level: int, progression: Dictionary) -> Dictionary:
	var xp_required: int = _xp_required_for_level(level, progression)
	var tracks: Dictionary = {
		TRACK_FREE: _build_track_reward(level, TRACK_FREE),
		TRACK_PREMIUM: _build_track_reward(level, TRACK_PREMIUM),
		TRACK_ELITE: _build_track_reward(level, TRACK_ELITE)
	}
	var scarcity_cap: int = -1
	if level > BASE_VISIBLE_MAX_LEVEL:
		var prestige_any: Variant = progression.get("prestige_pool", {})
		var prestige: Dictionary = prestige_any as Dictionary if typeof(prestige_any) == TYPE_DICTIONARY else {}
		scarcity_cap = compute_prestige_cap_for_level(level, maxi(1, int(prestige.get("seed_base_slots", 500))))
		if level > POST_100_PREMIUM_MAX_LEVEL:
			tracks[TRACK_PREMIUM] = {"reward_type": REWARD_NONE}
		tracks[TRACK_FREE] = {"reward_type": REWARD_NONE}
	return {
		"level": level,
		"xp_required": xp_required,
		"tracks": tracks,
		"scarcity_cap": scarcity_cap
	}

func _xp_required_for_level(level: int, progression: Dictionary) -> int:
	var xp_curve_any: Variant = progression.get("xp_curve", {})
	if typeof(xp_curve_any) != TYPE_DICTIONARY:
		return 100
	var xp_curve: Dictionary = xp_curve_any as Dictionary
	var bands_any: Variant = xp_curve.get("bands", [])
	if typeof(bands_any) != TYPE_ARRAY:
		return 100
	for band_any in bands_any as Array:
		if typeof(band_any) != TYPE_DICTIONARY:
			continue
		var band: Dictionary = band_any as Dictionary
		var band_from: int = maxi(1, int(band.get("from", 1)))
		var band_to: int = maxi(band_from, int(band.get("to", band_from)))
		if level < band_from or level > band_to:
			continue
		return maxi(1, int(band.get("xp_required", 100)))
	return 100

func _build_track_reward(level: int, track_slot: String) -> Dictionary:
	if level > BASE_VISIBLE_MAX_LEVEL:
		return _build_prestige_track_reward(level, track_slot)
	return _build_core_track_reward(level, track_slot)

func _build_core_track_reward(level: int, track_slot: String) -> Dictionary:
	var slot: int = ((level - 1) % 10) + 1
	var quarter: int = clampi(int((level - 1) / 25), 0, 3)
	match track_slot:
		TRACK_FREE:
			if level in [15, 35, 55, 75, 95, 100]:
				return _cosmetic_reward("bp_free_milestone_l%03d" % level)
			if level in [10, 30, 50, 70, 90]:
				return _ticket_reward(1)
			if level in [20, 40, 60, 80]:
				return _honey_reward(12 + quarter * 2)
			if slot == 1 or slot == 4 or slot == 8:
				return _honey_reward(6 + quarter * 2)
			return _none_reward()
		TRACK_PREMIUM:
			if level in [25, 50, 75, 100]:
				return _cosmetic_reward("bp_premium_headline_l%03d" % level)
			if slot == 10:
				return _ticket_reward(1)
			if slot == 8:
				return _cosmetic_reward("bp_premium_set_%02d_l%03d" % [quarter + 1, level])
			return _honey_reward(5 + quarter)
		TRACK_ELITE:
			if level in [25, 50, 75, 100]:
				return _ticket_reward(2)
			if slot == 6:
				return _ticket_reward(1)
			if slot == 3 or slot == 8:
				return _cosmetic_reward("bp_elite_set_%02d_l%03d" % [quarter + 1, level])
			return _honey_reward(7 + quarter * 2)
	return _none_reward()

func _build_prestige_track_reward(level: int, track_slot: String) -> Dictionary:
	var slot: int = ((level - PRESTIGE_START_LEVEL) % 10) + 1
	match track_slot:
		TRACK_FREE:
			return _none_reward()
		TRACK_PREMIUM:
			if level > POST_100_PREMIUM_MAX_LEVEL:
				return _none_reward()
			if slot % 2 == 1:
				return _cosmetic_reward("bp_premium_prestige_l%03d" % level)
			return _ticket_reward(1)
		TRACK_ELITE:
			if slot == 2 or slot == 6:
				return _ticket_reward(2)
			if slot == 3 or slot == 8 or slot == 10:
				return _cosmetic_reward("bp_elite_prestige_l%03d" % level)
			return _honey_reward(14 + int((level - PRESTIGE_START_LEVEL) / 5) * 2)
	return _none_reward()

func _none_reward() -> Dictionary:
	return {"reward_type": REWARD_NONE}

func _honey_reward(quantity: int) -> Dictionary:
	return {"reward_type": REWARD_HONEY, "quantity": maxi(1, quantity)}

func _ticket_reward(quantity: int) -> Dictionary:
	return {"reward_type": REWARD_ACCESS_TICKET, "quantity": maxi(1, quantity)}

func _cosmetic_reward(cosmetic_id: String) -> Dictionary:
	return {"reward_type": REWARD_COSMETIC, "cosmetic_id": cosmetic_id, "quantity": 1}
