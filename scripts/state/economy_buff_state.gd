extends Node

const SFLog = preload("res://scripts/util/sf_log.gd")
const BuffCatalog = preload("res://scripts/state/buff_catalog.gd")
const ModeRulesConfigScript = preload("res://scripts/state/mode_rules_config.gd")
const EconomyBuffModelsScript = preload("res://scripts/state/economy_buff_models.gd")

signal economy_state_changed(snapshot: Dictionary)
signal mode_changed(mode_key: String)
signal validation_failed(payload: Dictionary)
signal buff_event(event: Dictionary)

const CONFIG_PATH: String = "res://data/rules/mode_rules_config.tres"
const SAVE_PATH: String = "user://economy_buff_state.json"

var _config: ModeRulesConfigScript = null

var _current_mode_key: String = ModeRulesConfigScript.MODE_STANDARD
var _overtime_active: bool = false

var _wallets_by_player: Dictionary = {}
var _loadouts_by_player: Dictionary = {}
var _unlocked_additional_slots_by_player: Dictionary = {}
var _activation_state_by_player: Dictionary = {}

func _ready() -> void:
	SFLog.allow_tag("ECONOMY_STATE")
	SFLog.allow_tag("BUFF_RULES")
	_load_config()
	_load_state()
	_bootstrap_local_player()
	_emit_changed()

func intent_register_player(player_id: String) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return _error("missing_player_id", "Player id is required.")
	_ensure_player(clean_id)
	_save_state()
	_emit_changed()
	return {"ok": true, "player": get_player_snapshot(clean_id)}

func intent_set_mode(mode_key: String) -> Dictionary:
	var normalized: String = _config.normalized_mode(mode_key)
	if normalized == _current_mode_key:
		return {"ok": true, "mode_key": _current_mode_key}
	_current_mode_key = normalized
	_overtime_active = false
	_reset_all_activation_state()
	_apply_mode_constraints_to_all_players()
	_save_state()
	mode_changed.emit(_current_mode_key)
	SFLog.info("ECONOMY_STATE", {"mode_changed": _current_mode_key})
	_emit_changed()
	return {"ok": true, "mode_key": _current_mode_key}

func intent_set_overtime(active: bool) -> Dictionary:
	_overtime_active = active
	_emit_changed()
	return {"ok": true, "overtime_active": _overtime_active}

func intent_set_wallet(player_id: String, wallet: Dictionary) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return _error("missing_player_id", "Player id is required.")
	_ensure_player(clean_id)
	_wallets_by_player[clean_id] = EconomyBuffModelsScript.normalize_wallet(wallet)
	_save_state()
	_emit_changed()
	return {"ok": true, "wallet": (_wallets_by_player[clean_id] as Dictionary).duplicate(true)}

func intent_equip_buff(player_id: String, slot_index: int, buff_id: String) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return _error("missing_player_id", "Player id is required.")
	if slot_index < 0:
		return _error("slot_out_of_range", "Slot index must be >= 0.")
	_ensure_player(clean_id)
	var mode_rule: Dictionary = _mode_rule()
	if not bool(mode_rule.get("buffs_enabled", false)):
		return _error("buffs_disabled", "Buffs are disabled for this mode.")
	if bool(mode_rule.get("esports_standardized_buff_enabled", false)):
		return _error("standardized_no_loadout", "eSports standardized mode does not allow loadout choices.")
	var clean_buff_id: String = buff_id.strip_edges()
	if clean_buff_id == "":
		return _error("missing_buff_id", "Buff id is required.")
	var buff_def: Dictionary = BuffCatalog.get_buff(clean_buff_id)
	if buff_def.is_empty():
		return _error("unknown_buff", "Unknown buff id.")

	var old_loadout: Array[String] = _loadout_for_player(clean_id)
	var loadout: Array[String] = old_loadout.duplicate()
	if bool(mode_rule.get("unlimited_buffs", false)):
		while slot_index >= loadout.size():
			loadout.append("")
	else:
		var available_slots: int = _available_slots(clean_id)
		if slot_index >= available_slots:
			return _error("slot_locked", "Slot is locked for this mode/loadout.")
		while slot_index >= loadout.size():
			loadout.append("")
	loadout[slot_index] = clean_buff_id

	var validation: Dictionary = validate_loadout(_current_mode_key, loadout, _overtime_active, clean_id)
	if not bool(validation.get("ok", false)):
		return validation

	_loadouts_by_player[clean_id] = loadout
	_save_state()
	_emit_changed()
	return {"ok": true, "loadout": loadout.duplicate(), "validation": validation}

func intent_unequip_buff(player_id: String, slot_index: int) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return _error("missing_player_id", "Player id is required.")
	_ensure_player(clean_id)
	var loadout: Array[String] = _loadout_for_player(clean_id)
	if slot_index < 0 or slot_index >= loadout.size():
		return _error("slot_out_of_range", "Slot index out of range.")
	loadout[slot_index] = ""
	var validation: Dictionary = validate_loadout(_current_mode_key, loadout, _overtime_active, clean_id)
	if not bool(validation.get("ok", false)):
		return validation
	_loadouts_by_player[clean_id] = loadout
	_save_state()
	_emit_changed()
	return {"ok": true, "loadout": loadout.duplicate()}

func intent_activate_buff(player_id: String, slot_index: int) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return _error("missing_player_id", "Player id is required.")
	if slot_index < 0:
		return _error("slot_out_of_range", "Slot index must be >= 0.")
	_ensure_player(clean_id)
	var mode_rule: Dictionary = _mode_rule()
	if not bool(mode_rule.get("buffs_enabled", false)):
		return _error("buffs_disabled", "Buff activation is disabled for this mode.")

	if bool(mode_rule.get("esports_standardized_buff_enabled", false)):
		if slot_index != 0:
			return _error("standardized_slot_only", "Only standardized slot 0 can activate.")
		var standardized_buff_id: String = str(mode_rule.get("esports_standardized_buff_id", "")).strip_edges()
		if standardized_buff_id == "":
			return _error("standardized_missing_buff", "Standardized buff id is not configured.")
		return _activate_slot_internal(clean_id, 0, standardized_buff_id)

	if not bool(mode_rule.get("unlimited_buffs", false)) and slot_index >= _available_slots(clean_id):
		return _error("slot_locked", "Slot is not available for activation.")

	var loadout: Array[String] = _loadout_for_player(clean_id)
	if slot_index >= loadout.size():
		return _error("slot_out_of_range", "Slot index out of range.")
	var buff_id: String = str(loadout[slot_index]).strip_edges()
	if buff_id == "":
		return _error("empty_slot", "No buff equipped in this slot.")
	var buff_def: Dictionary = BuffCatalog.get_buff(buff_id)
	if buff_def.is_empty():
		return _error("unknown_buff", "Equipped buff is not in catalog.")

	if bool(mode_rule.get("classic_requires_overtime", false)):
		var classic_slot_index: int = int(mode_rule.get("classic_slot_index", -1))
		if slot_index == classic_slot_index and not _overtime_active:
			return _error("classic_locked_pre_overtime", "Classic slot unlocks at overtime.")

	return _activate_slot_internal(clean_id, slot_index, buff_id)

func intent_unlock_additional_slot(player_id: String) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return _error("missing_player_id", "Player id is required.")
	_ensure_player(clean_id)
	var mode_rule: Dictionary = _mode_rule()
	if not bool(mode_rule.get("buffs_enabled", false)):
		return _error("buffs_disabled", "Buff slots are disabled for this mode.")
	if bool(mode_rule.get("unlimited_buffs", false)):
		return _error("unlimited_mode", "Unlimited mode does not require slot unlocks.")
	var current_additional: int = int(_unlocked_additional_slots_by_player.get(clean_id, 0))
	var max_additional: int = maxi(0, int(mode_rule.get("max_additional_slots", 0)))
	if current_additional >= max_additional:
		return _error("max_slots_unlocked", "All additional slots are already unlocked.")
	var spend_result: Dictionary = intent_spend_nectar(clean_id, _config.slot_unlock_cost_nectar, "slot_unlock")
	if not bool(spend_result.get("ok", false)):
		return spend_result
	_unlocked_additional_slots_by_player[clean_id] = current_additional + 1
	_save_state()
	_emit_changed()
	return {
		"ok": true,
		"additional_slots_unlocked": int(_unlocked_additional_slots_by_player.get(clean_id, 0)),
		"available_slots": _available_slots(clean_id)
	}

func intent_pay_tournament_entry(player_id: String) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return _error("missing_player_id", "Player id is required.")
	_ensure_player(clean_id)
	var cost: int = maxi(0, _config.tournament_entry_cost_nectar)
	if cost <= 0:
		return {"ok": true, "cost": 0, "wallet": _wallet_for_player(clean_id)}
	var spend_result: Dictionary = intent_spend_nectar(clean_id, cost, "tournament_entry")
	if not bool(spend_result.get("ok", false)):
		return spend_result
	return {"ok": true, "cost": cost, "wallet": _wallet_for_player(clean_id)}

func intent_purchase_buff_access(player_id: String, buff_id: String, nectar_cost: int) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return _error("missing_player_id", "Player id is required.")
	var clean_buff_id: String = buff_id.strip_edges()
	if clean_buff_id == "":
		return _error("missing_buff_id", "Buff id is required.")
	if BuffCatalog.get_buff(clean_buff_id).is_empty():
		return _error("unknown_buff", "Unknown buff id.")
	var cost: int = maxi(0, nectar_cost)
	if cost <= 0:
		return _error("invalid_amount", "Nectar cost must be positive.")
	_ensure_player(clean_id)
	var spend_result: Dictionary = intent_spend_nectar(clean_id, cost, "buff_access:%s" % clean_buff_id)
	if not bool(spend_result.get("ok", false)):
		return spend_result
	return {"ok": true, "buff_id": clean_buff_id, "cost": cost, "wallet": _wallet_for_player(clean_id)}

func intent_spend_nectar(player_id: String, nectar_amount: int, reason: String) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return _error("missing_player_id", "Player id is required.")
	if nectar_amount <= 0:
		return _error("invalid_amount", "Nectar amount must be positive.")
	_ensure_player(clean_id)
	var wallet: Dictionary = _wallet_for_player(clean_id)
	var balance: int = int(wallet.get("nectar", 0))
	if balance < nectar_amount:
		return _error("insufficient_nectar", "Not enough Nectar.")
	wallet["nectar"] = balance - nectar_amount
	_wallets_by_player[clean_id] = wallet
	_save_state()
	_emit_changed()
	var event: Dictionary = {
		"type": "nectar_spent",
		"player_id": clean_id,
		"amount": nectar_amount,
		"reason": reason
	}
	buff_event.emit(event)
	SFLog.info("BUFF_RULES", event)
	return {"ok": true, "wallet": wallet.duplicate(true)}

func intent_record_match_completion(player_id: String, paid_entry: bool) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return _error("missing_player_id", "Player id is required.")
	_ensure_player(clean_id)
	var awards: Dictionary = _config.nectar_awards_for_mode(_current_mode_key)
	var key: String = "paid_match_completed" if paid_entry else "match_completed"
	var amount: int = maxi(0, int(awards.get(key, 0)))
	return _award_nectar(clean_id, amount, key)

func intent_record_tournament_participation(player_id: String) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return _error("missing_player_id", "Player id is required.")
	_ensure_player(clean_id)
	var awards: Dictionary = _config.nectar_awards_for_mode(_current_mode_key)
	var amount: int = maxi(0, int(awards.get("tournament_participation", 0)))
	return _award_nectar(clean_id, amount, "tournament_participation")

func intent_record_store_purchase(player_id: String, usd_amount: float) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return _error("missing_player_id", "Player id is required.")
	if usd_amount <= 0.0:
		return _error("invalid_amount", "USD amount must be positive.")
	_ensure_player(clean_id)
	var awards: Dictionary = _config.nectar_awards_for_mode(_current_mode_key)
	var kickback_per_usd: float = maxf(0.0, float(awards.get("purchase_kickback_per_usd", 0.0)))
	var nectar_kickback: int = int(round(usd_amount * kickback_per_usd))
	var wallet: Dictionary = _wallet_for_player(clean_id)
	wallet["usd"] = int(wallet.get("usd", 0)) + int(round(usd_amount))
	_wallets_by_player[clean_id] = wallet
	return _award_nectar(clean_id, nectar_kickback, "store_kickback")

func validate_loadout(mode_key: String, loadout: Array[String], overtime_active: bool, player_id: String = "") -> Dictionary:
	var mode_rule: Dictionary = _config.rule_for_mode(mode_key)
	if mode_rule.is_empty():
		return _error("unknown_mode", "Mode rules were not found.")
	if not bool(mode_rule.get("buffs_enabled", false)):
		if _non_empty_count(loadout) > 0:
			return _error("buffs_disabled", "Loadout must be empty because buffs are disabled.")
		return {"ok": true}
	if bool(mode_rule.get("esports_standardized_buff_enabled", false)):
		if _non_empty_count(loadout) > 0:
			return _error("standardized_no_choice", "Standardized eSports mode does not allow custom loadout.")
		return {"ok": true}

	var unlimited: bool = bool(mode_rule.get("unlimited_buffs", false))
	var available_slots: int = _available_slots(player_id) if player_id != "" else _baseline_slots_from_rule(mode_rule)
	if not unlimited and loadout.size() > available_slots:
		for idx in range(available_slots, loadout.size()):
			if str(loadout[idx]).strip_edges() != "":
				return _error("slot_overflow", "Equipped buff exceeds available slots.")

	var premium_count: int = 0
	var elite_count: int = 0
	for buff_id_any in loadout:
		var buff_id: String = str(buff_id_any).strip_edges()
		if buff_id == "":
			continue
		var buff_def: Dictionary = BuffCatalog.get_buff(buff_id)
		if buff_def.is_empty():
			return _error("unknown_buff", "Loadout contains unknown buff id: %s" % buff_id)
		var tier_name: String = EconomyBuffModelsScript.tier_name_from_buff(buff_def)
		if tier_name == EconomyBuffModelsScript.TIER_PREMIUM:
			premium_count += 1
		elif tier_name == EconomyBuffModelsScript.TIER_ELITE:
			elite_count += 1

	if not unlimited:
		var max_premium: int = int(mode_rule.get("max_premium", 0))
		var max_elite: int = int(mode_rule.get("max_elite", 0))
		if max_premium >= 0 and premium_count > max_premium:
			return _error("too_many_premium", "Loadout exceeds Premium cap for this mode.")
		if max_elite >= 0 and elite_count > max_elite:
			return _error("too_many_elite", "Loadout exceeds Elite cap for this mode.")

	if bool(mode_rule.get("classic_requires_overtime", false)) and not overtime_active:
		var classic_slot_index: int = int(mode_rule.get("classic_slot_index", -1))
		if classic_slot_index >= 0 and classic_slot_index < loadout.size():
			var classic_buff_id: String = str(loadout[classic_slot_index]).strip_edges()
			if classic_buff_id != "":
				var classic_def: Dictionary = BuffCatalog.get_buff(classic_buff_id)
				if not classic_def.is_empty() and EconomyBuffModelsScript.tier_name_from_buff(classic_def) != EconomyBuffModelsScript.TIER_CLASSIC:
					return _error("classic_slot_requires_classic", "Classic overtime slot only accepts Classic tier buff.")

	return {
		"ok": true,
		"premium_count": premium_count,
		"elite_count": elite_count,
		"available_slots": available_slots
	}

func get_mode_snapshot() -> Dictionary:
	var rule: Dictionary = _mode_rule()
	return {
		"mode_key": _current_mode_key,
		"label": str(rule.get("label", _current_mode_key)),
		"overtime_active": _overtime_active,
		"rules": rule
	}

func get_player_snapshot(player_id: String) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	if clean_id == "":
		return {}
	_ensure_player(clean_id)
	var mode_rule: Dictionary = _mode_rule()
	var loadout: Array[String] = _loadout_for_player(clean_id)
	var activation_state: Dictionary = _activation_state_for_player(clean_id)
	var entries: Array[Dictionary] = []
	for idx in range(loadout.size()):
		var buff_id: String = str(loadout[idx]).strip_edges()
		var buff_def: Dictionary = BuffCatalog.get_buff(buff_id)
		entries.append({
			"slot_index": idx,
			"buff_id": buff_id,
			"tier": EconomyBuffModelsScript.tier_name_from_buff(buff_def) if not buff_def.is_empty() else EconomyBuffModelsScript.TIER_CLASSIC,
			"name": str(buff_def.get("name", buff_id)),
			"activated": bool(activation_state.get(str(idx), false)),
			"classic_locked": _is_classic_slot_locked(mode_rule, idx)
		})
	var standardized_active: bool = bool(mode_rule.get("esports_standardized_buff_enabled", false))
	var standardized_buff_id: String = str(mode_rule.get("esports_standardized_buff_id", "")).strip_edges()
	if standardized_active and entries.is_empty():
		entries.append({
			"slot_index": 0,
			"buff_id": standardized_buff_id,
			"tier": EconomyBuffModelsScript.TIER_CLASSIC,
			"name": str(BuffCatalog.get_buff(standardized_buff_id).get("name", standardized_buff_id)),
			"activated": bool(activation_state.get("0", false)),
			"classic_locked": false
		})
	return {
		"player_id": clean_id,
		"mode_key": _current_mode_key,
		"overtime_active": _overtime_active,
		"buffs_enabled": bool(mode_rule.get("buffs_enabled", false)),
		"loadout_ui_enabled": bool(mode_rule.get("loadout_ui_enabled", false)),
		"unlimited_buffs": bool(mode_rule.get("unlimited_buffs", false)),
		"available_slots": _available_slots(clean_id),
		"additional_slots_unlocked": int(_unlocked_additional_slots_by_player.get(clean_id, 0)),
		"wallet": _wallet_for_player(clean_id).duplicate(true),
		"entries": entries,
		"esports_standardized_buff_enabled": standardized_active,
		"esports_standardized_buff_id": standardized_buff_id,
		"slot_unlock_cost_nectar": _config.slot_unlock_cost_nectar,
		"entry_currency": _config.entry_currency_for_mode(_current_mode_key),
		"entry_cost": _config.entry_cost_for_mode(_current_mode_key)
	}

func get_state_snapshot() -> Dictionary:
	return {
		"mode": get_mode_snapshot(),
		"players": _players_snapshot(),
		"player_count": _wallets_by_player.size()
	}

func _activate_slot_internal(player_id: String, slot_index: int, buff_id: String) -> Dictionary:
	var activation_state: Dictionary = _activation_state_for_player(player_id)
	var key: String = str(slot_index)
	if bool(activation_state.get(key, false)):
		return _error("already_activated", "This slot already activated this match.")
	activation_state[key] = true
	_activation_state_by_player[player_id] = activation_state
	_save_state()
	var event: Dictionary = {
		"type": "buff_activated",
		"player_id": player_id,
		"slot_index": slot_index,
		"buff_id": buff_id,
		"mode_key": _current_mode_key
	}
	buff_event.emit(event)
	SFLog.info("BUFF_RULES", event)
	_emit_changed()
	return {"ok": true, "event": event}

func _award_nectar(player_id: String, amount: int, source: String) -> Dictionary:
	var safe_amount: int = maxi(0, amount)
	var wallet: Dictionary = _wallet_for_player(player_id)
	wallet["nectar"] = int(wallet.get("nectar", 0)) + safe_amount
	_wallets_by_player[player_id] = wallet
	_save_state()
	var event: Dictionary = {
		"type": "nectar_awarded",
		"player_id": player_id,
		"amount": safe_amount,
		"source": source,
		"mode_key": _current_mode_key
	}
	buff_event.emit(event)
	SFLog.info("BUFF_RULES", event)
	_emit_changed()
	return {"ok": true, "awarded": safe_amount, "wallet": wallet.duplicate(true)}

func _ensure_player(player_id: String) -> void:
	if not _wallets_by_player.has(player_id):
		_wallets_by_player[player_id] = EconomyBuffModelsScript.new_wallet()
	if not _loadouts_by_player.has(player_id):
		_loadouts_by_player[player_id] = _default_loadout_for_mode(_mode_rule())
	if not _unlocked_additional_slots_by_player.has(player_id):
		_unlocked_additional_slots_by_player[player_id] = 0
	if not _activation_state_by_player.has(player_id):
		_activation_state_by_player[player_id] = {}
	_apply_mode_constraints_to_player(player_id)

func _loadout_for_player(player_id: String) -> Array[String]:
	var loadout_any: Variant = _loadouts_by_player.get(player_id, [])
	return EconomyBuffModelsScript.normalize_loadout(loadout_any)

func _wallet_for_player(player_id: String) -> Dictionary:
	var wallet_any: Variant = _wallets_by_player.get(player_id, EconomyBuffModelsScript.new_wallet())
	if typeof(wallet_any) != TYPE_DICTIONARY:
		return EconomyBuffModelsScript.new_wallet()
	return EconomyBuffModelsScript.normalize_wallet(wallet_any as Dictionary)

func _activation_state_for_player(player_id: String) -> Dictionary:
	var state_any: Variant = _activation_state_by_player.get(player_id, {})
	if typeof(state_any) != TYPE_DICTIONARY:
		return {}
	return (state_any as Dictionary).duplicate(true)

func _available_slots(player_id: String) -> int:
	var mode_rule: Dictionary = _mode_rule()
	if bool(mode_rule.get("unlimited_buffs", false)):
		var existing_size: int = _loadout_for_player(player_id).size()
		return maxi(existing_size, maxi(1, _baseline_slots_from_rule(mode_rule)))
	if bool(mode_rule.get("esports_standardized_buff_enabled", false)):
		return 1
	var baseline: int = _baseline_slots_from_rule(mode_rule)
	var max_additional: int = maxi(0, int(mode_rule.get("max_additional_slots", 0)))
	var max_total: int = maxi(0, int(mode_rule.get("max_total_slots", baseline + max_additional)))
	var unlocked: int = clampi(int(_unlocked_additional_slots_by_player.get(player_id, 0)), 0, max_additional)
	return clampi(baseline + unlocked, 0, max_total)

func _baseline_slots_from_rule(mode_rule: Dictionary) -> int:
	return maxi(0, int(mode_rule.get("baseline_free_slots", 0)))

func _is_classic_slot_locked(mode_rule: Dictionary, slot_index: int) -> bool:
	if not bool(mode_rule.get("classic_requires_overtime", false)):
		return false
	var classic_slot_index: int = int(mode_rule.get("classic_slot_index", -1))
	if classic_slot_index < 0:
		return false
	if slot_index != classic_slot_index:
		return false
	return not _overtime_active

func _default_loadout_for_mode(mode_rule: Dictionary) -> Array[String]:
	var loadout: Array[String] = []
	if not bool(mode_rule.get("buffs_enabled", false)):
		return loadout
	if bool(mode_rule.get("esports_standardized_buff_enabled", false)):
		return loadout
	var slots: int = _baseline_slots_from_rule(mode_rule)
	if slots <= 0:
		return loadout
	var classic_id: String = _first_buff_id_for_tier(EconomyBuffModelsScript.TIER_CLASSIC)
	for i in range(slots):
		loadout.append(classic_id)
	return loadout

func _first_buff_id_for_tier(tier_name: String) -> String:
	var all_buffs: Array = BuffCatalog.list_all()
	for buff_any in all_buffs:
		if typeof(buff_any) != TYPE_DICTIONARY:
			continue
		var buff: Dictionary = buff_any as Dictionary
		var tier: String = EconomyBuffModelsScript.tier_name_from_buff(buff)
		if tier != tier_name:
			continue
		var buff_id: String = str(buff.get("id", "")).strip_edges()
		if buff_id != "":
			return buff_id
	return ""

func _apply_mode_constraints_to_all_players() -> void:
	for player_id_any in _wallets_by_player.keys():
		_apply_mode_constraints_to_player(str(player_id_any))

func _apply_mode_constraints_to_player(player_id: String) -> void:
	var mode_rule: Dictionary = _mode_rule()
	var loadout: Array[String] = _loadout_for_player(player_id)
	if not bool(mode_rule.get("buffs_enabled", false)):
		loadout.clear()
		_loadouts_by_player[player_id] = loadout
		_activation_state_by_player[player_id] = {}
		return
	if bool(mode_rule.get("esports_standardized_buff_enabled", false)):
		loadout.clear()
		_loadouts_by_player[player_id] = loadout
		_activation_state_by_player[player_id] = {}
		return
	if not bool(mode_rule.get("unlimited_buffs", false)):
		var slots: int = _available_slots(player_id)
		while loadout.size() > slots:
			loadout.pop_back()
	_loadouts_by_player[player_id] = loadout

func _reset_all_activation_state() -> void:
	for player_id_any in _activation_state_by_player.keys():
		_activation_state_by_player[player_id_any] = {}

func _players_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for player_id_any in _wallets_by_player.keys():
		var player_id: String = str(player_id_any)
		out[player_id] = get_player_snapshot(player_id)
	return out

func _mode_rule() -> Dictionary:
	return _config.rule_for_mode(_current_mode_key)

func _error(code: String, message: String) -> Dictionary:
	var payload: Dictionary = {"ok": false, "code": code, "message": message}
	validation_failed.emit(payload)
	SFLog.info("BUFF_RULES", {"validation_error": code, "message": message})
	return payload

func _non_empty_count(loadout: Array[String]) -> int:
	var count: int = 0
	for buff_id_any in loadout:
		if str(buff_id_any).strip_edges() != "":
			count += 1
	return count

func _bootstrap_local_player() -> void:
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager == null:
		_ensure_player("local_player")
		return
	if profile_manager.has_method("ensure_loaded"):
		profile_manager.call("ensure_loaded")
	var local_id: String = ""
	if profile_manager.has_method("get_user_id"):
		local_id = str(profile_manager.call("get_user_id")).strip_edges()
	if local_id == "":
		local_id = "local_player"
	_ensure_player(local_id)

func _emit_changed() -> void:
	economy_state_changed.emit(get_state_snapshot())

func _load_config() -> void:
	var config_any: Variant = load(CONFIG_PATH)
	if config_any is ModeRulesConfigScript:
		_config = config_any as ModeRulesConfigScript
	else:
		_config = ModeRulesConfigScript.new()
	_current_mode_key = _config.normalized_mode(_current_mode_key)

func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed_any: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed_any) != TYPE_DICTIONARY:
		return
	var parsed: Dictionary = parsed_any as Dictionary
	_current_mode_key = _config.normalized_mode(str(parsed.get("current_mode_key", _config.default_mode_key)))
	_overtime_active = bool(parsed.get("overtime_active", false))
	_wallets_by_player = _load_player_dictionary(parsed.get("wallets_by_player", {}))
	_loadouts_by_player = _load_player_dictionary(parsed.get("loadouts_by_player", {}))
	_unlocked_additional_slots_by_player = _load_player_dictionary(parsed.get("unlocked_additional_slots_by_player", {}))
	_activation_state_by_player = _load_player_dictionary(parsed.get("activation_state_by_player", {}))

func _save_state() -> void:
	var payload: Dictionary = {
		"current_mode_key": _current_mode_key,
		"overtime_active": _overtime_active,
		"wallets_by_player": _wallets_by_player,
		"loadouts_by_player": _loadouts_by_player,
		"unlocked_additional_slots_by_player": _unlocked_additional_slots_by_player,
		"activation_state_by_player": _activation_state_by_player
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _load_player_dictionary(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
