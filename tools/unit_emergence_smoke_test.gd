extends Node

const UnitRenderer := preload("res://scripts/renderers/unit_renderer.gd")

var _failed: bool = false

func _ready() -> void:
	await get_tree().process_frame
	var renderer: Node2D = UnitRenderer.new()
	add_child(renderer)
	renderer.unit_emergence_enabled = true
	renderer.bind_hives([
		{"id": 1, "x": 0, "y": 0, "owner_id": 1, "radius_px": 24.0},
		{"id": 2, "x": 4, "y": 0, "owner_id": 2, "radius_px": 24.0}
	], 1)
	await get_tree().process_frame

	var image := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 1.0))
	var tex := ImageTexture.create_from_image(image)
	var node := Node2D.new()
	node.set_meta("unit_id", 101)
	renderer.add_child(node)
	var sprite := Sprite2D.new()
	sprite.name = "UnitSprite"
	sprite.texture = tex
	sprite.scale = Vector2(2.0, 2.0)
	sprite.set_meta(&"unit_base_scale", sprite.scale)
	node.add_child(sprite)
	var outline := Sprite2D.new()
	outline.name = "UnitOutlineSprite"
	outline.texture = tex
	outline.scale = Vector2(2.5, 2.5)
	outline.set_meta(&"unit_outline_base_scale", outline.scale)
	node.add_child(outline)
	renderer.call("_ensure_bee_clip_controller", 101, sprite)
	renderer.call("_ensure_bee_clip_outline_controller", 101, outline)

	var hive_by_id: Dictionary = renderer.call("_build_hive_by_id") as Dictionary
	var ud: Dictionary = {"id": 101, "from_id": 1, "to_id": 2, "a_id": 1, "b_id": 2, "dir": 1}
	var travel_dir := Vector2.RIGHT
	var source_boundary: Vector2 = renderer.call("_hive_shell_contact_world", 1, hive_by_id, travel_dir) as Vector2

	renderer.call("_apply_unit_emergence_visuals", node, ud, hive_by_id, source_boundary, travel_dir)
	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	var outline_mat: ShaderMaterial = outline.material as ShaderMaterial
	_assert_true(_vec_close(sprite.scale, Vector2(2.0, 2.0)), "fresh unit should keep its sprite shape during emergence")
	_assert_true(_vec_close(sprite.position, Vector2.ZERO), "fresh unit should not shift its sprite during emergence")
	_assert_true(mat != null and float(mat.get_shader_parameter(&"source_reveal_enabled")) > 0.5, "fresh unit should enable source reveal mask")
	_assert_true(mat != null and float(mat.get_shader_parameter(&"source_reveal")) < 0.1, "fresh unit should start with nose-first reveal")
	_assert_true(outline_mat != null and float(outline_mat.get_shader_parameter(&"source_reveal_enabled")) > 0.5, "outline should use the same source reveal mask")

	renderer.call("_apply_unit_emergence_visuals", node, ud, hive_by_id, source_boundary + travel_dir * 140.0, travel_dir)
	_assert_true(_vec_close(sprite.scale, Vector2(2.0, 2.0)), "unit should return to full sprite scale after emergence distance")
	_assert_true(_vec_close(sprite.position, Vector2.ZERO), "unit sprite offset should reset after emergence distance")
	_assert_true(mat != null and float(mat.get_shader_parameter(&"source_reveal_enabled")) < 0.5, "unit should disable source reveal mask after emergence distance")

	var state := {"spawn_wall_us": Time.get_ticks_usec(), "spawn_sim_us": 100000, "dir": travel_dir}
	renderer.set("_unit_visual_by_id", {101: state})
	renderer.call("_apply_unit_emergence_visuals", node, ud, hive_by_id, source_boundary + travel_dir * 140.0, travel_dir)
	_assert_true(mat != null and float(mat.get_shader_parameter(&"source_reveal_enabled")) > 0.5, "newly spawned unit should stay masked even if first sample is already down-lane")
	await get_tree().create_timer(0.60).timeout
	renderer.call("_apply_unit_emergence_visuals", node, ud, hive_by_id, source_boundary + travel_dir * 140.0, travel_dir)
	_assert_true(mat != null and float(mat.get_shader_parameter(&"source_reveal_enabled")) < 0.5, "time-gated emergence should complete after the reveal duration")

	var moving_unit: Dictionary = {"id": 202, "from_id": 1, "to_id": 2, "a_id": 1, "b_id": 2, "dir": 1, "t": 0.08}
	renderer.call("_ingest_unit_sample", moving_unit, hive_by_id, 202, null, null, 200000)
	var moving_state: Dictionary = (renderer.get("_unit_visual_by_id") as Dictionary).get(202, {}) as Dictionary
	_assert_true(not bool(moving_state.get("just_spawned", true)), "fresh unit should skip stationary just-spawned render branch")
	_assert_true(bool(moving_state.get("warm_spawned", false)), "fresh unit should warm-start behind its first sim sample")
	var prev_pos: Vector2 = moving_state.get("prev_pos", Vector2.ZERO)
	var curr_pos: Vector2 = moving_state.get("curr_pos", Vector2.ZERO)
	_assert_true(prev_pos.distance_to(curr_pos) > 10.0, "fresh unit should have immediate visual travel distance")

	if _failed:
		get_tree().quit(1)
		return
	print("UNIT_EMERGENCE_SMOKE: PASS")
	get_tree().quit(0)

func _vec_close(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) <= 0.001

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	_failed = true
	push_error("UNIT_EMERGENCE_SMOKE: %s" % label)
