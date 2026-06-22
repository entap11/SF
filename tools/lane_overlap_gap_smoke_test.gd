extends SceneTree

const LaneOverlapGapsScript := preload("res://scripts/renderers/lane_overlap_gaps.gd")

var _failed: bool = false

func _init() -> void:
	var crossing: Dictionary = {
		"other": {
			"a_pos": Vector2(50.0, -50.0),
			"b_pos": Vector2(50.0, 50.0),
			"a_id": 3,
			"b_id": 4,
			"lane_id": 2,
			"z_index": 2,
			"width": 12.0
		}
	}
	var intervals: Array = LaneOverlapGapsScript.visible_intervals(
		Vector2(0.0, 0.0),
		Vector2(100.0, 0.0),
		1,
		1,
		2,
		1,
		12.0,
		crossing,
		"self",
		10.0,
		0.06,
		14.0
	)
	_expect(intervals.size() == 2, "lower-priority crossing lane should split into two visible intervals")
	if intervals.size() == 2:
		var left: Vector2 = intervals[0] as Vector2
		var right: Vector2 = intervals[1] as Vector2
		_expect(left.x == 0.0 and left.y < 0.5, "left interval should stop before crossing")
		_expect(right.x > 0.5 and right.y == 1.0, "right interval should resume after crossing")

	var lower_crossing: Dictionary = crossing.duplicate(true)
	(lower_crossing["other"] as Dictionary)["z_index"] = 0
	var uncut: Array = LaneOverlapGapsScript.visible_intervals(
		Vector2(0.0, 0.0),
		Vector2(100.0, 0.0),
		1,
		1,
		2,
		1,
		12.0,
		lower_crossing,
		"self",
		10.0,
		0.06,
		14.0
	)
	_expect(uncut.size() == 1 and (uncut[0] as Vector2) == Vector2(0.0, 1.0), "higher-priority lane should stay continuous")

	var shared_endpoint: Dictionary = crossing.duplicate(true)
	(shared_endpoint["other"] as Dictionary)["a_id"] = 2
	var joined: Array = LaneOverlapGapsScript.visible_intervals(
		Vector2(0.0, 0.0),
		Vector2(100.0, 0.0),
		1,
		1,
		2,
		1,
		12.0,
		shared_endpoint,
		"self",
		10.0,
		0.06,
		14.0
	)
	_expect(joined.size() == 1 and (joined[0] as Vector2) == Vector2(0.0, 1.0), "lanes sharing a hive endpoint should not be split")

	if _failed:
		quit(1)
		return
	print("LANE_OVERLAP_GAP_SMOKE: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("LANE_OVERLAP_GAP_SMOKE: %s" % message)
