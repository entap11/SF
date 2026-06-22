extends SceneTree

var _failed: bool = false

func _initialize() -> void:
	await process_frame
	var arena_script := load("res://scripts/arena.gd")
	_expect_true(arena_script is Script, "Arena script should parse as a Script resource")
	var main_menu_script := load("res://scripts/ui/main_menu.gd")
	_expect_true(main_menu_script is Script, "Main menu script should parse as a Script resource")
	var shell_script := load("res://scripts/shell.gd")
	_expect_true(shell_script is Script, "Shell script should parse as a Script resource")
	var source := FileAccess.get_file_as_string("res://scripts/arena.gd")
	var main_menu_source := FileAccess.get_file_as_string("res://scripts/ui/main_menu.gd")
	var shell_source := FileAccess.get_file_as_string("res://scripts/shell.gd")
	_expect_true(source.contains("var _app_lifecycle: Node = null"), "Arena should keep an AppLifecycle reference")
	_expect_true(source.contains("_bind_app_lifecycle()"), "Arena ready path should bind AppLifecycle")
	_expect_true(source.contains("app_backgrounded"), "Arena should subscribe to app_backgrounded")
	_expect_true(source.contains("app_foregrounded"), "Arena should subscribe to app_foregrounded")
	_expect_true(source.contains("pause_match_clock"), "Arena background handler should freeze the authoritative match clock")
	_expect_true(source.contains("resume_match_clock"), "Arena foreground handler should resume the authoritative match clock")
	_expect_true(source.contains("func _is_pvp_runtime_active()"), "Arena should have a PvP runtime activity gate")
	_expect_true(source.contains("if _is_pvp_runtime_active():\n\t\treturn false"), "local lifecycle pause should skip active PvP runtime")
	_expect_true(source.contains("sim_runner.set_running(false, \"app_background\")"), "background handler should stop the local sim")
	_expect_true(source.contains("sim_runner.set_running(true, \"app_foreground\")"), "foreground handler should restore the local sim")
	_expect_true(source.contains("func _async_submission_expiry_snapshot"), "Arena should check async submission expiry before lifecycle resume")
	_expect_true(source.contains("TREE_META_VS_WINDOW_DEADLINE_UNIX"), "Arena should read the async run window deadline")
	_expect_true(source.contains("TREE_META_HIVE_TOURNAMENT_DEADLINE_UNIX"), "Arena should read hive tournament submission deadlines")
	_expect_true(source.contains("LIFECYCLE_CONTEST_EXPIRED_REASON"), "Arena should use a stable contest-expired end reason")
	_expect_true(source.contains("_expire_local_async_submission(expiry_snapshot, reason)"), "foreground handler should route expired async runs into expiry handling")
	_expect_true(source.contains("begin_match_end\", 0, LIFECYCLE_CONTEST_EXPIRED_REASON"), "expired async runs should end as non-winning results")
	_expect_true(source.contains("Submission window expired. This run cannot submit."), "stage overlay should explain expired submissions")
	_expect_true(source.contains("func _style_prematch_countdown_label()"), "Arena should centralize prematch countdown styling")
	_expect_true(source.contains("_prematch_countdown_label.anchor_right = 1.0"), "Prematch countdown should span the full viewport")
	_expect_true(source.contains("_prematch_countdown_label.anchor_bottom = 1.0"), "Prematch countdown should center vertically")
	_expect_true(source.contains("_prematch_countdown_label.add_theme_font_size_override(\"font_size\", 220)"), "Prematch countdown should use the large center-screen type")
	_expect_true(source.contains("if _is_progressive_runtime_mode():\n\t\tgame_over = true"), "Legacy Arena end-game path should route Progressive wins into Progressive handling")
	_expect_true(source.contains("_on_match_ended(winner, reason)"), "Legacy Arena end-game path should call match-ended handling for Progressive")
	_expect_true(source.contains("func _should_play_post_match_song"), "Arena should gate post-match music per mode")
	_expect_true(source.contains("return int(tree.get_meta(\"progressive_stage_index\", 0)) <= 0"), "Progressive post-match music should only play for stage 1")
	_expect_true(shell_source.contains("\"STAGE_RACE\", \"PROGRESSIVE\", \"TIMED_RACE\""), "Shell prematch HUD should include Progressive as a full-HUD mode")
	_expect_true(shell_source.contains("label.add_theme_font_size_override(\"font_size\", 220)"), "Shell prematch countdown should use the large center-screen type")
	_expect_true(shell_source.contains("progressive_stage_number"), "Shell prematch card should read Progressive stage metadata")
	_expect_true(main_menu_source.contains("tree.set_meta(\"hive_tournament_deadline_unix\""), "hive tournament launches should carry their submission deadline")
	_expect_true(main_menu_source.contains("\"hive_tournament_deadline_unix\""), "hive tournament deadline meta should be cleared between launches")
	if not _failed:
		print("ARENA_LIFECYCLE_PAUSE_SOURCE_SMOKE: PASS")
	quit(1 if _failed else 0)

func _expect_true(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("ARENA_LIFECYCLE_PAUSE_SOURCE_SMOKE: %s" % message)
