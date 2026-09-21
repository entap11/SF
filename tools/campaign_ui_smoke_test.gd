extends SceneTree

const Catalog = preload("res://scripts/state/campaign_catalog.gd")
const Store = preload("res://scripts/state/campaign_progress_store.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("CAMPAIGN_UI: " + message)

func _run() -> void:
	if not OS.get_user_data_dir().contains("SwarmfrontCampaignChecks-"):
		push_error("Use tools/run_campaign_pilot_checks.py to isolate player data.")
		quit(2)
		return
	root.size = Vector2i(1080, 1920)
	var runtime: Node = root.get_node("CampaignRuntime")
	var store = Store.new()
	store.save_path = "user://campaign_ui.smoke.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.save_path))
	runtime.set("store", store)
	root.get_node("ProfileManager").call("smoke_force_identity_state", "01900000-0000-7000-8000-000000000002", "ABC 124", "UI Pilot", true, true)
	root.get_node("ProfileManager").call("mark_onboarding_complete")
	var scene: PackedScene = load("res://scenes/MainMenu.tscn")
	var menu: Node = scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	var main_button: Button = menu.get("menu_jukebox_button")
	check(main_button.text == "CAMPAIGN", "main entry is Campaign")
	check(not (main_button.get_node("SkinTex") as Control).visible, "old Jukebox artwork does not cover Campaign label")
	check(menu.get_node_or_null("DashPanel/DashRoot/JukeboxEntry") != null, "Dashboard offers Jukebox")
	await capture("main")
	menu.call("_open_campaign")
	await process_frame
	await process_frame
	var panel: Control = menu.get("_challenge_hub")
	check(panel != null and str(panel.get("mode")) == "campaign", "Campaign route opens shared hub")
	check(str(panel.get("selected_id")) == str(Catalog.levels()[0].id), "fresh Continue selects first level")
	check(not (panel.get("_play") as Button).disabled, "first level playable")
	for size_px in [Vector2i(1080, 1920), Vector2i(944, 2048), Vector2i(1080, 1500)]:
		root.size = size_px
		await process_frame
		await process_frame
		var play: Button = panel.get("_play")
		var back: Button = panel.get("_close")
		check(play.get_global_rect().end.y <= back.get_global_rect().position.y, "persistent actions do not overlap")
		check(panel.get_global_rect().encloses(back.get_global_rect()), "Back remains inside viewport")
		check(play.size.x <= panel.size.x and back.size.x <= panel.size.x, "actions fit width")
	root.size = Vector2i(1080, 1920)
	await process_frame
	await capture("campaign")
	menu.call("_close_challenge_hub")
	await process_frame
	menu.call("_open_jukebox_panel")
	await process_frame
	await process_frame
	panel = menu.get("_challenge_hub")
	check(str(panel.get("mode")) == "jukebox", "Dashboard route opens Jukebox selector")
	await capture("jukebox-initial")
	var bot: OptionButton = panel.get("_bot")
	bot.select(4)
	bot.item_selected.emit(4)
	await process_frame
	var chosen: Dictionary = Catalog.find(str(panel.get("selected_id")))
	check(str(chosen.get("bot", "")) == "swarm_lord", "bot selector resolves corresponding campaign level")
	check((panel.get("_play") as Button).disabled, "locked level browsable but cannot launch")
	check(str((panel.get("_heading") as Label).text).contains("LEVEL"), "Jukebox identifies campaign level")
	for _frame in range(5):
		await process_frame
	check(panel.get_global_rect().encloses((panel.get("_close") as Button).get_global_rect()), "Jukebox Back fits viewport")
	await capture("jukebox")
	menu.call("_close_challenge_hub")
	await process_frame
	check((menu.get("dash_panel") as Control).visible, "Jukebox Back returns to Dashboard")
	print("CAMPAIGN_UI_SMOKE: %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	quit(0 if failures.is_empty() else 1)

func capture(name: String) -> void:
	var directory: String = OS.get_environment("SF_CAMPAIGN_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await create_timer(0.3).timeout
	for _frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(directory.path_join(name + ".png"))
