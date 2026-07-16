extends SceneTree

const HiveNodeScript := preload("res://scripts/hive/hive_node.gd")
const HiveGeometry := preload("res://scripts/sim/hive_geometry.gd")

var _failed := false

func _init() -> void:
	await process_frame
	var center := Vector2(100.0, 100.0)
	var radius := 20.0
	var right: Vector2 = HiveNodeScript.lane_shell_anchor_world(center, Vector2.RIGHT, radius)
	var left: Vector2 = HiveNodeScript.lane_shell_anchor_world(center, Vector2.LEFT, radius)
	var up: Vector2 = HiveNodeScript.lane_shell_anchor_world(center, Vector2.UP, radius)
	var down: Vector2 = HiveNodeScript.lane_shell_anchor_world(center, Vector2.DOWN, radius)
	var expected_skirt_y := center.y + (radius * HiveNodeScript.LANE_SHELL_SKIRT_Y_RADIUS_MULT) + HiveNodeScript.LANE_SHELL_SKIRT_Y_EXTRA_PX
	_expect(is_equal_approx(right.y, expected_skirt_y), "right-facing port must sit on the lower skirt")
	_expect(is_equal_approx(left.y, expected_skirt_y), "left-facing port must sit on the matching lower skirt")
	_expect(is_equal_approx(up.x, center.x) and up.y < center.y, "vertical-up port must keep its straight centerline")
	_expect(is_equal_approx(down.x, center.x) and down.y > center.y, "vertical-down port must keep its straight centerline")
	var medium_right: Vector2 = HiveNodeScript.lane_shell_anchor_world(center, Vector2.RIGHT, radius, HiveGeometry.TIER_2_MIN_POWER)
	var large_right: Vector2 = HiveNodeScript.lane_shell_anchor_world(center, Vector2.RIGHT, radius, HiveGeometry.TIER_3_MIN_POWER)
	_expect(medium_right.y > right.y, "medium-tier side port must follow the larger skirt")
	_expect(large_right.y > medium_right.y, "large-tier side port must follow the larger skirt")
	var large_up: Vector2 = HiveNodeScript.lane_shell_anchor_world(center, Vector2.UP, radius, HiveGeometry.TIER_3_MIN_POWER)
	_expect(large_up.is_equal_approx(up), "hive tier must not bend a vertical lane")

	var diagonal_dir := Vector2(1.0, 1.0).normalized()
	var diagonal: Vector2 = HiveNodeScript.lane_shell_anchor_world(center, diagonal_dir, radius)
	var diagonal_without_skirt := _ellipse_anchor(center, diagonal_dir, radius)
	var expected_diagonal_shift := ((radius * HiveNodeScript.LANE_SHELL_SKIRT_Y_RADIUS_MULT) + HiveNodeScript.LANE_SHELL_SKIRT_Y_EXTRA_PX) * absf(diagonal_dir.x)
	_expect(is_equal_approx(diagonal.y - diagonal_without_skirt.y, expected_diagonal_shift), "diagonal port must receive a proportional skirt offset")

	var pair: Dictionary = HiveNodeScript.lane_anchor_pair_world(Vector2.ZERO, Vector2(200.0, 0.0), null, radius, radius)
	var pair_a: Vector2 = pair.get("a", Vector2.INF)
	var pair_b: Vector2 = pair.get("b", Vector2.INF)
	_expect(is_equal_approx(pair_a.y, pair_b.y), "opposing horizontal skirt ports must share one baseline")
	_expect(pair_a.x > 0.0 and pair_b.x < 200.0, "opposing skirt ports must face each other")

	if _failed:
		quit(1)
		return
	print("HIVE_PORT_SKIRT_GEOMETRY_SMOKE: PASS")
	quit(0)

func _ellipse_anchor(center: Vector2, direction: Vector2, radius: float) -> Vector2:
	var dir := direction.normalized()
	var rx := radius * HiveNodeScript.LANE_SHELL_RADIUS_X_MULT
	var ry_mult: float = HiveNodeScript.LANE_SHELL_RADIUS_Y_BOTTOM_MULT if dir.y >= 0.0 else HiveNodeScript.LANE_SHELL_RADIUS_Y_TOP_MULT
	var ry := radius * ry_mult
	var denom := sqrt((dir.x * dir.x) / (rx * rx) + (dir.y * dir.y) / (ry * ry))
	return center + (dir / denom)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("HIVE_PORT_SKIRT_GEOMETRY_SMOKE: %s" % message)
