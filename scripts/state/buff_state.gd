class_name BuffState
extends RefCounted

const BuffDefinitions = preload("res://scripts/state/buff_definitions.gd")
const BuffCatalog = preload("res://scripts/state/buff_catalog.gd")

signal buff_state_changed(snapshot: Dictionary)
signal buff_activated(payload: Dictionary)
signal buff_expired(payload: Dictionary)
signal buff_replaced(payload: Dictionary)
signal buff_activation_rejected(payload: Dictionary)
signal supercharge_release_requested(payload: Dictionary)

const LOADOUT_SIZE: int = 3
const START_SLOTS: int = 2
const OVERTIME_SLOTS: int = 3

const TIER_CLASSIC: String = BuffDefinitions.TIER_CLASSIC
const TIER_PREMIUM: String = BuffDefinitions.TIER_PREMIUM
const TIER_ELITE: String = BuffDefinitions.TIER_ELITE

var loadout: Array = []
var slots: Array = []
var slots_active: int = START_SLOTS
var tap_to_top_enabled: bool = false

var _active_by_category: Dictionary = {
	BuffDefinitions.CATEGORY_UNIT: {},
	BuffDefinitions.CATEGORY_HIVE: {},
	BuffDefinitions.CATEGORY_LANE: {}
}
var _buff_chill_timer_sec: float = 0.0
var _buff_category_timers: Dictionary = {
	BuffDefinitions.CATEGORY_UNIT: 0.0,
	BuffDefinitions.CATEGORY_HIVE: 0.0,
	BuffDefinitions.CATEGORY_LANE: 0.0
}
var _last_update_ms: int = 0

func configure_loadout(entries: Array) -> Dictionary:
	if entries.size() != LOADOUT_SIZE:
		return {"ok": false, "error": "Loadout must have %d buffs" % LOADOUT_SIZE}
	var next_slots: Array = []
	for entry_any in entries:
		if typeof(entry_any) != TYPE_DICTIONARY:
			return {"ok": false, "error": "Loadout entry is not a Dictionary"}
		var entry: Dictionary = entry_any as Dictionary
		var buff_id: String = str(entry.get("id", "")).strip_edges()
		if buff_id == "":
			return {"ok": false, "error": "Loadout entry missing id"}
		var canonical_id: String = _canonical_buff_id(buff_id)
		if canonical_id == "":
			return {"ok": false, "error": "Unknown buff id: %s" % buff_id}
		var buff_def: Dictionary = BuffDefinitions.get_definition(canonical_id)
		if buff_def.is_empty():
			return {"ok": false, "error": "Unknown buff id: %s" % buff_id}
		var tier: String = BuffDefinitions.normalize_tier(str(entry.get("tier", TIER_CLASSIC)))
		var target_any: Variant = entry.get("target", {})
		var target: Dictionary = {}
		if typeof(target_any) == TYPE_DICTIONARY:
			target = (target_any as Dictionary).duplicate(true)
		next_slots.append({
			"id": canonical_id,
			"tier": tier,
			"category": BuffDefinitions.category_for(canonical_id),
			"target": target,
			"active": false,
			"consumed": false,
			"ends_ms": 0
		})
	loadout = entries.duplicate(true)
	slots = next_slots
	slots_active = min(START_SLOTS, slots.size())
	tap_to_top_enabled = false
	reset_for_match()
	return {"ok": true}

func reset_for_match() -> void:
	slots_active = min(START_SLOTS, slots.size())
	tap_to_top_enabled = false
	for i in range(slots.size()):
		var slot: Dictionary = slots[i] as Dictionary
		slot["active"] = false
		slot["consumed"] = false
		slot["ends_ms"] = 0
		slots[i] = slot
	_active_by_category[BuffDefinitions.CATEGORY_UNIT] = {}
	_active_by_category[BuffDefinitions.CATEGORY_HIVE] = {}
	_active_by_category[BuffDefinitions.CATEGORY_LANE] = {}
	_buff_chill_timer_sec = 0.0
	_buff_category_timers[BuffDefinitions.CATEGORY_UNIT] = 0.0
	_buff_category_timers[BuffDefinitions.CATEGORY_HIVE] = 0.0
	_buff_category_timers[BuffDefinitions.CATEGORY_LANE] = 0.0
	_last_update_ms = 0
	_emit_state_changed()

func unlock_third_slot() -> void:
	slots_active = min(OVERTIME_SLOTS, slots.size())
	_emit_state_changed()

func enable_tap_to_top() -> void:
	tap_to_top_enabled = true
	_emit_state_changed()

func is_slot_active(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	return bool((slots[slot_index] as Dictionary).get("active", false))

func is_slot_consumed(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	return bool((slots[slot_index] as Dictionary).get("consumed", false))

func can_activate_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	if slot_index >= slots_active:
		return false
	if _buff_chill_timer_sec > 0.0:
		return false
	var slot: Dictionary = slots[slot_index] as Dictionary
	if bool(slot.get("active", false)):
		return false
	if bool(slot.get("consumed", false)):
		return false
	return true

func activate_slot(slot_index: int, now_ms: int, target: Dictionary = {}) -> bool:
	if not can_activate_slot(slot_index):
		return false
	var slot: Dictionary = slots[slot_index] as Dictionary
	var slot_target: Dictionary = {}
	if typeof(slot.get("target", {})) == TYPE_DICTIONARY:
		slot_target = (slot.get("target", {}) as Dictionary).duplicate(true)
	if not target.is_empty():
		slot_target = target.duplicate(true)
	var owner_id: int = int(slot_target.get("owner_id", 1))
	var result: Dictionary = intent_activate_buff(
		owner_id,
		str(slot.get("id", "")),
		str(slot.get("tier", TIER_CLASSIC)),
		slot_target,
		now_ms,
		slot_index
	)
	return bool(result.get("ok", false))

func update(now_ms: int) -> void:
	if _last_update_ms == 0:
		_last_update_ms = now_ms
		_sync_slots_from_active(now_ms)
		_emit_state_changed()
		return
	var delta_ms: int = max(0, now_ms - _last_update_ms)
	_last_update_ms = now_ms
	var delta_sec: float = float(delta_ms) / 1000.0
	if delta_sec <= 0.0:
		_sync_slots_from_active(now_ms)
		_emit_state_changed()
		return
	_buff_chill_timer_sec = max(0.0, _buff_chill_timer_sec - delta_sec)
	for category in BuffDefinitions.supported_categories():
		var category_key: String = str(category)
		var timer_now: float = max(0.0, float(_buff_category_timers.get(category_key, 0.0)) - delta_sec)
		_buff_category_timers[category_key] = timer_now
		if timer_now <= 0.0:
			_expire_category(category_key, "timer_expired", now_ms)
	_sync_slots_from_active(now_ms)
	_emit_state_changed()

func refill_slot(slot_index: int) -> bool:
	if not tap_to_top_enabled:
		return false
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var slot: Dictionary = slots[slot_index] as Dictionary
	if not bool(slot.get("consumed", false)):
		return false
	slot["consumed"] = false
	slots[slot_index] = slot
	_emit_state_changed()
	return true

func intent_activate_buff(
	owner_id: int,
	buff_id: String,
	tier: String,
	target: Dictionary,
	now_ms: int,
	source_slot_index: int = -1
) -> Dictionary:
	var clean_id: String = buff_id.strip_edges()
	if clean_id == "":
		return _reject("missing_buff_id", "Buff id is required.")
	var canonical_id: String = _canonical_buff_id(clean_id)
	if canonical_id == "":
		return _reject("unknown_buff", "Buff id is unknown.")
	var buff_def: Dictionary = BuffDefinitions.get_definition(canonical_id)
	if buff_def.is_empty():
		return _reject("unknown_buff", "Buff id is unknown.")
	var category: String = str(buff_def.get("category", "")).to_lower()
	if category == "":
		return _reject("invalid_category", "Buff category missing.")
	if _buff_chill_timer_sec > 0.0:
		return _reject(
			"global_chill_active",
			"Buff chill active for %.2fs." % _buff_chill_timer_sec,
			{"remaining_sec": _buff_chill_timer_sec}
		)
	var target_type: String = BuffDefinitions.target_type_for(canonical_id)
	if BuffDefinitions.requires_target(canonical_id):
		if target.is_empty():
			return _reject("target_required", "Target is required.", {"target_type": target_type})
		if not _target_payload_matches_type(target_type, target):
			return _reject("invalid_target", "Target payload does not match buff target type.", {"target_type": target_type})
	var normalized_tier: String = BuffDefinitions.normalize_tier(tier)
	var duration_sec: float = BuffDefinitions.duration_seconds_for(canonical_id, normalized_tier)
	if duration_sec <= 0.0:
		return _reject("invalid_duration", "Buff duration is invalid.")

	var active_entry: Dictionary = {
		"id": canonical_id,
		"requested_id": clean_id,
		"owner_id": owner_id,
		"tier": normalized_tier,
		"category": category,
		"target_type": target_type,
		"target": target.duplicate(true),
		"effects": BuffDefinitions.effect_payload_for(canonical_id),
		"duration_sec": duration_sec,
		"remaining_sec": duration_sec,
		"started_ms": now_ms,
		"ends_ms": now_ms + int(round(duration_sec * 1000.0)),
		"source_slot_index": source_slot_index
	}

	if not (_active_by_category.get(category, {}) as Dictionary).is_empty():
		var replaced: Dictionary = (_active_by_category.get(category, {}) as Dictionary).duplicate(true)
		_expire_category(category, "replaced", now_ms)
		buff_replaced.emit({
			"category": category,
			"previous": replaced,
			"next_id": clean_id,
			"at_ms": now_ms
		})

	_active_by_category[category] = active_entry
	_buff_category_timers[category] = duration_sec
	_buff_chill_timer_sec = BuffDefinitions.BUFF_CHILL_SECONDS
	_sync_slots_from_active(now_ms)
	var payload: Dictionary = {
		"ok": true,
		"category": category,
		"active": active_entry.duplicate(true),
		"snapshot": get_runtime_snapshot()
	}
	buff_activated.emit(payload)
	_emit_state_changed()
	return payload

func intent_release_supercharge(owner_id: int, hive_id: int, now_ms: int) -> Dictionary:
	var active_hive_any: Variant = get_active_hive_buff()
	if typeof(active_hive_any) != TYPE_DICTIONARY:
		return _reject("no_active_hive_buff", "No active hive buff.")
	var active_hive: Dictionary = active_hive_any as Dictionary
	if str(active_hive.get("id", "")) != BuffDefinitions.HIVE_SUPERCHARGE_QUEUE:
		return _reject("not_supercharge", "Active hive buff is not supercharge queue.")
	if int(active_hive.get("owner_id", -1)) != owner_id:
		return _reject("not_owner", "Only the activating player can release supercharge.")
	var target_any: Variant = active_hive.get("target", {})
	if typeof(target_any) != TYPE_DICTIONARY:
		return _reject("missing_target", "Supercharge target hive missing.")
	var target: Dictionary = target_any as Dictionary
	if int(target.get("hive_id", -1)) != hive_id:
		return _reject("wrong_hive", "Supercharge release hive mismatch.")
	var event: Dictionary = {
		"ok": true,
		"owner_id": owner_id,
		"hive_id": hive_id,
		"at_ms": now_ms,
		"buff_id": BuffDefinitions.HIVE_SUPERCHARGE_QUEUE
	}
	supercharge_release_requested.emit(event)
	return event

func get_runtime_snapshot() -> Dictionary:
	return {
		"active_unit_buff": get_active_unit_buff(),
		"active_hive_buff": get_active_hive_buff(),
		"active_lane_buff": get_active_lane_buff(),
		"buff_chill_timer": _buff_chill_timer_sec,
		"buff_category_timers": _buff_category_timers.duplicate(true),
		"slots_active": slots_active,
		"tap_to_top_enabled": tap_to_top_enabled,
		"slots": slots.duplicate(true)
	}

func get_active_unit_buff() -> Variant:
	return _active_or_null(BuffDefinitions.CATEGORY_UNIT)

func get_active_hive_buff() -> Variant:
	return _active_or_null(BuffDefinitions.CATEGORY_HIVE)

func get_active_lane_buff() -> Variant:
	return _active_or_null(BuffDefinitions.CATEGORY_LANE)

func get_buff_chill_timer() -> float:
	return _buff_chill_timer_sec

func get_buff_category_timers() -> Dictionary:
	return _buff_category_timers.duplicate(true)

func get_active_for_category(category: String) -> Dictionary:
	var category_key: String = category.strip_edges().to_lower()
	if category_key == "":
		return {}
	var active_any: Variant = _active_by_category.get(category_key, {})
	if typeof(active_any) != TYPE_DICTIONARY:
		return {}
	return (active_any as Dictionary).duplicate(true)

func _active_or_null(category: String) -> Variant:
	var active_any: Variant = _active_by_category.get(category, {})
	if typeof(active_any) != TYPE_DICTIONARY:
		return null
	var active: Dictionary = active_any as Dictionary
	if active.is_empty():
		return null
	return active.duplicate(true)

func _target_payload_matches_type(target_type: String, target: Dictionary) -> bool:
	match target_type:
		BuffDefinitions.TARGET_HIVE:
			return int(target.get("hive_id", -1)) > 0
		BuffDefinitions.TARGET_LANE:
			return int(target.get("lane_id", -1)) > 0
		_:
			return true

func _canonical_buff_id(buff_id: String) -> String:
	var clean_id: String = buff_id.strip_edges()
	if clean_id == "":
		return ""
	var upper_id: String = clean_id.to_upper()
	if BuffDefinitions.has_definition(upper_id):
		return upper_id
	if BuffDefinitions.has_definition(clean_id):
		return clean_id
	var catalog_buff: Dictionary = BuffCatalog.get_buff(clean_id)
	if catalog_buff.is_empty():
		return ""
	var canonical_any: Variant = catalog_buff.get("canonical_id", "")
	var canonical_id: String = str(canonical_any).strip_edges().to_upper()
	if canonical_id != "" and BuffDefinitions.has_definition(canonical_id):
		return canonical_id
	return ""

func _expire_category(category: String, reason: String, now_ms: int) -> void:
	var active_any: Variant = _active_by_category.get(category, {})
	if typeof(active_any) != TYPE_DICTIONARY:
		_active_by_category[category] = {}
		_buff_category_timers[category] = 0.0
		return
	var active: Dictionary = active_any as Dictionary
	if active.is_empty():
		_active_by_category[category] = {}
		_buff_category_timers[category] = 0.0
		return
	var slot_index: int = int(active.get("source_slot_index", -1))
	if slot_index >= 0 and slot_index < slots.size():
		var slot: Dictionary = slots[slot_index] as Dictionary
		slot["active"] = false
		slot["consumed"] = true
		slot["ends_ms"] = now_ms
		slots[slot_index] = slot
	_active_by_category[category] = {}
	_buff_category_timers[category] = 0.0
	buff_expired.emit({
		"category": category,
		"reason": reason,
		"buff": active.duplicate(true),
		"at_ms": now_ms
	})

func _sync_slots_from_active(now_ms: int) -> void:
	for i in range(slots.size()):
		var slot: Dictionary = slots[i] as Dictionary
		slot["active"] = false
		slot["ends_ms"] = 0
		slots[i] = slot
	for category in BuffDefinitions.supported_categories():
		var category_key: String = str(category)
		var active_any: Variant = _active_by_category.get(category_key, {})
		if typeof(active_any) != TYPE_DICTIONARY:
			continue
		var active: Dictionary = active_any as Dictionary
		if active.is_empty():
			continue
		var slot_index: int = int(active.get("source_slot_index", -1))
		if slot_index < 0 or slot_index >= slots.size():
			continue
		var slot: Dictionary = slots[slot_index] as Dictionary
		slot["active"] = true
		slot["consumed"] = false
		slot["ends_ms"] = int(active.get("ends_ms", now_ms))
		slots[slot_index] = slot

func _reject(code: String, message: String, extra: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = {
		"ok": false,
		"code": code,
		"message": message,
		"snapshot": get_runtime_snapshot()
	}
	for key_any in extra.keys():
		payload[key_any] = extra.get(key_any)
	buff_activation_rejected.emit(payload)
	return payload

func _emit_state_changed() -> void:
	buff_state_changed.emit(get_runtime_snapshot())

static func duration_sec_for_tier(tier: String) -> float:
	return BuffDefinitions.duration_seconds_for(BuffDefinitions.UNIT_SWARM_DAMAGE, tier)

static func price_for(_tier_level: int, tier: String) -> float:
	var normalized_tier: String = BuffDefinitions.normalize_tier(tier)
	if normalized_tier == BuffDefinitions.TIER_PREMIUM:
		return 0.35
	if normalized_tier == BuffDefinitions.TIER_ELITE:
		return 0.50
	return 0.20
