class_name MapModeRules
extends RefCounted

const HIDDEN_CTF_ALLOTMENT_ROLL: String = "roll"
const HIDDEN_CTF_ALLOTMENT_PATTERNS: Array[String] = [
	"left_right",
	"top_bottom",
	"diagonal_down",
	"diagonal_up",
	"checkerboard",
	"shuffle"
]
const CAPTURE_FLAG_CENTER_NEUTRAL_MIN_HIVES: int = 8
const CAPTURE_FLAG_CENTER_NEUTRAL_MAX_COUNT: int = 4

static func map_supports_game_mode(map_data: Dictionary, mode_id: String) -> Dictionary:
	var clean_mode: String = _normalize_mode_id(mode_id)
	var is_3p_game: bool = clean_mode == "3P_FFA" or clean_mode == "3P"
	var has_3p_bucket: bool = _map_has_player_bucket(map_data, "3P") or _map_has_player_bucket(map_data, "3P_FFA")
	if is_3p_game:
		if not has_3p_bucket:
			return {"ok": false, "reason": "requires_3p_map"}
		return {"ok": true, "reason": ""}
	if has_3p_bucket:
		return {"ok": false, "reason": "3p_map_requires_3p_mode"}
	if bool(map_data.get("strict_player_buckets", false)):
		var required_bucket: String = _required_player_bucket_for_mode(clean_mode)
		if not required_bucket.is_empty() and not _map_has_player_bucket(map_data, required_bucket):
			return {
				"ok": false,
				"reason": "requires_%s_map" % required_bucket.to_lower()
			}
	if clean_mode == "HIDDEN_CAPTURE_FLAG":
		var hidden_summary: Dictionary = hidden_capture_flag_split_summary(map_data)
		if not bool(hidden_summary.get("ok", false)):
			return {
				"ok": false,
				"reason": "hidden_ctf_%s" % str(hidden_summary.get("reason", "invalid"))
			}
	return {"ok": true, "reason": ""}

static func active_owner_contract_for_mode(mode_id: String) -> Dictionary:
	var clean_mode: String = _normalize_mode_id(mode_id)
	match clean_mode:
		"1V1", "PVP", "1P":
			return {
				"ok": true,
				"required_owners": [1, 2],
				"forbidden_owners": [3, 4],
				"reason": ""
			}
		"2V2", "2P":
			return {
				"ok": true,
				"required_owners": [1, 2, 3, 4],
				"forbidden_owners": [],
				"reason": ""
			}
		"3P_FFA", "3P":
			return {
				"ok": true,
				"required_owners": [1, 2, 3],
				"forbidden_owners": [4],
				"reason": ""
			}
		"4P_FFA", "4P":
			return {
				"ok": true,
				"required_owners": [1, 2, 3, 4],
				"forbidden_owners": [],
				"reason": ""
			}
		_:
			return {"ok": false, "required_owners": [], "forbidden_owners": [], "reason": "no_owner_contract"}

static func map_matches_active_owner_contract(map_data: Dictionary, mode_id: String) -> Dictionary:
	var contract: Dictionary = active_owner_contract_for_mode(mode_id)
	if not bool(contract.get("ok", false)):
		return {"ok": true, "reason": ""}
	var counts: Dictionary = _owner_counts_for_map(map_data)
	for owner_any in contract.get("required_owners", []) as Array:
		var owner_id: int = int(owner_any)
		if int(counts.get(owner_id, 0)) <= 0:
			return {
				"ok": false,
				"reason": "missing_owner_%d" % owner_id,
				"owner_counts": counts
			}
	for owner_any in contract.get("forbidden_owners", []) as Array:
		var owner_id: int = int(owner_any)
		if int(counts.get(owner_id, 0)) > 0:
			return {
				"ok": false,
				"reason": "forbidden_owner_%d" % owner_id,
				"owner_counts": counts
			}
	return {"ok": true, "reason": "", "owner_counts": counts}

static func hidden_capture_flag_split_summary(map_data: Dictionary) -> Dictionary:
	var hives_v: Variant = map_data.get("hives", [])
	if typeof(hives_v) != TYPE_ARRAY:
		return {"ok": false, "reason": "missing_hives", "owner_counts": {}}
	var hives: Array = _valid_hive_dicts(hives_v as Array)
	if hives.size() < 4:
		return {"ok": false, "reason": "too_few_hives", "owner_counts": {}}
	var neutral_count: int = _capture_flag_center_neutral_target_count(hives.size())
	var owned_count: int = maxi(0, hives.size() - neutral_count)
	var p1_count: int = int(ceil(float(owned_count) * 0.5))
	var p2_count: int = owned_count - p1_count
	return {
		"ok": true,
		"reason": "",
		"owner_counts": {1: p1_count, 2: p2_count, 0: neutral_count},
		"total_hives": hives.size()
	}

static func apply_capture_flag_territory_split(map_data: Dictionary, options: Dictionary = {}) -> Dictionary:
	var out: Dictionary = map_data.duplicate(true)
	var hives_v: Variant = out.get("hives", [])
	if typeof(hives_v) != TYPE_ARRAY:
		return out
	var hives: Array = hives_v as Array
	var candidates: Array = _valid_hive_dicts(hives)
	if candidates.size() < 4:
		return out
	var p1_center: Vector2 = _owner_centroid_or_extreme(candidates, 1, true)
	var p2_center: Vector2 = _owner_centroid_or_extreme(candidates, 2, false)
	var axis: Vector2 = p2_center - p1_center
	if axis.length_squared() <= 0.0001:
		axis = _widest_map_axis(candidates)
	if axis.length_squared() <= 0.0001:
		axis = Vector2.RIGHT
	axis = axis.normalized()
	var midpoint: Vector2 = (p1_center + p2_center) * 0.5
	var neutral_lookup: Dictionary = _capture_flag_center_neutral_lookup(candidates, midpoint, axis)
	for hive_any in candidates:
		var hive: Dictionary = hive_any as Dictionary
		var hive_id: String = _hive_id_sort_key(hive)
		if neutral_lookup.has(hive_id):
			_set_hive_owner(hive, 0)
			continue
		var projection: float = (_hive_pos(hive) - midpoint).dot(axis)
		if is_equal_approx(projection, 0.0):
			var d1: float = _hive_pos(hive).distance_squared_to(p1_center)
			var d2: float = _hive_pos(hive).distance_squared_to(p2_center)
			_set_hive_owner(hive, 1 if d1 <= d2 else 2)
		else:
			_set_hive_owner(hive, 1 if projection < 0.0 else 2)
	out["hives"] = hives
	out["capture_flag_territory_split"] = {
		"owner_counts": _owner_counts_for_hives(hives),
		"neutral_count": int(neutral_lookup.size()),
		"mode": str(options.get("mode", "CAPTURE_FLAG"))
	}
	return out

static func apply_hidden_capture_flag_owner_split(map_data: Dictionary, options: Dictionary = {}) -> Dictionary:
	var out: Dictionary = map_data.duplicate(true)
	var hives_v: Variant = out.get("hives", [])
	if typeof(hives_v) != TYPE_ARRAY:
		return out
	var hives: Array = hives_v as Array
	var split: Dictionary = _hidden_capture_flag_split(hives, out, options)
	for hive_any in split.get("p1", []) as Array:
		_set_hive_owner(hive_any as Dictionary, 1)
	for hive_any in split.get("p2", []) as Array:
		_set_hive_owner(hive_any as Dictionary, 2)
	out["hives"] = hives
	out["hidden_ctf_owner_split"] = {
		"no_npc": true,
		"owner_counts": _owner_counts_for_hives(hives),
		"pattern": str(split.get("pattern", "")),
		"seed": int(split.get("seed", 0))
	}
	return out

static func _hidden_capture_flag_split(hives: Array, map_data: Dictionary, options: Dictionary = {}) -> Dictionary:
	var candidates: Array = _valid_hive_dicts(hives)
	var target_count: int = int(candidates.size() / 2)
	if target_count <= 0:
		return {"p1": [], "p2": candidates, "pattern": "", "seed": int(options.get("seed", 0))}
	var seed: int = int(options.get("seed", 0))
	if seed == 0:
		seed = int(Time.get_ticks_msec())
	var pattern: String = str(options.get("pattern", HIDDEN_CTF_ALLOTMENT_ROLL)).strip_edges().to_lower()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	if pattern.is_empty() or pattern == HIDDEN_CTF_ALLOTMENT_ROLL:
		pattern = HIDDEN_CTF_ALLOTMENT_PATTERNS[rng.randi_range(0, HIDDEN_CTF_ALLOTMENT_PATTERNS.size() - 1)]
	var ranked: Array = _rank_hives_for_hidden_ctf_pattern(candidates, map_data, pattern, rng)
	var p1: Array = []
	var p2: Array = []
	for i in range(ranked.size()):
		var hive: Dictionary = ranked[i] as Dictionary
		if i < target_count:
			p1.append(hive)
		else:
			p2.append(hive)
	return {
		"p1": p1,
		"p2": p2,
		"pattern": pattern,
		"seed": seed
	}

static func _rank_hives_for_hidden_ctf_pattern(hives: Array, map_data: Dictionary, pattern: String, rng: RandomNumberGenerator) -> Array:
	var ranked: Array = hives.duplicate()
	var grid_w: float = maxf(1.0, float(map_data.get("grid_w", map_data.get("grid_width", map_data.get("width", 18)))))
	var grid_h: float = maxf(1.0, float(map_data.get("grid_h", map_data.get("grid_height", map_data.get("height", 28)))))
	match pattern:
		"left_right":
			ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if not is_equal_approx(_hive_x(a), _hive_x(b)):
					return _hive_x(a) < _hive_x(b)
				return _hive_y(a) < _hive_y(b)
			)
		"top_bottom":
			ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if not is_equal_approx(_hive_y(a), _hive_y(b)):
					return _hive_y(a) < _hive_y(b)
				return _hive_x(a) < _hive_x(b)
			)
		"diagonal_down":
			ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var score_a: float = (_hive_x(a) / grid_w) + (_hive_y(a) / grid_h)
				var score_b: float = (_hive_x(b) / grid_w) + (_hive_y(b) / grid_h)
				if not is_equal_approx(score_a, score_b):
					return score_a < score_b
				return _hive_id_sort_key(a) < _hive_id_sort_key(b)
			)
		"diagonal_up":
			ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var score_a: float = (_hive_x(a) / grid_w) - (_hive_y(a) / grid_h)
				var score_b: float = (_hive_x(b) / grid_w) - (_hive_y(b) / grid_h)
				if not is_equal_approx(score_a, score_b):
					return score_a < score_b
				return _hive_id_sort_key(a) < _hive_id_sort_key(b)
			)
		"checkerboard":
			ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var parity_a: int = int(floor(_hive_x(a)) + floor(_hive_y(a))) % 2
				var parity_b: int = int(floor(_hive_x(b)) + floor(_hive_y(b))) % 2
				if parity_a != parity_b:
					return parity_a < parity_b
				if not is_equal_approx(_hive_y(a), _hive_y(b)):
					return _hive_y(a) < _hive_y(b)
				return _hive_x(a) < _hive_x(b)
			)
		"shuffle":
			_shuffle_hives(ranked, rng)
		_:
			_shuffle_hives(ranked, rng)
	return ranked

static func _valid_hive_dicts(hives: Array) -> Array:
	var out: Array = []
	for hive_any in hives:
		if typeof(hive_any) == TYPE_DICTIONARY:
			out.append(hive_any as Dictionary)
	return out

static func _shuffle_hives(hives: Array, rng: RandomNumberGenerator) -> void:
	for i in range(hives.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = hives[i]
		hives[i] = hives[j]
		hives[j] = tmp

static func _set_hive_owner(hive: Dictionary, owner_id: int) -> void:
	hive["owner_id"] = owner_id
	if hive.has("owner"):
		hive["owner"] = "NPC" if owner_id <= 0 else "P%d" % owner_id

static func _owner_counts_for_hives(hives: Array) -> Dictionary:
	var counts: Dictionary = {}
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var owner_id: int = int((hive_any as Dictionary).get("owner_id", 0))
		counts[owner_id] = int(counts.get(owner_id, 0)) + 1
	return counts

static func _owner_counts_for_map(map_data: Dictionary) -> Dictionary:
	var hives_any: Variant = map_data.get("hives", [])
	if typeof(hives_any) == TYPE_ARRAY:
		var hive_counts: Dictionary = _owner_counts_for_hives(hives_any as Array)
		if not hive_counts.is_empty():
			return hive_counts
	var counts: Dictionary = {}
	var nodes_any: Variant = map_data.get("nodes", [])
	if typeof(nodes_any) != TYPE_ARRAY:
		return counts
	for node_any in nodes_any as Array:
		if typeof(node_any) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_any as Dictionary
		var kind: String = str(node.get("kind", "hive")).strip_edges().to_lower()
		if kind != "hive" and kind != "player_hive" and kind != "npc_hive":
			continue
		var owner_id: int = int(node.get("owner_id", -1))
		if owner_id < 0:
			var owner_text: String = str(node.get("owner", node.get("team", ""))).strip_edges().to_upper()
			owner_id = 0
			if owner_text.begins_with("P") and owner_text.trim_prefix("P").is_valid_int():
				owner_id = int(owner_text.trim_prefix("P"))
		counts[owner_id] = int(counts.get(owner_id, 0)) + 1
	return counts

static func _map_has_player_bucket(map_data: Dictionary, bucket: String) -> bool:
	var required: String = _normalize_bucket(bucket)
	if required.is_empty():
		return false
	for bucket_any in _map_player_buckets(map_data):
		if _normalize_bucket(str(bucket_any)) == required:
			return true
	return false

static func _map_player_buckets(map_data: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var buckets_v: Variant = map_data.get("player_buckets", [])
	if typeof(buckets_v) == TYPE_ARRAY:
		for bucket_any in buckets_v as Array:
			var bucket: String = str(bucket_any).strip_edges()
			if not bucket.is_empty():
				out.append(bucket)
	var mode: String = str(map_data.get("mode", "")).strip_edges()
	if not mode.is_empty():
		out.append(mode)
	return out

static func _required_player_bucket_for_mode(clean_mode: String) -> String:
	match clean_mode:
		"1V1", "1P":
			return "1P"
		"2V2":
			return "2V2"
		"4P_FFA", "4P":
			return "4P_FFA"
		_:
			return ""

static func _normalize_mode_id(mode_id: String) -> String:
	return _normalize_bucket(mode_id)

static func _normalize_bucket(value: String) -> String:
	return value.strip_edges().to_upper().replace(" ", "_").replace("-", "_")

static func _hive_x(hive: Dictionary) -> float:
	if hive.has("x"):
		return float(hive.get("x", 0.0))
	var grid_pos: Variant = hive.get("grid_pos", [])
	if typeof(grid_pos) == TYPE_ARRAY and (grid_pos as Array).size() >= 1:
		return float((grid_pos as Array)[0])
	return 0.0

static func _hive_y(hive: Dictionary) -> float:
	if hive.has("y"):
		return float(hive.get("y", 0.0))
	var grid_pos: Variant = hive.get("grid_pos", [])
	if typeof(grid_pos) == TYPE_ARRAY and (grid_pos as Array).size() >= 2:
		return float((grid_pos as Array)[1])
	return 0.0

static func _hive_pos(hive: Dictionary) -> Vector2:
	return Vector2(_hive_x(hive), _hive_y(hive))

static func _hive_id_sort_key(hive: Dictionary) -> String:
	return str(hive.get("id", "")).strip_edges()

static func _owner_centroid_or_extreme(hives: Array, owner_id: int, prefer_min: bool) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0
	for hive_any in hives:
		var hive: Dictionary = hive_any as Dictionary
		if int(hive.get("owner_id", 0)) != owner_id:
			continue
		sum += _hive_pos(hive)
		count += 1
	if count > 0:
		return sum / float(count)
	var axis: Vector2 = _widest_map_axis(hives)
	var best: Vector2 = _hive_pos(hives[0] as Dictionary)
	var best_score: float = best.dot(axis)
	for hive_any in hives:
		var pos: Vector2 = _hive_pos(hive_any as Dictionary)
		var score: float = pos.dot(axis)
		if prefer_min:
			if score < best_score:
				best = pos
				best_score = score
		elif score > best_score:
			best = pos
			best_score = score
	return best

static func _widest_map_axis(hives: Array) -> Vector2:
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	for hive_any in hives:
		var pos: Vector2 = _hive_pos(hive_any as Dictionary)
		min_x = minf(min_x, pos.x)
		max_x = maxf(max_x, pos.x)
		min_y = minf(min_y, pos.y)
		max_y = maxf(max_y, pos.y)
	if (max_x - min_x) >= (max_y - min_y):
		return Vector2.RIGHT
	return Vector2.DOWN

static func _capture_flag_center_neutral_lookup(hives: Array, midpoint: Vector2, axis: Vector2) -> Dictionary:
	var target_count: int = _capture_flag_center_neutral_target_count(hives.size())
	var lookup: Dictionary = {}
	if target_count <= 0:
		return lookup
	var ranked: Array = []
	for hive_any in hives:
		var hive: Dictionary = hive_any as Dictionary
		var owner_id: int = int(hive.get("owner_id", 0))
		if owner_id == 1 or owner_id == 2:
			continue
		var rel: Vector2 = _hive_pos(hive) - midpoint
		ranked.append({
			"id": _hive_id_sort_key(hive),
			"center_score": absf(rel.dot(axis)) + rel.length() * 0.04
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.get("center_score", 0.0)), float(b.get("center_score", 0.0))):
			return float(a.get("center_score", 0.0)) < float(b.get("center_score", 0.0))
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	for i in range(mini(target_count, ranked.size())):
		lookup[str((ranked[i] as Dictionary).get("id", ""))] = true
	return lookup

static func _capture_flag_center_neutral_target_count(hive_count: int) -> int:
	if hive_count < CAPTURE_FLAG_CENTER_NEUTRAL_MIN_HIVES:
		return 0
	if hive_count >= 12:
		return CAPTURE_FLAG_CENTER_NEUTRAL_MAX_COUNT
	return 2
