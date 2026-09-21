extends SceneTree

const Catalog = preload("res://scripts/state/campaign_catalog.gd")
const Exit = preload("res://scripts/state/match_exit_intent.gd")
var failed := false

class AdProvider:
	extends RefCounted
	var opened: Array[String] = []
	func request_ad(slot: String, _placement: String, _policy: Dictionary) -> Dictionary:
		return {"filled": true, "creative": {"id": slot, "title": "Swarmfront sponsor", "destination_url": "https://example.com/" + slot, "image_path": "res://assets/ads/test_creatives/biodynamic_laser_cleaning_banner.png"}}
	func open_ad(record: Dictionary, _event: Dictionary) -> Dictionary:
		opened.append(str(record.creative.destination_url))
		return {"ok": true, "opened": false, "test_provider": true}

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("MATCH_CHROME: " + message)

func capture(name: String) -> void:
	var folder := OS.get_environment("SF_CAMPAIGN_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name() == "headless":
		return
	await create_timer(0.3).timeout
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))

func tap_hive(arena: Node, hive_id: int) -> void:
	var api: Object = arena.get("api")
	var hive: HiveData = api.get_state().find_hive_by_id(hive_id)
	var local_pos: Vector2 = api.cell_center(hive.grid_pos)
	var input: Object = arena.get("input_system")
	for event_type in ["press", "release"]:
		input.call("handle_pointer_event", {"type": event_type, "button": MOUSE_BUTTON_LEFT,
			"local_pos": local_pos, "world_pos": local_pos, "screen_pos": local_pos,
			"is_touch": true, "hive_id": hive_id, "lane_id": -1}, api)

func _run() -> void:
	if not OS.get_user_data_dir().contains("SwarmfrontCampaignChecks-"):
		quit(2)
		return
	root.size = Vector2i(1080, 2348)
	node_added.connect(func(node: Node):
		if node.name == "BuffTargetingDeviceEvidenceCollector":
			node.call_deferred("set_process", false)
		elif node.name == "BuffTargetingDeviceEvidenceLayer":
			node.call_deferred("hide")
	)
	var profile: Node = root.get_node("ProfileManager")
	profile.call("smoke_force_identity_state", "01900000-0000-7000-8000-000000000003", "ABC 125", "Layout Pilot", true, true)
	profile.call("mark_onboarding_complete")
	profile.call("mark_tutorial_controls_completed")
	profile.call("mark_controls_hint_seen")
	var config_node: Node = root.get_node("OpsConfig")
	var config: Dictionary = config_node.call("get_config_snapshot")
	config["config_version"] = "match-chrome-fixture"
	config["feature_flags"]["enable_ads"] = true
	config["ads"]["external_ads_enabled"] = true
	config["ads"]["placements"] = {"handshake": true, "in_game": true, "post_match": true}
	config_node.call("force_config_for_smoke", config, "remote_fresh")
	var manager: Node = root.get_node("AdManager")
	var provider := AdProvider.new()
	manager.call("set_provider", provider)
	var runtime: Node = root.get_node("CampaignRuntime")
	var response: Dictionary = runtime.call("request_launch", str(Catalog.levels()[0].id), "campaign")
	check(bool(response.ok), "campaign launches")
	if not bool(response.ok):
		quit(1)
		return
	var ops: Node = root.get_node("OpsState")
	for i in range(600):
		await create_timer(0.05).timeout
		if current_scene != null and current_scene.name == "Shell" and int(ops.get("match_phase")) == 1:
			break
	check(int(ops.get("match_phase")) == 1, "match reaches running")
	var shell: Node = current_scene
	var collector: Node = shell.get_node_or_null("BuffTargetingDeviceEvidenceCollector")
	if collector != null:
		collector.set_process(false)
	var diagnostics: CanvasLayer = shell.get_node_or_null("BuffTargetingDeviceEvidenceLayer") as CanvasLayer
	if diagnostics != null:
		diagnostics.visible = false
	var arena: Node = shell.find_child("Arena", true, false)
	arena.call("_ensure_in_game_ad_surface")
	shell.call("_configure_shell_world_viewport_opening")
	await create_timer(0.5).timeout
	var layout: Dictionary = shell.call("get_match_hud_layout")
	var top: Control = arena.get("_in_game_ad_surface")
	var bottom: Control = arena.get("_bottom_match_ad_surface")
	check(top.is_visible_in_tree() and bottom.is_visible_in_tree(), "no-buff match has both banners")
	check(top.get_global_rect().is_equal_approx(layout.ad), "top creative fits declared slot")
	check(bottom.get_global_rect().is_equal_approx(layout.bottom_ad), "bottom creative fits declared slot")
	check(is_equal_approx(float(arena.call("_arena_playfield_top_screen_y")), float(layout.top_inset)), "actual battlefield meets header")
	check(not quit_on_go_back, "Android Back cannot silently quit a match")
	await capture("arena-no-buffs")
	var match_state: GameState = ops.call("get_state")
	var selected_source: int = -1
	for hive: HiveData in match_state.hives:
		if hive.owner_id == int(arena.get("active_player_id")):
			selected_source = hive.id
			break
	check(selected_source > 0, "fixture has a selectable player hive")
	tap_hive(arena, selected_source)
	await create_timer(0.2).timeout
	var lanes: Node = arena.find_child("LaneRenderer", true, false)
	lanes.call("_refresh_readability_context")
	var focus_context: Dictionary = lanes.get("readability_context")
	check(int(focus_context.get("focus_hive", -1)) == selected_source, "hive tap updates actual renderer focus")
	var destinations: Dictionary = focus_context.get("available_targets", {})
	check(not destinations.is_empty(), "selected player hive exposes new destinations")
	var hive_nodes: Dictionary = lanes.get("hive_nodes_by_id")
	for destination in destinations:
		var visual: Node = hive_nodes[destination].get_node("Visual")
		check(is_equal_approx(float(visual.get("_connection_opacity")), 1.0), "available destination is fully visible in the actual scene")
	await capture("arena-selected-hive")
	tap_hive(arena, selected_source)
	var tap: Dictionary = manager.call("record_tap", "in_game_hud")
	check(bool(tap.get("saved", false)) and provider.opened.is_empty(), "in-match tap saves without opening browser")
	manager.call("record_tap", "in_game_hud")
	check((manager.call("saved_match_ads") as Array).size() == 1, "repeat tap does not duplicate saved creative")
	check(not bool((manager.call("open_saved_match_ad", 0) as Dictionary).get("ok", false)), "saved link cannot open during gameplay")
	shell.call("_on_back_pressed")
	var menu: Control = shell.get("_match_menu_panel")
	check(menu != null and menu.is_visible_in_tree(), "Menu opens in place")
	await capture("match-menu")
	menu.call("_on_leave")
	check(current_scene == shell and (menu.get("_body") as Label).text.contains("won't unlock"), "first Leave warns without leaving")
	await capture("quit-confirmation")
	(menu.get("_resume") as Button).pressed.emit()
	await process_frame
	check(current_scene == shell and not is_instance_valid(shell.get("_match_menu_panel")), "No keeps the same match")
	# Capture staked wording without calling a financial service.
	shell.call("_open_match_menu")
	menu = shell.get("_match_menu_panel")
	menu.set("warning_text", Exit.warning({"paid": true}))
	menu.call("_on_leave")
	await capture("stake-confirmation")
	shell.call("_close_match_menu")
	# Switch only the presentation fixture to the existing buff-enabled debug path.
	runtime.call("finish_session")
	shell.call("_sync_buff_ui")
	shell.call("_configure_shell_world_viewport_opening")
	await process_frame
	await process_frame
	layout = shell.call("get_match_hud_layout")
	check(bool(layout.buffs_allowed), "buff-enabled fixture selects buff footer")
	check(not (shell.get("_ally_buff_strip") as Control).visible, "1v1 cannot show a nonexistent teammate")
	check(not bottom.visible, "buffs replace bottom ad")
	bottom.call("set_ad_available", true)
	check(not bottom.visible, "late ad fill cannot cover buff controls")
	var player_strip: Control = shell.get("_player_buff_strip")
	for slot in player_strip.find_children("BuffSlot?", "Panel", true, false):
		check((layout.footer as Rect2).encloses((slot as Control).get_global_rect()), "buff slot stays inside footer")
	await capture("arena-buffs")
	# Terminal result remains simulation-owned. No browser/network is opened by this fixture.
	ops.call("begin_match_end", 1, "capture_all", 0)
	ops.call("finalize_match_end")
	var runner: Node = shell.find_child("SimRunner", true, false)
	runner.emit_signal("match_ended", 1, "capture_all")
	for i in range(5):
		await process_frame
	var overlay: Node = arena.get("outcome_overlay")
	var saved_button: Button = overlay.get("_saved_ads_button")
	check(saved_button != null and saved_button.is_visible_in_tree(), "results offer saved ads")
	await capture("results-saved-ad")
	manager.call("mark_filled", "in_game_hud", "in_game", {}, {"id": "replacement", "destination_url": "https://example.com/replacement"})
	var opened: Dictionary = manager.call("open_saved_match_ad", 0)
	check(bool(opened.ok) and provider.opened == ["https://example.com/in_game_hud"], "results open original saved creative, not a later ad")
	saved_button.pressed.emit()
	await capture("saved-ads")
	current_scene.queue_free()
	current_scene = null
	await process_frame
	print("MATCH_CHROME_SMOKE: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
