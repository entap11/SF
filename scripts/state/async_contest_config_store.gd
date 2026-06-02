class_name AsyncContestConfigStore
extends RefCounted

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_REGISTRY := preload("res://scripts/maps/map_registry.gd")
const MAP_MODE_RULES := preload("res://scripts/maps/map_mode_rules.gd")
const MatchSetupRandomizer := preload("res://scripts/state/match_setup_randomizer.gd")

const SAVE_PATH_DEFAULT: String = "user://async_contest_dash_config_v1.json"
const SCHEMA_V1: String = "swarmfront.async_contest_dash.v1"
const SCOPE_DAILY: String = "DAILY"
const SCOPE_WEEKLY: String = "WEEKLY"
const SCOPE_MONTHLY: String = "MONTHLY"
const SCOPE_SEASONAL: String = "SEASONAL"
const SCOPES: Array[String] = [SCOPE_DAILY, SCOPE_WEEKLY, SCOPE_MONTHLY, SCOPE_SEASONAL]
const ACTIVE_SCOPES: Array[String] = [SCOPE_WEEKLY, SCOPE_MONTHLY, SCOPE_SEASONAL]
const MAP_COUNTS: Array[int] = [3, 5]
const PRIZE_TYPES: Array[String] = ["Honey", "Money", "Skin", "Buffs", "Bundle"]
const BOT_STYLES: Array[String] = ["balancer", "turtle", "raider", "greedy", "swarm_lord"]
const BOT_TIERS: Array[String] = ["easy", "medium", "hard"]
const DEFAULT_MODE_ID: String = "STAGE_RACE"

var _loaded: bool = false
var _root: Dictionary = {}
var _available_maps_cache: Array[Dictionary] = []
var save_path: String = SAVE_PATH_DEFAULT

func load_config() -> Dictionary:
	_ensure_loaded()
	return _root.duplicate(true)

func save_config(config: Dictionary) -> bool:
	_root = _normalize_root(config)
	_loaded = true
	return _save()

func config_for(scope: String, map_count: int) -> Dictionary:
	_ensure_loaded()
	var clean_scope: String = normalize_scope(scope)
	var clean_count: int = normalize_map_count(map_count)
	var configs: Dictionary = _root.get("configs", {}) as Dictionary
	var scope_configs: Dictionary = configs.get(clean_scope, {}) as Dictionary
	var key: String = str(clean_count)
	if not scope_configs.has(key):
		return _default_config(clean_scope, clean_count)
	return _normalize_config(clean_scope, clean_count, scope_configs.get(key, {}) as Dictionary)

func update_config(scope: String, map_count: int, values: Dictionary) -> Dictionary:
	_ensure_loaded()
	var clean_scope: String = normalize_scope(scope)
	var clean_count: int = normalize_map_count(map_count)
	if clean_scope == SCOPE_DAILY:
		return config_for(clean_scope, clean_count)
	var configs: Dictionary = _root.get("configs", {}) as Dictionary
	var scope_configs: Dictionary = configs.get(clean_scope, {}) as Dictionary
	var normalized: Dictionary = _normalize_config(clean_scope, clean_count, values)
	scope_configs[str(clean_count)] = normalized
	configs[clean_scope] = scope_configs
	_root["configs"] = configs
	_root["updated_unix"] = int(Time.get_unix_time_from_system())
	_save()
	return normalized.duplicate(true)

func available_async_maps() -> Array[Dictionary]:
	if not _available_maps_cache.is_empty():
		return _available_maps_cache.duplicate(true)
	var out: Array[Dictionary] = []
	for path_any in MAP_LOADER.list_maps():
		var path: String = str(path_any).strip_edges()
		if path.is_empty():
			continue
		var map_id: String = MAP_REGISTRY.map_id_from_path(path)
		if _looks_like_3p_map(path, map_id):
			continue
		var loaded: Dictionary = MAP_LOADER.load_map(path)
		if not bool(loaded.get("ok", false)):
			continue
		var data: Dictionary = loaded.get("data", {}) as Dictionary
		if _map_has_3p_bucket(data):
			continue
		var summary: Dictionary = MAP_MODE_RULES.map_supports_game_mode(data, DEFAULT_MODE_ID)
		if not bool(summary.get("ok", false)):
			continue
		out.append({
			"path": path,
			"map_id": map_id,
			"title": MAP_REGISTRY.public_map_display_name_for_id(map_id),
			"sort_key": MAP_REGISTRY.public_map_sort_key_for_id(map_id)
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("sort_key", "")) < str(b.get("sort_key", ""))
	)
	_available_maps_cache = out.duplicate(true)
	return out

func launch_options(scope: String, map_count: int) -> Dictionary:
	var clean_scope: String = normalize_scope(scope)
	if clean_scope == SCOPE_DAILY:
		return {}
	var clean_count: int = normalize_map_count(map_count)
	var config: Dictionary = config_for(clean_scope, clean_count)
	var paths: Array[String] = _valid_config_map_paths(config, clean_count)
	var out: Dictionary = {
		"vs_cpu_style": str(config.get("bot_style", "balancer")).strip_edges().to_lower(),
		"vs_cpu_tier": str(config.get("bot_tier", "medium")).strip_edges().to_lower(),
		"async_contest_scope": clean_scope,
		"async_prize_type": str(config.get("prize_type", "Honey")),
		"async_prize_amount": str(config.get("amount", "")),
		"async_contest_dash_config": config.duplicate(true)
	}
	if paths.size() >= clean_count:
		out["stage_map_paths"] = paths
		var ids := PackedStringArray()
		for path in paths:
			ids.append(MAP_REGISTRY.map_id_from_path(path))
		out["map_ids"] = ids
	var randomizer_payload: Dictionary = randomizer_payload_for_config(clean_scope, clean_count, config)
	if not randomizer_payload.is_empty():
		out[MatchSetupRandomizer.CONTEXT_KEY] = randomizer_payload
	return out

func randomizer_payload_for_config(scope: String, map_count: int, config: Dictionary) -> Dictionary:
	var pct: int = clampi(int(config.get("randomizer_pct", 0)), 0, 100)
	if pct <= 0:
		return {}
	var seed: int = _positive_seed(int(config.get("randomizer_seed", 0)))
	if seed <= 0:
		seed = _stable_positive_hash("%s|%d|randomizer" % [normalize_scope(scope), normalize_map_count(map_count)])
	var category_chance: float = float(pct) / 100.0
	var rng := RandomNumberGenerator.new()
	rng.seed = _positive_seed(seed + (normalize_map_count(map_count) * 1009) + normalize_scope(scope).hash())
	var categories: Dictionary = {}
	for category in MatchSetupRandomizer.CATEGORY_ORDER:
		if rng.randf() <= category_chance:
			categories[category] = _random_power_value(rng)
	var hit: bool = not categories.is_empty()
	var payload: Dictionary = {
		"version": 1,
		"hit": hit,
		"seed": seed,
		"chance": 1.0,
		"category_chance": category_chance,
		"categories": categories
	}
	if not hit:
		return payload
	if categories.has(MatchSetupRandomizer.CATEGORY_STRUCTURE_POWER):
		payload["structures"] = {
			"kind": "mixed",
			"slot_policy": "all_slots"
		}
	payload["description"] = MatchSetupRandomizer.description(payload)
	return payload

static func normalize_scope(scope: String) -> String:
	var clean: String = scope.strip_edges().to_upper()
	if clean == "YEARLY" or clean == "SEASON":
		return SCOPE_SEASONAL
	if SCOPES.has(clean):
		return clean
	return SCOPE_WEEKLY

static func normalize_map_count(map_count: int) -> int:
	return 5 if map_count >= 5 else 3

func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_root = _default_root()
	if not FileAccess.file_exists(_resolved_save_path()):
		return
	var file: FileAccess = FileAccess.open(_resolved_save_path(), FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_root = _normalize_root(parsed as Dictionary)

func _default_root() -> Dictionary:
	var configs: Dictionary = {}
	for scope in ACTIVE_SCOPES:
		var scope_configs: Dictionary = {}
		for map_count in MAP_COUNTS:
			scope_configs[str(map_count)] = _default_config(scope, map_count)
		configs[scope] = scope_configs
	return {
		"_schema": SCHEMA_V1,
		"updated_unix": int(Time.get_unix_time_from_system()),
		"configs": configs
	}

func _normalize_root(raw: Dictionary) -> Dictionary:
	var out: Dictionary = _default_root()
	var configs_any: Variant = raw.get("configs", {})
	if typeof(configs_any) != TYPE_DICTIONARY:
		return out
	var raw_configs: Dictionary = configs_any as Dictionary
	var out_configs: Dictionary = out.get("configs", {}) as Dictionary
	for scope_any in raw_configs.keys():
		var scope: String = normalize_scope(str(scope_any))
		if scope == SCOPE_DAILY:
			continue
		var raw_scope_any: Variant = raw_configs.get(scope_any)
		if typeof(raw_scope_any) != TYPE_DICTIONARY:
			continue
		var raw_scope: Dictionary = raw_scope_any as Dictionary
		var scope_configs: Dictionary = out_configs.get(scope, {}) as Dictionary
		for count_any in raw_scope.keys():
			var count: int = normalize_map_count(int(str(count_any)))
			var value_any: Variant = raw_scope.get(count_any)
			if typeof(value_any) == TYPE_DICTIONARY:
				scope_configs[str(count)] = _normalize_config(scope, count, value_any as Dictionary)
		out_configs[scope] = scope_configs
	out["configs"] = out_configs
	out["updated_unix"] = maxi(0, int(raw.get("updated_unix", out.get("updated_unix", 0))))
	return out

func _default_config(scope: String, map_count: int) -> Dictionary:
	var clean_scope: String = normalize_scope(scope)
	var clean_count: int = normalize_map_count(map_count)
	var maps: Array[Dictionary] = available_async_maps()
	var paths: Array[String] = []
	if not maps.is_empty():
		for i in range(clean_count):
			var entry: Dictionary = maps[i % maps.size()]
			paths.append(str(entry.get("path", "")))
	return {
		"scope": clean_scope,
		"map_count": clean_count,
		"map_paths": paths,
		"bot_style": "balancer",
		"bot_tier": "medium",
		"prize_type": "Honey",
		"amount": "",
		"randomizer_pct": 0,
		"randomizer_seed": _stable_positive_hash("%s|%d|async-contest" % [clean_scope, clean_count])
	}

func _normalize_config(scope: String, map_count: int, raw: Dictionary) -> Dictionary:
	var base: Dictionary = _default_config(scope, map_count)
	var paths: Array[String] = []
	var raw_paths_any: Variant = raw.get("map_paths", raw.get("stage_map_paths", base.get("map_paths", [])))
	if typeof(raw_paths_any) == TYPE_ARRAY:
		for path_any in raw_paths_any as Array:
			var path: String = str(path_any).strip_edges()
			if not path.is_empty():
				paths.append(path)
	while paths.size() < int(base.get("map_count", 3)) and not (base.get("map_paths", []) as Array).is_empty():
		paths.append(str((base.get("map_paths", []) as Array)[paths.size() % (base.get("map_paths", []) as Array).size()]))
	base["map_paths"] = paths
	var style: String = str(raw.get("bot_style", base.get("bot_style", "balancer"))).strip_edges().to_lower()
	base["bot_style"] = style if BOT_STYLES.has(style) else "balancer"
	var tier: String = str(raw.get("bot_tier", base.get("bot_tier", "medium"))).strip_edges().to_lower()
	base["bot_tier"] = tier if BOT_TIERS.has(tier) else "medium"
	var prize: String = str(raw.get("prize_type", base.get("prize_type", "Honey"))).strip_edges()
	base["prize_type"] = prize if PRIZE_TYPES.has(prize) else "Honey"
	base["amount"] = str(raw.get("amount", base.get("amount", ""))).strip_edges()
	base["randomizer_pct"] = clampi(int(raw.get("randomizer_pct", base.get("randomizer_pct", 0))), 0, 100)
	base["randomizer_seed"] = _positive_seed(int(raw.get("randomizer_seed", base.get("randomizer_seed", 1))))
	return base

func _valid_config_map_paths(config: Dictionary, map_count: int) -> Array[String]:
	var allowed: Dictionary = {}
	for entry in available_async_maps():
		allowed[str(entry.get("path", ""))] = true
	var out: Array[String] = []
	var paths_any: Variant = config.get("map_paths", [])
	if typeof(paths_any) == TYPE_ARRAY:
		for path_any in paths_any as Array:
			var path: String = str(path_any).strip_edges()
			if path.is_empty() or not bool(allowed.get(path, false)):
				continue
			out.append(path)
			if out.size() >= map_count:
				return out
	return out

func _random_power_value(rng: RandomNumberGenerator) -> int:
	return MatchSetupRandomizer.POWER_VALUES[rng.randi_range(0, MatchSetupRandomizer.POWER_VALUES.size() - 1)]

func _looks_like_3p_map(path: String, map_id: String) -> bool:
	var token: String = ("%s|%s" % [path, map_id]).to_lower()
	return token.contains("__3p") or token.contains("/3p") or token.ends_with("_3p") or token.contains("3p.")

func _map_has_3p_bucket(map_data: Dictionary) -> bool:
	var buckets_v: Variant = map_data.get("player_buckets", [])
	if typeof(buckets_v) == TYPE_ARRAY:
		for bucket_any in buckets_v as Array:
			var bucket: String = str(bucket_any).strip_edges().to_upper().replace("-", "_")
			if bucket == "3P" or bucket == "3P_FFA":
				return true
	var mode: String = str(map_data.get("mode", "")).strip_edges().to_upper().replace("-", "_")
	return mode == "3P" or mode == "3P_FFA"

func _positive_seed(value: int) -> int:
	var out: int = abs(value)
	return maxi(1, out)

func _stable_positive_hash(text: String) -> int:
	var h: int = 17
	for i in range(text.length()):
		h = int((h * 31 + text.unicode_at(i)) % 2147483647)
	return maxi(1, h)

func _save() -> bool:
	var file: FileAccess = FileAccess.open(_resolved_save_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_root, "\t"))
	return true

func _resolved_save_path() -> String:
	var clean: String = save_path.strip_edges()
	return clean if not clean.is_empty() else SAVE_PATH_DEFAULT
