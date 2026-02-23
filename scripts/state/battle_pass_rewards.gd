class_name BattlePassRewards
extends RefCounted

const REWARD_NONE: String = "none"
const REWARD_HONEY: String = "honey"
const REWARD_BUFF: String = "buff"
const REWARD_COSMETIC: String = "cosmetic"
const REWARD_ACCESS_TICKET: String = "access_ticket"

const INVENTORY_COSMETICS: String = "cosmetics"
const INVENTORY_BUFFS: String = "buffs"
const INVENTORY_ACCESS_TICKETS: String = "access_tickets"

func normalize_wallet(raw_wallet: Dictionary) -> Dictionary:
	var wallet: Dictionary = {
		"honey": 0,
		"nectar": 0,
		"wax": 0
	}
	wallet["honey"] = maxi(0, int(raw_wallet.get("honey", 0)))
	wallet["nectar"] = maxi(0, int(raw_wallet.get("nectar", 0)))
	wallet["wax"] = maxi(0, int(raw_wallet.get("wax", 0)))
	return wallet

func normalize_inventory(raw_inventory: Dictionary) -> Dictionary:
	var inventory: Dictionary = {
		INVENTORY_COSMETICS: {},
		INVENTORY_BUFFS: {},
		INVENTORY_ACCESS_TICKETS: 0
	}
	var cosmetics_any: Variant = raw_inventory.get(INVENTORY_COSMETICS, {})
	if typeof(cosmetics_any) == TYPE_DICTIONARY:
		inventory[INVENTORY_COSMETICS] = (cosmetics_any as Dictionary).duplicate(true)
	var buffs_any: Variant = raw_inventory.get(INVENTORY_BUFFS, {})
	if typeof(buffs_any) == TYPE_DICTIONARY:
		inventory[INVENTORY_BUFFS] = (buffs_any as Dictionary).duplicate(true)
	inventory[INVENTORY_ACCESS_TICKETS] = maxi(0, int(raw_inventory.get(INVENTORY_ACCESS_TICKETS, 0)))
	return inventory

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
		wallet["honey"] = maxi(0, int(wallet.get("honey", 0))) + quantity
		return {
			"ok": true,
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
		var buffs: Dictionary = inventory.get(INVENTORY_BUFFS, {}) as Dictionary
		buffs[buff_id] = {
			"owned": true,
			"account_bound": true
		}
		inventory[INVENTORY_BUFFS] = buffs
		if profile_manager != null and profile_manager.has_method("add_owned_buffs"):
			profile_manager.call("add_owned_buffs", [buff_id])
		return {
			"ok": true,
			"reward_type": REWARD_BUFF,
			"buff_id": buff_id,
			"quantity": 1,
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

	return {
		"ok": false,
		"reason": "unknown_reward_type",
		"reward_type": reward_type,
		"wallet": wallet,
		"inventory": inventory
	}
