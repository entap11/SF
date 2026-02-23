class_name BattlePassConfig
extends RefCounted

const DEFAULT_CONFIG_PATH: String = "res://data/battle_pass/battle_pass_config.json"
const SCHEMA_VERSION_CURRENT: int = 1

const TRACK_FREE: String = "free"
const TRACK_PREMIUM: String = "premium"
const TRACK_ELITE: String = "elite"

const REWARD_NONE: String = "none"
const REWARD_HONEY: String = "honey"
const REWARD_BUFF: String = "buff"
const REWARD_COSMETIC: String = "cosmetic"
const REWARD_ACCESS_TICKET: String = "access_ticket"

const POST_100_PREMIUM_MAX_LEVEL: int = 110
const POST_100_ELITE_MAX_LEVEL: int = 120

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
	return int(_config.get("total_levels", 100))

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
	return bool(_config.get("scarcity_feature_default_enabled", false))

func is_post_100_level(level: int) -> bool:
	return level > 100

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
	return 100

func get_xp_award(source_name: String) -> int:
	var xp_awards_any: Variant = _config.get("xp_awards", {})
	if typeof(xp_awards_any) != TYPE_DICTIONARY:
		return 0
	var xp_awards: Dictionary = xp_awards_any as Dictionary
	var key: String = source_name.strip_edges().to_lower()
	return maxi(0, int(xp_awards.get(key, 0)))

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

func _build_default_config() -> Dictionary:
	var now_unix: int = int(Time.get_unix_time_from_system())
	var season_start_unix: int = now_unix
	var season_end_unix: int = season_start_unix + (60 * 60 * 24 * 90)
	var levels: Array = []
	var scarcity_base: int = 500
	var scarcity_decay: float = 0.90
	for level in range(1, POST_100_ELITE_MAX_LEVEL + 1):
		var level_def: Dictionary = _build_default_level(level, scarcity_base, scarcity_decay)
		levels.append(level_def)
	var config: Dictionary = {
		"schema_version": SCHEMA_VERSION_CURRENT,
		"season_id": "tf_beta_s1",
		"start_time_unix": season_start_unix,
		"end_time_unix": season_end_unix,
		"total_levels": POST_100_ELITE_MAX_LEVEL,
		"scarcity_feature_default_enabled": false,
		"cadence_rules": {
			"digit_1": REWARD_HONEY,
			"digit_7": REWARD_BUFF,
			"digit_0": REWARD_ACCESS_TICKET
		},
		"levels": levels,
		"veteran_start": {
			"claim_unlock_level": 10,
			"opt_out_allowed": true,
			"grants": {
				"member_this_season": 120,
				"member_last_season": 110,
				"played_every_mode_last_season": 130,
				"money_async_last_season": 90,
				"money_vs_last_season": 110
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
			"match_completion": 24,
			"win_bonus": 8,
			"money_match_bonus": 16,
			"capture_tower": 3
		},
		"quests": [
			{"id": "weekly_gain_5_levels", "event_key": "level_gain", "target": 5, "xp_reward": 120, "reward": {"reward_type": REWARD_NONE}},
			{"id": "weekly_win_3_async_tournaments", "event_key": "async_tournament_win", "target": 3, "xp_reward": 140, "reward": {"reward_type": REWARD_NONE}},
			{"id": "weekly_play_1_money_match", "event_key": "money_match_played", "target": 1, "xp_reward": 90, "reward": {"reward_type": REWARD_NONE}},
			{"id": "weekly_capture_15_towers", "event_key": "capture_tower", "target": 15, "xp_reward": 110, "reward": {"reward_type": REWARD_NONE}}
		],
		"quest_bonuses": [
			{
				"id": "weekly_combo_bonus",
				"required_quests": ["weekly_gain_5_levels", "weekly_play_1_money_match", "weekly_capture_15_towers"],
				"reward": {"reward_type": REWARD_COSMETIC, "cosmetic_id": "bp_weekly_combo_badge", "quantity": 1},
				"xp_reward": 80
			}
		]
	}
	return config

func _build_default_level(level: int, scarcity_base: int, scarcity_decay: float) -> Dictionary:
	var xp_required: int = 100
	var tracks: Dictionary = {
		TRACK_FREE: _build_default_track_reward(level, TRACK_FREE),
		TRACK_PREMIUM: _build_default_track_reward(level, TRACK_PREMIUM),
		TRACK_ELITE: _build_default_track_reward(level, TRACK_ELITE)
	}
	var scarcity_cap: int = -1
	if level > 100:
		var post_offset: int = level - 101
		scarcity_cap = maxi(1, int(round(float(scarcity_base) * pow(scarcity_decay, float(post_offset)))))
		if level > POST_100_PREMIUM_MAX_LEVEL:
			tracks[TRACK_PREMIUM] = {"reward_type": REWARD_NONE}
		tracks[TRACK_FREE] = {"reward_type": REWARD_NONE}
	var level_def: Dictionary = {
		"level": level,
		"xp_required": xp_required,
		"tracks": tracks,
		"scarcity_cap": scarcity_cap
	}
	return level_def

func _build_default_track_reward(level: int, track_slot: String) -> Dictionary:
	var digit: int = level % 10
	var reward: Dictionary = {"reward_type": REWARD_COSMETIC, "cosmetic_id": "bp_cosmetic_l%03d_%s" % [level, track_slot], "quantity": 1}
	if digit == 1:
		var honey_amount: int = 30
		if track_slot == TRACK_PREMIUM:
			honey_amount = 45
		elif track_slot == TRACK_ELITE:
			honey_amount = 60
		reward = {"reward_type": REWARD_HONEY, "quantity": honey_amount}
	elif digit == 7:
		var buff_id: String = "buff_swarm_speed_classic"
		if track_slot == TRACK_PREMIUM:
			buff_id = "buff_hive_faster_production_classic"
		elif track_slot == TRACK_ELITE:
			buff_id = "buff_tower_fire_rate_classic"
		reward = {"reward_type": REWARD_BUFF, "buff_id": buff_id, "quantity": 1}
	elif digit == 0:
		if level > 100 and track_slot == TRACK_FREE:
			reward = {"reward_type": REWARD_NONE}
		else:
			var ticket_qty: int = 1
			if track_slot == TRACK_ELITE:
				ticket_qty = 2
			reward = {"reward_type": REWARD_ACCESS_TICKET, "quantity": ticket_qty}
	else:
		if track_slot == TRACK_FREE and digit % 2 == 0:
			reward = {"reward_type": REWARD_HONEY, "quantity": 20}
	return reward
