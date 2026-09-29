class_name BuffLoadoutPolicy
extends RefCounted

const BuffCatalog = preload("res://scripts/state/buff_catalog.gd")
const BuffDefinitions = preload("res://scripts/state/buff_definitions.gd")

const LOADOUT_SIZE: int = 3
const MAX_PREMIUM: int = 1
const MAX_ELITE: int = 1

static func validate_catalog_ids(ids: Array) -> Dictionary:
	if ids.size() > LOADOUT_SIZE:
		return _error("too_many_slots", "Loadout cannot exceed %d buffs." % LOADOUT_SIZE)
	var tiers: Array[String] = []
	for buff_id_any in ids:
		var buff_id: String = str(buff_id_any).strip_edges()
		if buff_id == "":
			continue
		var buff: Dictionary = BuffCatalog.get_buff(buff_id)
		if buff.is_empty():
			return _error("unknown_buff", "Loadout contains an unknown buff: %s." % buff_id)
		tiers.append(str(buff.get("tier", BuffDefinitions.TIER_CLASSIC)))
	return validate_tiers(tiers)

static func validate_entries(entries: Array) -> Dictionary:
	if entries.size() > LOADOUT_SIZE:
		return _error("too_many_slots", "Loadout cannot exceed %d buffs." % LOADOUT_SIZE)
	var tiers: Array[String] = []
	for entry_any in entries:
		if typeof(entry_any) != TYPE_DICTIONARY:
			return _error("invalid_entry", "Loadout entry is not a Dictionary.")
		var entry: Dictionary = entry_any as Dictionary
		tiers.append(str(entry.get("tier", BuffDefinitions.TIER_CLASSIC)))
	return validate_tiers(tiers)

static func validate_tiers(tiers: Array[String]) -> Dictionary:
	var premium_count: int = 0
	var elite_count: int = 0
	for tier_any in tiers:
		var tier: String = BuffDefinitions.normalize_tier(str(tier_any))
		if tier == BuffDefinitions.TIER_PREMIUM:
			premium_count += 1
		elif tier == BuffDefinitions.TIER_ELITE:
			elite_count += 1
	if premium_count > MAX_PREMIUM:
		return _error("too_many_premium", "Loadout cannot include more than one Premium buff.")
	if elite_count > MAX_ELITE:
		return _error("too_many_elite", "Loadout cannot include more than one Elite buff.")
	return {
		"ok": true,
		"premium_count": premium_count,
		"elite_count": elite_count
	}

static func allows_catalog_id(existing_ids: Array, candidate_id: String) -> bool:
	var candidate: String = candidate_id.strip_edges()
	if candidate == "":
		return true
	var proposed: Array = existing_ids.duplicate()
	proposed.append(candidate)
	return bool(validate_catalog_ids(proposed).get("ok", false))

static func _error(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "error": message}
