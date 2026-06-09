extends SceneTree

var _failed: bool = false
var _background_signal_count: int = 0
var _foreground_signal_count: int = 0
var _focus_signal_count: int = 0
var _lifecycle_signal_count: int = 0

func _initialize() -> void:
	await process_frame
	var lifecycle: Node = get_root().get_node_or_null("/root/AppLifecycle")
	_expect_true(lifecycle != null, "AppLifecycle autoload should exist")
	if lifecycle == null:
		quit(1)
		return
	lifecycle.app_backgrounded.connect(func(_reason: String, _paused_at_msec: int, _paused_at_unix: int) -> void:
		_background_signal_count += 1
	)
	lifecycle.app_foregrounded.connect(func(_reason: String, _elapsed_msec: int, _resumed_at_unix: int) -> void:
		_foreground_signal_count += 1
	)
	lifecycle.app_focus_changed.connect(func(_focused: bool, _reason: String) -> void:
		_focus_signal_count += 1
	)
	lifecycle.lifecycle_changed.connect(func(_snapshot: Dictionary) -> void:
		_lifecycle_signal_count += 1
	)
	_test_background_foreground(lifecycle)
	_test_focus_events(lifecycle)
	_test_notification_router(lifecycle)
	if not _failed:
		print("APP_LIFECYCLE_SMOKE: PASS")
	quit(1 if _failed else 0)

func _test_background_foreground(lifecycle: Node) -> void:
	lifecycle.call("record_background_event", "smoke_background")
	var backgrounded: bool = bool(lifecycle.call("is_backgrounded"))
	_expect_true(backgrounded, "record_background_event should mark app backgrounded")
	var snap: Dictionary = lifecycle.call("get_snapshot") as Dictionary
	_expect_eq(str(snap.get("last_background_reason", "")), "smoke_background", "background reason should be tracked")
	_expect_true(int(snap.get("background_count", 0)) >= 1, "background count should increment")
	_expect_true(_background_signal_count >= 1, "background signal should emit")
	lifecycle.call("record_foreground_event", "smoke_foreground")
	_expect_true(not bool(lifecycle.call("is_backgrounded")), "record_foreground_event should clear app backgrounded")
	snap = lifecycle.call("get_snapshot") as Dictionary
	_expect_eq(str(snap.get("last_foreground_reason", "")), "smoke_foreground", "foreground reason should be tracked")
	_expect_true(int(snap.get("foreground_count", 0)) >= 1, "foreground count should increment")
	_expect_true(_foreground_signal_count >= 1, "foreground signal should emit")
	_expect_true(_lifecycle_signal_count >= 2, "lifecycle changed should emit for background and foreground")

func _test_focus_events(lifecycle: Node) -> void:
	lifecycle.call("record_focus_event", false, "smoke_focus_out")
	_expect_true(not bool(lifecycle.call("has_window_focus")), "focus out should clear window focus")
	lifecycle.call("record_focus_event", true, "smoke_focus_in")
	_expect_true(bool(lifecycle.call("has_window_focus")), "focus in should set window focus")
	var snap: Dictionary = lifecycle.call("get_snapshot") as Dictionary
	_expect_true(int(snap.get("focus_lost_count", 0)) >= 1, "focus lost count should increment")
	_expect_true(int(snap.get("focus_gained_count", 0)) >= 1, "focus gained count should increment")
	_expect_true(_focus_signal_count >= 2, "focus signal should emit for focus out and in")

func _test_notification_router(lifecycle: Node) -> void:
	_expect_true(bool(lifecycle.call("handle_lifecycle_notification", NOTIFICATION_APPLICATION_PAUSED)), "pause notification should be handled")
	_expect_true(bool(lifecycle.call("is_backgrounded")), "pause notification should mark backgrounded")
	_expect_true(bool(lifecycle.call("handle_lifecycle_notification", NOTIFICATION_APPLICATION_RESUMED)), "resume notification should be handled")
	_expect_true(not bool(lifecycle.call("is_backgrounded")), "resume notification should mark foregrounded")
	_expect_true(not bool(lifecycle.call("handle_lifecycle_notification", -999999)), "unknown notification should not be handled")

func _expect_true(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("APP_LIFECYCLE_SMOKE: %s" % message)

func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failed = true
	push_error("APP_LIFECYCLE_SMOKE: %s actual=%s expected=%s" % [message, str(actual), str(expected)])
