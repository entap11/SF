extends SceneTree

const Catalog = preload("res://scripts/state/campaign_catalog.gd")
const Store = preload("res://scripts/state/campaign_progress_store.gd")
var failures: Array[String] = []
var runtime: Node
var ops: Node

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("CAMPAIGN_FLOW: " + message)

func wait_running() -> bool:
	for i in range(450):
		await create_timer(0.05).timeout
		if int(ops.get("match_phase")) == 1 and current_scene != null and current_scene.name == "Shell":
			return true
	return false

func _run() -> void:
	if not OS.get_user_data_dir().contains("SwarmfrontCampaignChecks-"):
		push_error("Use tools/run_campaign_pilot_checks.py to isolate player data.")
		quit(2)
		return
	runtime = root.get_node("CampaignRuntime")
	ops = root.get_node("OpsState")
	var profile: Node = root.get_node("ProfileManager")
	profile.call("smoke_force_identity_state", "01900000-0000-7000-8000-000000000001", "ABC 123", "Campaign Pilot", true, true)
	profile.call("mark_onboarding_complete")
	profile.call("mark_tutorial_controls_completed")
	profile.call("mark_controls_hint_seen")
	var store = Store.new()
	store.save_path = "user://campaign_flow.smoke.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.save_path))
	runtime.set("store", store)
	var levels: Array[Dictionary] = Catalog.levels()
	var blocked: Dictionary = runtime.call("request_launch", str(levels[1].id), "jukebox")
	check(not bool(blocked.ok), "Jukebox cannot bypass unlock contract")
	var response: Dictionary = runtime.call("request_launch", str(levels[0].id), "campaign")
	check(bool(response.ok), "campaign launch accepted: " + str(response))
	if not bool(response.ok):
		_finish()
		return
	check(not bool((runtime.call("request_launch", str(levels[0].id), "campaign") as Dictionary).ok), "duplicate launch rejected during scene transition")
	if not await wait_running():
		check(false, "first level reaches RUNNING")
		_finish()
		return
	var bot: Dictionary = ops.call("get_bot_profile", 2)
	check(str(bot.get("style", "")) == str(levels[0].bot), "actual bot matches catalog")
	check(str(bot.get("tier", "")) == str(levels[0].difficulty), "actual difficulty matches catalog")
	check(int(ops.get("bot_match_seed")) == int(levels[0].seed), "actual seeded behavior matches challenge")
	var buff: Dictionary = ops.call("apply_authoritative_buff_command", {})
	check(str(buff.get("reason", "")) == "campaign_fixed_loadout", "fixed loadout enforced by simulation")
	await create_timer(0.3).timeout
	# Terminal fixture goes through the simulation owner, then the production signal.
	ops.call("begin_match_end", 2, "capture_all", 0)
	ops.call("finalize_match_end")
	var runner: Node = current_scene.find_child("SimRunner", true, false)
	runner.emit_signal("match_ended", 2, "capture_all")
	await process_frame
	await process_frame
	var loss: Dictionary = runtime.call("result")
	check(bool(loss.get("ok", false)), "terminal loss saved: " + str(loss) + " phase=" + str(ops.get("match_phase")) + " elapsed=" + str(ops.get("match_elapsed_ms")))
	if not bool(loss.get("ok", false)):
		_finish()
		return
	check(int(loss.get("stingers", -1)) == 0 and int(loss.get("best_ms", -1)) == 0, "loss awards neither stingers nor PB")
	check(store.is_unlocked(runtime.call("player_id"), str(levels[1].id)), "loss unlocks next level")
	var arena: Node = current_scene.find_child("Arena", true, false)
	var overlay: Node = arena.get("outcome_overlay")
	for _frame in range(5):
		await process_frame
	var capture_dir: String = OS.get_environment("SF_CAMPAIGN_CAPTURE_DIR")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(capture_dir.path_join("campaign-loss.png"))
	check(str((overlay.get("rematch_button") as Button).text) == "NEXT LEVEL", "loss presents Next Level")
	check((overlay.get("record_label") as Label).is_visible_in_tree(), "loss explains award eligibility")
	runner.emit_signal("match_ended", 2, "capture_all")
	check(int(store.snapshot(runtime.call("player_id"), levels[0]).get("attempts", 0)) == 1, "duplicate signal deduped")
	arena.call("_on_post_match_action", "campaign_next")
	await scene_changed
	if not await wait_running():
		check(false, "Next reaches second level RUNNING")
		_finish()
		return
	check(str((runtime.call("active_level") as Dictionary).id) == str(levels[1].id), "Next launches exact next definition")
	check(not is_instance_valid(overlay), "previous result is released on Next")
	await create_timer(0.3).timeout
	ops.call("begin_match_end", 1, "capture_all", 0)
	ops.call("finalize_match_end")
	runner = current_scene.find_child("SimRunner", true, false)
	runner.emit_signal("match_ended", 1, "capture_all")
	await process_frame
	check(int((runtime.call("result") as Dictionary).get("stingers", 0)) > 0, "winning terminal earns stingers")
	check(store.board(levels[1]).size() == 1, "winning time reaches challenge board")
	check(not has_meta("jukebox_result_commit_signature"), "campaign result cannot enter legacy map-only boards")
	for _frame in range(5):
		await process_frame
	var win_overlay: Node = current_scene.find_child("Arena", true, false).get("outcome_overlay")
	check((win_overlay.get("record_label") as Label).is_visible_in_tree(), "winning stingers and PB are visible")
	var result_panel: Control = win_overlay.get("panel")
	var record_label: Label = win_overlay.get("record_label")
	check(result_panel.get_global_rect().encloses(record_label.get_global_rect()) and record_label.get_parent() == win_overlay.get("vbox"), "winning rewards remain in the fixed result area")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(capture_dir.path_join("campaign-win.png"))
	runtime.call("request_return")
	await scene_changed
	await process_frame
	await process_frame
	check(not bool(runtime.call("is_active")), "return clears active session")
	var hub: Control = current_scene.get_node_or_null("CampaignHub") as Control
	check(hub != null, "return reopens Campaign")
	if hub != null:
		current_scene.call("_open_jukebox_panel")
		var jukebox: Node = current_scene.get("_challenge_hub")
		jukebox.call("select_level", str(levels[1].id))
		var bookmark: String = store.continue_id(runtime.call("player_id"))
		jukebox.call("_launch")
		await scene_changed
		check(bool(runtime.call("is_active")), "Jukebox launches unlocked challenge")
		check(str((runtime.call("active_level") as Dictionary).record_key) == str(levels[1].record_key), "both entrances launch the same record definition")
		check(store.continue_id(runtime.call("player_id")) == bookmark, "Jukebox does not displace Campaign Continue")
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await process_frame
	await process_frame
	_finish()

func _finish() -> void:
	print("CAMPAIGN_FLOW_SMOKE: %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	quit(0 if failures.is_empty() else 1)
