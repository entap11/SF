extends SceneTree

const MAIN_MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"

var _menu: Control = null

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(MAIN_MENU_SCENE_PATH) as PackedScene
	if scene == null:
		push_error("HIVE_INACTIVE_QUEEN_SUCCESSION_UI_SMOKE: failed to load MainMenu.tscn")
		quit(1)
		return
	_menu = scene.instantiate() as Control
	if _menu == null:
		push_error("HIVE_INACTIVE_QUEEN_SUCCESSION_UI_SMOKE: failed to instantiate MainMenu.tscn")
		quit(1)
		return
	get_root().add_child(_menu)
	await process_frame
	await process_frame
	var now_unix: int = int(Time.get_unix_time_from_system())
	_test_locked_until_twelve_weeks(now_unix)
	_test_active_soldier_can_claim_for_senior_soldier(now_unix)
	_test_queen_cannot_claim(now_unix)
	_test_inactive_local_member_cannot_claim(now_unix)
	_test_active_member_fallback_preview(now_unix)
	_test_succession_event_feed_label()
	print("HIVE_INACTIVE_QUEEN_SUCCESSION_UI_SMOKE: PASS")
	quit(0)

func _test_locked_until_twelve_weeks(now_unix: int) -> void:
	var status: Dictionary = _menu.call("_build_inactive_queen_succession_status", _hive(now_unix, {
		"q": _member("q", "Active Queen", "queen", now_unix - 10000, now_unix - 60, 1000),
		"s": _member("s", "Soldier", "soldier", now_unix - 9000, now_unix - 30, 800)
	}), "s", "soldier", now_unix) as Dictionary
	_assert_true(not bool(status.get("can_claim", false)), "active queen should keep succession locked")
	_assert_eq(str(status.get("button_text", "")), "SUCCESSION LOCKED", "locked state button text")

func _test_active_soldier_can_claim_for_senior_soldier(now_unix: int) -> void:
	var status: Dictionary = _menu.call("_build_inactive_queen_succession_status", _hive(now_unix, {
		"q": _member("q", "Inactive Queen", "queen", now_unix - 2000000, now_unix - (13 * 7 * 24 * 60 * 60), 1000),
		"s_old": _member("s_old", "Senior Soldier", "soldier", now_unix - 1000000, now_unix - 30, 800),
		"s_new": _member("s_new", "New Soldier", "soldier", now_unix - 500000, now_unix - 30, 1200),
		"m": _member("m", "Member", "member", now_unix - 400000, now_unix - 30, 5000)
	}), "s_new", "soldier", now_unix) as Dictionary
	_assert_true(bool(status.get("can_claim", false)), "active non-queen member should be able to claim eligible succession")
	_assert_eq(str(status.get("successor_player_id", "")), "s_old", "senior active soldier should preview as successor")

func _test_queen_cannot_claim(now_unix: int) -> void:
	var status: Dictionary = _menu.call("_build_inactive_queen_succession_status", _hive(now_unix, {
		"q": _member("q", "Inactive Queen", "queen", now_unix - 2000000, now_unix - (13 * 7 * 24 * 60 * 60), 1000),
		"s": _member("s", "Soldier", "soldier", now_unix - 9000, now_unix - 30, 800)
	}), "q", "queen", now_unix) as Dictionary
	_assert_true(not bool(status.get("can_claim", false)), "queen should not be able to claim own succession")
	_assert_eq(str(status.get("button_text", "")), "QUEEN CANNOT CLAIM", "queen self-claim button text")

func _test_inactive_local_member_cannot_claim(now_unix: int) -> void:
	var status: Dictionary = _menu.call("_build_inactive_queen_succession_status", _hive(now_unix, {
		"q": _member("q", "Inactive Queen", "queen", now_unix - 2000000, now_unix - (13 * 7 * 24 * 60 * 60), 1000),
		"m": _member("m", "Inactive Member", "member", now_unix - 9000, now_unix - (8 * 24 * 60 * 60), 800),
		"m2": _member("m2", "Active Member", "member", now_unix - 8000, now_unix - 30, 700)
	}), "m", "member", now_unix) as Dictionary
	_assert_true(not bool(status.get("can_claim", false)), "inactive local member should not be able to claim")
	_assert_eq(str(status.get("button_text", "")), "CHECK IN TO CLAIM", "inactive local member button text")

func _test_active_member_fallback_preview(now_unix: int) -> void:
	var status: Dictionary = _menu.call("_build_inactive_queen_succession_status", _hive(now_unix, {
		"q": _member("q", "Inactive Queen", "queen", now_unix - 2000000, now_unix - (13 * 7 * 24 * 60 * 60), 1000),
		"s_inactive": _member("s_inactive", "Inactive Soldier", "soldier", now_unix - 9000, now_unix - (8 * 24 * 60 * 60), 5000),
		"m_low": _member("m_low", "Low Member", "member", now_unix - 8000, now_unix - 30, 100),
		"m_high": _member("m_high", "High Member", "member", now_unix - 7000, now_unix - 30, 900)
	}), "m_low", "member", now_unix) as Dictionary
	_assert_true(bool(status.get("can_claim", false)), "active member should be able to claim when eligible")
	_assert_eq(str(status.get("successor_player_id", "")), "m_high", "highest-contribution active member should preview as fallback successor")

func _test_succession_event_feed_label() -> void:
	var label: String = str(_menu.call("_hive_feed_type_label", "hive_inactive_queen_succession_claimed"))
	_assert_eq(label, "GOVERNANCE", "succession event should be labeled as governance")

func _hive(now_unix: int, members: Dictionary) -> Dictionary:
	var out_members: Array[Dictionary] = []
	for member_any in members.values():
		out_members.append((member_any as Dictionary).duplicate(true))
	return {
		"hive_id": "h_ui_succession",
		"name": "UI Succession Smoke",
		"created_at_unix": now_unix - 3000000,
		"members": out_members,
		"member_count": out_members.size()
	}

func _member(player_id: String, display_name: String, role: String, joined_at_unix: int, last_seen_at_unix: int, honey: int) -> Dictionary:
	return {
		"player_id": player_id,
		"display_name": display_name,
		"role": role,
		"joined_at_unix": joined_at_unix,
		"last_seen_at_unix": last_seen_at_unix,
		"honey_contributed": honey
	}

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	push_error("HIVE_INACTIVE_QUEEN_SUCCESSION_UI_SMOKE: %s" % label)
	quit(1)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	push_error("HIVE_INACTIVE_QUEEN_SUCCESSION_UI_SMOKE: %s (expected %s, got %s)" % [label, expected, actual])
	quit(1)
