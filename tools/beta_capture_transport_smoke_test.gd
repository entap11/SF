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
	capture.call("begin", collector, {"map_id": "simple_syrup", "mode": "1V1"})
	capture.call("_flush_writer")
	var paths: Array = capture.call("pending_paths")
	assert(paths.size() == 1)
	capture.call("_upload_next")
	assert(capture.get("_http") == null, "active match capture must block upload")
	capture.call("finish", "completed", 1)
	capture.call("_flush_writer")
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
	print("BETA_CAPTURE_TRANSPORT_PASS: active-game exclusion, offline retention, HTTP gzip upload, receipt acknowledgement")
	quit(0)

func _wait_request(capture: Node) -> void:
	for index in 1000:
		if capture.get("_http") == null:
			return
		await create_timer(0.01).timeout
	push_error("transport smoke timed out")
	quit(1)
