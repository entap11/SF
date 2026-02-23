class_name ModeRulesConfig
extends Resource

const MODE_STANDARD: String = "STANDARD"
const MODE_STEROIDS: String = "STEROIDS_LEAGUE"
const MODE_ESPORTS_NO_BUFFS: String = "ESPORTS_NO_BUFFS"
const MODE_ESPORTS_STANDARDIZED: String = "ESPORTS_STANDARDIZED"

const ENTRY_FREE: String = "FREE"
const ENTRY_NECTAR: String = "NECTAR"
const ENTRY_USD: String = "USD"

@export var enabled: bool = true
@export var default_mode_key: String = MODE_STANDARD
@export var slot_unlock_cost_nectar: int = 50
@export var tournament_entry_cost_nectar: int = 100

# Data-driven single source of truth for mode rules.
@export var rules_by_mode: Dictionary = {
	MODE_STANDARD: {
		"label": "Standard",
		"buffs_enabled": true,
		"loadout_ui_enabled": true,
		"baseline_free_slots": 1,
		"max_additional_slots": 3,
		"max_total_slots": 4,
		"max_elite": 1,
		"max_premium": 1,
		"classic_slot_index": 3,
		"classic_requires_overtime": true,
		"unlimited_buffs": false,
		"esports_standardized_buff_enabled": false,
		"esports_standardized_buff_id": "",
		"entry_currency": ENTRY_FREE,
		"entry_cost": 0,
		"nectar_awards": {
			"match_completed": 8,
			"paid_match_completed": 24,
			"tournament_participation": 12,
			"purchase_kickback_per_usd": 6.0
		}
	},
	MODE_STEROIDS: {
		"label": "Steroids League",
		"buffs_enabled": true,
		"loadout_ui_enabled": true,
		"baseline_free_slots": 0,
		"max_additional_slots": 0,
		"max_total_slots": 0,
		"max_elite": -1,
		"max_premium": -1,
		"classic_slot_index": -1,
		"classic_requires_overtime": false,
		"unlimited_buffs": true,
		"esports_standardized_buff_enabled": false,
		"esports_standardized_buff_id": "",
		"entry_currency": ENTRY_USD,
		"entry_cost": 20,
		"nectar_awards": {
			"match_completed": 20,
			"paid_match_completed": 45,
			"tournament_participation": 0,
			"purchase_kickback_per_usd": 6.0
		}
	},
	MODE_ESPORTS_NO_BUFFS: {
		"label": "eSports (No Buffs)",
		"buffs_enabled": false,
		"loadout_ui_enabled": false,
		"baseline_free_slots": 0,
		"max_additional_slots": 0,
		"max_total_slots": 0,
		"max_elite": 0,
		"max_premium": 0,
		"classic_slot_index": -1,
		"classic_requires_overtime": false,
		"unlimited_buffs": false,
		"esports_standardized_buff_enabled": false,
		"esports_standardized_buff_id": "",
		"entry_currency": ENTRY_FREE,
		"entry_cost": 0,
		"nectar_awards": {
			"match_completed": 6,
			"paid_match_completed": 6,
			"tournament_participation": 10,
			"purchase_kickback_per_usd": 6.0
		}
	},
	MODE_ESPORTS_STANDARDIZED: {
		"label": "eSports (Standardized Buff)",
		"buffs_enabled": true,
		"loadout_ui_enabled": false,
		"baseline_free_slots": 1,
		"max_additional_slots": 0,
		"max_total_slots": 1,
		"max_elite": 0,
		"max_premium": 0,
		"classic_slot_index": -1,
		"classic_requires_overtime": false,
		"unlimited_buffs": false,
		"esports_standardized_buff_enabled": true,
		"esports_standardized_buff_id": "buff_swarm_speed_classic",
		"entry_currency": ENTRY_FREE,
		"entry_cost": 0,
		"nectar_awards": {
			"match_completed": 6,
			"paid_match_completed": 6,
			"tournament_participation": 10,
			"purchase_kickback_per_usd": 6.0
		}
	}
}

func mode_keys() -> Array[String]:
	var keys: Array[String] = []
	for mode_key_any in rules_by_mode.keys():
		var mode_key: String = str(mode_key_any).strip_edges().to_upper()
		if mode_key == "":
			continue
		keys.append(mode_key)
	keys.sort()
	return keys

func has_mode(mode_key: String) -> bool:
	var key: String = mode_key.strip_edges().to_upper()
	return rules_by_mode.has(key)

func normalized_mode(mode_key: String) -> String:
	var key: String = mode_key.strip_edges().to_upper()
	if has_mode(key):
		return key
	return default_mode_key.strip_edges().to_upper()

func rule_for_mode(mode_key: String) -> Dictionary:
	var key: String = normalized_mode(mode_key)
	var rule_any: Variant = rules_by_mode.get(key, {})
	if typeof(rule_any) != TYPE_DICTIONARY:
		return {}
	return (rule_any as Dictionary).duplicate(true)

func nectar_awards_for_mode(mode_key: String) -> Dictionary:
	var rule: Dictionary = rule_for_mode(mode_key)
	var awards_any: Variant = rule.get("nectar_awards", {})
	if typeof(awards_any) != TYPE_DICTIONARY:
		return {}
	return (awards_any as Dictionary).duplicate(true)

func entry_currency_for_mode(mode_key: String) -> String:
	var rule: Dictionary = rule_for_mode(mode_key)
	var currency: String = str(rule.get("entry_currency", ENTRY_FREE)).strip_edges().to_upper()
	if currency == "":
		return ENTRY_FREE
	return currency

func entry_cost_for_mode(mode_key: String) -> int:
	var rule: Dictionary = rule_for_mode(mode_key)
	return maxi(0, int(rule.get("entry_cost", 0)))
