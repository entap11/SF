extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	if not OS.get_user_data_dir().contains("BetaCaptureTransportChecks"):
		quit(2)
		return
	var capture := root.get_node("BetaMatchCapture")
	var identity := root.get_node("PlayerIdentityRuntime")
	var profile := root.get_node("ProfileManager")
	profile.call("apply_backend_identity", {"id": "01900000-0000-7000-8000-000000000001", "call_sign": "BetaTest"})
	var token_state: RefCounted = identity.get("_session")
	token_state.call("accept_session_response", {"access_token": "local-beta-smoke", "session": {
		"player_id": profile.call("get_user_id"), "device_id": "local", "id": "local",
		"expires_at_unix": int(Time.get_unix_time_from_system()) + 600}})
	ProjectSettings.set_setting("swarmfront/identity/backend_url", OS.get_environment("SF_BETA_SMOKE_URL"))
	var collector := preload("res://scripts/state/match_telemetry_collector.gd").new()
	collector.begin_match("transport", "beta", "simple_syrup", 2, [1, 2], 1000, {})
	capture.call("begin", collector, {"map_id": "simple_syrup", "mode": "1V1", "local_seat": 1})
	capture.call("_flush_writer")
	var paths: Array = capture.call("pending_paths")
	assert(paths.size() == 1)
	capture.call("_upload_next")
	assert(capture.get("_http") == null, "active match capture must block upload")
	capture.call("finish", "completed", 1)
	capture.call("_flush_writer")
	var feedback_record := preload("res://scripts/state/beta_feedback_record.gd")
	var answers := {"experience": "new", "challenge": "about_right", "interesting": "yes", "controls": "yes"}
	capture.call("show_feedback_prompt")
	var panel: Node = capture.get("_feedback_panel")
	assert(panel != null)
	assert(panel.get("_save").disabled, "feedback must not have preselected ratings")
	for key in answers:
		panel.call("select_answer", key, answers[key])
	assert(not panel.get("_save").disabled)
	capture.call("_close_feedback_panel")
	assert(feedback_record.read_json(feedback_record.PROMPT_PATH).draft == answers, "draft survives closing UI")
	capture.call("show_feedback_prompt")
	panel = capture.get("_feedback_panel")
	assert(panel.get("_answers") == answers, "restored prompt must read saved draft")
	assert(capture.call("submit_feedback", answers))
	var feedback_path: String = paths[0].trim_suffix(".json.gz") + ".feedback.json"
	assert(FileAccess.file_exists(feedback_path), "feedback needs an independent durable queue entry")
	assert(not FileAccess.file_exists(feedback_record.PROMPT_PATH), "submitted prompt must not repeat")
	capture.call("_upload_next")
	assert(capture.get("_http") == null, "local-only feedback must not upload")
	capture.call("set_sharing", true)
	capture.call("_upload_next")
	print("UPLOAD_STARTED=", capture.get("_http") != null, " collector=", capture.get("_collector") != null, " running=", root.get_node("OpsState").call("is_match_running"), " auth=", identity.call("is_authenticated"))
	await _wait_request(capture)
	assert(FileAccess.file_exists(paths[0]), "network failure must retain recording")
	capture.call("_upload_next")
	print("UPLOAD_STARTED=", capture.get("_http") != null, " collector=", capture.get("_collector") != null, " running=", root.get_node("OpsState").call("is_match_running"), " auth=", identity.call("is_authenticated"))
	await _wait_request(capture)
	if FileAccess.file_exists(paths[0]):
		print("BETA_CAPTURE_TRANSPORT_FAILURE ", capture.call("queue_status"), " authenticated=", identity.call("is_authenticated"))
		quit(1)
		return
	assert(FileAccess.file_exists(feedback_path), "game receipt cannot delete feedback")
	capture.call("_upload_next")
	await _wait_request(capture)
	assert(FileAccess.file_exists(feedback_path), "wrong feedback hash must retain the answer")
	capture.call("_upload_next")
	await _wait_request(capture)
	assert(not FileAccess.file_exists(feedback_path), "matching feedback receipt must remove the answer")
	# Identity scoping and skip: neither may produce a submitted answer.
	capture.call("offer_feedback", {"capture_id": "d".repeat(32), "owner_key": "e".repeat(64)})
	capture.call("show_feedback_prompt")
	assert(capture.get("_feedback_panel") == null)
	assert(not capture.call("submit_feedback", answers))
	capture.call("skip_feedback")
	assert(not FileAccess.file_exists(feedback_record.PROMPT_PATH))
	print("BETA_CAPTURE_TRANSPORT_PASS: capture and feedback retry, receipt isolation, sharing, saved draft, skip and owner scoping")
	quit(0)

func _wait_request(capture: Node) -> void:
	for index in 1000:
		if capture.get("_http") == null:
			return
		await create_timer(0.01).timeout
	push_error("transport smoke timed out")
	quit(1)
