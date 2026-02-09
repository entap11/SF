class_name MatchRecordsStore
extends RefCounted

const SAVE_PATH: String = "user://match_records_v1.json"
const SCHEMA_V1: String = "swarmfront.match_records.v1"

var _loaded: bool = false
var _records_by_id: Dictionary = {}
var _h2h_by_pair: Dictionary = {}

func get_record(id_key: String) -> Dictionary:
	_ensure_loaded()
	var key: String = _normalize_key(id_key)
	if key.is_empty():
		return {"wins": 0, "losses": 0}
	var entry_any: Variant = _records_by_id.get(key, null)
	if typeof(entry_any) != TYPE_DICTIONARY:
		return {"wins": 0, "losses": 0}
	var entry: Dictionary = entry_any as Dictionary
	return {
		"wins": int(entry.get("wins", 0)),
		"losses": int(entry.get("losses", 0))
	}

func get_h2h(a_key: String, b_key: String) -> Dictionary:
	_ensure_loaded()
	var a_norm: String = _normalize_key(a_key)
	var b_norm: String = _normalize_key(b_key)
	if a_norm.is_empty() or b_norm.is_empty() or a_norm == b_norm:
		return {"a_wins": 0, "b_wins": 0}
	var pair: String = _pair_key(a_norm, b_norm)
	var entry_any: Variant = _h2h_by_pair.get(pair, null)
	if typeof(entry_any) != TYPE_DICTIONARY:
		return {"a_wins": 0, "b_wins": 0}
	var entry: Dictionary = entry_any as Dictionary
	var left: String = str(entry.get("a", ""))
	var right: String = str(entry.get("b", ""))
	var left_wins: int = int(entry.get("a_wins", 0))
	var right_wins: int = int(entry.get("b_wins", 0))
	if left == a_norm and right == b_norm:
		return {"a_wins": left_wins, "b_wins": right_wins}
	return {"a_wins": right_wins, "b_wins": left_wins}

func record_match(winner_key: String, loser_keys: Array[String], h2h_a_key: String = "", h2h_b_key: String = "") -> void:
	_ensure_loaded()
	var changed: bool = false
	var winner_norm: String = _normalize_key(winner_key)
	if not winner_norm.is_empty():
		var winner_entry: Dictionary = _ensure_record_entry(winner_norm)
		winner_entry["wins"] = int(winner_entry.get("wins", 0)) + 1
		_records_by_id[winner_norm] = winner_entry
		changed = true
	var seen_losers: Dictionary = {}
	for loser_key in loser_keys:
		var loser_norm: String = _normalize_key(loser_key)
		if loser_norm.is_empty() or loser_norm == winner_norm:
			continue
		if seen_losers.has(loser_norm):
			continue
		seen_losers[loser_norm] = true
		var loser_entry: Dictionary = _ensure_record_entry(loser_norm)
		loser_entry["losses"] = int(loser_entry.get("losses", 0)) + 1
		_records_by_id[loser_norm] = loser_entry
		changed = true
	var h2h_a_norm: String = _normalize_key(h2h_a_key)
	var h2h_b_norm: String = _normalize_key(h2h_b_key)
	if not winner_norm.is_empty() and not h2h_a_norm.is_empty() and not h2h_b_norm.is_empty() and h2h_a_norm != h2h_b_norm:
		if winner_norm == h2h_a_norm or winner_norm == h2h_b_norm:
			if _record_h2h_result(h2h_a_norm, h2h_b_norm, winner_norm):
				changed = true
	if changed:
		_save()

func _record_h2h_result(a_key: String, b_key: String, winner_key: String) -> bool:
	var pair: String = _pair_key(a_key, b_key)
	var entry_any: Variant = _h2h_by_pair.get(pair, null)
	var entry: Dictionary = {}
	if typeof(entry_any) == TYPE_DICTIONARY:
		entry = entry_any as Dictionary
	var left: String = str(entry.get("a", ""))
	var right: String = str(entry.get("b", ""))
	if left.is_empty() or right.is_empty():
		if a_key < b_key:
			left = a_key
			right = b_key
		else:
			left = b_key
			right = a_key
		entry = {
			"a": left,
			"b": right,
			"a_wins": int(entry.get("a_wins", 0)),
			"b_wins": int(entry.get("b_wins", 0))
		}
	var left_wins: int = int(entry.get("a_wins", 0))
	var right_wins: int = int(entry.get("b_wins", 0))
	var changed: bool = false
	if winner_key == left:
		left_wins += 1
		changed = true
	elif winner_key == right:
		right_wins += 1
		changed = true
	if not changed:
		return false
	entry["a"] = left
	entry["b"] = right
	entry["a_wins"] = left_wins
	entry["b_wins"] = right_wins
	_h2h_by_pair[pair] = entry
	return true

func _ensure_record_entry(id_key: String) -> Dictionary:
	var entry_any: Variant = _records_by_id.get(id_key, null)
	var entry: Dictionary = {}
	if typeof(entry_any) == TYPE_DICTIONARY:
		entry = entry_any as Dictionary
	entry["wins"] = int(entry.get("wins", 0))
	entry["losses"] = int(entry.get("losses", 0))
	_records_by_id[id_key] = entry
	return entry

func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_records_by_id.clear()
	_h2h_by_pair.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_hydrate(parsed as Dictionary)

func _hydrate(root: Dictionary) -> void:
	var records_any: Variant = root.get("records_by_id", root.get("records", {}))
	if typeof(records_any) == TYPE_DICTIONARY:
		var records: Dictionary = records_any as Dictionary
		for key_any in records.keys():
			var key: String = _normalize_key(str(key_any))
			if key.is_empty():
				continue
			var entry_any: Variant = records.get(key_any)
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any as Dictionary
			_records_by_id[key] = {
				"wins": int(entry.get("wins", entry.get("w", 0))),
				"losses": int(entry.get("losses", entry.get("l", 0)))
			}
	var h2h_any: Variant = root.get("h2h_by_pair", root.get("h2h", {}))
	if typeof(h2h_any) == TYPE_DICTIONARY:
		var h2h: Dictionary = h2h_any as Dictionary
		for pair_any in h2h.keys():
			var entry_any: Variant = h2h.get(pair_any)
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any as Dictionary
			var left: String = _normalize_key(str(entry.get("a", "")))
			var right: String = _normalize_key(str(entry.get("b", "")))
			if left.is_empty() or right.is_empty():
				var pair_parts: PackedStringArray = str(pair_any).split("|", false)
				if pair_parts.size() == 2:
					left = _normalize_key(pair_parts[0])
					right = _normalize_key(pair_parts[1])
			if left.is_empty() or right.is_empty() or left == right:
				continue
			var pair_key: String = _pair_key(left, right)
			var normalized: Dictionary = {
				"a": left if left < right else right,
				"b": right if left < right else left,
				"a_wins": int(entry.get("a_wins", entry.get("aWins", 0))),
				"b_wins": int(entry.get("b_wins", entry.get("bWins", 0)))
			}
			_h2h_by_pair[pair_key] = normalized

func _save() -> void:
	var payload: Dictionary = {
		"_schema": SCHEMA_V1,
		"records_by_id": _records_by_id,
		"h2h_by_pair": _h2h_by_pair,
		"updated_unix": int(Time.get_unix_time_from_system())
	}
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(payload))

func _pair_key(a_key: String, b_key: String) -> String:
	if a_key < b_key:
		return "%s|%s" % [a_key, b_key]
	return "%s|%s" % [b_key, a_key]

func _normalize_key(raw_key: String) -> String:
	return raw_key.strip_edges()
