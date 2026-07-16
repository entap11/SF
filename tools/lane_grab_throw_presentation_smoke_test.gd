extends SceneTree

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var arena_scene: PackedScene = load("res://scenes/Arena.tscn") as PackedScene
	_expect(arena_scene != null, "Arena scene must load the canonical lane renderer")
	if arena_scene == null:
		quit(1)
		return
	var arena: Node = arena_scene.instantiate()
	var renderer: Node2D = arena.get_node_or_null("MapRoot/LaneRenderer") as Node2D
	_expect(renderer != null, "Arena scene must expose LaneRenderer")
	if renderer == null:
		arena.free()
		quit(1)
		return
	var source := Vector2(0.0, 0.0)
	var dest := Vector2(300.0, 0.0)
	var anchor := Vector2(150.0, 0.0)
	var medium_curve: PackedVector2Array = renderer.call(
		"_lane_grab_tension_curve_points",
		source,
		dest,
		anchor,
		Vector2(150.0, 60.0)
	) as PackedVector2Array
	var max_curve: PackedVector2Array = renderer.call(
		"_lane_grab_tension_curve_points",
		source,
		dest,
		anchor,
		Vector2(150.0, 1000.0)
	) as PackedVector2Array

	_expect(medium_curve.size() == 25, "grab rail must use the configured smooth curve resolution")
	_expect(not medium_curve.is_empty() and medium_curve[0].is_equal_approx(source), "grab rail must remain attached to the source hive")
	_expect(not medium_curve.is_empty() and medium_curve[-1].y > dest.y, "pulling away must detach the destination end toward the gesture")
	_expect(not max_curve.is_empty(), "maximum bend curve must be generated")
	if not max_curve.is_empty():
		var endpoint_vec: Vector2 = max_curve[-1] - source
		var endpoint_angle_deg: float = absf(rad_to_deg(endpoint_vec.angle()))
		_expect(endpoint_angle_deg >= 14.0 and endpoint_angle_deg <= 16.0, "constant 30-degree arc must place its endpoint on the 15-degree chord")
		var tangent_angles := PackedFloat32Array()
		for i in range(1, max_curve.size()):
			tangent_angles.append(rad_to_deg((max_curve[i] - max_curve[i - 1]).angle()))
		_expect(not tangent_angles.is_empty() and absf(tangent_angles[-1]) >= 29.0, "large pulls must retain nearly 30 degrees of tangent at the loose end")
		if tangent_angles.size() >= 3:
			var expected_turn: float = tangent_angles[1] - tangent_angles[0]
			for i in range(2, tangent_angles.size()):
				_expect(absf((tangent_angles[i] - tangent_angles[i - 1]) - expected_turn) <= 0.05, "curve must turn uniformly without flattening")

	var source_text := FileAccess.get_file_as_string("res://scripts/renderers/lane_renderer.gd")
	_expect(source_text.contains("LANE_GRAB_BRIGHTNESS_MULTIPLIER: float = 5.0"), "selected lane brightness must be amplified fivefold")
	_expect(source_text.contains("LANE_GRAB_GLOW_BOOST: float = 2.5"), "selected lane must receive an explicit glow boost")
	_expect(source_text.contains("anchor_world"), "curve displacement must be measured from the grabbed point")
	_expect(source_text.contains("LANE_GRAB_MAX_BEND_DEG: float = 30.0"), "throw-away curve must expose the 30 degree cap")
	_expect(source_text.contains("Line2D.LINE_TEXTURE_STRETCH"), "curved rail must preserve the complete normal lane texture")

	renderer.call(
		"set_lane_grab_preview",
		1,
		"a",
		"throw_ready",
		source,
		dest,
		Vector2(150.0, 60.0),
		anchor
	)
	var core_line: Line2D = renderer.get_node_or_null("LaneGrabTensionLine") as Line2D
	var glow_line: Line2D = renderer.get_node_or_null("LaneGrabTensionGlow") as Line2D
	var edge_rail_a: Line2D = renderer.get_node_or_null("LaneGrabEdgeRailA") as Line2D
	var edge_rail_b: Line2D = renderer.get_node_or_null("LaneGrabEdgeRailB") as Line2D
	_expect(core_line != null and core_line.visible, "throw-ready preview must replace the straight rail with a visible curve")
	_expect(glow_line != null and glow_line.visible, "throw-ready preview must add a wide additive glow")
	_expect(edge_rail_a != null and edge_rail_a.visible, "bent lane must retain its first visible edge rail")
	_expect(edge_rail_b != null and edge_rail_b.visible, "bent lane must retain its second visible edge rail")
	if edge_rail_a != null and edge_rail_b != null and not edge_rail_a.points.is_empty() and not edge_rail_b.points.is_empty():
		_expect(edge_rail_a.points[0].distance_to(edge_rail_b.points[0]) >= 6.0, "parallel rails must preserve the lane silhouette while bending")
	if core_line != null:
		var core_material: ShaderMaterial = core_line.material as ShaderMaterial
		_expect(core_material != null, "curved rail must retain the lane texture shader")
		if core_material != null:
			_expect(is_equal_approx(float(core_material.get_shader_parameter("lane_brightness")), 3.4), "curved rail brightness must be exactly five times the 0.68 baseline")
			_expect(is_equal_approx(float(core_material.get_shader_parameter("glow_boost")), 2.5), "curved rail shader must use the hot glow boost")
	var hidden_straight: Color = renderer.call("_lane_grab_preview_color", 1, "a", Color.YELLOW) as Color
	_expect(hidden_straight.a <= 0.001, "straight selected rail must disappear beneath the detached curve")
	var selected_piece: Sprite2D = renderer.call("_create_lane_sprite_node") as Sprite2D
	renderer.call("_apply_lane_grab_piece_material", selected_piece, 1, "a")
	var selected_material: ShaderMaterial = selected_piece.material as ShaderMaterial
	_expect(selected_material != null, "selected straight-rail fallback must retain a lane shader")
	if selected_material != null:
		_expect(is_equal_approx(float(selected_material.get_shader_parameter("lane_brightness")), 3.4), "selected straight-rail fallback must also use fivefold brightness")
		_expect(is_equal_approx(float(selected_material.get_shader_parameter("glow_boost")), 2.5), "selected straight-rail fallback must also glow")
	selected_piece.free()
	renderer.call("clear_lane_grab_preview")

	arena.free()
	if _failed:
		quit(1)
		return
	print("LANE_GRAB_THROW_PRESENTATION_SMOKE: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("LANE_GRAB_THROW_PRESENTATION_SMOKE: %s" % message)
