extends SceneTree

const MatchShadowControllerScript := preload("res://scripts/renderers/match_shadow_controller.gd")
const HiveNodeScene := preload("res://scenes/hive/HiveNode.tscn")

const CAPTURE_SIZE: Vector2i = Vector2i(512, 512)
const OUTPUT_PATH: String = "/tmp/swarmfront_match_shadows/match_shadow_preview.png"
const PROGRESS_MARKERS: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
const BACKGROUND: Color = Color(0.12, 0.11, 0.15, 1.0)

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = CAPTURE_SIZE
	RenderingServer.set_default_clear_color(BACKGROUND)
	DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
	_add_readability_backdrop()
	var controller: RefCounted = MatchShadowControllerScript.new()
	controller.call("configure", "res://assets/sprites/sf_skin_v1/match_shadows.json", true)
	var snapshot: Dictionary = controller.call("debug_snapshot") as Dictionary
	if not bool(snapshot.get("enabled", false)):
		_fail("production shadow assets are not ready: %s" % str(snapshot.get("errors", [])))
	if _failed:
		quit(1)
		return
	for progress_value in PROGRESS_MARKERS:
		controller.call("set_progress", progress_value)
	var preview_progress: float = 0.0
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if not user_args.is_empty():
		preview_progress = clampf(float(user_args[0]), 0.0, 1.0)
	controller.call("set_progress", preview_progress)
	_expect(int(snapshot.get("material_count", 0)) == 3, "preview should retain exactly one material per enabled tier")
	var hive: Node2D = HiveNodeScene.instantiate() as Node2D
	hive.position = Vector2(205.0, 300.0)
	root.add_child(hive)
	await process_frame
	hive.call("apply_render", 1, 25, 27.0, Color(1.0, 0.75, 0.08, 1.0), 14, "Hive", 1, 3, 3, {})
	hive.call("apply_match_shadow_presentation", controller.call("presentation_for_tier", 3) as Dictionary)

	for _frame in range(3):
		await process_frame
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("capture image is empty")
	else:
		if image.get_width() >= CAPTURE_SIZE.x and image.get_height() >= CAPTURE_SIZE.y:
			image = image.get_region(Rect2i(Vector2i.ZERO, CAPTURE_SIZE))
		var save_error: Error = image.save_png(OUTPUT_PATH)
		if save_error != OK:
			_fail("failed to save capture (%d)" % save_error)
	if _failed:
		quit(1)
		return
	print("MATCH_SHADOW_VISUAL_HARNESS: PASS")
	print(OUTPUT_PATH)
	quit(0)

func _add_readability_backdrop() -> void:
	var floor := Polygon2D.new()
	floor.polygon = PackedVector2Array([
		Vector2(0.0, 120.0),
		Vector2(float(CAPTURE_SIZE.x), 120.0),
		Vector2(float(CAPTURE_SIZE.x), float(CAPTURE_SIZE.y)),
		Vector2(0.0, float(CAPTURE_SIZE.y))
	])
	floor.color = Color(0.24, 0.22, 0.29, 1.0)
	floor.z_index = -20
	root.add_child(floor)
	var lane := Line2D.new()
	lane.points = PackedVector2Array([
		Vector2(0.0, 330.0),
		Vector2(float(CAPTURE_SIZE.x), 330.0)
	])
	lane.width = 18.0
	lane.default_color = Color(0.68, 0.61, 0.82, 0.82)
	lane.z_index = -8
	root.add_child(lane)

func _expect(value: bool, message: String) -> void:
	if value:
		return
	_fail(message)

func _fail(message: String) -> void:
	_failed = true
	push_error("MATCH_SHADOW_VISUAL_HARNESS: %s" % message)
