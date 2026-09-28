extends SceneTree

var failures: Array[String] = []
var ops: Node
var session: Node

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("BOT_PHONE: " + message)

func wait_running() -> bool:
	for _i in range(1200):
		await create_timer(0.05).timeout
		if int(ops.get("match_phase")) == 1 and current_scene != null and current_scene.name == "Shell":
			return true
	return false

func run() -> void:
	if not (OS.get_user_data_dir().contains("SwarmfrontBotPhoneChecks") or OS.get_user_data_dir().contains("SwarmfrontBetaCaptureChecks")):
		quit(2)
		return
	ops = root.get_node("OpsState")
	session = root.get_node("BotEvaluationSession")
	for game in [0, 1]:
		var result: Dictionary = session.call("request_launch", game)
		check(bool(result.get("ok", false)), "launch accepted")
		if not await wait_running():
			check(false, "launch reached RUNNING")
			break
		var state: GameState = ops.get("state")
		check(state.hives.size() == 7, "exact seven-hive map")
		check(str(ops.get("current_map_id")) == "MAP_simple_syrup__1p", "correct map id")
		check(int(ops.get("bot_match_seed")) == 9282026, "fixed seed applied")
		var active_seats := 0
		for player in ops.get("match_roster"):
			if bool(player.get("active", false)):
				active_seats += 1
		check(active_seats == 2, "two active players")
		check(str(ops.get("victory_mode")) == "conquest", "conquest rules")
		var profile: Dictionary = ops.call("get_bot_profile", 2)
		check(str(profile.get("style")) == ("balancer" if game == 0 else "raider"), "correct opponent")
		check(str(profile.get("tier")) == "medium", "medium tier")
		check(bool(profile.get("human_behavior_enabled", false)) == (game == 0), "pilot selection is explicit")
		check(not bool((ops.call("apply_authoritative_buff_command", {}) as Dictionary).get("ok", true)), "fixed empty buff loadout")
		var command: Dictionary = ops.call("apply_lane_intent", 1, 2, "attack")
		check(bool(command.get("ok", false)), "human command uses standard authority")
		await create_timer(7.0).timeout
		var partial: Dictionary = session.call("finish_recording", false)
		check(bool(partial.get("ok", false)), "partial export saved")
		if not bool(partial.get("ok", false)):
			break
		var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(partial.path)))
		check(not bool(payload.metadata.bot_evaluation.completed), "partial remains incomplete")
		check(payload.replay.frames.size() > 0, "board snapshots included")
		check(payload.metadata.bot_evaluation.map_sha256 == FileAccess.get_sha256("res://maps/tutorial/MAP_simple_syrup__1p.json"), "map fingerprint")
		var human_found := false
		var policy_found := false
		var choice_found := false
		for event in payload.events:
			if event.get("k", "") == "human_evaluation_intent":
				human_found = event.has("observation")
			if event.get("k", "") == "bot_started":
				policy_found = event.profile.get("policy", "baseline_v3") == ("human_balancer_v3" if game == 0 else "baseline_v3")
			if event.get("k", "") == "bot_evaluation_choice":
				choice_found = event.has("memory_before") and event.has("observation")
		check(human_found and policy_found, "human observation and effective bot policy persisted")
		if game == 0:
			check(choice_found, "Balancer choice context persisted")
		# Synthetic end only in the smoke fixture, through the simulation owner.
		ops.call("begin_match_end", 2, "capture_all", 0)
		ops.call("finalize_match_end")
		var arena: Node = current_scene.find_child("Arena", true, false)
		arena.call("_on_match_ended", 2, "capture_all")
		await process_frame
		await process_frame
		var saved: Dictionary = session.get("last_save")
		payload = JSON.parse_string(FileAccess.get_file_as_string(str(saved.path)))
		check(bool(payload.metadata.bot_evaluation.completed), "terminal recording complete")
		check(int(payload.metadata.winner_player_id) == 2, "actual winner exported")
		var capture := root.get_node("BetaMatchCapture")
		if bool(capture.call("enabled")):
			capture.call("_flush_writer")
			var completed_found := false
			for capture_path in capture.call("pending_paths"):
				var recording: Dictionary = preload("res://scripts/state/beta_capture_record.gd").read_record(capture_path)
				if recording.get("status") == "completed" and not recording.get("profiles", []).is_empty():
					if recording.profiles[0].get("style") == ("balancer" if game == 0 else "raider"):
						completed_found = recording.winner_seat == 2 and not recording.frames.is_empty() and not recording.events.is_empty()
			check(completed_found, "automatic beta archive records Arena lifecycle")
		var overlay: Node = arena.get("outcome_overlay")
		check((overlay.get("rematch_button") as Button).text == ("PLAY RAIDER" if game == 0 else "DONE"), "optional next game UI")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("SF_BOT_PHONE_ARTIFACTS").path_join("outcome-%d.png" % game))
		session.call("request_return")
		await scene_changed
		await process_frame
		check(not bool(session.call("is_active")), "return clears session")
		check(not bool(ops.call("bot_evaluation_active")), "normal gameplay cannot inherit evaluation")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SF_BOT_PHONE_ARTIFACTS").path_join("hub.png"))
	print("BOT_PHONE_EVALUATION_SMOKE: " + ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
