extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	await process_frame
	var ops_state: Node = get_root().get_node_or_null("/root/OpsState")
	_expect_true(ops_state != null, "OpsState autoload should exist")
	if ops_state == null:
		quit(1)
		return
	var tree: SceneTree = self
	tree.set_meta("vs_mode", "PROGRESSIVE")
	tree.set_meta("progressive_bot_attack_grace_ms", 20000)
	tree.set_meta("progressive_human_owner_id", 1)
	var state: GameState = ops_state.call("reset_state_from_map", {
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 2, "x": 4, "y": 0, "owner_id": 2, "power": 50, "kind": "Hive"},
			{"id": 3, "x": 8, "y": 0, "owner_id": 0, "power": 5, "kind": "Hive"}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2},
			{"a_id": 2, "b_id": 3}
		]
	})
	_expect_true(state != null, "state should reset")
	ops_state.set("match_roster", [
		{"seat": 1, "is_cpu": false, "active": true},
		{"seat": 2, "is_cpu": true, "active": true}
	])
	ops_state.set("match_phase", 1)
	ops_state.set("match_elapsed_ms", 5000)
	var blocked: Dictionary = ops_state.call("apply_lane_intent", 2, 1, "attack")
	_expect_true(not bool(blocked.get("ok", false)), "CPU attack into human should be blocked during grace")
	_expect_eq(str(blocked.get("reason", "")), "progressive_attack_grace", "blocked attack reason")
	var neutral: Dictionary = ops_state.call("apply_lane_intent", 2, 3, "attack")
	_expect_true(bool(neutral.get("ok", false)), "CPU attack into neutral should remain allowed during grace")
	_expect_true(not bool(tree.get_meta("progressive_bot_attack_grace_broken", false)), "CPU neutral attack should not break bot grace")
	var still_blocked: Dictionary = ops_state.call("apply_lane_intent", 2, 1, "attack")
	_expect_eq(str(still_blocked.get("reason", "")), "progressive_attack_grace", "CPU should still be blocked after neutral expansion")
	ops_state.call("reset_state_from_map", {
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 2, "x": 4, "y": 0, "owner_id": 2, "power": 50, "kind": "Hive"}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2}
		]
	})
	ops_state.set("match_roster", [
		{"seat": 1, "is_cpu": false, "active": true},
		{"seat": 2, "is_cpu": true, "active": true}
	])
	ops_state.set("match_phase", 1)
	ops_state.set("match_elapsed_ms", 5000)
	tree.set_meta("progressive_bot_attack_grace_broken", false)
	var human_bot: Dictionary = ops_state.call("apply_lane_intent", 1, 2, "attack")
	_expect_true(bool(human_bot.get("ok", false)), "human attack into CPU should be allowed during grace")
	_expect_true(bool(tree.get_meta("progressive_bot_attack_grace_broken", false)), "human attack into CPU should break bot grace")
	var retaliate: Dictionary = ops_state.call("apply_lane_intent", 2, 1, "attack")
	_expect_true(bool(retaliate.get("ok", false)), "CPU attack into human should be allowed after human breaks grace")
	ops_state.call("reset_state_from_map", {
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 2, "x": 4, "y": 0, "owner_id": 2, "power": 50, "kind": "Hive"}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2}
		]
	})
	ops_state.set("match_roster", [
		{"seat": 1, "is_cpu": false, "active": true},
		{"seat": 2, "is_cpu": true, "active": true}
	])
	ops_state.set("match_phase", 1)
	ops_state.set("match_elapsed_ms", 20000)
	var expired: Dictionary = ops_state.call("apply_lane_intent", 2, 1, "attack")
	_expect_true(bool(expired.get("ok", false)), "CPU attack into human should be allowed after grace expires")
	for key in ["vs_mode", "progressive_bot_attack_grace_ms", "progressive_human_owner_id", "progressive_bot_attack_grace_broken"]:
		if tree.has_meta(key):
			tree.remove_meta(key)
	if not _failed:
		print("PROGRESSIVE_BOT_GRACE_SMOKE: PASS")
	quit(1 if _failed else 0)


func _expect_true(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("PROGRESSIVE_BOT_GRACE_SMOKE: %s" % message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failed = true
	push_error("PROGRESSIVE_BOT_GRACE_SMOKE: %s actual=%s expected=%s" % [message, str(actual), str(expected)])
