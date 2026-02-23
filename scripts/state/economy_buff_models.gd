class_name EconomyBuffModels
extends RefCounted

enum BuffTier {
	CLASSIC,
	PREMIUM,
	ELITE
}

enum WalletCurrency {
	HONEY,
	NECTAR,
	WAX,
	USD
}

const TIER_CLASSIC: String = "CLASSIC"
const TIER_PREMIUM: String = "PREMIUM"
const TIER_ELITE: String = "ELITE"

static func normalize_tier_name(tier_name: String) -> String:
	var key: String = tier_name.strip_edges().to_upper()
	if key == "PREMIUM":
		return TIER_PREMIUM
	if key == "ELITE":
		return TIER_ELITE
	return TIER_CLASSIC

static func tier_name_from_buff(buff_def: Dictionary) -> String:
	return normalize_tier_name(str(buff_def.get("tier", "classic")))

static func new_wallet() -> Dictionary:
	return {
		"honey": 0,
		"nectar": 0,
		"wax": 0,
		"usd": 0
	}

static func normalize_wallet(raw_wallet: Dictionary) -> Dictionary:
	var wallet: Dictionary = new_wallet()
	wallet["honey"] = maxi(0, int(raw_wallet.get("honey", 0)))
	wallet["nectar"] = maxi(0, int(raw_wallet.get("nectar", 0)))
	wallet["wax"] = maxi(0, int(raw_wallet.get("wax", 0)))
	wallet["usd"] = maxi(0, int(raw_wallet.get("usd", 0)))
	return wallet

static func normalize_loadout(loadout_any: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(loadout_any) != TYPE_ARRAY:
		return out
	for buff_id_any in loadout_any as Array:
		var buff_id: String = str(buff_id_any).strip_edges()
		if buff_id == "":
			out.append("")
			continue
		out.append(buff_id)
	return out
