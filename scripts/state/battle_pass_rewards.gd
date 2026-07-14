class_name BattlePassRewards
extends RefCounted

const REWARD_NONE: String = "none"
const REWARD_HONEY: String = "honey"
const REWARD_BUFF: String = "buff"
const REWARD_COSMETIC: String = "cosmetic"
const REWARD_ACCESS_TICKET: String = "access_ticket"
const REWARD_ANALYTICS_CREDIT: String = "analytics_credit"
const REWARD_BUNDLE_TOKEN: String = "bundle_token"
const REWARD_AD_FREE_DAYS: String = "ad_free_days"

const INVENTORY_COSMETICS: String = "cosmetics"
const LEGACY_INVENTORY_BUFFS: String = "buffs"
const INVENTORY_ACCESS_TICKETS: String = "access_tickets"
const INVENTORY_ANALYTICS_CREDITS: String = "analytics_credits"
const INVENTORY_BUNDLE_TOKENS: String = "bundle_tokens"
const INVENTORY_AD_FREE_DAYS: String = "ad_free_days"

func normalize_wallet(raw_wallet: Dictionary) -> Dictionary:
	# Currency does not belong to the Battle Path reward inventory. Honey is
	# player-owned, Wax is RankState-owned, and Nectar is seasonal path XP.
	# Keep this migration shim so old saves load without preserving a second
	# authoritative wallet.
	var _discarded_legacy_wallet: Dictionary = raw_wallet
	return {}

func normalize_inventory(raw_inventory: Dictionary) -> Dictionary:
	var inventory: Dictionary = {
		INVENTORY_COSMETICS: {},
		INVENTORY_ACCESS_TICKETS: 0,
		INVENTORY_ANALYTICS_CREDITS: {},
		INVENTORY_BUNDLE_TOKENS: {},
		INVENTORY_AD_FREE_DAYS: 0
	}
	var cosmetics_any: Variant = raw_inventory.get(INVENTORY_COSMETICS, {})
	if typeof(cosmetics_any) == TYPE_DICTIONARY:
		inventory[INVENTORY_COSMETICS] = (cosmetics_any as Dictionary).duplicate(true)
	inventory[INVENTORY_ACCESS_TICKETS] = maxi(0, int(raw_inventory.get(INVENTORY_ACCESS_TICKETS, 0)))
	var analytics_any: Variant = raw_inventory.get(INVENTORY_ANALYTICS_CREDITS, {})
	if typeof(analytics_any) == TYPE_DICTIONARY:
		inventory[INVENTORY_ANALYTICS_CREDITS] = (analytics_any as Dictionary).duplicate(true)
	var bundle_any: Variant = raw_inventory.get(INVENTORY_BUNDLE_TOKENS, {})
	if typeof(bundle_any) == TYPE_DICTIONARY:
		inventory[INVENTORY_BUNDLE_TOKENS] = (bundle_any as Dictionary).duplicate(true)
	inventory[INVENTORY_AD_FREE_DAYS] = maxi(0, int(raw_inventory.get(INVENTORY_AD_FREE_DAYS, 0)))
	return inventory

func migrate_legacy_buff_inventory(raw_inventory: Dictionary, profile_manager: Node) -> int:
	if profile_manager == null:
		return 0
	var buffs_any: Variant = raw_inventory.get(LEGACY_INVENTORY_BUFFS, {})
	if typeof(buffs_any) != TYPE_DICTIONARY:
		return 0
	var migrated: int = 0
	for buff_id_any in (buffs_any as Dictionary).keys():
		var buff_id: String = str(buff_id_any).strip_edges()
		if buff_id == "":
			continue
		var entry_any: Variant = (buffs_any as Dictionary).get(buff_id_any, {})
		if typeof(entry_any) == TYPE_DICTIONARY and not bool((entry_any as Dictionary).get("owned", true)):
			continue
		var already_owned: bool = profile_manager.has_method("owns_buff") and bool(profile_manager.call("owns_buff", buff_id, "vs", 1))
		if not already_owned and profile_manager.has_method("grant_buff"):
			var result: Dictionary = profile_manager.call("grant_buff", buff_id, 1, "battle_pass_legacy_migration") as Dictionary
			if bool(result.get("ok", false)):
				migrated += 1
	return migrated

func grant_reward(
	reward_def: Dictionary,
	wallet_state: Dictionary,
	inventory_state: Dictionary,
	profile_manager: Node = null
) -> Dictionary:
	var wallet: Dictionary = normalize_wallet(wallet_state)
	var inventory: Dictionary = normalize_inventory(inventory_state)
	var reward_type: String = str(reward_def.get("reward_type", REWARD_NONE)).strip_edges().to_lower()
	var quantity: int = maxi(0, int(reward_def.get("quantity", 1)))
	if quantity <= 0:
		quantity = 1

	if reward_type == REWARD_NONE or reward_type.is_empty():
		return {
			"ok": false,
			"reason": "empty_reward",
			"wallet": wallet,
			"inventory": inventory
		}

	if reward_type == REWARD_HONEY:
		return {
			"ok": false,
			"reason": "honey_requires_player_authority",
			"reward_type": REWARD_HONEY,
			"quantity": quantity,
			"wallet": wallet,
			"inventory": inventory
		}

	if reward_type == REWARD_BUFF:
		var buff_id: String = str(reward_def.get("buff_id", "")).strip_edges()
		if buff_id.is_empty():
			return {
				"ok": false,
				"reason": "missing_buff_id",
				"wallet": wallet,
				"inventory": inventory
			}
		if profile_manager == null or not profile_manager.has_method("grant_buff"):
			return {
				"ok": false,
				"reason": "buff_inventory_authority_missing",
				"wallet": wallet,
				"inventory": inventory
			}
		var ownership_result: Dictionary = profile_manager.call(
			"grant_buff",
			buff_id,
			quantity,
			"battle_pass_reward"
		) as Dictionary
		if not bool(ownership_result.get("ok", false)):
			return {
				"ok": false,
				"reason": str(ownership_result.get("reason", "buff_grant_failed")),
				"wallet": wallet,
				"inventory": inventory
			}
		return {
			"ok": true,
			"reward_type": REWARD_BUFF,
			"buff_id": buff_id,
			"quantity": quantity,
			"ownership": ownership_result,
			"wallet": wallet,
			"inventory": inventory
		}

	if reward_type == REWARD_COSMETIC:
		var cosmetic_id: String = str(reward_def.get("cosmetic_id", "")).strip_edges()
		if cosmetic_id.is_empty():
			return {
				"ok": false,
				"reason": "missing_cosmetic_id",
				"wallet": wallet,
				"inventory": inventory
			}
		var cosmetics: Dictionary = inventory.get(INVENTORY_COSMETICS, {}) as Dictionary
		cosmetics[cosmetic_id] = {
			"owned": true,
			"account_bound": true
		}
		inventory[INVENTORY_COSMETICS] = cosmetics
		return {
			"ok": true,
			"reward_type": REWARD_COSMETIC,
			"cosmetic_id": cosmetic_id,
			"quantity": 1,
			"wallet": wallet,
			"inventory": inventory
		}

	if reward_type == REWARD_ACCESS_TICKET:
		inventory[INVENTORY_ACCESS_TICKETS] = maxi(0, int(inventory.get(INVENTORY_ACCESS_TICKETS, 0))) + quantity
		return {
			"ok": true,
			"reward_type": REWARD_ACCESS_TICKET,
			"quantity": quantity,
			"wallet": wallet,
			"inventory": inventory
		}

	if reward_type == REWARD_ANALYTICS_CREDIT:
		var package_id: String = str(reward_def.get("package_id", reward_def.get("analytics_package_id", ""))).strip_edges()
		if package_id.is_empty():
			return {
				"ok": false,
				"reason": "missing_package_id",
				"wallet": wallet,
				"inventory": inventory
			}
		var analytics_credits: Dictionary = inventory.get(INVENTORY_ANALYTICS_CREDITS, {}) as Dictionary
		analytics_credits[package_id] = maxi(0, int(analytics_credits.get(package_id, 0))) + quantity
		inventory[INVENTORY_ANALYTICS_CREDITS] = analytics_credits
		return {
			"ok": true,
			"reward_type": REWARD_ANALYTICS_CREDIT,
			"package_id": package_id,
			"quantity": quantity,
			"wallet": wallet,
			"inventory": inventory
		}

	if reward_type == REWARD_BUNDLE_TOKEN:
		var bundle_id: String = str(reward_def.get("bundle_id", "")).strip_edges()
		if bundle_id.is_empty():
			return {
				"ok": false,
				"reason": "missing_bundle_id",
				"wallet": wallet,
				"inventory": inventory
			}
		var bundle_tokens: Dictionary = inventory.get(INVENTORY_BUNDLE_TOKENS, {}) as Dictionary
		bundle_tokens[bundle_id] = maxi(0, int(bundle_tokens.get(bundle_id, 0))) + quantity
		inventory[INVENTORY_BUNDLE_TOKENS] = bundle_tokens
		return {
			"ok": true,
			"reward_type": REWARD_BUNDLE_TOKEN,
			"bundle_id": bundle_id,
			"quantity": quantity,
			"wallet": wallet,
			"inventory": inventory
		}

	if reward_type == REWARD_AD_FREE_DAYS:
		inventory[INVENTORY_AD_FREE_DAYS] = maxi(0, int(inventory.get(INVENTORY_AD_FREE_DAYS, 0))) + quantity
		return {
			"ok": true,
			"reward_type": REWARD_AD_FREE_DAYS,
			"quantity": quantity,
			"wallet": wallet,
			"inventory": inventory
		}

	return {
		"ok": false,
		"reason": "unknown_reward_type",
		"reward_type": reward_type,
		"wallet": wallet,
		"inventory": inventory
	}

func grant_rewards(
	reward_defs: Array,
	wallet_state: Dictionary,
	inventory_state: Dictionary,
	profile_manager: Node = null
) -> Dictionary:
	var wallet: Dictionary = normalize_wallet(wallet_state)
	var inventory: Dictionary = normalize_inventory(inventory_state)
	var grants: Array[Dictionary] = []
	for reward_any in reward_defs:
		if typeof(reward_any) != TYPE_DICTIONARY:
			continue
		var reward_def: Dictionary = reward_any as Dictionary
		var reward_type: String = str(reward_def.get("reward_type", REWARD_NONE)).strip_edges().to_lower()
		if reward_type == REWARD_NONE or reward_type.is_empty():
			continue
		var grant_result: Dictionary = grant_reward(reward_def, wallet, inventory, profile_manager)
		if not bool(grant_result.get("ok", false)):
			return {
				"ok": false,
				"reason": "reward_batch_failed",
				"failed_reward": reward_def.duplicate(true),
				"grant_result": grant_result,
				"wallet": wallet,
				"inventory": inventory,
				"grants": grants
			}
		wallet = (grant_result.get("wallet", wallet) as Dictionary).duplicate(true)
		inventory = (grant_result.get("inventory", inventory) as Dictionary).duplicate(true)
		grants.append(grant_result.duplicate(true))
	return {
		"ok": true,
		"wallet": wallet,
		"inventory": inventory,
		"grants": grants
	}
