extends SceneTree

const BaselineBotPolicyScript := preload("res://scripts/bot/baseline_bot_policy.gd")
const OpsStateScript := preload("res://scripts/ops/ops_state.gd")

var _failed := false

func _init() -> void:
	await process_frame
	_test_balancer_and_raider_diverge_on_same_board()
	_test_raider_skips_suicidal_home_opener()
	_test_turtle_medium_pushes_when_shell_is_stable()
	if _failed:
		quit(1)
		return
	print("BOT_STYLE_SEPARATION_SMOKE: PASS")
	quit(0)

func _test_balancer_and_raider_diverge_on_same_board() -> void:
	var state := GameState.new()
	state.load_from_map_dict({
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "kind": "Hive", "power": 18},
			{"id": 2, "x": 1, "y": 0, "owner_id": 2, "kind": "Hive", "power": 8},
			{"id": 3, "x": 0, "y": 1, "owner_id": 3, "kind": "Hive", "power": 6},
			{"id": 4, "x": 1, "y": 1, "owner_id": 0, "kind": "Hive", "power": 5}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2},
			{"a_id": 1, "b_id": 3},
			{"a_id": 1, "b_id": 4},
			{"a_id": 2, "b_id": 4},
			{"a_id": 3, "b_id": 4}
		]
	})

	var ops_state := OpsStateScript.new()
	var policy := BaselineBotPolicyScript.new()
	var team_by_seat := {1: 1, 2: 2, 3: 1, 4: 4}

	var balancer_profile: Dictionary = ops_state.call("_build_bot_profile_for_seat", 1, "balancer", "medium") as Dictionary
	balancer_profile["team_by_seat"] = team_by_seat
	var balancer_intent: Dictionary = policy.choose_intent(state, 1, balancer_profile, 0)
	_assert_eq(str(balancer_intent.get("intent", "")), "feed", "balancer should stabilize the weak ally first")
	_assert_eq(int(balancer_intent.get("dst", 0)), 3, "balancer should feed the allied weak hive")

	var raider_profile: Dictionary = ops_state.call("_build_bot_profile_for_seat", 1, "raider", "medium") as Dictionary
	raider_profile["team_by_seat"] = team_by_seat
	var raider_intent: Dictionary = policy.choose_intent(state, 1, raider_profile, 0)
	_assert_eq(str(raider_intent.get("intent", "")), "attack", "raider should pressure the enemy-owned hive")
	_assert_eq(int(raider_intent.get("dst", 0)), 2, "raider should target the enemy-owned hive")
	ops_state.free()

func _test_raider_skips_suicidal_home_opener() -> void:
	var state := GameState.new()
	state.load_from_map_dict({
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "kind": "Hive", "power": 10},
			{"id": 2, "x": 5, "y": 0, "owner_id": 2, "kind": "Hive", "power": 10},
			{"id": 3, "x": 1, "y": 1, "owner_id": 0, "kind": "Hive", "power": 5},
			{"id": 4, "x": 4, "y": 1, "owner_id": 0, "kind": "Hive", "power": 5}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2},
			{"a_id": 1, "b_id": 3},
			{"a_id": 2, "b_id": 4}
		]
	})

	var ops_state := OpsStateScript.new()
	var policy := BaselineBotPolicyScript.new()
	var raider_profile: Dictionary = ops_state.call("_build_bot_profile_for_seat", 1, "raider", "medium") as Dictionary
	raider_profile["team_by_seat"] = {1: 1, 2: 2, 3: 3, 4: 4}
	var raider_intent: Dictionary = policy.choose_intent(state, 1, raider_profile, 0)
	_assert_eq(str(raider_intent.get("intent", "")), "attack", "raider should still open aggressively")
	_assert_eq(int(raider_intent.get("dst", 0)), 3, "raider should take the edge neutral instead of home-harassing first")
	ops_state.free()

# Full allied reserves make expansion unambiguously preferable to more feeding.
func _test_turtle_medium_pushes_when_shell_is_stable() -> void:
	var state := GameState.new()
	state.load_from_map_dict({
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "kind": "Hive", "power": 18},
			{"id": 2, "x": 4, "y": 0, "owner_id": 2, "kind": "Hive", "power": 9},
			{"id": 3, "x": 0, "y": 4, "owner_id": 3, "kind": "Hive", "power": 50},
			{"id": 4, "x": 3, "y": 3, "owner_id": 0, "kind": "Hive", "power": 6}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2},
			{"a_id": 1, "b_id": 3},
			{"a_id": 1, "b_id": 4}
		]
	})

	var ops_state := OpsStateScript.new()
	var policy := BaselineBotPolicyScript.new()
	var turtle_profile: Dictionary = ops_state.call("_build_bot_profile_for_seat", 1, "turtle", "medium") as Dictionary
	turtle_profile["team_by_seat"] = {1: 1, 2: 2, 3: 1, 4: 4}
	_assert_eq(state.can_connect(1, 4), true, "stable-shell fixture must offer an unobstructed neutral route")
	# A personality is probabilistic. A stable shell must yield neutral expansion
	# across decision opportunities, not one prescribed move at a single hash.
	var expansion_count := 0
	var choices: Dictionary = {}
	for tick_index in range(64):
		state.tick = tick_index
		var turtle_intent: Dictionary = policy.choose_intent(state, 1, turtle_profile, tick_index * 100)
		var key := "%s:%d" % [turtle_intent.get("intent", ""), turtle_intent.get("dst", 0)]
		choices[key] = int(choices.get(key, 0)) + 1
		if str(turtle_intent.get("intent", "")) == "attack" and int(turtle_intent.get("dst", 0)) == 4:
			expansion_count += 1
	_assert_eq(expansion_count >= 8, true, "a supplied turtle must regularly take the available neutral: %s" % choices)
	ops_state.free()

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_failed = true
	push_error("BOT_STYLE_SEPARATION_SMOKE: %s (expected %s, got %s)" % [label, str(expected), str(actual)])
