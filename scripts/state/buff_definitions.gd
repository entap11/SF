class_name BuffDefinitions
extends RefCounted

const CATEGORY_UNIT: String = "unit"
const CATEGORY_HIVE: String = "hive"
const CATEGORY_LANE: String = "lane"

const TARGET_NONE: String = "none"
const TARGET_HIVE: String = "hive"
const TARGET_LANE: String = "lane"

const TIER_CLASSIC: String = "classic"
const TIER_PREMIUM: String = "premium"
const TIER_ELITE: String = "elite"

const BUFF_CHILL_SECONDS: float = 15.0

const DURATION_STANDARD_BY_TIER: Dictionary = {
	TIER_CLASSIC: 5.0,
	TIER_PREMIUM: 7.0,
	TIER_ELITE: 11.0
}

const DURATION_SHORT_BY_TIER: Dictionary = {
	TIER_CLASSIC: 3.0,
	TIER_PREMIUM: 5.0,
	TIER_ELITE: 7.0
}

const UNIT_SWARM_DAMAGE: String = "SWARM_DAMAGE"
const UNIT_HIVE_IMPACT_DAMAGE: String = "HIVE_IMPACT_DAMAGE"
const UNIT_SPEED: String = "UNIT_SPEED"

const HIVE_SINGLE_PRODUCTION_BOOST: String = "SINGLE_PRODUCTION_BOOST"
const HIVE_GLOBAL_PRODUCTION_BOOST: String = "GLOBAL_PRODUCTION_BOOST"
const HIVE_SHIELD_SINGLE: String = "HIVE_SHIELD_SINGLE"
const HIVE_SHIELD_GLOBAL: String = "HIVE_SHIELD_GLOBAL"
const HIVE_SHOCK_IMMUNITY: String = "SHOCK_IMMUNITY"
const HIVE_SUPERCHARGE_QUEUE: String = "SUPERCHARGE_QUEUE"

const LANE_FREEZE: String = "FREEZE_LANE"
const LANE_STEAL: String = "STEAL_LANE"
const LANE_TREACHEROUS: String = "TREACHEROUS_LANE"

const _BUFFS: Dictionary = {
	UNIT_SWARM_DAMAGE: {
		"id": UNIT_SWARM_DAMAGE,
		"display_name": "Swarm Damage",
		"category": CATEGORY_UNIT,
		"target_type": TARGET_NONE,
		"duration_profile": "standard",
		"effects": {
			"swarm_combat_damage_mult": 1.25,
			"exclude_hive_impact": true
		}
	},
	UNIT_HIVE_IMPACT_DAMAGE: {
		"id": UNIT_HIVE_IMPACT_DAMAGE,
		"display_name": "Hive Impact Damage",
		"category": CATEGORY_UNIT,
		"target_type": TARGET_NONE,
		"duration_profile": "standard",
		"effects": {
			"hive_impact_damage_mult": 2,
			"exclude_swarm_combat": true
		}
	},
	UNIT_SPEED: {
		"id": UNIT_SPEED,
		"display_name": "Unit Speed",
		"category": CATEGORY_UNIT,
		"target_type": TARGET_HIVE,
		"duration_profile": "standard",
		"effects": {
			"unit_speed_mult": 1.25,
			"spawn_hive_only": true
		}
	},
	HIVE_SINGLE_PRODUCTION_BOOST: {
		"id": HIVE_SINGLE_PRODUCTION_BOOST,
		"display_name": "Single Production Boost",
		"category": CATEGORY_HIVE,
		"target_type": TARGET_HIVE,
		"duration_profile": "standard",
		"effects": {
			"production_time_mult": 0.7,
			"scope": "single_hive"
		}
	},
	HIVE_GLOBAL_PRODUCTION_BOOST: {
		"id": HIVE_GLOBAL_PRODUCTION_BOOST,
		"display_name": "Global Production Boost",
		"category": CATEGORY_HIVE,
		"target_type": TARGET_NONE,
		"duration_profile": "short",
		"effects": {
			"production_time_mult": 0.7,
			"scope": "all_hives"
		}
	},
	HIVE_SHIELD_SINGLE: {
		"id": HIVE_SHIELD_SINGLE,
		"display_name": "Hive Shield Single",
		"category": CATEGORY_HIVE,
		"target_type": TARGET_HIVE,
		"duration_profile": "standard",
		"effects": {
			"landing_bee_damage_immune": true,
			"scope": "single_hive"
		}
	},
	HIVE_SHIELD_GLOBAL: {
		"id": HIVE_SHIELD_GLOBAL,
		"display_name": "Hive Shield Global",
		"category": CATEGORY_HIVE,
		"target_type": TARGET_NONE,
		"duration_profile": "short",
		"effects": {
			"landing_bee_damage_immune": true,
			"scope": "all_hives"
		}
	},
	HIVE_SHOCK_IMMUNITY: {
		"id": HIVE_SHOCK_IMMUNITY,
		"display_name": "Shock Immunity",
		"category": CATEGORY_HIVE,
		"target_type": TARGET_HIVE,
		"duration_profile": "standard",
		"effects": {
			"shock_immune": true
		}
	},
	HIVE_SUPERCHARGE_QUEUE: {
		"id": HIVE_SUPERCHARGE_QUEUE,
		"display_name": "Supercharge Queue",
		"category": CATEGORY_HIVE,
		"target_type": TARGET_HIVE,
		"duration_profile": "standard",
		"effects": {
			"queue_mode": true,
			"manual_release_required": true,
			"visual_indicator_required": true
		}
	},
	LANE_FREEZE: {
		"id": LANE_FREEZE,
		"display_name": "Freeze Lane",
		"category": CATEGORY_LANE,
		"target_type": TARGET_LANE,
		"duration_profile": "standard",
		"effects": {
			"freeze_enemy_advance": true,
			"enemy_still_can_fight": true
		}
	},
	LANE_STEAL: {
		"id": LANE_STEAL,
		"display_name": "Steal Lane",
		"category": CATEGORY_LANE,
		"target_type": TARGET_LANE,
		"duration_profile": "standard",
		"effects": {
			"enemy_convert_ratio": 0.5
		}
	},
	LANE_TREACHEROUS: {
		"id": LANE_TREACHEROUS,
		"display_name": "Treacherous Lane",
		"category": CATEGORY_LANE,
		"target_type": TARGET_LANE,
		"duration_profile": "standard",
		"effects": {
			"reverse_enemy_current": true,
			"reverse_enemy_new": true
		}
	}
}

static func list_all_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for buff_id_any in _BUFFS.keys():
		ids.append(str(buff_id_any))
	ids.sort()
	return ids

static func list_ids_for_category(category: String) -> PackedStringArray:
	var normalized_category: String = category.strip_edges().to_lower()
	var out: PackedStringArray = PackedStringArray()
	for buff_id in list_all_ids():
		var buff_def: Dictionary = get_definition(buff_id)
		if str(buff_def.get("category", "")).to_lower() == normalized_category:
			out.append(buff_id)
	return out

static func get_definition(buff_id: String) -> Dictionary:
	var clean_id: String = buff_id.strip_edges()
	if clean_id == "":
		return {}
	if not _BUFFS.has(clean_id):
		return {}
	return (_BUFFS.get(clean_id, {}) as Dictionary).duplicate(true)

static func has_definition(buff_id: String) -> bool:
	return not get_definition(buff_id).is_empty()

static func normalize_tier(tier: String) -> String:
	var normalized_tier: String = tier.strip_edges().to_lower()
	if normalized_tier == TIER_PREMIUM:
		return TIER_PREMIUM
	if normalized_tier == TIER_ELITE:
		return TIER_ELITE
	return TIER_CLASSIC

static func duration_seconds_for(buff_id: String, tier: String) -> float:
	var buff_def: Dictionary = get_definition(buff_id)
	if buff_def.is_empty():
		return 0.0
	var duration_profile: String = str(buff_def.get("duration_profile", "standard")).to_lower()
	var normalized_tier: String = normalize_tier(tier)
	if duration_profile == "short":
		return float(DURATION_SHORT_BY_TIER.get(normalized_tier, DURATION_SHORT_BY_TIER[TIER_CLASSIC]))
	return float(DURATION_STANDARD_BY_TIER.get(normalized_tier, DURATION_STANDARD_BY_TIER[TIER_CLASSIC]))

static func category_for(buff_id: String) -> String:
	var buff_def: Dictionary = get_definition(buff_id)
	if buff_def.is_empty():
		return ""
	return str(buff_def.get("category", "")).to_lower()

static func target_type_for(buff_id: String) -> String:
	var buff_def: Dictionary = get_definition(buff_id)
	if buff_def.is_empty():
		return TARGET_NONE
	var target_type: String = str(buff_def.get("target_type", TARGET_NONE)).to_lower()
	if target_type == TARGET_HIVE:
		return TARGET_HIVE
	if target_type == TARGET_LANE:
		return TARGET_LANE
	return TARGET_NONE

static func requires_target(buff_id: String) -> bool:
	return target_type_for(buff_id) != TARGET_NONE

static func effect_payload_for(buff_id: String) -> Dictionary:
	var buff_def: Dictionary = get_definition(buff_id)
	if buff_def.is_empty():
		return {}
	var effect_any: Variant = buff_def.get("effects", {})
	if typeof(effect_any) != TYPE_DICTIONARY:
		return {}
	return (effect_any as Dictionary).duplicate(true)

static func supported_categories() -> PackedStringArray:
	return PackedStringArray([CATEGORY_UNIT, CATEGORY_HIVE, CATEGORY_LANE])
