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
