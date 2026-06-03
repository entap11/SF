class_name MatchSetupRandomizer
extends RefCounted

const CONTEXT_KEY: String = "match_randomizer"
const TREE_META_KEY: String = "vs_match_randomizer"
const RANDOMIZER_CHANCE: float = 0.10
const CATEGORY_CHANCE: float = 0.33
const BOTH_STRUCTURE_TYPES_CHANCE: float = 0.15
const POWER_VALUES: Array[int] = [5, 15, 20, 25]
const CATEGORY_HIVE_START_POWER: String = "hive_start_power"
const CATEGORY_TOWER_POWER: String = "tower_power"
const CATEGORY_BARRACKS_POWER: String = "barracks_power"
const CATEGORY_STRUCTURE_POWER: String = CATEGORY_TOWER_POWER
const CATEGORY_NPC_HIVE_POWER: String = "npc_hive_power"
const CATEGORY_ORDER: Array[String] = [
	CATEGORY_HIVE_START_POWER,
	CATEGORY_TOWER_POWER,
	CATEGORY_BARRACKS_POWER,
	CATEGORY_NPC_HIVE_POWER
]

static func roll(rng: RandomNumberGenerator) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var seed: int = _positive_seed(rng.randi())
	if rng.randf() > RANDOMIZER_CHANCE:
		return {
			"version": 1,
			"hit": false,
			"seed": seed,
			"chance": RANDOMIZER_CHANCE,
			"category_chance": CATEGORY_CHANCE,
			"categories": {}
		}
	var categories: Dictionary = {}
	for category in CATEGORY_ORDER:
		if rng.randf() <= CATEGORY_CHANCE:
			categories[category] = _random_power_value(rng)
	if categories.is_empty():
		var fallback_category: String = CATEGORY_ORDER[rng.randi_range(0, CATEGORY_ORDER.size() - 1)]
		categories[fallback_category] = _random_power_value(rng)
	_limit_dual_structure_categories(categories, rng)
	var payload: Dictionary = {
		"version": 1,
		"hit": true,
		"seed": seed,
		"chance": RANDOMIZER_CHANCE,
		"category_chance": CATEGORY_CHANCE,
		"categories": categories
	}
	_add_structure_payload(payload, categories)
	payload["description"] = description(payload)
	return payload

static func description(payload: Dictionary) -> String:
	if not bool(payload.get("hit", false)):
		return ""
	var categories_v: Variant = payload.get("categories", {})
	if typeof(categories_v) != TYPE_DICTIONARY:
		return ""
	var categories: Dictionary = categories_v as Dictionary
	var parts: Array[String] = []
	if categories.has(CATEGORY_HIVE_START_POWER):
		parts.append("hive start %d" % int(categories.get(CATEGORY_HIVE_START_POWER, 0)))
	if categories.has(CATEGORY_TOWER_POWER):
		parts.append("towers %d" % int(categories.get(CATEGORY_TOWER_POWER, 0)))
	if categories.has(CATEGORY_BARRACKS_POWER):
		parts.append("barracks %d" % int(categories.get(CATEGORY_BARRACKS_POWER, 0)))
	if categories.has(CATEGORY_NPC_HIVE_POWER):
		parts.append("NPC hives %d" % int(categories.get(CATEGORY_NPC_HIVE_POWER, 0)))
	if parts.is_empty():
		return ""
	return "Randomized: %s." % ", ".join(parts)

static func apply_start_slots(map_data: Dictionary, payload: Dictionary, active_seats: Array) -> Dictionary:
	if map_data.is_empty():
		return map_data
	var start_slots: Array = _start_slot_ids(map_data)
	if start_slots.size() < 2:
		return map_data
	var seats: Array = _active_player_seats(active_seats)
	if seats.is_empty():
		return map_data
	var out: Dictionary = map_data.duplicate(true)
	var hives_v: Variant = out.get("hives", [])
	if typeof(hives_v) != TYPE_ARRAY:
		return map_data
	var hives: Array = hives_v as Array
	var hives_by_id: Dictionary = {}
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		hives_by_id[int(hive.get("id", 0))] = hive
	var valid_slots: Array = []
	for slot_id_any in start_slots:
		var slot_id: int = int(slot_id_any)
		if hives_by_id.has(slot_id) and not valid_slots.has(slot_id):
			valid_slots.append(slot_id)
	if valid_slots.size() < 2:
		return map_data
	for slot_id_any in valid_slots:
		var hive: Dictionary = hives_by_id[int(slot_id_any)] as Dictionary
		_set_hive_owner_id(hive, 0)
	var seed: int = _payload_seed(payload)
	if seed <= 0:
		seed = _stable_positive_hash("%s|%s" % [str(out.get("id", out.get("map_id", ""))), str(seats)])
	var shuffled_slots: Array = valid_slots.duplicate()
	_shuffle_ints(shuffled_slots, seed)
	var assign_count: int = mini(seats.size(), shuffled_slots.size())
	var assignments: Array = []
	for i in range(assign_count):
		var hive_id: int = int(shuffled_slots[i])
		var seat: int = int(seats[i])
		var assigned_hive: Dictionary = hives_by_id[hive_id] as Dictionary
		_set_hive_owner_id(assigned_hive, seat)
		assignments.append({"seat": seat, "hive_id": hive_id})
	out["hives"] = hives
	out["start_slot_assignment"] = {
		"seed": seed,
		"active_seats": seats,
		"assignments": assignments,
		"start_slots": valid_slots
	}
	return out

static func should_randomize_start_slots(payload: Dictionary) -> bool:
	return bool(payload.get("randomize_start_slots", false))

static func apply_to_map_data(map_data: Dictionary, payload: Dictionary) -> Dictionary:
	if map_data.is_empty() or not bool(payload.get("hit", false)):
		return map_data
	var categories_v: Variant = payload.get("categories", {})
	if typeof(categories_v) != TYPE_DICTIONARY:
		return map_data
	var categories: Dictionary = categories_v as Dictionary
	if categories.is_empty():
		return map_data
	var out: Dictionary = map_data.duplicate(true)
	if categories.has(CATEGORY_HIVE_START_POWER):
		_set_hive_power(out, true, int(categories.get(CATEGORY_HIVE_START_POWER, 0)))
	if categories.has(CATEGORY_NPC_HIVE_POWER):
		_set_hive_power(out, false, int(categories.get(CATEGORY_NPC_HIVE_POWER, 0)))
	if categories.has(CATEGORY_TOWER_POWER) or categories.has(CATEGORY_BARRACKS_POWER):
		_populate_structure_slots(out, payload, categories)
		if categories.has(CATEGORY_TOWER_POWER):
			_set_structure_power(out, "towers", int(categories.get(CATEGORY_TOWER_POWER, 0)))
		if categories.has(CATEGORY_BARRACKS_POWER):
			_set_structure_power(out, "barracks", int(categories.get(CATEGORY_BARRACKS_POWER, 0)))
	out[CONTEXT_KEY] = payload.duplicate(true)
	return out

static func _random_power_value(rng: RandomNumberGenerator) -> int:
	return POWER_VALUES[rng.randi_range(0, POWER_VALUES.size() - 1)]

static func _limit_dual_structure_categories(categories: Dictionary, rng: RandomNumberGenerator) -> void:
	if not categories.has(CATEGORY_TOWER_POWER) or not categories.has(CATEGORY_BARRACKS_POWER):
		return
	if rng.randf() <= BOTH_STRUCTURE_TYPES_CHANCE:
		return
	if rng.randi_range(0, 1) == 0:
		categories.erase(CATEGORY_BARRACKS_POWER)
	else:
		categories.erase(CATEGORY_TOWER_POWER)

static func _add_structure_payload(payload: Dictionary, categories: Dictionary) -> void:
	var has_towers: bool = categories.has(CATEGORY_TOWER_POWER)
	var has_barracks: bool = categories.has(CATEGORY_BARRACKS_POWER)
	if not has_towers and not has_barracks:
		return
	var kind: String = "mixed" if has_towers and has_barracks else ("tower" if has_towers else "barracks")
	payload["structures"] = {
		"kind": kind,
		"slot_policy": "all_slots",
		"allow_towers": has_towers,
		"allow_barracks": has_barracks
	}

static func _positive_seed(value: int) -> int:
	var out: int = abs(value)
	if out == 0:
		out = 1
	return out

static func _payload_seed(payload: Dictionary) -> int:
	if payload.has("start_slot_seed"):
		return _positive_seed(int(payload.get("start_slot_seed", 0)))
	if payload.has("seed"):
		return _positive_seed(int(payload.get("seed", 0)))
	return 0

static func _start_slot_ids(map_data: Dictionary) -> Array:
	var slots_v: Variant = map_data.get("start_slots", [])
	if typeof(slots_v) != TYPE_ARRAY:
		return []
	var out: Array = []
	for slot_any in slots_v as Array:
		var slot_id: int = int(slot_any)
		if slot_id > 0 and not out.has(slot_id):
			out.append(slot_id)
	return out

static func _active_player_seats(active_seats: Array) -> Array:
	var seats: Array = []
	for seat_any in active_seats:
		var seat: int = int(seat_any)
		if seat >= 1 and seat <= 4 and not seats.has(seat):
			seats.append(seat)
	seats.sort()
	return seats

static func _shuffle_ints(values: Array, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _positive_seed(seed)
	for i in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = values[i]
		values[i] = values[j]
		values[j] = tmp

static func _stable_positive_hash(text: String) -> int:
	var h: int = 17
	for i in range(text.length()):
		h = int((h * 31 + text.unicode_at(i)) % 2147483647)
	return maxi(1, h)

static func _set_hive_owner_id(hive: Dictionary, owner_id: int) -> void:
	hive["owner_id"] = owner_id
	if hive.has("owner"):
		hive["owner"] = "P%d" % owner_id if owner_id > 0 else "NPC"

static func _set_hive_power(map_data: Dictionary, player_owned: bool, power_raw: int) -> void:
	var power: int = clampi(power_raw, 1, 50)
	var hives_v: Variant = map_data.get("hives", [])
	if typeof(hives_v) != TYPE_ARRAY:
		return
	var hives: Array = hives_v as Array
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		var owner_id: int = int(hive.get("owner_id", hive.get("owner", 0)))
		if player_owned and owner_id <= 0:
			continue
		if not player_owned and owner_id > 0:
			continue
		hive["power"] = power
		if hive.has("pwr"):
			hive["pwr"] = power
	map_data["hives"] = hives

static func _set_structure_power(map_data: Dictionary, key: String, power_raw: int) -> void:
	var power: int = clampi(power_raw, 1, 50)
	var structures_v: Variant = map_data.get(key, [])
	if typeof(structures_v) != TYPE_ARRAY:
		return
	var structures: Array = structures_v as Array
	for structure_any in structures:
		if typeof(structure_any) != TYPE_DICTIONARY:
			continue
		var structure: Dictionary = structure_any as Dictionary
		structure["power"] = power
		structure["current_power"] = power
	map_data[key] = structures

static func _populate_structure_slots(map_data: Dictionary, payload: Dictionary, categories: Dictionary) -> void:
	var slots_v: Variant = map_data.get("structure_slots", [])
	if typeof(slots_v) != TYPE_ARRAY:
		return
	var slots: Array = slots_v as Array
	if slots.is_empty():
		return
	var desired_kind: String = _structure_kind_from_payload(payload)
	var towers: Array = []
	var barracks: Array = []
	var next_tower_id: int = 1
	var next_barracks_id: int = 1
	for slot_index in range(slots.size()):
		var slot_any: Variant = slots[slot_index]
		if typeof(slot_any) != TYPE_DICTIONARY:
			continue
		var slot: Dictionary = slot_any as Dictionary
		var kind: String = _structure_kind_for_slot(slot, desired_kind, _payload_seed(payload), slot_index)
		if kind.is_empty():
			continue
		var gp: Array = _slot_grid_pos(slot)
		if gp.is_empty():
			continue
		var power: int = int(categories.get(CATEGORY_TOWER_POWER if kind == "tower" else CATEGORY_BARRACKS_POWER, 0))
		if power <= 0:
			continue
		power = clampi(power, 1, 50)
		var structure: Dictionary = {
			"id": next_tower_id if kind == "tower" else next_barracks_id,
			"grid_pos": gp,
			"required_hive_ids": _slot_int_list(slot.get("required_hive_ids", [])),
			"control_hive_ids": _slot_int_list(slot.get("control_hive_ids", [])),
			"owner_id": int(slot.get("owner_id", 0)),
			"power": power,
			"current_power": power
		}
		if kind == "tower":
			towers.append(structure)
			next_tower_id += 1
		elif kind == "barracks":
			barracks.append(structure)
			next_barracks_id += 1
	map_data["towers"] = towers
	map_data["barracks"] = barracks

static func _structure_kind_from_payload(payload: Dictionary) -> String:
	var structures_v: Variant = payload.get("structures", {})
	if typeof(structures_v) == TYPE_DICTIONARY:
		var structures: Dictionary = structures_v as Dictionary
		var kind: String = str(structures.get("kind", "")).strip_edges().to_lower()
		if kind == "tower" or kind == "barracks" or kind == "mixed":
			return kind
	return "tower"

static func _structure_kind_for_slot(slot: Dictionary, desired_kind: String, seed: int = 0, slot_index: int = 0) -> String:
	var allowed: Array = []
	var allowed_v: Variant = slot.get("allowed", ["tower", "barracks"])
	if typeof(allowed_v) == TYPE_ARRAY:
		for kind_any in allowed_v as Array:
			var kind: String = str(kind_any).strip_edges().to_lower()
			if (kind == "tower" or kind == "barracks") and not allowed.has(kind):
				allowed.append(kind)
	if allowed.is_empty():
		allowed = ["tower", "barracks"]
	if desired_kind == "mixed":
		if allowed.size() == 1:
			return str(allowed[0])
		var slot_key: String = "%d|%d|%s|%s" % [seed, slot_index, str(slot.get("id", "")), str(slot.get("grid_pos", slot.get("pos", [])))]
		var idx: int = _stable_positive_hash(slot_key) % allowed.size()
		return str(allowed[idx])
	if allowed.has(desired_kind):
		return desired_kind
	return str(allowed[0])

static func _slot_grid_pos(slot: Dictionary) -> Array:
	var gp_v: Variant = slot.get("grid_pos", null)
	if typeof(gp_v) == TYPE_ARRAY:
		var gp: Array = gp_v as Array
		if gp.size() >= 2:
			return [int(gp[0]), int(gp[1])]
	var pos_v: Variant = slot.get("pos", null)
	if typeof(pos_v) == TYPE_DICTIONARY:
		var pos: Dictionary = pos_v as Dictionary
		return [int(pos.get("x", pos.get("gx", -1))), int(pos.get("y", pos.get("gy", -1)))]
	if slot.has("x") and slot.has("y"):
		return [int(slot.get("x", -1)), int(slot.get("y", -1))]
	return []

static func _slot_int_list(values_v: Variant) -> Array:
	var out: Array = []
	if typeof(values_v) != TYPE_ARRAY:
		return out
	for value_any in values_v as Array:
		var value: int = int(value_any)
		if value > 0 and not out.has(value):
			out.append(value)
	return out
