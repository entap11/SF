extends SceneTree

const Catalog = preload("res://scripts/state/campaign_catalog.gd")
var failed := false
var ops: Node
var saves: Node
var profile: Node

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("SAVED_MATCH_MODES: " + message)

func _run() -> void:
	if not OS.get_user_data_dir().contains("SwarmfrontSavedMatchChecks-"):
		quit(2)
		return
	create_timer(150).timeout.connect(func(): quit(1))
	ops = root.get_node("OpsState")
	saves = root.get_node("SavedMatch")
	profile = root.get_node("ProfileManager")
	profile.smoke_force_identity_state("01900000-0000-7000-8000-000000000001", "ABC 123", "Resume Pilot", true, true)
	profile.mark_onboarding_complete()
	profile.mark_tutorial_controls_completed()
	profile.mark_controls_hint_seen()
	var runtime: Node = root.get_node("CampaignRuntime")
	var levels: Array[Dictionary] = Catalog.levels()
	runtime.request_launch(str(levels[0].id))
	var arena: Node = await _wait_arena()
	if arena == null:
		_finish()
		return
	await create_timer(0.3).timeout
	check(saves.checkpoint(arena, true), "campaign checkpoint")
	var id: String = saves.active_id
	set_meta("vs_price_usd", 5)
	check(not saves.can_save(arena) and not saves.checkpoint(arena, true), "money game cannot checkpoint")
	set_meta("vs_price_usd", 0)
	set_meta("vs_handshake_session_id", "live-test")
	check(not saves.can_save(arena), "live game cannot checkpoint")
	remove_meta("vs_handshake_session_id")
	arena.call("_on_app_backgrounded", "test", Time.get_ticks_msec(), int(Time.get_unix_time_from_system()))
	var elapsed: int = ops.match_elapsed_ms
	await create_timer(0.15).timeout
	check(not arena.sim_runner.running and ops.match_elapsed_ms == elapsed, "background freezes board and clock")
	check(not saves.store.read(profile.get_user_id(), id).is_empty(), "background saves to disk")
	arena.call("_on_app_foregrounded", "test", 150, int(Time.get_unix_time_from_system()))
	check(arena.sim_runner.running, "foreground resumes in-memory game")
	var expired: Dictionary = saves.store.read(profile.get_user_id(), id)
	expired.context["public_contest_submission_deadline_at"] = "2020-01-01T00:00:00Z"
	check(not saves.validate(expired).ok, "closed attempt cannot resume")
	saves.discard_active()

	# Complete map one of an independent, non-money three-map run.
	runtime.finish_session()
	set_meta("vs_mode", "TIMED_RACE")
	set_meta("vs_stage_map_paths", [str(levels[0].map_path), str(levels[0].map_path), str(levels[0].map_path)])
	set_meta("vs_stage_current_index", 0)
	set_meta("vs_stage_round_results", [])
	set_meta("vs_stage_run_id", "resume-stage-run")
	set_meta("public_contest_attempt", {"attempt_id": "same-attempt", "submission_deadline_at": "2099-01-01T00:00:00Z"})
	ops.begin_match_end(1, "capture_all", 0)
	ops.finalize_match_end()
	arena.sim_runner.emit_signal("match_ended", 1, "capture_all")
	for i in 8:
		await process_frame
	var transition: Dictionary = saves.store.read(profile.get_user_id(), saves.active_id)
	check(bool(transition.get("launch_only", false)), "between-map exit saves next stage")
	if not bool(transition.get("launch_only", false)):
		_finish()
		return
	check(int(transition.context.vs_stage_current_index) == 1, "next map index saved")
	check(transition.context.vs_stage_round_results.size() == 1, "completed map result saved exactly once")
	var response: Dictionary = saves.request_resume(str(transition.id))
	check(response.ok, "stage continuation launch")
	await scene_changed
	arena = await _wait_arena()
	if arena == null:
		_finish()
		return
	check(int(get_meta("vs_stage_current_index")) == 1, "resume launches next map")
	check(get_meta("vs_stage_round_results").size() == 1, "earlier map preserved")
	check(str(get_meta("public_contest_attempt").attempt_id) == "same-attempt", "same contest attempt preserved")
	check(saves.checkpoint(arena, true), "new stage replaces transition checkpoint")
	check(not saves.store.read(profile.get_user_id(), str(transition.id)).is_empty() and not bool(saves.store.read(profile.get_user_id(), str(transition.id)).get("launch_only", false)), "no replayable transition left behind")
	saves.discard_active()

	# Rebuild the tutorial's presentation and instruction state around its saved board.
	for key in get_meta_list():
		if saves.call("_context_key", str(key)):
			remove_meta(key)
	profile.prepare_tutorial_controls_sandbox()
	change_scene_to_file("res://scenes/Shell.tscn")
	await scene_changed
	current_scene.call("_on_tutorial_pressed")
	arena = await _wait_arena()
	if arena == null:
		_finish()
		return
	for i in 5:
		await process_frame
	var before: Dictionary = arena.tutorial_controls_smoke_snapshot()
	check(bool(before.active), "tutorial active")
	check(saves.checkpoint(arena, true), "paused tutorial saves")
	id = saves.active_id
	response = saves.request_resume(id)
	check(response.ok, "tutorial resumes")
	await scene_changed
	arena = await _wait_arena(true)
	if arena == null:
		_finish()
		return
	var restored: Dictionary = arena.tutorial_controls_smoke_snapshot()
	check(str(restored.current_step) == str(before.current_step), "tutorial instruction preserved")
	check(restored.anchors == before.anchors, "tutorial targets preserved")
	for i in 160:
		await create_timer(0.05).timeout
		if arena.get("_saved_resume_seconds") < 0:
			break
	check(not arena.sim_runner.running, "reading step stays paused after countdown")
	var source_id: int = int(restored.anchors.start_hive)
	check(bool(current_scene.call("_tutorial_controls_smoke_commit_hive_press", arena, source_id)), "restored tutorial accepts the instructed hive")
	await current_scene.call("_tutorial_controls_smoke_select_hive", arena, source_id)
	for i in 40:
		await create_timer(0.05).timeout
		if str(arena.tutorial_controls_smoke_snapshot().current_step) != str(restored.current_step):
			break
	check(str(arena.tutorial_controls_smoke_snapshot().current_step) != str(restored.current_step), "restored tutorial responds to continue input")
	saves.discard_active()
	_finish()

func _wait_arena(restoring: bool = false) -> Node:
	for i in 650:
		await create_timer(0.05).timeout
		if current_scene == null or current_scene.name != "Shell":
			continue
		var arena: Node = current_scene.find_child("Arena", true, false)
		if arena != null and bool(arena.get("_match_started")) and ops.match_phase == 1 and (not restoring or saves.pending.is_empty()):
			return arena
	check(false, "arena reaches requested state")
	return null

func _finish() -> void:
	print("SAVED_MATCH_MODES: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
