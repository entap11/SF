class_name BuffState
extends RefCounted

const TIER_CLASSIC := "classic"
const TIER_PREMIUM := "premium"
const TIER_ELITE := "elite"

const LOADOUT_SIZE := 3
const START_SLOTS := 2
const OVERTIME_SLOTS := 3
const MAX_ELITE_PER_MATCH := 1
const MAX_PREMIUM_PER_MATCH := 1

const DURATION_SEC := {
	TIER_CLASSIC: 10.0,
	TIER_PREMIUM: 15.0,
	TIER_ELITE: 20.0
}

const PRICE_TIER_1 := {
	TIER_CLASSIC: 0.10,
	TIER_PREMIUM: 0.15,
	TIER_ELITE: 0.20
}

const PRICE_TIER_2 := {
	TIER_CLASSIC: 0.25,
	TIER_PREMIUM: 0.30,
	TIER_ELITE: 0.35
}

const PRICE_TIER_3 := {
	TIER_CLASSIC: 0.40,
	TIER_PREMIUM: 0.45,
	TIER_ELITE: 0.50
}

var loadout: Array = []
var slots: Array = []
var slots_active: int = START_SLOTS
var tap_to_top_enabled: bool = false

func configure_loadout(entries: Array) -> Dictionary:
	if entries.size() != LOADOUT_SIZE:
		return {"ok": false, "error": "Loadout must have %d buffs" % LOADOUT_SIZE}
	var elite_count: int = 0
	var premium_count: int = 0
	var new_slots: Array = []
	for entry_v in entries:
		if typeof(entry_v) != TYPE_DICTIONARY:
			return {"ok": false, "error": "Loadout entry is not a Dictionary"}
		var entry: Dictionary = entry_v
		var buff_id: String = str(entry.get("id", "")).strip_edges()
		if buff_id == "":
			return {"ok": false, "error": "Loadout entry missing id"}
		var tier: String = str(entry.get("tier", TIER_CLASSIC)).to_lower()
		if tier == TIER_PREMIUM:
			premium_count += 1
		elif tier == TIER_ELITE:
			elite_count += 1
		else:
			tier = TIER_CLASSIC
		new_slots.append({
			"id": buff_id,
			"tier": tier,
			"active": false,
			"consumed": false,
			"ends_ms": 0
		})
	if elite_count > MAX_ELITE_PER_MATCH:
		return {"ok": false, "error": "Loadout exceeds elite limit"}
	if premium_count > MAX_PREMIUM_PER_MATCH:
		return {"ok": false, "error": "Loadout exceeds premium limit"}
	loadout = entries
	slots = new_slots
	slots_active = min(START_SLOTS, slots.size())
	tap_to_top_enabled = false
	return {"ok": true}

func reset_for_match() -> void:
	slots_active = min(START_SLOTS, slots.size())
	tap_to_top_enabled = false
	for i in range(slots.size()):
		var slot: Dictionary = slots[i]
		slot["active"] = false
		slot["consumed"] = false
		slot["ends_ms"] = 0
		slots[i] = slot

func unlock_third_slot() -> void:
	slots_active = min(OVERTIME_SLOTS, slots.size())

func enable_tap_to_top() -> void:
	tap_to_top_enabled = true

func is_slot_active(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	return bool(slots[slot_index].get("active", false))

func is_slot_consumed(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	return bool(slots[slot_index].get("consumed", false))

func can_activate_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	if slot_index >= slots_active:
		return false
	var slot: Dictionary = slots[slot_index]
	if bool(slot.get("active", false)):
		return false
	if bool(slot.get("consumed", false)):
		return false
	return true

func activate_slot(slot_index: int, now_ms: int) -> bool:
	if not can_activate_slot(slot_index):
		return false
	var slot: Dictionary = slots[slot_index]
	var tier: String = str(slot.get("tier", TIER_CLASSIC)).to_lower()
	var duration_sec: float = float(DURATION_SEC.get(tier, DURATION_SEC[TIER_CLASSIC]))
	slot["active"] = true
	slot["ends_ms"] = now_ms + int(round(duration_sec * 1000.0))
	slots[slot_index] = slot
	return true

func update(now_ms: int) -> void:
	for i in range(slots.size()):
		var slot: Dictionary = slots[i]
		if bool(slot.get("active", false)) and int(slot.get("ends_ms", 0)) <= now_ms:
			slot["active"] = false
			slot["consumed"] = true
			slots[i] = slot

func refill_slot(slot_index: int) -> bool:
	if not tap_to_top_enabled:
		return false
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var slot: Dictionary = slots[slot_index]
	if not bool(slot.get("consumed", false)):
		return false
	slot["consumed"] = false
	slots[slot_index] = slot
	return true

static func duration_sec_for_tier(tier: String) -> float:
	return float(DURATION_SEC.get(tier.to_lower(), DURATION_SEC[TIER_CLASSIC]))

static func price_for(tier_level: int, tier: String) -> float:
	var table: Dictionary = PRICE_TIER_1
	if tier_level == 2:
		table = PRICE_TIER_2
	elif tier_level == 3:
		table = PRICE_TIER_3
	return float(table.get(tier.to_lower(), table[TIER_CLASSIC]))
