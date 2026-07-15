class_name BuffCatalog
extends RefCounted

const BuffDefinitions := preload("res://scripts/state/buff_definitions.gd")

const BUFF_SPRITE_DIR: String = "res://assets/sprites/sf_skin_v1/buffs"
const RETIRED_STEAL_LANE_PREFIX: String = "buff_steal_lane_"

static var _loaded: bool = false
static var _by_id: Dictionary = {}
static var _by_category: Dictionary = {}
static var _by_tier: Dictionary = {}
static var _all: Array = []
static var _stacking_default: String = "replace"

static func _ensure_loaded() -> bool:
	if _loaded:
		return true
	_loaded = true
	_by_id.clear()
	_by_category.clear()
	_by_tier.clear()
	_all.clear()

	var tiers: PackedStringArray = PackedStringArray([
		BuffDefinitions.TIER_CLASSIC,
		BuffDefinitions.TIER_PREMIUM,
		BuffDefinitions.TIER_ELITE
	])
	for buff_key in BuffDefinitions.list_all_ids():
		var buff_def: Dictionary = BuffDefinitions.get_definition(buff_key)
		if buff_def.is_empty():
			continue
		for tier_name in tiers:
			var generated: Dictionary = _generated_entry(buff_def, tier_name)
			_register_entry(generated)

	var aliases: Dictionary = _alias_map()
	for alias_any in aliases.keys():
		var alias_id: String = str(alias_any)
		var target_id: String = str(aliases.get(alias_any, ""))
		if not _by_id.has(target_id):
			continue
		_by_id[alias_id] = (_by_id.get(target_id, {}) as Dictionary).duplicate(true)
		(_by_id[alias_id] as Dictionary)["id"] = alias_id
	return true

static func _generated_entry(buff_def: Dictionary, tier_name: String) -> Dictionary:
	var base_id: String = str(buff_def.get("id", "")).to_lower()
	var generated_id: String = "buff_%s_%s" % [base_id, tier_name]
	var effects_dict: Dictionary = BuffDefinitions.effect_payload_for(str(buff_def.get("id", "")))
	var effects_arr: Array = []
	for key_any in effects_dict.keys():
		effects_arr.append({"type": str(key_any), "value": effects_dict.get(key_any)})
	return {
		"id": generated_id,
		"canonical_id": str(buff_def.get("id", "")),
		"name": str(buff_def.get("display_name", generated_id)),
		"category": str(buff_def.get("category", "unknown")),
		"target_type": str(buff_def.get("target_type", BuffDefinitions.TARGET_NONE)),
		"tier": tier_name,
		"duration_sec": BuffDefinitions.duration_seconds_for(str(buff_def.get("id", "")), tier_name),
		"icon_path": icon_path_for(str(buff_def.get("id", "")), tier_name),
		"effects": effects_arr,
		"stacking": _stacking_default,
		"price_tier": 1
	}

static func icon_path_for(canonical_id: String, tier_name: String) -> String:
	var clean_id: String = canonical_id.strip_edges().to_upper()
	var tier_suffix: String = _sprite_tier_suffix(tier_name)
	var stems: PackedStringArray = _sprite_stems_for(clean_id)
	for stem in stems:
		var path: String = "%s/%s_%s.png" % [BUFF_SPRITE_DIR, stem, tier_suffix]
		if ResourceLoader.exists(path):
			return path
	var fallback: String = "%s/tower_activated.PNG" % BUFF_SPRITE_DIR
	if ResourceLoader.exists(fallback):
		return fallback
	return ""

static func _sprite_tier_suffix(tier_name: String) -> String:
	var normalized: String = BuffDefinitions.normalize_tier(tier_name)
	if normalized == BuffDefinitions.TIER_PREMIUM:
		return "prem"
	if normalized == BuffDefinitions.TIER_ELITE:
		return "elite"
	return "classic"

static func _sprite_stems_for(canonical_id: String) -> PackedStringArray:
	match canonical_id:
		BuffDefinitions.UNIT_SWARM_DAMAGE:
			return PackedStringArray(["unit_lane_swarmdamage"])
		BuffDefinitions.UNIT_HIVE_IMPACT_DAMAGE:
			return PackedStringArray(["unit_global_2xdamage", "unit_lane_2xdamage"])
		BuffDefinitions.UNIT_SPEED:
			return PackedStringArray(["unit_lane_speed", "unit_global_speed"])
		BuffDefinitions.HIVE_SINGLE_PRODUCTION_BOOST:
			return PackedStringArray(["hive_lane_production", "hive_lane_produciton"])
		BuffDefinitions.HIVE_GLOBAL_PRODUCTION_BOOST:
			return PackedStringArray(["hive_global_production"])
		BuffDefinitions.HIVE_SHIELD_SINGLE:
			return PackedStringArray(["hive_lane_hiveshield", "hive_lane_hivedefense"])
		BuffDefinitions.HIVE_SHIELD_GLOBAL:
			return PackedStringArray(["hive_global_hivedefense"])
		BuffDefinitions.HIVE_SHOCK_IMMUNITY:
			return PackedStringArray(["hive_lane_hivedefense", "hive_global_hivedefense"])
		BuffDefinitions.HIVE_GLOBAL_SHOCK_IMMUNITY:
			return PackedStringArray(["hive_global_hivedefense", "hive_lane_hivedefense"])
		BuffDefinitions.HIVE_SUPERCHARGE_QUEUE:
			return PackedStringArray(["hive_global_production", "hive_lane_production"])
		BuffDefinitions.LANE_FREEZE:
			return PackedStringArray(["tower_rangeincrease_local"])
		BuffDefinitions.LANE_TREACHEROUS:
			return PackedStringArray(["tower_doubletap"])
	return PackedStringArray()

static func _register_entry(entry: Dictionary) -> void:
	var buff_id: String = str(entry.get("id", "")).strip_edges()
	if buff_id == "":
		return
	_by_id[buff_id] = entry
	_all.append(entry)
	var category: String = str(entry.get("category", "unknown"))
	if not _by_category.has(category):
		_by_category[category] = []
	(_by_category[category] as Array).append(entry)
	var tier: String = str(entry.get("tier", "unknown"))
	if not _by_tier.has(tier):
		_by_tier[tier] = []
	(_by_tier[tier] as Array).append(entry)

static func _alias_map() -> Dictionary:
	return {
		"buff_swarm_speed_classic": "buff_unit_speed_classic",
		"buff_hive_faster_production_classic": "buff_single_production_boost_classic",
		"buff_tower_fire_rate_classic": "buff_swarm_damage_classic"
	}

static func get_buff(buff_id: String) -> Dictionary:
	if not _ensure_loaded():
		return {}
	var clean_id: String = buff_id.strip_edges()
	if clean_id == "":
		return {}
	if _by_id.has(clean_id):
		return (_by_id.get(clean_id, {}) as Dictionary).duplicate(true)
	var retired_tier: String = clean_id.to_lower().trim_prefix(RETIRED_STEAL_LANE_PREFIX)
	if clean_id.to_lower().begins_with(RETIRED_STEAL_LANE_PREFIX) and [
		BuffDefinitions.TIER_CLASSIC,
		BuffDefinitions.TIER_PREMIUM,
		BuffDefinitions.TIER_ELITE
	].has(retired_tier):
		return {
			"id": clean_id,
			"canonical_id": "STEAL_LANE",
			"name": "Steal Lane (Retired)",
			"category": BuffDefinitions.CATEGORY_LANE,
			"target_type": BuffDefinitions.TARGET_LANE,
			"tier": retired_tier,
			"retired": true,
			"selectable": false,
			"effects": []
		}
	var upper_id: String = clean_id.to_upper()
	if BuffDefinitions.has_definition(upper_id):
		var fallback_id: String = "buff_%s_%s" % [upper_id.to_lower(), BuffDefinitions.TIER_CLASSIC]
		if _by_id.has(fallback_id):
			var fallback: Dictionary = (_by_id.get(fallback_id, {}) as Dictionary).duplicate(true)
			fallback["id"] = clean_id
			return fallback
	return {}

static func is_selectable(buff_id: String) -> bool:
	var buff: Dictionary = get_buff(buff_id)
	return not buff.is_empty() and bool(buff.get("selectable", true)) and not bool(buff.get("retired", false))

static func list_all() -> Array:
	if not _ensure_loaded():
		return []
	return _all.duplicate(true)

static func list_by_category(category: String) -> Array:
	if not _ensure_loaded():
		return []
	return (_by_category.get(category, []) as Array).duplicate(true)

static func list_by_tier(tier: String) -> Array:
	if not _ensure_loaded():
		return []
	return (_by_tier.get(tier, []) as Array).duplicate(true)

static func list_categories() -> PackedStringArray:
	if not _ensure_loaded():
		return PackedStringArray()
	var out: PackedStringArray = PackedStringArray()
	for category_any in _by_category.keys():
		out.append(str(category_any))
	out.sort()
	return out

static func list_tiers() -> PackedStringArray:
	if not _ensure_loaded():
		return PackedStringArray()
	var out: PackedStringArray = PackedStringArray()
	for tier_any in _by_tier.keys():
		out.append(str(tier_any))
	out.sort()
	return out

static func stacking_default() -> String:
	_ensure_loaded()
	return _stacking_default
