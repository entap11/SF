extends SceneTree

const TEST_VIEWPORT_SIZE := Vector2i(944, 2048)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = TEST_VIEWPORT_SIZE
	await process_frame
	var scene := load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		push_error("MAIN_MENU_HIVE_MOBILE_LAYOUT_SMOKE: failed to load MainMenu.tscn")
		quit(1)
		return
	var menu: Node = scene.instantiate()
	get_root().add_child(menu)
	await process_frame
	await process_frame

	var profile: Dictionary = {
		"view_mode": "member",
		"name": "The Swarmfathers",
		"tier": "Bronze",
		"member_role": "Queen",
		"office_title": "Queen",
		"ecosystem_rank": 47,
		"member_rank_within_hive": 1,
		"member_since_text": "Member for 16d",
		"hive_honey": 0,
		"hive_honey_total": 0,
		"member_count": 12,
		"member_capacity": 14,
		"pending_governance_count": 0,
		"can_spend_hive_honey": true,
		"pinned_notice_message": "",
		"pinned_notice_meta": "",
		"season_reset_text": "Resets in 12d 04h",
		"messages": [],
		"message_records": [],
		"achievements": [],
		"member_records": [],
		"created_at_unix": 0,
		"avg_member_service_days": 16,
		"tournament_wins": 0,
		"hive_championships": 0,
		"tournament_entries": {},
		"tournament_status_line": "",
		"leave_request": {},
		"invite_only": false,
		"can_post_hive_comms": true,
		"can_pin_hive_notice": true,
		"can_manage_invites": true,
		"pending_invite_count": 0,
		"received_application_count": 0
	}
	menu.set("_hive_panel_profile", profile)
	if menu.has_method("_apply_hive_panel_mobile_layout"):
		menu.call("_apply_hive_panel_mobile_layout")
	if menu.has_method("_refresh_hive_panel"):
		menu.call("_refresh_hive_panel")
	await process_frame

	var panel: Control = menu.get_node_or_null("DashPanel/DashHivePanel") as Control
	if panel == null:
		_fail("DashHivePanel missing")
		return
	var title: Label = menu.get_node_or_null("DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveTitle") as Label
	var sub: Label = menu.get_node_or_null("DashPanel/DashHivePanel/HiveVBox/HiveHeaderPanel/HiveHeaderVBox/HiveSub") as Label
	if title == null or title.text != "THE SWARMFATHERS":
		_fail("Hive identity title missing")
		return
	if title.get_theme_font_size("font_size") < 28:
		_fail("Hive title font too small")
		return
	if sub == null or sub.text.find("Rank #47") == -1 or sub.text.find("12/14 Members") == -1 or sub.text.find("Role: Queen") == -1:
		_fail("Hive identity metadata missing")
		return

	var overview_button: Button = menu.get_node_or_null("DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel/HiveOverviewVBox/HiveOverviewSectionButton") as Button
	var members_button: Button = menu.get_node_or_null("DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveRosterPanel/HiveRosterVBox/HiveMembersSectionButton") as Button
	var activity_button: Button = menu.get_node_or_null("DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivitySectionButton") as Button
	var comms_button: Button = menu.get_node_or_null("DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveCommsSectionButton") as Button
	var tournaments_button: Button = menu.get_node_or_null("DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTournamentsPanel/HiveTournamentsVBox/HiveTournamentsSectionButton") as Button
	for button in [overview_button, members_button, activity_button, comms_button, tournaments_button]:
		if button == null or button.custom_minimum_size.y < 48.0:
			_fail("Hive section button missing or too short")
			return

	var membership_text: String = _panel_text(menu.get_node_or_null("DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTopRow/HiveOverviewPanel"))
	if membership_text.find("Role: Queen") == -1 or membership_text.find("Time in Hive: 16d") == -1 or membership_text.find("Can Spend Honey: Yes") == -1:
		_fail("Membership card was not converted to readable label/value rows")
		return
	if membership_text.find("Leadership:") != -1:
		_fail("Old membership copy still present")
		return
	if membership_text.find("Founded:") == -1 or membership_text.find("Tournament Wins: 0") == -1:
		_fail("Compact trophy strip missing")
		return

	activity_button.pressed.emit()
	await process_frame
	var activity1: Label = menu.get_node_or_null("DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActivityPanel/HiveActivityVBox/HiveActivity1") as Label
	if activity1 == null or not activity1.visible or activity1.text != "No recent hive activity.":
		_fail("Recent Activity empty state missing")
		return

	comms_button.pressed.emit()
	await process_frame
	var comms_empty_count: int = _count_text(panel, "No hive communications yet.")
	if comms_empty_count != 1:
		_fail("Hive comms empty state should appear exactly once, got %d" % comms_empty_count)
		return
	var old_empty_count: int = _count_text(panel, "No hive comms yet")
	if old_empty_count != 0:
		_fail("Old repeated hive comms empty state still present")
		return

	var action_grid: GridContainer = menu.get_node_or_null("DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveActionsPanel/HiveActionsVBox/HiveActionsRow") as GridContainer
	if action_grid == null or action_grid.columns != 2:
		_fail("Hive action row is not a two-column mobile grid")
		return
	for child in action_grid.get_children():
		var action_button: Button = child as Button
		if action_button != null and action_button.visible and action_button.custom_minimum_size.y < 54.0:
			_fail("Hive action button too short")
			return

	tournaments_button.pressed.emit()
	await process_frame
	var tournament_detail: Label = menu.get_node_or_null("DashPanel/DashHivePanel/HiveVBox/HiveBody/HiveBodyVBox/HiveTournamentsPanel/HiveTournamentsVBox/HiveTournamentsDetail") as Label
	if tournament_detail == null or not tournament_detail.visible or tournament_detail.text != "No active hive tournament.":
		_fail("Tournament expandable section missing")
		return

	var close_button: Button = menu.get_node_or_null("DashPanel/DashHivePanel/HiveVBox/HiveClose") as Button
	if close_button == null or close_button.text != "Close" or close_button.icon != null or close_button.custom_minimum_size.y < 54.0:
		_fail("Hive close button is not readable text")
		return
	if close_button.get_theme_font_size("font_size") < 18:
		_fail("Hive close font too small")
		return

	print("MAIN_MENU_HIVE_MOBILE_LAYOUT_SMOKE: PASS")
	quit(0)

func _panel_text(node: Node) -> String:
	if node == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	_collect_text(node, parts)
	return "\n".join(parts)

func _collect_text(node: Node, parts: PackedStringArray) -> void:
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		_collect_text(child, parts)

func _count_text(node: Node, text: String) -> int:
	if node == null:
		return 0
	var count: int = 0
	if node is Label and (node as Label).text == text:
		count += 1
	elif node is Button and (node as Button).text == text:
		count += 1
	for child in node.get_children():
		count += _count_text(child, text)
	return count

func _fail(message: String) -> void:
	push_error("MAIN_MENU_HIVE_MOBILE_LAYOUT_SMOKE: %s" % message)
	quit(1)
