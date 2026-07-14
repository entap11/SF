extends SceneTree

const BuffTargetResolverScript = preload("res://scripts/state/buff_target_resolver.gd")

class FakeGameState:
	extends RefCounted
	var tick: int = 42
	var hives: Array = [
		{"id": 1, "owner_id": 1},
		{"id": 2, "owner_id": 1},
		{"id": 3, "owner_id": 2}
	]
	var lanes: Array = [
		{"id": 10, "a_id": 1, "b_id": 3},
		{"id": 11, "a_id": 1, "b_id": 2},
		{"id": 12, "a_id": 1, "b_id": 99},
		{"id": 13, "a_id": 1, "b_id": 2, "send_a": false, "send_b": false}
	]

var _failed: bool = false

func _init() -> void:
	var resolver := BuffTargetResolverScript.new()
	var state := FakeGameState.new()

	var hive_preview: Dictionary = resolver.get_preview_eligible_targets(state, 1, "buff_unit_speed_classic")
	_expect(bool(hive_preview.get("ok", false)), "hive preview succeeds")
	_expect(str(hive_preview.get("target_type", "")) == "hive", "hive target type is authoritative")
	_expect((hive_preview.get("eligible_target_ids", []) as Array) == [1, 2], "only owned stable hive IDs are eligible")
	_expect(bool(resolver.validate_canonical_target(state, 1, "buff_unit_speed_classic", "hive", 2).get("ok", false)), "owned hive validates")
	_expect(not bool(resolver.validate_canonical_target(state, 1, "buff_unit_speed_classic", "hive", 3).get("ok", false)), "enemy hive rejects")

	var lane_preview: Dictionary = resolver.get_preview_eligible_targets(state, 1, "buff_freeze_lane_classic")
	_expect(bool(lane_preview.get("ok", false)), "lane preview succeeds")
	_expect((lane_preview.get("eligible_target_ids", []) as Array) == [10, 11], "only active lanes with stable endpoints are eligible")
	_expect(bool(resolver.validate_canonical_target(state, 1, "buff_freeze_lane_classic", "lane", 10).get("ok", false)), "stable lane validates")
	state.lanes = [{"id": 11, "a_id": 1, "b_id": 2}]
	var stale: Dictionary = resolver.validate_canonical_target(state, 1, "buff_freeze_lane_classic", "lane", 10)
	_expect(not bool(stale.get("ok", false)) and str(stale.get("reason", "")) == "target_ineligible", "stale lane deterministically rejects")

	var global_preview: Dictionary = resolver.get_preview_eligible_targets(state, 1, "buff_global_production_boost_classic")
	_expect((global_preview.get("eligible_target_ids", []) as Array) == ["global"], "global target uses explicit stable token")
	_expect(bool(resolver.validate_canonical_target(state, 1, "buff_global_production_boost_classic", "global", "global").get("ok", false)), "global token validates")
	_expect(not bool(resolver.validate_canonical_target(state, 1, "buff_global_production_boost_classic", "global", 1).get("ok", false)), "coordinate-like global target rejects")
	var perf: Dictionary = resolver.performance_snapshot()
	_expect(not bool(perf.get("per_frame_processing", true)) and int(perf.get("retained_target_sets", -1)) == 0, "eligibility scans are request-scoped with no retained per-frame allocation")

	if _failed:
		quit(1)
		return
	print("BUFF_TARGET_RESOLVER_SMOKE: PASS")
	quit(0)

func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_TARGET_RESOLVER_SMOKE: %s" % label)
