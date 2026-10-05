extends SceneTree

class TestProfile:
	extends Node
	var zero_ads: bool = false
	func has_store_entitlement(flag: String) -> bool:
		return zero_ads and flag == "zero_ads"
	func get_user_id() -> String:
		return ""

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = root.get_node("AdManager")
	var original_profile: Node = root.get_node("ProfileManager")
	original_profile.name = "OriginalProfileManager"
	var profile := TestProfile.new()
	profile.name = "ProfileManager"
	root.add_child(profile)
	ProjectSettings.set_setting("swarmfront/ads/dev_biodynamic_test_ads", true)
	ProjectSettings.set_setting("swarmfront/ads/dev_biodynamic_open_url_on_tap", false)
	manager.call("_install_dev_biodynamic_provider_if_enabled")
	manager.call("clear_measurement_events")
	var policy: Dictionary = manager.call("get_policy", "match_loading", "handshake")
	_expect(not policy.allowed, "installing the test creative must not enable live ads")
	var config_node: Node = root.get_node("OpsConfig")
	var config: Dictionary = config_node.call("get_config_snapshot")
	config["feature_flags"]["enable_ads"] = true
	config["ads"]["external_ads_enabled"] = true
	config_node.call("force_config_for_smoke", config, "remote_fresh")
	var scene: PackedScene = load("res://scenes/ui/MainMenuLoadingCover.tscn")
	var cover: Variant = scene.instantiate()
	root.add_child(cover)
	cover.minimum_visible_seconds = 0.01
	cover.eye_fade_delay_seconds = 0.0
	cover.eye_fade_seconds = 0.0
	cover.eye_final_brighten_seconds = 0.0
	cover.fade_seconds = 0.0
	var started: int = Time.get_ticks_msec()
	await cover.present_for_match_readiness()
	cover.set_match_readiness_stage("render")
	var ad: Variant = cover.get_node("LoadingSponsor/MatchLoadingAd")
	var state: Dictionary = manager.call("get_slot_state", "match_loading")
	_expect(state.get("filled", false), "loading slot should fill with supplied video")
	_expect(state.get("creative", {}).get("video_path", "").ends_with("biodynamic_mobile_loading_10s.ogv"), "loading must select the supplied video")
	_expect(state.get("creative", {}).get("destination_url", "") == "https://www.biodynamicusa.com", "video must use the requested destination")
	var video: VideoStreamPlayer = ad.get("_video")
	_expect(video != null and video.is_playing(), "video must actually play")
	_expect(video != null and video.volume_db <= -80.0, "video must start muted")
	await create_timer(0.2).timeout
	var frame: AspectRatioContainer = ad.get("_video_frame")
	_expect(frame != null and is_equal_approx(frame.ratio, 4.0 / 3.0), "video must keep its original 4:3 framing")
	var preview: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--visual-path="):
			preview = true
			await create_timer(3.8).timeout
			await _tap_and_check(ad, video, manager)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(argument.trim_prefix("--visual-path="))
	if preview:
		cover.hide_immediately()
	else:
		await _tap_and_check(ad, video, manager)
		await create_timer(2.1).timeout
		_expect(not ad.get_node("TapFeedback").visible and video.is_playing(), "confirmation must dismiss without interrupting video")
		await cover.release_after_match_ready()
		var elapsed: int = Time.get_ticks_msec() - started
		_expect(elapsed >= 9750 and elapsed < 13000, "video must complete in the ten-second loading window: %d ms" % elapsed)
		state = manager.call("get_slot_state", "match_loading")
		_expect(state.get("reason", "") == "completed", "video must finish normally, not time out")
		_expect(int(state.get("impressions", 0)) == 1, "video must record one viewable impression")
	var banner: Dictionary = manager.call("request_ad", "in_game_hud", "in_game")
	_expect(banner.get("creative", {}).get("image_path", "").ends_with("biodynamic_top_banner.png"), "in-game top slot must use its static banner")
	_expect(not banner.get("creative", {}).has("video_path"), "in-game slots must never receive the loading video")
	if not preview:
		profile.zero_ads = true
		var events: Array = manager.call("get_measurement_events")
		await cover.present_for_match_readiness()
		_expect(not ad.visible and cover.get_node("LoadingSponsor/SwarmfrontLoadingContent").visible, "ad-free players must receive internal content")
		cover.hide_immediately()
		_expect(manager.call("get_measurement_events") == events, "ad-free loading must emit no ad measurements")
	cover.free()
	profile.free()
	original_profile.name = "ProfileManager"
	manager.call("clear_provider")
	if not _failed:
		print("BIODYNAMIC_LOADING_AD_SMOKE: PASS")
	quit(1 if _failed else 0)

func _tap_and_check(ad: Control, video: VideoStreamPlayer, manager: Node) -> void:
	var has_clipboard: bool = DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)
	var original_clipboard: String = DisplayServer.clipboard_get() if has_clipboard else ""
	var position_before: float = video.stream_position
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	ad.call("_gui_input", tap)
	await process_frame
	var feedback: Label = ad.get("_tap_feedback_label")
	if has_clipboard:
		_expect(DisplayServer.clipboard_get() == "https://www.biodynamicusa.com", "tap must copy the URL to the system clipboard")
		_expect(feedback != null and feedback.text == "LINK COPIED", "successful copy must show confirmation")
		DisplayServer.clipboard_set(original_clipboard)
	else:
		_expect(feedback != null and feedback.text == "CLIPBOARD UNAVAILABLE", "unsupported clipboard must not report success")
	_expect(video.is_playing() and video.stream_position >= position_before, "copy must not pause or restart the video")
	var snapshot: Dictionary = manager.call("get_provider_debug_snapshot")
	_expect(snapshot.get("opened_urls", []).is_empty(), "tapping the ad must never invoke provider open")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("BIODYNAMIC_LOADING_AD_SMOKE: %s" % message)
