class_name ProgressiveRunStore
extends RefCounted

const ProgressiveConfigScript := preload("res://scripts/state/progressive_config.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")

const SAVE_PATH_DEFAULT: String = "user://progressive_run_v1.json"
const SCHEMA_V1: String = "swarmfront.progressive_run.v1"
const STATUS_ACTIVE: String = "active"
const STATUS_COMPLETE: String = "complete"
const STATUS_LOST: String = "lost"

var save_path: String = SAVE_PATH_DEFAULT


func start_run(plan: Array[Dictionary], player_profile: Dictionary = {}) -> Dictionary:
	var clean_plan: Array[Dictionary] = _normalize_plan(plan)
	if clean_plan.is_empty():
		clean_plan = ProgressiveConfigScript.build_stage_plan()
	var now_unix: int = int(Time.get_unix_time_from_system())
	var run: Dictionary = {
		"_schema": SCHEMA_V1,
		"run_id": _new_run_id(player_profile),
		"mode_id": ProgressiveConfigScript.MODE_ID,
		"status": STATUS_ACTIVE,
		"created_unix": now_unix,
		"updated_unix": now_unix,
		"stage_index": 0,
		"stage_count": clean_plan.size(),
		"total_stars": 0,
		"max_stars": clean_plan.size() * ProgressiveConfigScript.STAR_MAX,
		"stage_results": [],
		"stage_plan": clean_plan,
		"player_profile": player_profile.duplicate(true)
	}
	save_current_run(run)
	return run.duplicate(true)


func load_current_run() -> Dictionary:
	var file_path: String = _resolved_save_path()
	if not FileAccess.file_exists(file_path):
		return {}
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var root: Dictionary = parsed as Dictionary
	if str(root.get("_schema", "")) != SCHEMA_V1:
		return {}
	var run_any: Variant = root.get("current_run", {})
	if typeof(run_any) != TYPE_DICTIONARY:
		return {}
	return _normalize_run(run_any as Dictionary)


func save_current_run(run: Dictionary) -> bool:
	var normalized: Dictionary = _normalize_run(run)
	if normalized.is_empty():
		return false
	normalized["updated_unix"] = int(Time.get_unix_time_from_system())
	var file: FileAccess = FileAccess.open(_resolved_save_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"_schema": SCHEMA_V1,
		"current_run": normalized
	}, "\t"))
	return true


func current_stage(run: Dictionary) -> Dictionary:
	var normalized: Dictionary = _normalize_run(run)
	if normalized.is_empty():
		return {}
	var plan: Array[Dictionary] = normalized.get("stage_plan", []) as Array[Dictionary]
	if plan.is_empty():
		return {}
	var index: int = clampi(int(normalized.get("stage_index", 0)), 0, plan.size() - 1)
	return plan[index].duplicate(true)


func record_stage_result(run_id: String, result: Dictionary) -> Dictionary:
	var run: Dictionary = load_current_run()
	if run.is_empty() or str(run.get("run_id", "")) != run_id.strip_edges():
		return {"ok": false, "reason": "run_not_found"}
	if str(run.get("status", STATUS_ACTIVE)) != STATUS_ACTIVE:
		return {"ok": false, "reason": "run_not_active", "run": run}
	var stage_count: int = maxi(1, int(run.get("stage_count", 1)))
	var stage_index: int = clampi(int(result.get("stage_index", run.get("stage_index", 0))), 0, stage_count - 1)
	var clean_result: Dictionary = result.duplicate(true)
	clean_result["stage_index"] = stage_index
	clean_result["stage_number"] = stage_index + 1
	clean_result["stars"] = clampi(int(clean_result.get("stars", 0)), 0, ProgressiveConfigScript.STAR_MAX)
	clean_result["recorded_unix"] = int(Time.get_unix_time_from_system())
	var results: Array = run.get("stage_results", []) as Array
	results = _upsert_result(results, stage_index, clean_result)
	run["stage_results"] = results
	run["total_stars"] = _total_stars(results)
	if bool(clean_result.get("passed", false)):
		var next_index: int = stage_index + 1
		run["stage_index"] = mini(next_index, stage_count - 1)
		if next_index >= stage_count:
			run["status"] = STATUS_COMPLETE
	else:
		run["status"] = STATUS_LOST
	save_current_run(run)
	return {"ok": true, "run": run.duplicate(true)}


func clear_current_run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_resolved_save_path()))


func _normalize_run(raw: Dictionary) -> Dictionary:
	var run: Dictionary = raw.duplicate(true)
	if str(run.get("mode_id", ProgressiveConfigScript.MODE_ID)) != ProgressiveConfigScript.MODE_ID:
		return {}
	var plan: Array[Dictionary] = _normalize_plan(run.get("stage_plan", []) as Array)
	if plan.is_empty():
		return {}
	run["_schema"] = SCHEMA_V1
	run["mode_id"] = ProgressiveConfigScript.MODE_ID
	run["run_id"] = str(run.get("run_id", "")).strip_edges()
	if str(run.get("run_id", "")).is_empty():
		return {}
	run["status"] = _normalize_status(str(run.get("status", STATUS_ACTIVE)))
	run["stage_plan"] = plan
	run["stage_count"] = plan.size()
	run["stage_index"] = clampi(int(run.get("stage_index", 0)), 0, plan.size() - 1)
	run["max_stars"] = plan.size() * ProgressiveConfigScript.STAR_MAX
	var results: Array = run.get("stage_results", []) as Array
	run["stage_results"] = _normalize_results(results, plan.size())
	run["total_stars"] = _total_stars(run["stage_results"] as Array)
	if typeof(run.get("player_profile", {})) != TYPE_DICTIONARY:
		run["player_profile"] = {}
	return run


func _normalize_plan(plan_any: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for stage_any in plan_any:
		if typeof(stage_any) != TYPE_DICTIONARY:
			continue
		var stage: Dictionary = (stage_any as Dictionary).duplicate(true)
		if str(stage.get("map_path", "")).strip_edges().is_empty():
			continue
		stage["stage_index"] = maxi(0, int(stage.get("stage_index", out.size())))
		stage["stage_number"] = int(stage.get("stage_number", int(stage.get("stage_index", out.size())) + 1))
		stage = _refresh_stage_score_defaults(stage)
		out.append(stage)
	return out


func _refresh_stage_score_defaults(stage: Dictionary) -> Dictionary:
	var out: Dictionary = stage.duplicate(true)
	var map_path: String = str(out.get("map_path", "")).strip_edges()
	if map_path.is_empty():
		return out
	var loaded: Dictionary = MAP_LOADER.load_map(map_path)
	if not bool(loaded.get("ok", false)):
		return out
	var data_any: Variant = loaded.get("data", {})
	if typeof(data_any) != TYPE_DICTIONARY:
		return out
	var hive_count: int = ProgressiveConfigScript.conquerable_hive_count_from_map_data(data_any as Dictionary)
	out["conquerable_hive_count"] = hive_count
	out["thresholds_ms"] = ProgressiveConfigScript.threshold_ms_for_hives(hive_count)
	return out


func _normalize_results(results: Array, stage_count: int) -> Array:
	var out: Array = []
	for result_any in results:
		if typeof(result_any) != TYPE_DICTIONARY:
			continue
		var result: Dictionary = (result_any as Dictionary).duplicate(true)
		var stage_index: int = int(result.get("stage_index", -1))
		if stage_index < 0 or stage_index >= stage_count:
			continue
		result["stars"] = clampi(int(result.get("stars", 0)), 0, ProgressiveConfigScript.STAR_MAX)
		out = _upsert_result(out, stage_index, result)
	return out


func _upsert_result(results: Array, stage_index: int, result: Dictionary) -> Array:
	var out: Array = []
	var replaced: bool = false
	for existing_any in results:
		if typeof(existing_any) != TYPE_DICTIONARY:
			continue
		var existing: Dictionary = (existing_any as Dictionary).duplicate(true)
		if int(existing.get("stage_index", -1)) == stage_index:
			out.append(result.duplicate(true))
			replaced = true
		else:
			out.append(existing)
	if not replaced:
		out.append(result.duplicate(true))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("stage_index", 0)) < int(b.get("stage_index", 0))
	)
	return out


func _total_stars(results: Array) -> int:
	var total: int = 0
	for result_any in results:
		if typeof(result_any) == TYPE_DICTIONARY:
			total += clampi(int((result_any as Dictionary).get("stars", 0)), 0, ProgressiveConfigScript.STAR_MAX)
	return total


func _normalize_status(status: String) -> String:
	var clean: String = status.strip_edges().to_lower()
	if clean == STATUS_COMPLETE or clean == STATUS_LOST:
		return clean
	return STATUS_ACTIVE


func _new_run_id(player_profile: Dictionary) -> String:
	var uid: String = str(player_profile.get("uid", player_profile.get("player_id", "local"))).strip_edges()
	if uid.is_empty():
		uid = "local"
	return "progressive_%s_%d_%d" % [uid.sha256_text().substr(0, 10), Time.get_unix_time_from_system(), Time.get_ticks_msec()]


func _resolved_save_path() -> String:
	var clean: String = save_path.strip_edges()
	return clean if not clean.is_empty() else SAVE_PATH_DEFAULT
