extends SceneTree

const GameStateScript := preload("res://scripts/state/game_state.gd")
const OpsStateScript := preload("res://scripts/ops/ops_state.gd")

var _failed: bool = false

func _initialize() -> void:
	await process_frame
	var ops_state: Node = get_root().get_node_or_null("/root/OpsState")
	_expect(ops_state != null, "OpsState autoload should exist")
	if ops_state == null:
		quit(1)
		return
	var previous_test_timer: bool = bool(ops_state.get("SF_TEST_MATCH_TIMER"))
	var previous_state: GameState = ops_state.call("get_state") as GameState
	ops_state.set("SF_TEST_MATCH_TIMER", true)
	var fixture_state: GameState = GameStateScript.new()
	fixture_state.init_core_defaults()
	ops_state.set("state", fixture_state)
	ops_state.call("reset_match_state")
	_expect(
		int(ops_state.get("match_regulation_duration_ms")) == int(OpsStateScript.MATCH_DURATION_MS_TEST),
		"reset should capture the configured immutable regulation duration"
	)
	_expect(
		int(ops_state.get("match_duration_ms")) == int(ops_state.get("match_regulation_duration_ms")),
		"active duration should begin equal to regulation duration"
	)

	ops_state.set("in_overtime", true)
	ops_state.set("ot_checked", true)
	ops_state.set("match_duration_ms", int(ops_state.get("match_duration_ms")) + 60000)
	_expect(
		int(ops_state.get("match_regulation_duration_ms")) == int(OpsStateScript.MATCH_DURATION_MS_TEST),
		"overtime extension must not mutate regulation duration"
	)

	var snapshot: Dictionary = ops_state.call("get_authority_snapshot") as Dictionary
	_expect(
		int(snapshot.get("match_regulation_duration_ms", 0)) == int(OpsStateScript.MATCH_DURATION_MS_TEST),
		"authority snapshot should include regulation duration"
	)
	ops_state.set("match_regulation_duration_ms", 123)
	ops_state.set("in_overtime", false)
	ops_state.set("ot_checked", false)
	ops_state.call("restore_authority_snapshot", snapshot)
	_expect(
		int(ops_state.get("match_regulation_duration_ms")) == int(OpsStateScript.MATCH_DURATION_MS_TEST),
		"restore should recover regulation duration"
	)
	_expect(bool(ops_state.get("in_overtime")), "restore should recover overtime state")
	_expect(bool(ops_state.get("ot_checked")), "restore should recover overtime check state")

	ops_state.set("SF_TEST_MATCH_TIMER", previous_test_timer)
	ops_state.set("state", previous_state)
	ops_state.call("reset_match_state")
	if _failed:
		quit(1)
		return
	print("MATCH_SHADOW_CLOCK_CONTRACT_SMOKE: PASS")
	quit(0)

func _expect(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("MATCH_SHADOW_CLOCK_CONTRACT_SMOKE: %s" % message)
