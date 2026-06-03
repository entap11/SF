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

static func hidden_capture_flag_split_summary(map_data: Dictionary) -> Dictionary:
	var hives_v: Variant = map_data.get("hives", [])
	if typeof(hives_v) != TYPE_ARRAY:
		return {"ok": false, "reason": "missing_hives", "owner_counts": {}}
	var hives: Array = _valid_hive_dicts(hives_v as Array)
	if hives.size() < 4:
		return {"ok": false, "reason": "too_few_hives", "owner_counts": {}}
	if hives.size() % 2 != 0:
		return {
			"ok": false,
			"reason": "odd_hive_count",
			"owner_counts": {},
			"total_hives": hives.size()
		}
	var each: int = int(hives.size() / 2)
	return {
		"ok": true,
		"reason": "",
		"owner_counts": {1: each, 2: each},
		"total_hives": hives.size()
	}

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
		hive["owner"] = "P%d" % owner_id

static func _owner_counts_for_hives(hives: Array) -> Dictionary:
	var counts: Dictionary = {}
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var owner_id: int = int((hive_any as Dictionary).get("owner_id", 0))
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

static func _hive_id_sort_key(hive: Dictionary) -> String:
	return str(hive.get("id", "")).strip_edges()
