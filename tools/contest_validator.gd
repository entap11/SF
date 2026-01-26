@tool
extends Node

const CONTESTS_DIR := "res://data/contests"

func _ready() -> void:
	if Engine.is_editor_hint():
		validate_all_contests()

func validate_all_contests() -> void:
	var dir := DirAccess.open(CONTESTS_DIR)
	if dir == null:
		push_error("ContestValidator: cannot open %s" % CONTESTS_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			_validate_single_contest(CONTESTS_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

func _validate_single_contest(path: String) -> void:
	var res := load(path)
	if res == null:
		push_error("ContestValidator: failed to load %s" % path)
		return
	if not (res is ContestDef):
		push_error("ContestValidator: %s is not ContestDef (got %s)" % [path, res])
		return

	var contest: ContestDef = res
	var parts := _parse_contest_id(contest.id)
	if parts.is_empty():
		push_warning("ContestValidator: invalid id '%s' in %s" % [contest.id, path])
		return

	var changed := false

	if contest.scope != parts.get("scope"):
		contest.scope = parts.get("scope")
		changed = true
	if contest.currency != parts.get("currency"):
		contest.currency = parts.get("currency")
		changed = true
	if contest.price != parts.get("price"):
		contest.price = parts.get("price")
		changed = true
	if contest.time_slice != parts.get("time"):
		contest.time_slice = parts.get("time")
		changed = true

	if changed:
		ResourceSaver.save(contest, path)
		print("ContestValidator: fixed field mismatch in %s (id=%s)" % [path, contest.id])

	var computed_id := _build_id_from_fields(contest)
	if computed_id != contest.id:
		push_warning("ContestValidator: id mismatch in %s: stored=%s, computed=%s" % [
			path, contest.id, computed_id
		])

func _parse_contest_id(contest_id: String) -> Dictionary:
	# Expect "{SCOPE}_{CURRENCY}_{PRICE}_{TIME}"
	var parts := contest_id.split("_")
	if parts.size() < 4:
		return {}

	var scope := parts[0]
	var currency := parts[1]
	var price := parts[2].to_int()
	var time_and_rest := "_".join(parts.slice(3, parts.size()))
	var time_parts := time_and_rest.split("_", false, 1)
	var time := time_parts[0]

	return {
		"scope": scope,
		"currency": currency,
		"price": price,
		"time": time,
	}

func _build_id_from_fields(contest: ContestDef) -> String:
	return "%s_%s_%d_%s" % [
		contest.scope,
		contest.currency,
		contest.price,
		contest.time_slice,
	]
