extends SceneTree

const HiveNodeScene := preload("res://scenes/hive/HiveNode.tscn")
const HiveGrowthRules := preload("res://scripts/sim/hive_growth_rules.gd")
const TeamVisuals := preload("res://scripts/renderers/team_visuals.gd")

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var node: Node = HiveNodeScene.instantiate()
	root.add_child(node)
	await process_frame

	node.call(
		"apply_render",
		2,
		12,
		27.0,
		TeamVisuals.owner_color(2),
		14,
		"Hive",
		0,
		2,
		HiveGrowthRules.TIER_MEDIUM
	)
	node.call("set_capture_flag_marker", true, 2, false)
	await process_frame

	var flag: Sprite2D = node.get_node_or_null("CaptureFlagSprite") as Sprite2D
	var shadow: Sprite2D = node.get_node_or_null("MatchShadowSprite") as Sprite2D
	var base_layer: Node2D = node.get_node_or_null("Visual/BaseSpriteLayer") as Node2D
	_expect(flag != null, "capture flag sprite missing")
	if flag == null:
		return
	_expect(flag.visible, "visible CTF flag should show")
	_expect(flag.texture != null, "capture flag texture missing")
	_expect(flag.texture.resource_path == "res://assets/sprites/sf_skin_v1/flag_ctf.png", "visible CTF should use flag_ctf.png")
	_expect(flag.get_parent() == node, "capture flag must stay outside the shadowed Visual subtree")
	_expect(shadow != null and shadow.z_index < flag.z_index, "capture flag should render above the cast shadow")
	_expect(base_layer != null and flag.z_index < base_layer.z_index, "capture flag should remain behind the hive body")
	_expect(flag.position.x > 0.0 and flag.position.y > 0.0, "capture flag should sit down-right in the hive shadow")
	_expect(flag.scale.x > 0.0 and is_equal_approx(flag.scale.x, flag.scale.y), "capture flag scale should be uniform")
	if flag.texture != null:
		var image: Image = flag.texture.get_image()
		_expect(image != null and image.detect_alpha() != Image.ALPHA_NONE, "capture flag asset should have transparency")
	_expect(flag.material is ShaderMaterial, "capture flag should use team-color projection")
	if flag.material is ShaderMaterial:
		var material: ShaderMaterial = flag.material as ShaderMaterial
		var projected_color: Color = material.get_shader_parameter("to_color") as Color
		_expect(projected_color.is_equal_approx(TeamVisuals.owner_color(2)), "capture flag projection should use the flag owner's team color")

	var medium_scale: float = flag.scale.x
	node.call(
		"apply_render",
		2,
		50,
		27.0,
		TeamVisuals.owner_color(2),
		14,
		"Hive",
		0,
		3,
		HiveGrowthRules.TIER_LARGE
	)
	node.call("set_capture_flag_marker", true, 2, true)
	await process_frame
	_expect(flag.visible, "hidden CTF owner-visible flag should use the same sprite")
	_expect(flag.texture != null and flag.texture.resource_path == "res://assets/sprites/sf_skin_v1/flag_hctf.png", "hidden CTF should use flag_hctf.png")
	if flag.texture != null:
		var hidden_image: Image = flag.texture.get_image()
		_expect(hidden_image != null and hidden_image.detect_alpha() != Image.ALPHA_NONE, "hidden CTF flag asset should have transparency")
	_expect(flag.scale.x > medium_scale, "capture flag should scale with the hive growth tier")
	_expect(bool(flag.get_meta("capture_flag_hidden", false)), "hidden CTF presentation metadata should be retained")

	node.call("set_capture_flag_marker", true, 2, false)
	_expect(flag.texture != null and flag.texture.resource_path == "res://assets/sprites/sf_skin_v1/flag_ctf.png", "switching back to visible CTF should restore flag_ctf.png")
	node.call("set_capture_flag_marker", false, 2, false)
	_expect(not flag.visible, "unmarked hive should hide the capture flag sprite")

	if _failed:
		quit(1)
		return
	print("CAPTURE_FLAG_VISUAL_SMOKE: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("CAPTURE_FLAG_VISUAL_SMOKE: %s" % message)
