extends SceneTree

const HiveNodeScene := preload("res://scenes/hive/HiveNode.tscn")
const HiveGeometry := preload("res://scripts/sim/hive_geometry.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not is_equal_approx(float(SimTuning.UNIT_SPEED_PX_PER_SEC), 176.4):
		_fail("unit speed should be 5 percent above 168.0")
		return
	var arena_source: String = FileAccess.get_file_as_string("res://scripts/arena.gd")
	var input_source: String = FileAccess.get_file_as_string("res://scripts/systems/input_system.gd")
	if not arena_source.contains("const HIVE_PICK_PADDING_PX := 0.0"):
		_fail("arena hive pick padding should be zero")
		return
	if not input_source.contains("const DRAG_HOVER_EXTRA_PX := 36.0"):
		_fail("drag hover extra radius should aggressively snap near hive silhouettes")
		return
	if not input_source.contains("const DEST_HIVE_ASSIST_SCALE := 1.30"):
		_fail("destination assist scale should be above neutral")
		return

	var node: Node = HiveNodeScene.instantiate()
	get_root().add_child(node)
	await process_frame
	node.call("apply_render", 1, 10, 27.0, Color(0.9, 0.7, 0.2, 1.0), 14, "Hive", 0, 2)
	await process_frame

	var body_shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var pick_shape := node.get_node_or_null("PickShape2D") as CollisionShape2D
	if body_shape == null or pick_shape == null:
		_fail("hive collision shapes should exist")
		return
	if not (body_shape.shape is CircleShape2D):
		_fail("hive body shape should be a circle")
		return
	if not (pick_shape.shape is CircleShape2D):
		_fail("hive pick shape should be a circle")
		return
	var body_circle := body_shape.shape as CircleShape2D
	var pick_circle := pick_shape.shape as CircleShape2D
	if not is_equal_approx(body_circle.radius, 27.0):
		_fail("hive body radius should match render radius")
		return
	var expected_pick_radius: float = HiveGeometry.hive_visual_footprint_radius_px(body_circle.radius, 10)
	if not is_equal_approx(pick_circle.radius, expected_pick_radius):
		_fail("hive pick radius should match visible hive footprint")
	if not pick_circle.radius > body_circle.radius:
		_fail("hive pick radius should cover visible footprint beyond body circle")
		return
	if pick_shape.position != Vector2.ZERO:
		_fail("hive pick shape should stay centered on the hive")
		return

	print("HIVE_PICK_RADIUS_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("HIVE_PICK_RADIUS_SMOKE: %s" % message)
	quit(1)
