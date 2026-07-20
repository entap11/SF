extends SceneTree

var _failed: bool = false

func _init() -> void:
	get_root().size = Vector2i(944, 2048)
	await process_frame
	var overlay: OutcomeOverlay = OutcomeOverlay.new()
	overlay.name = "OutcomeOverlay"
	_build_overlay_children(overlay)
	get_root().add_child(overlay)
	await process_frame

	var ops_state: Node = get_root().get_node_or_null("OpsState")
	if ops_state == null:
		push_error("OUTCOME_OVERLAY_SMOKE: OpsState autoload missing")
		quit(1)
		return
	ops_state.set("rematch_deadline_ms", Time.get_ticks_msec() + 10000)
	var votes_any: Variant = ops_state.get("rematch_votes")
	if typeof(votes_any) == TYPE_DICTIONARY:
		(votes_any as Dictionary).clear()
	ops_state.set("post_end_action", "")
	set_meta("battle_pass_latest_nectar_award", {
		"xp_awarded": 61,
		"base_xp": 38,
		"xp_multiplier": 1.6,
		"nectar_breakdown": {
			"participation_nectar": 10,
			"win_bonus_nectar": 8,
			"first_win_bonus_nectar": 20
		}
	})
	overlay.show_outcome(1, "conquest", 1, "Record: 99-99", "H2H: noisy")
	await process_frame

	_assert_eq(_label_text(overlay, "Panel/VBox/Title"), "GAME OVER", "title")
	_assert_eq(_label_text(overlay, "Panel/VBox/Result"), "You won", "result")
	_assert_eq(_label_text(overlay, "Panel/VBox/Reason"), "Win by domination.", "reason")
	_assert_true(not _node_visible(overlay, "Panel/VBox/Record"), "record hidden")
	_assert_true(not _node_visible(overlay, "Panel/VBox/H2H"), "h2h hidden")
	_assert_true(not _node_visible(overlay, "Panel/VBox/StatsHeader"), "stats hidden")
	_assert_eq(_label_text(overlay, "Panel/VBox/NectarSummary"), "Nectar earned: +61 (play +10, win +8, first win +20, 1.6x pass)", "nectar summary")
	_assert_eq(_label_text(overlay, "Panel/VBox/Status"), "Play again?", "status")
	_assert_true(_font_size(overlay, "Panel/VBox/Title") >= 70, "title must meet the enlarged in-game screen-title floor")
	_assert_true(_font_size(overlay, "Panel/VBox/Result") >= 60, "result must meet the enlarged in-game panel-title floor")
	_assert_true(_font_size(overlay, "Panel/VBox/Reason") >= 40, "reason must meet the enlarged in-game body floor")
	_assert_true(_font_size(overlay, "Panel/VBox/NectarSummary") >= 40, "economy summary must meet the enlarged in-game body floor")
	_assert_true(_font_size(overlay, "Panel/VBox/Countdown") >= 40, "rematch countdown must meet the enlarged in-game body floor")
	_assert_true(_font_size(overlay, "Panel/VBox/Status") >= 40, "decision status must meet the enlarged in-game body floor")
	_assert_true(_button_font_size(overlay, "Panel/VBox/Buttons/Exit") >= 43, "main-menu action must meet the enlarged in-game button floor")
	_assert_true(_button_min_height(overlay, "Panel/VBox/Buttons/Rematch") >= 110.0, "rematch button must meet the enlarged persistent-action floor")
	var panel: Control = overlay.get_node_or_null("Panel") as Control
	_assert_true(panel != null and panel.custom_minimum_size.x >= 880.0 and panel.custom_minimum_size.y < 1150.0, "simple outcome panel should hug its reformatted content")
	_assert_true(_node_visible(overlay, "Panel/VBox/Buttons"), "wide outcome actions should use the two-column row")
	_assert_true(not _node_visible(overlay, "Panel/VBox/StackedButtons"), "wide outcome actions should not use the narrow stack")

	overlay.call("set_post_match_stats", _sample_stats_snapshot())
	await process_frame
	_assert_true(_node_visible(overlay, "PostMatchStatsPanel"), "enabled standard outcome should show canonical match statistics")
	_assert_eq(_label_text(overlay, "MatchLength"), "MATCH LENGTH   04:32", "authoritative match length")
	_assert_true(overlay.find_child("PlayerComparisonTable", true, false) != null, "wide 1v1 should use a comparison table")
	_assert_eq(_label_text(overlay, "Player1_hives_captured"), "7", "local hives captured")
	_assert_eq(_label_text(overlay, "Player2_units_created"), "280", "opponent units created")
	_assert_eq(_label_text(overlay, "Player1_units_landed"), "201", "local units landed")
	_assert_eq(_label_text(overlay, "Player2_swarms_initiated"), "14", "opponent swarms initiated")
	_assert_content_fits(overlay, "944x2048 standard stats result")

	set_meta("vs_mode", "ASYNC_SINGLE_MAP_TIMED")
	set_meta("jukebox_board_enabled", true)
	overlay.show_outcome(1, "conquest", 1)
	overlay.call("set_post_match_stats", _sample_stats_snapshot())
	await process_frame
	_assert_true(_node_visible(overlay, "PostMatchStatsPanel"), "Jukebox map result should show canonical match statistics")
	set_meta("jukebox_board_enabled", false)
	overlay.call("set_post_match_stats", _sample_stats_snapshot())
	await process_frame
	_assert_true(not _node_visible(overlay, "PostMatchStatsPanel"), "non-Jukebox single-map timed result should keep standard stats hidden")
	remove_meta("jukebox_board_enabled")
	remove_meta("vs_mode")
	overlay.call("set_post_match_stats", _sample_stats_snapshot())
	await process_frame

	get_root().size = Vector2i(720, 1280)
	overlay.call("_apply_readable_layout_for_size", Vector2(720.0, 1280.0))
	overlay.call("set_post_match_stats", _four_player_stats_snapshot())
	overlay.call("_apply_readable_layout_for_size", Vector2(720.0, 1280.0))
	await process_frame
	var player_cards: VBoxContainer = overlay.find_child("PlayerCards", true, false) as VBoxContainer
	_assert_true(player_cards != null and player_cards.get_child_count() == 4, "four-player outcome should use four stacked cards")
	_assert_true(player_cards != null and player_cards.get_child(0).name == "Player3Card", "local player card should sort first")
	_assert_true(player_cards != null and player_cards.get_child(1).name == "Player2Card", "non-local winner should sort after the local player")
	_assert_content_fits(overlay, "720x1280 four-player stats result")
	get_root().size = Vector2i(944, 2048)
	overlay.call("_apply_readable_layout")
	await process_frame

	_set_crucible_tree_meta()
	overlay.show_outcome(1, "capture_all", 1)
	overlay.call("set_post_match_stats", _sample_stats_snapshot())
	await process_frame
	_assert_true(not _node_visible(overlay, "PostMatchStatsPanel"), "Crucible must reject the standard stats component")
	_assert_eq(_label_text(overlay, "Panel/VBox/StatsHeader"), "Wax Wager", "crucible header")
	_assert_eq(_label_text(overlay, "Panel/VBox/StatMaxHivePower"), "Wax: start 50.000 Wax | after escrow 49.000 Wax | finish 50.800 Wax", "crucible balance status")
	_assert_eq(_label_text(overlay, "Panel/VBox/StatUnitsKilled"), "Stake 1.000 Wax | Winner payout 1.800 Wax | Award reserve 0.200 Wax | Net +0.800 Wax", "crucible stake status")
	_assert_eq(_label_text(overlay, "Panel/VBox/StatUnitsLanded"), "Crucible settlement: Settled. You won this Wax match.", "crucible settlement status")
	_assert_true(_font_size(overlay, "Panel/VBox/StatUnitsKilled") >= 40, "essential Wax status must meet the enlarged in-game body floor")
	_assert_content_fits(overlay, "944x2048 Crucible result")
	get_root().size = Vector2i(720, 1280)
	overlay.call("_apply_readable_layout_for_size", Vector2(720.0, 1280.0))
	await process_frame
	_assert_content_fits(overlay, "720x1280 Crucible result")
	_assert_true(_node_visible(overlay, "Panel/VBox/StackedButtons"), "narrow outcome actions should stack vertically")
	_assert_true(not _node_visible(overlay, "Panel/VBox/Buttons"), "narrow outcome actions should leave the two-column row")
	_assert_true(panel != null and panel.size.x <= 664.0 and panel.size.y <= 1224.0, "narrow outcome panel should respect the reformatted layout bounds")
	overlay.call("_apply_readable_layout_for_size", Vector2(432.0, 768.0))
	await process_frame
	_assert_content_fits(overlay, "432x768 compact-window Crucible result")
	_assert_true(panel != null and panel.size.x <= 376.0 and panel.size.y <= 712.0, "compact-window outcome panel should remain inside its layout bounds")
	get_root().size = Vector2i(944, 2048)
	overlay.call("_apply_readable_layout")
	await process_frame
	_clear_crucible_tree_meta()
	if has_meta("battle_pass_latest_nectar_award"):
		remove_meta("battle_pass_latest_nectar_award")

	overlay.show_stage_round_outcome({
		"mode_id": "PROGRESSIVE",
		"stage_number": 2,
		"stage_count": 18,
		"winner_id": 1,
		"local_player_id": 1,
		"reason": "capture_all",
		"elapsed_ms": 59000,
		"stars": 3,
		"total_stars": 7,
		"max_stars": 72,
		"thresholds_ms": {
			"four_star_ms": 52000,
			"three_star_ms": 62000,
			"two_star_ms": 72000
		},
			"next_label": "Next Stage",
			"exit_label": "Main Menu",
			"next_round_available": true,
			"next_button_enabled": true,
			"status_text": "Run stars: 7 / 72. Ready for the next stage?"
		})
	await process_frame
	_assert_true(not _node_visible(overlay, "PostMatchStatsPanel"), "Progressive result must keep standard stats hidden")
	_assert_eq(_label_text(overlay, "Panel/VBox/Title"), "GAUNTLET 2 OF 18", "progressive title")
	_assert_eq(_label_text(overlay, "Panel/VBox/Result"), "STAGE RESULT: YOU WON", "progressive result")
	_assert_eq(_label_text(overlay, "Panel/VBox/H2H"), "Run Stars: 7 / 72", "progressive running tally")
	_assert_eq(_button_text(overlay, "Panel/VBox/Buttons/Rematch"), "Next Stage", "progressive next button")
	_assert_true(not _node_visible(overlay, "Panel/VBox/Buttons/Rematch"), "progressive next button hidden during auto-advance")
	_assert_eq(_label_text(overlay, "Panel/VBox/StatUnitsLanded"), "Next stage starts automatically.", "progressive auto-advance text")
	_assert_content_fits(overlay, "944x2048 progressive stage result")

	overlay.show_stage_round_outcome({
		"round_number": 3,
		"total_rounds": 3,
		"winner_id": 1,
		"local_player_id": 1,
		"reason": "capture_all",
		"round_time_ms": 64000,
		"cumulative_time_ms": 191000,
		"local_owned_hives": 8,
		"opponent_owned_hives": 0,
		"current_rank": 1,
		"local_round_wins": 3,
		"opponent_round_wins": 0,
		"paid_entry": true,
		"wager_cents": 2000,
		"async_money_escrow_cents": 2000,
		"async_money_pot_cents": 2000,
		"async_money_balance_start_cents": 50000,
		"async_money_balance_after_entry_cents": 48000,
		"async_money_balance_finish_cents": 48000,
		"async_money_ledger_status": "escrowed",
		"next_label": "Finish Run",
		"exit_label": "Back to Lobby",
		"next_round_available": false,
		"next_button_enabled": true,
		"status_text": "Cumulative rank is provisional. Run complete."
	})
	await process_frame
	_assert_eq(_label_text(overlay, "Panel/VBox/StatsHeader"), "Money Status", "paid stage money header")
	_assert_eq(_label_text(overlay, "Panel/VBox/StatMaxHivePower"), "Wallet: start $500.00 | after entry $480.00 | finish $480.00", "paid stage wallet status")
	_assert_eq(_label_text(overlay, "Panel/VBox/StatUnitsKilled"), "Entry: $20.00 | Rank: #1 provisional | Pot: $20.00", "paid stage rank status")
	_assert_eq(_label_text(overlay, "Panel/VBox/StatUnitsLanded"), "Payout pending until contest close (3/3 maps).", "paid stage payout pending")
	_assert_content_fits(overlay, "944x2048 paid stage result")

	var tutorial_actions: Array[String] = []
	overlay.post_match_action.connect(func(action: String) -> void:
		tutorial_actions.append(action)
	)
	overlay.show_tutorial_controls_complete(1, "conquest", 1)
	await process_frame
	_assert_eq(_label_text(overlay, "Panel/VBox/Title"), "TUTORIAL COMPLETE", "controls tutorial completion title")
	_assert_eq(_label_text(overlay, "Panel/VBox/Result"), "Great! Now you know how the controls work.", "controls tutorial completion message")
	_assert_eq(_label_text(overlay, "Panel/VBox/Reason"), "Let's get you into a real game and put those skills to work.", "controls tutorial follow-up message")
	_assert_eq(_button_text(overlay, "Panel/VBox/Buttons/Exit"), "START NOW", "controls tutorial immediate follow-up action")
	_assert_true(_label_text(overlay, "Panel/VBox/Status").begins_with("Starting your first 1v1 in "), "controls tutorial auto-launch countdown")
	overlay.set("_tutorial_followup_auto_at_ms", Time.get_ticks_msec() - 1)
	overlay.call("_process", 0.0)
	_assert_true(tutorial_actions.has("tutorial_controls_followup"), "controls tutorial must auto-launch the easy 1v1 follow-up")

	overlay.show_tutorial_welcome_pack(1, "conquest", 1, 12, 2)
	await process_frame
	_assert_eq(_label_text(overlay, "Panel/VBox/Title"), "WELCOME PACK", "tutorial Welcome Pack title")
	_assert_eq(_label_text(overlay, "Panel/VBox/Result"), "GREAT FIRST WIN", "tutorial Welcome Pack result")
	_assert_eq(_label_text(overlay, "Panel/VBox/Record"), "12 Classic buff types", "tutorial Welcome Pack type count")
	_assert_eq(_label_text(overlay, "Panel/VBox/H2H"), "2 of every type", "tutorial Welcome Pack quantity")
	_assert_eq(_button_text(overlay, "Panel/VBox/Buttons/Exit"), "OPEN PACK", "tutorial Welcome Pack open action")
	_assert_true(not _node_visible(overlay, "Panel/VBox/Buttons/Rematch"), "tutorial Welcome Pack hides rematch")
	var welcome_open_button: Button = overlay.get_node_or_null("Panel/VBox/Buttons/Exit") as Button
	_assert_true(welcome_open_button != null, "tutorial Welcome Pack open button exists")
	if welcome_open_button != null:
		welcome_open_button.emit_signal("pressed")
	_assert_true(tutorial_actions.has("tutorial_welcome_pack_open"), "tutorial Welcome Pack emits claim-and-return action")

	if _failed:
		quit(1)
		return
	print("OUTCOME_OVERLAY_SMOKE: PASS")
	quit(0)

func _sample_stats_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"match_instance_id": "outcome_smoke",
		"duration_ms": 272000,
		"players": [
			{
				"seat": 1,
				"player_id": "local_smoke",
				"display_name": "Local Pilot",
				"team_id": 1,
				"is_local": true,
				"is_winner": true,
				"hives_captured": 7,
				"units_created": 312,
				"units_landed": 201,
				"swarms_initiated": 18
			},
			{
				"seat": 2,
				"player_id": "remote_smoke",
				"display_name": "BUFFBOT WITH A VERY LONG NAME",
				"team_id": 2,
				"is_local": false,
				"is_winner": false,
				"hives_captured": 4,
				"units_created": 280,
				"units_landed": 176,
				"swarms_initiated": 14
			}
		]
	}

func _four_player_stats_snapshot() -> Dictionary:
	var snapshot: Dictionary = _sample_stats_snapshot()
	snapshot["players"] = [
		{"seat": 1, "display_name": "ALPHA", "team_id": 1, "is_local": false, "is_winner": false, "hives_captured": 2, "units_created": 210, "units_landed": 150, "swarms_initiated": 11},
		{"seat": 2, "display_name": "BRAVO", "team_id": 2, "is_local": false, "is_winner": true, "hives_captured": 8, "units_created": 330, "units_landed": 245, "swarms_initiated": 22},
		{"seat": 3, "display_name": "LOCAL", "team_id": 3, "is_local": true, "is_winner": false, "hives_captured": 5, "units_created": 290, "units_landed": 201, "swarms_initiated": 17},
		{"seat": 4, "display_name": "DELTA WITH THE LONGEST NAME", "team_id": 4, "is_local": false, "is_winner": false, "hives_captured": 3, "units_created": 260, "units_landed": 188, "swarms_initiated": 15}
	]
	return snapshot

func _build_overlay_children(overlay: Control) -> void:
	var panel: Panel = Panel.new()
	panel.name = "Panel"
	overlay.add_child(panel)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	panel.add_child(vbox)
	for label_name in [
		"Title",
		"Result",
		"Reason",
		"Record",
		"H2H",
		"StatsHeader",
		"StatMaxHivePower",
		"StatUnitsKilled",
		"StatUnitsLanded",
		"Countdown",
		"Status"
	]:
		var label: Label = Label.new()
		label.name = label_name
		vbox.add_child(label)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "Buttons"
	vbox.add_child(buttons)
	var rematch: Button = Button.new()
	rematch.name = "Rematch"
	buttons.add_child(rematch)
	var exit: Button = Button.new()
	exit.name = "Exit"
	buttons.add_child(exit)

func _label_text(root: Node, path: String) -> String:
	var label: Label = _node_by_path_or_name(root, path) as Label
	if label == null:
		return "<missing>"
	return label.text

func _node_visible(root: Node, path: String) -> bool:
	var control: Control = _node_by_path_or_name(root, path) as Control
	return control != null and control.visible

func _font_size(root: Node, path: String) -> int:
	var label: Label = _node_by_path_or_name(root, path) as Label
	if label == null:
		return 0
	return int(label.get_theme_font_size("font_size"))

func _button_min_height(root: Node, path: String) -> float:
	var button: Button = _node_by_path_or_name(root, path) as Button
	if button == null:
		return 0.0
	return float(button.custom_minimum_size.y)

func _button_font_size(root: Node, path: String) -> int:
	var button: Button = _node_by_path_or_name(root, path) as Button
	if button == null:
		return 0
	return int(button.get_theme_font_size("font_size"))

func _assert_content_fits(overlay: OutcomeOverlay, label: String) -> void:
	var panel: Control = overlay.get_node_or_null("Panel") as Control
	var vbox: VBoxContainer = overlay.get_node_or_null("Panel/VBox") as VBoxContainer
	if panel == null or vbox == null:
		_assert_true(false, "%s hierarchy missing" % label)
		return
	var available_height: float = vbox.size.y
	var required_height: float = vbox.get_combined_minimum_size().y
	_assert_true(required_height <= available_height + 1.0, "%s content clips: required %.1f available %.1f" % [label, required_height, available_height])
	var viewport_rect: Rect2 = overlay.get_viewport().get_visible_rect()
	var panel_rect: Rect2 = panel.get_global_rect()
	_assert_true(panel_rect.position.x >= -1.0 and panel_rect.end.x <= viewport_rect.size.x + 1.0, "%s panel exceeds viewport width" % label)
	_assert_true(panel_rect.position.y >= -1.0 and panel_rect.end.y <= viewport_rect.size.y + 1.0, "%s panel exceeds viewport height" % label)
	for button_name in ["Rematch", "Exit"]:
		var button: Button = overlay.find_child(button_name, true, false) as Button
		if button == null or not button.visible:
			continue
		var button_rect: Rect2 = button.get_global_rect()
		_assert_true(panel_rect.encloses(button_rect), "%s %s action exceeds the fixed footer: panel=%s button=%s parent=%s" % [label, button_name, str(panel_rect), str(button_rect), str(button.get_parent().name)])

func _button_text(root: Node, path: String) -> String:
	var button: Button = _node_by_path_or_name(root, path) as Button
	if button == null:
		return "<missing>"
	return button.text

func _node_by_path_or_name(root: Node, path: String) -> Node:
	var direct: Node = root.get_node_or_null(path)
	if direct != null:
		return direct
	var segments: PackedStringArray = path.split("/", false)
	if segments.is_empty():
		return null
	return root.find_child(segments[segments.size() - 1], true, false)

func _set_crucible_tree_meta() -> void:
	set_meta("vs_crucible", true)
	set_meta("crucible_local_balance_start_millis", 50000)
	set_meta("crucible_local_balance_after_escrow_millis", 49000)
	set_meta("crucible_local_balance_finish_millis", 50800)
	set_meta("crucible_stake_each_millis", 1000)
	set_meta("crucible_winner_payout_millis", 1800)
	set_meta("crucible_burn_millis", 0)
	set_meta("crucible_award_reserve_millis", 200)
	set_meta("crucible_balance_delta_millis", 800)
	set_meta("crucible_settlement_status", "SETTLED")

func _clear_crucible_tree_meta() -> void:
	for key in [
		"vs_crucible",
		"crucible_local_balance_start_millis",
		"crucible_local_balance_after_escrow_millis",
		"crucible_local_balance_finish_millis",
		"crucible_stake_each_millis",
		"crucible_winner_payout_millis",
		"crucible_burn_millis",
		"crucible_award_reserve_millis",
		"crucible_balance_delta_millis",
		"crucible_settlement_status"
	]:
		if has_meta(key):
			remove_meta(key)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	push_error("OUTCOME_OVERLAY_SMOKE: %s expected=%s actual=%s" % [label, str(expected), str(actual)])
	_failed = true

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	push_error("OUTCOME_OVERLAY_SMOKE: assertion failed %s" % label)
	_failed = true
