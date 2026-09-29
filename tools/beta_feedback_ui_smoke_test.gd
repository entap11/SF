extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	if not OS.get_user_data_dir().contains("SwarmfrontBetaCaptureChecks"):
		quit(2)
		return
	var capture := root.get_node("BetaMatchCapture")
	var profile := root.get_node("ProfileManager")
	capture.call("offer_feedback", {"capture_id": "f".repeat(32), "owner_key": str(profile.call("get_user_id")).sha256_text()})
	capture.call("show_feedback_prompt")
	var panel: Node = capture.get("_feedback_panel")
	assert(panel != null)
	await process_frame
	await process_frame
	assert(panel.get("_save").disabled)
	var views: Array = []
	for spec in [["phone", Vector2i(1080, 1920)], ["compact", Vector2i(1080, 1080)]]:
		root.size = spec[1] / 2
		root.content_scale_size = spec[1]
		await process_frame
		await process_frame
		var save: Control = panel.get("_save")
		assert(root.get_visible_rect().encloses(save.get_global_rect()), "save must remain reachable")
		views.append({"name": spec[0], "viewport": str(root.get_visible_rect()), "save": str(save.get_global_rect())})
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("SF_BETA_FEEDBACK_ARTIFACTS").path_join("feedback-" + spec[0] + ".png"))
		panel.call("select_answer", "challenge", "about_right")
		panel.call("select_answer", "interesting", "yes")
		panel.call("select_answer", "controls", "no")
	capture.call("skip_feedback")
	await process_frame
	var evidence := FileAccess.open(OS.get_environment("SF_BETA_FEEDBACK_ARTIFACTS").path_join("ui-evidence.json"), FileAccess.WRITE)
	evidence.store_string(JSON.stringify({"passed": true, "views": views}, "\t"))
	evidence.close()
	print("BETA_FEEDBACK_UI_PASS: no default ratings, reachable save/skip on phone and compact viewports")
	quit(0)
