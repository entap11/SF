# Authoritative fixed-tick buff effect state. This system is the only gameplay
# interpreter for buff commands; Arena and UI consume its snapshots.
class_name AuthoritativeBuffSystem
extends RefCounted

const BuffDefinitions := preload("res://scripts/state/buff_definitions.gd")
const BuffCatalog := preload("res://scripts/state/buff_catalog.gd")

const TICKS_PER_SECOND: int = 10
const MAX_OUTCOME_HISTORY: int = 128
const TARGET_GLOBAL: String = "global"

static func activate(state: GameState, command: Dictionary) -> Dictionary:
	if state == null:
		return _reject(command, "missing_game_state")
	var owner_id: int = int(command.get("owner_id", 0))
	var activation_id: String = str(command.get("activation_id", "")).strip_edges()
	if owner_id <= 0:
		return _reject(command, "invalid_owner")
	if activation_id.is_empty():
		return _reject(command, "missing_activation_id")
	var outcome_key: String = _outcome_key(owner_id, activation_id)
	if state.buff_outcomes_by_activation_id.has(outcome_key):
		var prior: Dictionary = (state.buff_outcomes_by_activation_id.get(outcome_key, {}) as Dictionary).duplicate(true)
		prior["duplicate"] = true
		return prior
	if state.buff_outcomes_by_activation_id.size() >= MAX_OUTCOME_HISTORY:
		return _reject(command, "activation_history_full")
	var match_id: String = str(command.get("match_id", "")).strip_edges()
	if state.buff_match_id.is_empty():
		state.buff_match_id = match_id
	elif not match_id.is_empty() and state.buff_match_id != match_id:
		return _remember_outcome(state, outcome_key, _reject(command, "match_epoch_mismatch"))
	var identity: Dictionary = _identity(str(command.get("buff_id", "")))
	if not bool(identity.get("ok", false)):
		return _remember_outcome(state, outcome_key, _reject(command, str(identity.get("reason", "unknown_buff"))))
	var buff_id: String = str(identity.get("canonical_id", ""))
	var category: String = BuffDefinitions.category_for(buff_id)
	var target_type: String = BuffDefinitions.target_type_for(buff_id)
	if target_type == BuffDefinitions.TARGET_NONE:
		target_type = TARGET_GLOBAL
	var submitted_target_type: String = str(command.get("target_type", TARGET_GLOBAL)).strip_edges().to_lower()
	if submitted_target_type == BuffDefinitions.TARGET_NONE:
		submitted_target_type = TARGET_GLOBAL
	if submitted_target_type != target_type:
		return _remember_outcome(state, outcome_key, _reject(command, "target_type_mismatch"))
	var target_result: Dictionary = _resolve_target(state, owner_id, buff_id, target_type, command.get("target_id", null))
	if not bool(target_result.get("ok", false)):
		return _remember_outcome(state, outcome_key, _reject(command, str(target_result.get("reason", "target_ineligible"))))
	var current_tick: int = int(state.tick)
	var chill_until_tick: int = int(state.buff_chill_until_tick_by_owner.get(owner_id, 0))
	if current_tick < chill_until_tick:
		return _remember_outcome(state, outcome_key, _reject(command, "global_chill_active"))
	var tier: String = BuffDefinitions.normalize_tier(str(command.get("tier", BuffDefinitions.TIER_CLASSIC)))
	var duration_ticks: int = maxi(1, int(round(BuffDefinitions.duration_seconds_for(buff_id, tier) * float(TICKS_PER_SECOND))))
	var effect: Dictionary = {
		"activation_id": activation_id,
		"match_id": match_id,
		"owner_id": owner_id,
		"buff_id": buff_id,
		"inventory_buff_id": str(command.get("buff_id", "")),
		"tier": tier,
		"category": category,
		"target_type": target_type,
		"target_id": target_result.get("target_id", TARGET_GLOBAL),
		"target": target_result.get("target", {}) as Dictionary,
		"scoped_hive_ids": target_result.get("scoped_hive_ids", []) as Array,
		"started_tick": current_tick,
		"expires_tick": current_tick + duration_ticks,
		"duration_ticks": duration_ticks,
		"source_slot_index": int(command.get("source_slot_index", -1)),
		"queued_units": 0,
		"status": "active"
	}
	var category_key: String = _category_key(owner_id, category)
	var replaced_activation_id: String = str(state.buff_active_by_owner_category.get(category_key, ""))
	if not replaced_activation_id.is_empty():
		_expire(state, replaced_activation_id, "replaced", current_tick)
	state.buff_effects_by_activation_id[activation_id] = effect
	state.buff_active_by_owner_category[category_key] = activation_id
	state.buff_chill_until_tick_by_owner[owner_id] = current_tick + int(round(BuffDefinitions.BUFF_CHILL_SECONDS * float(TICKS_PER_SECOND)))
	var outcome: Dictionary = _base_outcome(command)
	outcome.merge({
		"ok": true,
		"status": "executed",
		"reason": "activated",
		"canonical_buff_id": buff_id,
		"execution_tick": current_tick,
		"effect": effect.duplicate(true)
	}, true)
	return _remember_outcome(state, outcome_key, outcome)

static func tick(state: GameState) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state == null or state.buff_effects_by_activation_id.is_empty():
		return events
	var activation_ids: Array = state.buff_effects_by_activation_id.keys()
	activation_ids.sort()
	for activation_any in activation_ids:
		var activation_id: String = str(activation_any)
		var effect_any: Variant = state.buff_effects_by_activation_id.get(activation_id, {})
		if typeof(effect_any) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_any as Dictionary
		var invalid_reason: String = _target_loss_reason(state, effect)
		if not invalid_reason.is_empty():
			events.append(_expire(state, activation_id, invalid_reason, int(state.tick)))
			continue
		if int(state.tick) >= int(effect.get("expires_tick", 0)):
			events.append(_expire(state, activation_id, "timer_expired", int(state.tick)))
	return events

static func snapshot(state: GameState) -> Dictionary:
	if state == null:
		return {}
	var effects: Array = []
	var ids: Array = state.buff_effects_by_activation_id.keys()
	ids.sort()
	for activation_any in ids:
		var effect_any: Variant = state.buff_effects_by_activation_id.get(activation_any, {})
		if typeof(effect_any) == TYPE_DICTIONARY:
			effects.append((effect_any as Dictionary).duplicate(true))
	return {
		"match_id": state.buff_match_id,
		"tick": int(state.tick),
		"effects": effects,
		"active_by_owner_category": state.buff_active_by_owner_category.duplicate(true),
		"chill_until_tick_by_owner": state.buff_chill_until_tick_by_owner.duplicate(true)
	}

static func active_effect(state: GameState, owner_id: int, buff_id: String) -> Dictionary:
	if state == null:
		return {}
	for effect_any in state.buff_effects_by_activation_id.values():
		if typeof(effect_any) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_any as Dictionary
		if int(effect.get("owner_id", 0)) == owner_id and str(effect.get("buff_id", "")) == buff_id:
			return effect
	return {}

static func _identity(requested_id: String) -> Dictionary:
	var clean_id: String = requested_id.strip_edges()
	var catalog: Dictionary = BuffCatalog.get_buff(clean_id)
	if catalog.is_empty() or not BuffCatalog.is_selectable(clean_id):
		return {"ok": false, "reason": "unknown_buff"}
	var canonical_id: String = str(catalog.get("canonical_id", clean_id)).strip_edges().to_upper()
	if not BuffDefinitions.has_definition(canonical_id):
		return {"ok": false, "reason": "unknown_buff"}
	return {"ok": true, "canonical_id": canonical_id}

static func _resolve_target(state: GameState, owner_id: int, buff_id: String, target_type: String, target_id_any: Variant) -> Dictionary:
	if target_type == TARGET_GLOBAL:
		if str(target_id_any).strip_edges().to_lower() != TARGET_GLOBAL:
			return {"ok": false, "reason": "target_ineligible"}
		var scoped_hives: Array = []
		for hive_any in state.hives:
			if hive_any is HiveData and int((hive_any as HiveData).owner_id) == owner_id:
				scoped_hives.append(int((hive_any as HiveData).id))
		scoped_hives.sort()
		return {"ok": true, "target_id": TARGET_GLOBAL, "target": {"kind": TARGET_GLOBAL}, "scoped_hive_ids": scoped_hives}
	if target_type == BuffDefinitions.TARGET_HIVE:
		var hive_id: int = int(target_id_any)
		var hive: HiveData = state.find_hive_by_id(hive_id)
		if hive == null or int(hive.owner_id) != owner_id:
			return {"ok": false, "reason": "target_ineligible"}
		return {"ok": true, "target_id": hive_id, "target": {"kind": "hive", "hive_id": hive_id}}
	if target_type == BuffDefinitions.TARGET_LANE:
		var lane_id: int = int(target_id_any)
		var lane: LaneData = _lane_by_id(state, lane_id)
		if lane == null or not _lane_active(lane):
			return {"ok": false, "reason": "target_ineligible"}
		var target: Dictionary = {"kind": "lane", "lane_id": lane_id, "a_id": int(lane.a_id), "b_id": int(lane.b_id)}
		if buff_id == BuffDefinitions.HIVE_SUPERCHARGE_QUEUE:
			var source: Dictionary = _supercharge_source(state, lane, owner_id)
			if not bool(source.get("ok", false)):
				return source
			target.merge(source, true)
		return {"ok": true, "target_id": lane_id, "target": target}
	return {"ok": false, "reason": "unsupported_target_type"}

static func _supercharge_source(state: GameState, lane: LaneData, owner_id: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var a_hive: HiveData = state.find_hive_by_id(int(lane.a_id))
	var b_hive: HiveData = state.find_hive_by_id(int(lane.b_id))
	if bool(lane.send_a) and a_hive != null and int(a_hive.owner_id) == owner_id:
		candidates.append({"source_hive_id": int(lane.a_id), "destination_hive_id": int(lane.b_id), "source_is_a": true})
	if bool(lane.send_b) and b_hive != null and int(b_hive.owner_id) == owner_id:
		candidates.append({"source_hive_id": int(lane.b_id), "destination_hive_id": int(lane.a_id), "source_is_a": false})
	if candidates.is_empty():
		return {"ok": false, "reason": "supercharge_source_missing"}
	if candidates.size() > 1:
		return {"ok": false, "reason": "supercharge_source_ambiguous"}
	var result: Dictionary = candidates[0].duplicate(true)
	result["ok"] = true
	return result

static func _target_loss_reason(state: GameState, effect: Dictionary) -> String:
	var target_type: String = str(effect.get("target_type", TARGET_GLOBAL))
	var owner_id: int = int(effect.get("owner_id", 0))
	if target_type == BuffDefinitions.TARGET_HIVE:
		var hive: HiveData = state.find_hive_by_id(int(effect.get("target_id", -1)))
		return "target_owner_lost" if hive == null or int(hive.owner_id) != owner_id else ""
	if target_type == BuffDefinitions.TARGET_LANE:
		var lane: LaneData = _lane_by_id(state, int(effect.get("target_id", -1)))
		if lane == null or not _lane_active(lane):
			return "target_lane_lost"
		if str(effect.get("buff_id", "")) == BuffDefinitions.HIVE_SUPERCHARGE_QUEUE:
			var target: Dictionary = effect.get("target", {}) as Dictionary
			var source: HiveData = state.find_hive_by_id(int(target.get("source_hive_id", -1)))
			if source == null or int(source.owner_id) != owner_id:
				return "source_hive_lost"
			if bool(target.get("source_is_a", false)) and not bool(lane.send_a):
				return "source_lane_direction_lost"
			if not bool(target.get("source_is_a", false)) and not bool(lane.send_b):
				return "source_lane_direction_lost"
	return ""

static func _expire(state: GameState, activation_id: String, reason: String, at_tick: int) -> Dictionary:
	var effect: Dictionary = (state.buff_effects_by_activation_id.get(activation_id, {}) as Dictionary).duplicate(true)
	if effect.is_empty():
		return {}
	state.buff_effects_by_activation_id.erase(activation_id)
	var category_key: String = _category_key(int(effect.get("owner_id", 0)), str(effect.get("category", "")))
	if str(state.buff_active_by_owner_category.get(category_key, "")) == activation_id:
		state.buff_active_by_owner_category.erase(category_key)
	return {"event": "buff_expired", "activation_id": activation_id, "reason": reason, "tick": at_tick, "effect": effect}

static func _lane_by_id(state: GameState, lane_id: int) -> LaneData:
	for lane_any in state.lanes:
		if lane_any is LaneData and int((lane_any as LaneData).id) == lane_id:
			return lane_any as LaneData
	return null

static func _lane_active(lane: LaneData) -> bool:
	return bool(lane.send_a) or bool(lane.send_b) or bool(lane.establish_a) or bool(lane.establish_b)

static func _base_outcome(command: Dictionary) -> Dictionary:
	return {
		"match_id": str(command.get("match_id", "")),
		"owner_id": int(command.get("owner_id", 0)),
		"activation_id": str(command.get("activation_id", "")),
		"canonical_command_id": str(command.get("command_id", "")),
		"buff_id": str(command.get("buff_id", "")),
		"target_type": str(command.get("target_type", "")),
		"target_id": command.get("target_id", null)
	}

static func _reject(command: Dictionary, reason: String) -> Dictionary:
	var outcome: Dictionary = _base_outcome(command)
	outcome.merge({"ok": false, "status": "deterministic_no_op", "reason": reason}, true)
	return outcome

static func _remember_outcome(state: GameState, outcome_key: String, outcome: Dictionary) -> Dictionary:
	state.buff_outcomes_by_activation_id[outcome_key] = outcome.duplicate(true)
	state.buff_outcome_order.append(outcome_key)
	return outcome

static func _outcome_key(owner_id: int, activation_id: String) -> String:
	return "%d|%s" % [owner_id, activation_id]

static func _category_key(owner_id: int, category: String) -> String:
	return "%d|%s" % [owner_id, category]
