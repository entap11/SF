extends SceneTree

const HiveNodeScene := preload("res://scenes/hive/HiveNode.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var node: Node = HiveNodeScene.instantiate()
	get_root().add_child(node)
	await process_frame
	if not node.has_method("apply_render"):
		_fail("HiveNode apply_render missing")
		return
	node.call("apply_render", 1, 25, 27.0, Color(0.9, 0.7, 0.2, 1.0), 14, "Hive", 1, 3)
	await process_frame
	var label: Label = node.get_node_or_null("Visual/PowerProjection/PowerBadge/Backing/PowerLabel") as Label
	if label == null or label.label_settings == null:
		_fail("power label missing")
		return
	if int(label.label_settings.font_size) != 84:
		_fail("power label font should use the current 84px hive label size")
		return
	var visual: Node = node.get_node_or_null("Visual")
	if visual == null:
		_fail("visual missing")
		return
	var pips: Array = visual.get("_lane_budget_pips") as Array
	if pips.size() != 3:
		_fail("expected three lane budget pips")
		return
	var first: Dictionary = pips[0] as Dictionary
	var outline: Line2D = first.get("outline", null) as Line2D
	if outline == null or outline.points.is_empty():
		_fail("lane budget pip outline missing")
		return
	if not is_equal_approx(outline.points[0].length(), 7.5):
		_fail("lane budget pip radius should be larger than the previous 6px")
		return
	var available: Dictionary = pips[1] as Dictionary
	var fill: Polygon2D = available.get("fill", null) as Polygon2D
	if fill == null or not fill.visible:
		_fail("lane budget pip fill should be visible")
		return
	if fill.color.r < 0.95 or fill.color.g < 0.95 or fill.color.b < 0.95:
		_fail("lane budget pip fill should be white for every player")
		return
	node.call("set_selected", true, Color(1.0, 0.82, 0.0, 1.0))
	await process_frame
	var selector_sprite: Sprite2D = node.get_node_or_null("Visual/SelectorRing") as Sprite2D
	if selector_sprite != null and selector_sprite.visible:
		_fail("selected hive should not show selector ring sprite")
		return
	var sprite: Sprite2D = node.get_node_or_null("Visual/BaseSpriteLayer/BaseSprite") as Sprite2D
	if sprite == null or not (sprite.material is ShaderMaterial):
		_fail("selected hive sprite should use shader material")
		return
	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	if float(mat.get_shader_parameter("selected_hot")) < 0.99:
		_fail("selected hive shader should enable white-hot metal")
		return
	print("HIVE_VISUAL_SCALE_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("HIVE_VISUAL_SCALE_SMOKE: %s" % message)
	quit(1)
