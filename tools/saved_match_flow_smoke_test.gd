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
		push_error("SAVED_MATCH_FLOW: " + message)

func _run() -> void:
	if not OS.get_user_data_dir().contains("SwarmfrontSavedMatchChecks-"):
		push_error("Use tools/run_saved_match_checks.py to isolate player data.")
		quit(2)
		return
	create_timer(100).timeout.connect(func():
		push_error("SAVED_MATCH_FLOW: timeout")
		quit(1)
	)
	ops = root.get_node("OpsState")
	saves = root.get_node("SavedMatch")
	profile = root.get_node("ProfileManager")
	profile.smoke_force_identity_state("01900000-0000-7000-8000-000000000001", "ABC 123", "Resume Pilot", true, true)
	profile.mark_onboarding_complete()
	profile.mark_tutorial_controls_completed()
	profile.mark_controls_hint_seen()
	if OS.get_cmdline_user_args().has("--restore"):
		await _restore()
	else:
		await _write()
	print("SAVED_MATCH_FLOW: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _wait_running() -> bool:
	for i in 600:
		await create_timer(0.05).timeout
		if current_scene != null and current_scene.name == "Shell" and ops.match_phase == 1:
			return true
	return false

func _write() -> void:
	var campaign: Node = root.get_node("CampaignRuntime")
	var levels: Array[Dictionary] = Catalog.levels()
	var launch: Dictionary = campaign.request_launch(str(levels[0].id), "campaign")
	check(launch.ok, "campaign launches")
	if not launch.ok or not await _wait_running():
		check(false, "fresh game reaches running")
		return
	await create_timer(1.0).timeout
	var arena: Node = current_scene.find_child("Arena", true, false)
	check(arena != null, "arena found")
	if arena == null:
		return
	check(saves.checkpoint(arena, true), "full game saved to disk: " + saves.last_error)
	var id: String = saves.active_id
	var saved: Dictionary = saves.store.read(profile.get_user_id(), id)
	check(not saved.is_empty(), "save readable")
	if saved.is_empty():
		return
	var expectation := {"id": id, "hash": ops.get_contract_state_hash(), "elapsed": ops.match_elapsed_ms,
		"remaining": ops.match_remaining_ms, "level": levels[0].id, "campaign_run": campaign.get("_run_id"),
		"started_at": int(get_meta("match_started_unix", 0))}
	var file := FileAccess.open("user://saved_match_restart_expectation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(expectation))
	file.close()
	# Exit the process with the saved checkpoint intact, just as after a kill.
	saves.set("_suppressed", true)

func _restore() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://saved_match_restart_expectation.json"))
	change_scene_to_file("res://scenes/MainMenu.tscn")
	await scene_changed
	for i in 5:
		await process_frame
	check(not saves.available().is_empty(), "fresh process discovers account's saved game")
	check(current_scene.get("_saved_game_dialog") != null, "main menu offers resume")
	var response: Dictionary = saves.request_resume(str(expected.id))
	check(response.ok, "saved game launch accepted: " + str(response))
	if not response.ok or not await _wait_running():
		check(false, "restored game loads")
		return
	var arena: Node = current_scene.find_child("Arena", true, false)
	check(ops.get_contract_state_hash() == str(expected.hash), "new process restores exact board hash (tick %d)" % ops.state.tick)
	check(ops.match_elapsed_ms == int(expected.elapsed), "new process restores elapsed time")
	check(ops.match_remaining_ms == int(expected.remaining), "new process restores remaining time")
	check(not arena.sim_runner.running and arena.get("_saved_resume_seconds") >= 0.0, "restored game waits for countdown: running=%s seconds=%s tick=%d" % [arena.sim_runner.running, arena.get("_saved_resume_seconds"), ops.state.tick])
	var campaign: Node = root.get_node("CampaignRuntime")
	check(campaign.is_active() and str(campaign.active_level().id) == str(expected.level), "campaign level restored")
	check(str(campaign.get("_run_id")) == str(expected.campaign_run), "same campaign attempt restored")
	check(int(get_meta("match_started_unix", 0)) == int(expected.started_at), "leaderboard start period preserved")
	await create_timer(0.3).timeout
	check(ops.match_elapsed_ms == int(expected.elapsed), "countdown does not consume match time")
	for i in 160:
		await create_timer(0.05).timeout
		if arena.get("_saved_resume_seconds") < 0.0:
			break
	check(arena.sim_runner.running, "simulation starts after countdown")
	await create_timer(0.4).timeout
	check(ops.match_elapsed_ms > int(expected.elapsed), "restored clock advances")
	check(saves.checkpoint(arena, true), "resumed game saves again")
	saves.discard_active()
	check(saves.store.read(profile.get_user_id(), str(expected.id)).is_empty(), "discard removes save")
	check(not saves.checkpoint(arena, true), "discard cannot be undone by exit autosave")
