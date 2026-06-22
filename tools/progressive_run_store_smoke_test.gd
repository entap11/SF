extends SceneTree

const ProgressiveConfigScript := preload("res://scripts/state/progressive_config.gd")
const ProgressiveRunStoreScript := preload("res://scripts/state/progressive_run_store.gd")

const SMOKE_SAVE_PATH: String = "user://progressive_run_store_smoke.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SMOKE_SAVE_PATH))
	var store: RefCounted = ProgressiveRunStoreScript.new()
	store.save_path = SMOKE_SAVE_PATH
	var plan: Array[Dictionary] = ProgressiveConfigScript.build_stage_plan(2)
	var run: Dictionary = store.start_run(plan, {"uid": "smoke_player", "display_name": "Smoke"})
	if str(run.get("status", "")) != ProgressiveRunStoreScript.STATUS_ACTIVE:
		_fail("new run should be active")
		return
	if int(run.get("stage_count", 0)) != 2:
		_fail("new run should preserve requested stage count")
		return
	var stage: Dictionary = store.current_stage(run)
	if int(stage.get("stage_index", -1)) != 0:
		_fail("current stage should start at index 0")
		return
	var thresholds: Dictionary = stage.get("thresholds_ms", {}) as Dictionary
	var stars: int = ProgressiveConfigScript.stars_for_elapsed(int(thresholds.get("four_star_ms", 0)), thresholds, true, "domination")
	var result: Dictionary = store.record_stage_result(str(run.get("run_id", "")), {
		"stage_index": 0,
		"elapsed_ms": int(thresholds.get("four_star_ms", 0)),
		"winner_id": 1,
		"reason": "domination",
		"passed": true,
		"stars": stars
	})
	if not bool(result.get("ok", false)):
		_fail("stage result should record")
		return
	var updated: Dictionary = result.get("run", {}) as Dictionary
	if int(updated.get("stage_index", 0)) != 1:
		_fail("passed first stage should advance to stage 2")
		return
	if int(updated.get("total_stars", 0)) != 4:
		_fail("total stars should include recorded stage stars")
		return
	var reloaded: Dictionary = store.load_current_run()
	if str(reloaded.get("run_id", "")) != str(run.get("run_id", "")):
		_fail("saved run should reload")
		return
	store.clear_current_run()
	print("PROGRESSIVE_RUN_STORE_SMOKE: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error("PROGRESSIVE_RUN_STORE_SMOKE: %s" % message)
	quit(1)
