extends SceneTree

var _failed: bool = false

func _init() -> void:
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
	overlay.show_outcome(1, "conquest", 1, "Record: 99-99", "H2H: noisy")
	await process_frame

	_assert_eq(_label_text(overlay, "Panel/VBox/Title"), "GAME OVER", "title")
	_assert_eq(_label_text(overlay, "Panel/VBox/Result"), "You won", "result")
	_assert_eq(_label_text(overlay, "Panel/VBox/Reason"), "Win by domination.", "reason")
	_assert_true(not _node_visible(overlay, "Panel/VBox/Record"), "record hidden")
	_assert_true(not _node_visible(overlay, "Panel/VBox/H2H"), "h2h hidden")
	_assert_true(not _node_visible(overlay, "Panel/VBox/StatsHeader"), "stats hidden")
	_assert_eq(_label_text(overlay, "Panel/VBox/Status"), "Play again?", "status")
	_assert_true(_font_size(overlay, "Panel/VBox/Title") >= 30, "title font should be readable")
	_assert_true(_font_size(overlay, "Panel/VBox/Result") >= 24, "result font should be readable")
	_assert_true(_button_min_height(overlay, "Panel/VBox/Buttons/Rematch") >= 58.0, "rematch button should be readable")
	var panel: Control = overlay.get_node_or_null("Panel") as Control
	_assert_true(panel != null and panel.custom_minimum_size.x >= 360.0 and panel.custom_minimum_size.y >= 420.0, "outcome panel should be larger")

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
	_assert_eq(_label_text(overlay, "Panel/VBox/Title"), "GAUNTLET 2 OF 18", "progressive title")
	_assert_eq(_label_text(overlay, "Panel/VBox/Result"), "STAGE RESULT: YOU WON", "progressive result")
	_assert_eq(_label_text(overlay, "Panel/VBox/H2H"), "Run Stars: 7 / 72", "progressive running tally")
	_assert_eq(_button_text(overlay, "Panel/VBox/Buttons/Rematch"), "Next Stage", "progressive next button")
	_assert_true(not _node_visible(overlay, "Panel/VBox/Buttons/Rematch"), "progressive next button hidden during auto-advance")
	_assert_eq(_label_text(overlay, "Panel/VBox/StatUnitsLanded"), "Next stage starts automatically.", "progressive auto-advance text")

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

	if _failed:
		quit(1)
		return
	print("OUTCOME_OVERLAY_SMOKE: PASS")
	quit(0)

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
	var label: Label = root.get_node_or_null(path) as Label
	if label == null:
		return "<missing>"
	return label.text

func _node_visible(root: Node, path: String) -> bool:
	var control: Control = root.get_node_or_null(path) as Control
	return control != null and control.visible

func _font_size(root: Node, path: String) -> int:
	var label: Label = root.get_node_or_null(path) as Label
	if label == null:
		return 0
	return int(label.get_theme_font_size("font_size"))

func _button_min_height(root: Node, path: String) -> float:
	var button: Button = root.get_node_or_null(path) as Button
	if button == null:
		return 0.0
	return float(button.custom_minimum_size.y)

func _button_text(root: Node, path: String) -> String:
	var button: Button = root.get_node_or_null(path) as Button
	if button == null:
		return "<missing>"
	return button.text

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
