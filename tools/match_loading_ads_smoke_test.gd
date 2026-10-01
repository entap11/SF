extends SceneTree

const COVER_PATH: String = "res://scenes/ui/MainMenuLoadingCover.tscn"

class TestProfile:
	extends Node
	var zero_ads: bool = false
	func has_store_entitlement(flag: String) -> bool:
		return zero_ads and flag == "zero_ads"
	func get_user_id() -> String:
		return ""

class VideoProvider:
	extends RefCounted
	var video_path: String = "res://missing-ad-video.ogv"
	func request_ad(_slot: String, _placement: String, _policy: Dictionary) -> Dictionary:
		return {"filled": true, "creative": {"id": "loading-video-test", "video_path": video_path}}

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = root.get_node("AdManager")
	manager.call("clear_provider")
	manager.call("clear_measurement_events")
	var config_node: Node = root.get_node("OpsConfig")
	var config: Dictionary = config_node.call("get_config_snapshot")
	config["config_version"] = "match-loading-smoke"
	config["feature_flags"]["enable_ads"] = true
	config["feature_flags"]["enable_house_ads"] = false
	config["ads"]["external_ads_enabled"] = true
	config["ads"]["house_ads_enabled"] = false
	config_node.call("force_config_for_smoke", config, "remote_fresh")
	var original_profile: Node = root.get_node("ProfileManager")
	original_profile.name = "OriginalProfileManager"
	var profile := TestProfile.new()
	profile.name = "ProfileManager"
	root.add_child(profile)
	ProjectSettings.set_setting("swarmfront/ads/fake_ads", false)
	ProjectSettings.set_setting("swarmfront/ads/show_placeholders", false)
	var cover_scene: PackedScene = load(COVER_PATH)
	var cover: Variant = cover_scene.instantiate()
	root.add_child(cover)
	cover.minimum_visible_seconds = 0.01
	cover.fade_seconds = 0.0
	cover.eye_fade_delay_seconds = 0.0
	cover.eye_fade_seconds = 0.0
	cover.eye_final_brighten_seconds = 0.0
	var ad: Variant = cover.get_node("LoadingSponsor/MatchLoadingAd")
	var progress: ProgressBar = cover.get_node("LoadingProgress")
	var sponsor: Control = cover.get_node("LoadingSponsor")
	var internal: Variant = sponsor.get_node("SwarmfrontLoadingContent")
	if OS.get_cmdline_user_args().has("--preview-only"):
		ProjectSettings.set_setting("swarmfront/ads/fake_ads", true)
		profile.zero_ads = true
		await cover.present_for_match_readiness()
		cover.set_match_readiness_stage("render")
		await _capture_preview("-ad-free")
		cover.hide_immediately()
		profile.zero_ads = false
		await cover.present_for_match_readiness()
		cover.set_match_readiness_stage("render")
		await _capture_preview("")
		cover.hide_immediately()
		cover.free()
		profile.free()
		original_profile.name = "ProfileManager"
		print("MATCH_LOADING_PREVIEW: PASS")
		quit(0)
		return

	# No fill never introduces an artificial ten-second wait.
	var started: int = Time.get_ticks_msec()
	await cover.present_for_match_readiness()
	_expect(not sponsor.visible and not ad.is_pending(), "no-fill must hide the sponsor and skip the ad hold")
	await cover.release_after_match_ready()
	_expect(Time.get_ticks_msec() - started < 1000, "no-fill should release promptly")

	ProjectSettings.set_setting("swarmfront/ads/fake_ads", true)
	await cover.present_for_main_menu()
	_expect(not sponsor.visible and not ad.is_pending(), "menu/startup must never request an ad")
	await cover.release_after_main_menu_ready()
	profile.zero_ads = true
	started = Time.get_ticks_msec()
	var events_before: Array = manager.call("get_measurement_events")
	var slot_before: Dictionary = manager.call("get_slot_state", "match_loading")
	await cover.present_for_match_readiness()
	_expect(sponsor.visible and internal.visible and not ad.visible, "zero_ads must replace the ad with internal content")
	_expect(internal.is_pending() and not ad.is_pending(), "internal content must use its own loading hold")
	_expect(cover.get("_sponsor_label").text == "FROM SWARMFRONT", "internal content must not be labeled sponsored")
	await _capture_preview("-ad-free")
	await cover.release_after_match_ready()
	var internal_elapsed: int = Time.get_ticks_msec() - started
	_expect(internal_elapsed >= 9950 and internal_elapsed < 13000, "ad-free content must use the same ten-second loading window")
	_expect(manager.call("get_measurement_events") == events_before, "internal content must not emit ad measurements")
	_expect(manager.call("get_slot_state", "match_loading") == slot_before, "internal content must not request or fill an ad slot")
	internal.display_seconds = 0.1
	config["ads"]["loading_content_items"] = [
		{"kind": "match_highlight", "title": "Fixture highlight", "body": "Verified match content supplied by the test."},
		{"kind": "accomplishment", "title": "Fixture accomplishment", "body": "Verified achievement supplied by the test."},
	]
	config_node.call("force_config_for_smoke", config, "remote_fresh")
	await cover.present_for_match_readiness()
	var first_category: String = internal.category_label()
	cover.hide_immediately()
	await cover.present_for_match_readiness()
	_expect(internal.category_label() != first_category, "configured content must rotate between games")
	await cover.release_after_match_ready()
	profile.zero_ads = false

	# Exercise the real ten-second default once, including measurement and geometry.
	started = Time.get_ticks_msec()
	await cover.present_for_match_readiness()
	_expect(ad.is_pending() and sponsor.visible, "filled creative must hold the loading cover")
	cover.set_match_readiness_stage("render")
	cover.set_match_readiness_stage("scene")
	_expect(progress.value == 70.0, "readiness milestones must not move backwards")
	var bounds: Rect2 = root.get_visible_rect()
	_expect(sponsor.size.y >= bounds.size.y * 0.45, "sponsor area must occupy almost half the screen")
	_expect(ad.get_global_rect().position.y > cover.get_node("PreparationStatus").get_global_rect().end.y, "ad must sit below preparation copy")
	_expect(bounds.encloses(sponsor.get_global_rect()), "sponsor must remain within the viewport")
	await _capture_preview("")
	cover.release_after_match_ready()
	await create_timer(0.15).timeout
	_expect(cover.is_match_transition_active(), "ready arena must remain covered during the ad")
	while cover.is_transition_active() and Time.get_ticks_msec() - started < 14000:
		await process_frame
	var elapsed: int = Time.get_ticks_msec() - started
	_expect(not cover.is_transition_active() and elapsed >= 9950 and elapsed < 13000, "filled loading window must last about ten seconds, bounded by timeout (actual: %d ms)" % elapsed)
	var state: Dictionary = manager.call("get_slot_state", "match_loading")
	_expect(int(state.get("impressions", 0)) == 1, "loading creative must record exactly one viewable impression")
	_expect(state.get("reason") == "completed", "normal display should complete before its timeout")

	# Cancellation must not let an old release coroutine hide a later transition.
	ad.display_seconds = 1.0
	await cover.present_for_match_readiness()
	cover.release_after_match_ready()
	await process_frame
	cover.hide_immediately()
	cover.show_for_main_menu()
	await create_timer(0.1).timeout
	_expect(cover.is_transition_active() and not cover.is_match_transition_active(), "canceled release must not hide a newer menu transition")
	_expect(not ad.is_pending(), "cancellation must stop playback")
	cover.hide_immediately()

	# A failed creative and a stalled/hidden creative must both fail open.
	var provider := VideoProvider.new()
	manager.call("set_provider", provider)
	await cover.present_for_match_readiness()
	_expect(not ad.is_pending(), "missing video must not hold loading")
	await cover.release_after_match_ready()
	provider.video_path = ""
	await cover.present_for_match_readiness()
	_expect(not ad.is_pending(), "an unrenderable provider fill must not hold loading")
	await cover.release_after_match_ready()
	manager.call("clear_provider")
	ad.timeout_seconds = 0.25
	await cover.present_for_match_readiness()
	ad.hide()
	started = Time.get_ticks_msec()
	await cover.release_after_match_ready()
	_expect(Time.get_ticks_msec() - started < 1000, "stalled display must release at its deadline")
	state = manager.call("get_slot_state", "match_loading")
	_expect(state.get("reason") == "timeout", "stalled display should report timeout")

	var video_path: String = OS.get_environment("SF_LOADING_TEST_VIDEO")
	if not video_path.is_empty():
		provider.video_path = video_path
		manager.call("set_provider", provider)
		ad.timeout_seconds = 2.0
		ad.display_seconds = 10.0
		await cover.present_for_match_readiness()
		_expect(ad.is_pending(), "available video must enter playback")
		started = Time.get_ticks_msec()
		await cover.release_after_match_ready()
		state = manager.call("get_slot_state", "match_loading")
		_expect(state.get("reason") == "completed", "video should finish through its completion callback")
		_expect(Time.get_ticks_msec() - started < 1800, "short video must release on completion rather than wait ten seconds")
		manager.call("clear_provider")
		profile.zero_ads = true
		config["ads"]["loading_content_items"] = [{"kind": "promo", "title": "Swarmfront preview", "body": "Internal video fixture", "video_path": video_path}]
		config_node.call("force_config_for_smoke", config, "remote_fresh")
		events_before = manager.call("get_measurement_events")
		await cover.present_for_match_readiness()
		await process_frame
		_expect(internal.get("_video").is_playing(), "internal promo video should play")
		cover.hide_immediately()
		_expect(not internal.get("_video").is_playing(), "canceling loading must stop the internal video")
		_expect(manager.call("get_measurement_events") == events_before, "internal video must never emit ad measurements")
		profile.zero_ads = false

	ProjectSettings.set_setting("swarmfront/ads/fake_ads", false)
	cover.free()
	profile.free()
	original_profile.name = "ProfileManager"
	if not _failed:
		print("MATCH_LOADING_ADS_SMOKE: PASS")
	quit(1 if _failed else 0)

func _capture_preview(suffix: String) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--visual-path="):
			await RenderingServer.frame_post_draw
			var path: String = argument.trim_prefix("--visual-path=")
			root.get_texture().get_image().save_png(path.get_basename() + suffix + ".png")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("MATCH_LOADING_ADS_SMOKE: %s" % message)
