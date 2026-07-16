extends SceneTree

const MatchShadowCatalogScript := preload("res://scripts/renderers/match_shadow_catalog.gd")
const MatchShadowControllerScript := preload("res://scripts/renderers/match_shadow_controller.gd")
const HiveNodeScene := preload("res://scenes/hive/HiveNode.tscn")

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var production_controller: RefCounted = MatchShadowControllerScript.new()
	production_controller.call(
		"configure",
		"res://assets/sprites/sf_skin_v1/match_shadows.json",
		true
	)
	var production_snapshot: Dictionary = production_controller.call("debug_snapshot") as Dictionary
	_expect(bool(production_snapshot.get("enabled", false)), "production shadow catalog should enable")
	_expect(int(production_snapshot.get("material_count", 0)) == 3, "production catalog should expose all three temporary tier materials")

	var fixture_dir: String = "user://match_shadow_smoke"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture_dir))
	var start_path: String = fixture_dir + "/shadow_start.png"
	var middle_path: String = fixture_dir + "/shadow_middle.png"
	var end_path: String = fixture_dir + "/shadow_end.png"
	_write_mask(start_path, 0.25)
	_write_mask(middle_path, 0.55)
	_write_mask(end_path, 0.85)
	var catalog: Dictionary = _fixture_catalog(start_path, middle_path, end_path)
	var validation_errors: PackedStringArray = MatchShadowCatalogScript.validate_catalog(catalog, true, false)
	_expect(validation_errors.is_empty(), "fixture catalog should validate: %s" % str(validation_errors))

	var controller: RefCounted = MatchShadowControllerScript.new()
	controller.call("configure_from_data", catalog)
	var controller_snapshot: Dictionary = controller.call("debug_snapshot") as Dictionary
	_expect(bool(controller_snapshot.get("enabled", false)), "controller should enable for valid fixture assets")
	_expect(int(controller_snapshot.get("material_count", 0)) == 2, "enabled medium and large tiers should allocate one material each")

	_expect_approx(
		float(MatchShadowControllerScript.progress_from_clock({
			"started": false,
			"elapsed_ms": 500,
			"regulation_duration_ms": 1000
		})),
		0.0,
		"prematch should hold at the starting keyframe"
	)
	_expect_approx(
		float(MatchShadowControllerScript.progress_from_clock({
			"started": true,
			"elapsed_ms": 350,
			"regulation_duration_ms": 1000,
			"over": true
		})),
		0.35,
		"an early outcome should freeze at elapsed regulation progress"
	)
	_expect_approx(
		float(MatchShadowControllerScript.progress_from_clock({
			"started": true,
			"elapsed_ms": 350,
			"regulation_duration_ms": 1000,
			"in_overtime": true
		})),
		1.0,
		"overtime should hold at the final keyframe"
	)
	_expect_approx(
		float(MatchShadowControllerScript.progress_from_clock({
			"started": true,
			"elapsed_ms": 350,
			"regulation_duration_ms": 0
		})),
		0.0,
		"untimed modes should hold at the starting keyframe"
	)

	controller.call("set_progress", 0.25)
	var material: ShaderMaterial = controller.call("material_for_tier", 3) as ShaderMaterial
	_expect(material != null, "large shared material should exist")
	if material != null:
		_expect_approx(float(material.get_shader_parameter("keyframe_blend")), 0.5, "piecewise blend should resolve within the first segment")

	var node_a: Node = HiveNodeScene.instantiate()
	var node_b: Node = HiveNodeScene.instantiate()
	root.add_child(node_a)
	root.add_child(node_b)
	await process_frame
	node_a.call("apply_render", 1, 25, 27.0, Color(1.0, 0.75, 0.1, 1.0), 14, "Hive", 1, 3, 3, {})
	node_b.call("apply_render", 2, 25, 27.0, Color(1.0, 0.1, 0.1, 1.0), 14, "Hive", 1, 3, 3, {})
	var presentation: Dictionary = controller.call("presentation_for_tier", 3) as Dictionary
	node_a.call("apply_match_shadow_presentation", presentation)
	node_b.call("apply_match_shadow_presentation", presentation)
	var shadow_a: Sprite2D = node_a.get_node_or_null("MatchShadowSprite") as Sprite2D
	var shadow_b: Sprite2D = node_b.get_node_or_null("MatchShadowSprite") as Sprite2D
	_expect(shadow_a != null and shadow_b != null, "each hive should own a stable match-shadow sprite")
	if shadow_a != null and shadow_b != null:
		_expect(shadow_a.get_parent() == node_a, "shadow should be a direct HiveNode child")
		_expect(shadow_a.material == shadow_b.material, "same-tier hives should share one material instance")
		_expect(shadow_a.visible and shadow_b.visible, "valid presentations should show both shadows")
		var shadow_position_before: Vector2 = shadow_a.position
		var visual: Node2D = node_a.get_node_or_null("Visual") as Node2D
		visual.position += Vector2(12.0, -4.0)
		await process_frame
		_expect(shadow_a.position == shadow_position_before, "transient Visual movement must not move the stable shadow")
		var debug: Dictionary = node_a.call("get_match_shadow_debug_snapshot") as Dictionary
		_expect(not bool(debug.get("is_visual_child", true)), "shadow must remain outside the transient Visual subtree")

	node_a.call("apply_match_shadow_presentation", {"enabled": false})
	_expect(shadow_a == null or not shadow_a.visible, "disabled presentation should restore the visual baseline")

	var node_c: Node = HiveNodeScene.instantiate()
	root.add_child(node_c)
	await process_frame
	node_c.call("apply_render", 1, 12, 27.0, Color(1.0, 0.75, 0.1, 1.0), 14, "Hive", 1, 2, 2, {})
	node_c.call("apply_match_shadow_presentation", controller.call("presentation_for_tier", 2) as Dictionary)
	var shadow_c: Sprite2D = node_c.get_node_or_null("MatchShadowSprite") as Sprite2D
	var contact_c: Sprite2D = node_c.get_node_or_null("MatchContactShadowSprite") as Sprite2D
	var medium_material: ShaderMaterial = controller.call("material_for_tier", 2) as ShaderMaterial
	var large_material: ShaderMaterial = controller.call("material_for_tier", 3) as ShaderMaterial
	_expect(shadow_c != null and shadow_c.material == medium_material, "medium hive should begin with the medium shared material")
	var medium_contact_scale: Vector2 = contact_c.scale if contact_c != null else Vector2.ZERO
	_expect(contact_c != null and contact_c.visible, "medium hive should begin with a visible contact shadow")
	node_c.call("apply_render", 1, 25, 27.0, Color(1.0, 0.75, 0.1, 1.0), 14, "Hive", 1, 3, 3, {
		"play": true,
		"mode": "full",
		"old_tier": 2,
		"new_tier": 3,
		"unlocked_slot_index": 2
	})
	node_c.call("apply_match_shadow_presentation", controller.call("presentation_for_tier", 3) as Dictionary)
	_expect(shadow_c == null or shadow_c.material == medium_material, "growth flash should defer the shadow tier swap until its cover frame")
	_expect(contact_c == null or contact_c.scale == medium_contact_scale, "growth flash should defer the contact-shadow resize until its cover frame")
	await create_timer(0.34).timeout
	_expect(shadow_c != null and shadow_c.material == large_material, "growth flash cover frame should apply the pending large shadow")
	_expect(contact_c != null and contact_c.scale.x > medium_contact_scale.x, "growth flash cover frame should apply the large contact-shadow size")
	node_a.queue_free()
	node_b.queue_free()
	node_c.queue_free()

	if _failed:
		quit(1)
		return
	print("MATCH_SHADOW_SMOKE: PASS")
	quit(0)

func _fixture_catalog(start_path: String, middle_path: String, end_path: String) -> Dictionary:
	return {
		"version": 1,
		"enabled": true,
		"profiles": {
			"small": {"enabled": false},
			"med": {
				"enabled": true,
				"ground_anchor_px": [8, 12],
				"local_offset": [0, 0],
				"scale": 0.9,
				"opacity": 0.5,
				"color": "#15131B",
				"keyframes": [
					{"progress": 0.0, "path": start_path},
					{"progress": 0.5, "path": middle_path},
					{"progress": 1.0, "path": end_path}
				]
			},
			"large": {
				"enabled": true,
				"ground_anchor_px": [8, 12],
				"local_offset": [0, 0],
				"scale": 1.0,
				"opacity": 0.5,
				"color": "#15131B",
				"keyframes": [
					{"progress": 0.0, "path": start_path},
					{"progress": 0.5, "path": middle_path},
					{"progress": 1.0, "path": end_path}
				]
			}
		}
	}

func _write_mask(path: String, alpha_value: float) -> void:
	var image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(4, 13):
		for x in range(3, 14):
			var dx: float = float(x - 8) / 6.0
			var dy: float = float(y - 8) / 5.0
			if (dx * dx) + (dy * dy) <= 1.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha_value))
	var error: Error = image.save_png(path)
	_expect(error == OK, "fixture mask should save: %s" % path)

func _expect(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("MATCH_SHADOW_SMOKE: %s" % message)

func _expect_approx(value: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(value, expected), "%s (expected %.4f got %.4f)" % [message, expected, value])
