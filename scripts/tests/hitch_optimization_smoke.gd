extends SceneTree

const GAME_STATE := preload("res://scripts/state/game_state.gd")
const UNIT_RENDERER := preload("res://scripts/renderers/unit_renderer.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	_test_execution_metric_connectivity_cache()
	_test_bee_clip_endpoint_guard()
	if _failures.is_empty():
		print("HITCH_OPTIMIZATION_SMOKE_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("HITCH_OPTIMIZATION_SMOKE_FAIL %s" % failure)
	quit(1)

func _test_execution_metric_connectivity_cache() -> void:
	var state: GameState = GAME_STATE.new()
	state.hives = [
		HiveData.new(1, Vector2i(0, 0), 1, 100, "Hive"),
		HiveData.new(2, Vector2i(0, 5), 2, 100, "Hive"),
		HiveData.new(3, Vector2i(5, 0), 3, 100, "Hive")
	]
	state.rebuild_indexes()
	var expected_before: int = _direct_available_target_count(state, 1)
	var metrics_before: Dictionary = state.get_execution_metrics_for_hive(1)
	_assert_equal(int(metrics_before.get("available_targets", -1)), expected_before, "cached targets match direct geometry")
	state.lanes.append(LaneData.new(1, 1, 2, 1, true, false))
	state.rebuild_indexes()
	var expected_after: int = _direct_available_target_count(state, 1)
	var metrics_after: Dictionary = state.get_execution_metrics_for_hive(1)
	_assert_equal(int(metrics_after.get("available_targets", -1)), expected_after, "active lane is excluded from cached targets")

func _direct_available_target_count(state: GameState, source_id: int) -> int:
	var count: int = 0
	for hive_any in state.hives:
		var hive: HiveData = hive_any as HiveData
		if hive == null or int(hive.id) == source_id:
			continue
		var target_id: int = int(hive.id)
		if state.is_outgoing_lane_active(source_id, target_id):
			continue
		if state.can_connect(source_id, target_id):
			count += 1
	return count

func _test_bee_clip_endpoint_guard() -> void:
	var renderer: Node2D = UNIT_RENDERER.new()
	var node := Node2D.new()
	node.position = Vector2(500.0, 0.0)
	renderer.set("_unit_samples_by_id", {
		7: {"s1": {"a": Vector2.ZERO, "b": Vector2(1000.0, 0.0)}}
	})
	_assert_equal(bool(renderer.call("_unit_needs_live_bee_clip_update", 7, node)), false, "mid-lane clip work is skipped")
	node.position = Vector2(100.0, 0.0)
	_assert_equal(bool(renderer.call("_unit_needs_live_bee_clip_update", 7, node)), true, "endpoint clip work remains active")
	renderer.set("_bee_clip_collision_active_by_unit_id", {7: true})
	node.position = Vector2(500.0, 0.0)
	_assert_equal(bool(renderer.call("_unit_needs_live_bee_clip_update", 7, node)), true, "collision clip work remains active")
	node.free()
	renderer.free()

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s expected=%s actual=%s" % [label, str(expected), str(actual)])
