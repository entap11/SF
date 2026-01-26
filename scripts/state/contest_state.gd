extends Node

signal run_requested(context: Dictionary)

const CONTESTS_DIR := "res://data/contests"
const LEADERBOARDS_DIR := "res://data/leaderboards"
const ENTRY_SAVE_PATH := "user://contest_entries.json"

var contests: Dictionary = {}
var player_entries: Dictionary = {}

func _ready() -> void:
	load_contests()
	_load_entries()

func build_contest_id(parts: Dictionary) -> String:
	var scope := str(parts.get("scope", "")).to_upper()
	var currency := str(parts.get("currency", "")).to_upper()
	var price := int(parts.get("price", 0))
	var time_slice := _normalize_time_slice(str(parts.get("time", "")))
	var suffix := str(parts.get("suffix", ""))
	var base := "%s_%s_%d_%s" % [scope, currency, price, time_slice]
	if not suffix.is_empty():
		base = "%s_%s" % [base, suffix]
	return base

func parse_contest_id(contest_id: String) -> Dictionary:
	var parts := contest_id.split("_")
	if parts.size() < 4:
		return {}
	var scope := str(parts[0]).to_upper()
	var currency := str(parts[1]).to_upper()
	var price := int(parts[2])
	var time_slice := _normalize_time_slice(str(parts[3]))
	var suffix := ""
	if parts.size() > 4:
		suffix = "_".join(parts.slice(4, parts.size()))
	return {
		"scope": scope,
		"currency": currency,
		"price": price,
		"time": time_slice,
		"suffix": suffix
	}

func normalize_contest_id(contest_id: String) -> String:
	var parts := parse_contest_id(contest_id)
	if parts.is_empty():
		return contest_id
	return build_contest_id(parts)

func load_contests() -> void:
	contests.clear()
	var dir := DirAccess.open(CONTESTS_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not _is_resource_file(file_name):
			continue
		var res: Resource = load("%s/%s" % [CONTESTS_DIR, file_name])
		if res is ContestDef and not res.id.is_empty():
			var normalized_id := normalize_contest_id(res.id)
			if normalized_id.is_empty():
				continue
			if normalized_id != res.id:
				res.id = normalized_id
			var parts := parse_contest_id(normalized_id)
			if not parts.is_empty():
				if res.scope.is_empty():
					res.scope = str(parts.get("scope", res.scope))
				if res.currency.is_empty():
					res.currency = str(parts.get("currency", res.currency))
				if res.price <= 0:
					res.price = int(parts.get("price", res.price))
				if res.time_slice.is_empty():
					res.time_slice = str(parts.get("time", res.time_slice))
			if res.mode.is_empty():
				res.mode = "TIME_PUZZLE"
			contests[normalized_id] = res

func get_contest(contest_id: String) -> ContestDef:
	return contests.get(normalize_contest_id(contest_id))

func get_contests_by_scope(scope: String) -> Array[ContestDef]:
	var result: Array[ContestDef] = []
	var scope_upper := scope.to_upper()
	for contest in contests.values():
		if contest == null:
			continue
		if contest.scope.to_upper() != scope_upper:
			continue
		if not contest.published:
			continue
		if contest.price <= 0:
			continue
		if contest.map_ids.size() != 5:
			continue
		result.append(contest)
	result.sort_custom(func(a: ContestDef, b: ContestDef) -> bool:
		return a.price < b.price
	)
	return result

func get_contest_by_scope(scope: String) -> ContestDef:
	var contests_by_scope := get_contests_by_scope(scope)
	if contests_by_scope.is_empty():
		return null
	return contests_by_scope[0]

func get_buff_cap_per_map(contest_id: String) -> int:
	var contest: ContestDef = contests.get(normalize_contest_id(contest_id))
	if contest == null:
		return 0
	return contest.buff_cap_per_map

func is_entered(contest_id: String) -> bool:
	return player_entries.has(normalize_contest_id(contest_id))

func enter_contest(contest_id: String) -> void:
	var normalized_id := normalize_contest_id(contest_id)
	if normalized_id.is_empty():
		return
	player_entries[normalized_id] = int(Time.get_unix_time_from_system())
	_save_entries()

func build_run_context(contest_id: String, map_id: String) -> Dictionary:
	var normalized_id := normalize_contest_id(contest_id)
	var contest: ContestDef = contests.get(normalized_id)
	if contest == null:
		return {}
	var context: Dictionary = {
		"contest_id": normalized_id,
		"map_id": map_id,
		"scope": contest.scope,
		"price": contest.price,
		"buff_cap_per_map": contest.buff_cap_per_map
	}
	run_requested.emit(context)
	return context

func get_map_ids(contest: ContestDef) -> PackedStringArray:
	if contest == null:
		return PackedStringArray()
	return contest.map_ids

func get_leaderboard_entries(contest_id: String, map_id: String) -> Array:
	var normalized_id := normalize_contest_id(contest_id)
	var path := "%s/%s/%s.json" % [LEADERBOARDS_DIR, normalized_id, map_id]
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	if err != OK:
		return []
	if typeof(json.data) != TYPE_ARRAY:
		return []
	return json.data

func get_best_score(contest_id: String, map_id: String) -> int:
	var entries := get_leaderboard_entries(contest_id, map_id)
	if entries.is_empty():
		return 0
	var first: Dictionary = entries[0]
	return int(first.get("best_score", 0))

func _load_entries() -> void:
	player_entries.clear()
	if not FileAccess.file_exists(ENTRY_SAVE_PATH):
		return
	var f := FileAccess.open(ENTRY_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	player_entries = json.data
	var normalized: Dictionary = {}
	for key in player_entries.keys():
		var normalized_id := normalize_contest_id(str(key))
		normalized[normalized_id] = player_entries[key]
	player_entries = normalized

func _save_entries() -> void:
	var f := FileAccess.open(ENTRY_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(player_entries))

func _is_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".res")

func _normalize_time_slice(time_slice: String) -> String:
	if time_slice.length() == 7 and time_slice.substr(4, 1) == "W":
		return "%s-%s" % [time_slice.substr(0, 4), time_slice.substr(4, 3)]
	if time_slice.length() == 6 and time_slice.is_valid_int():
		return "%s-%s" % [time_slice.substr(0, 4), time_slice.substr(4, 2)]
	return time_slice
