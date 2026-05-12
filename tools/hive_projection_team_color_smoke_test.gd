extends SceneTree

const HiveVisualScript := preload("res://scripts/hive/hive_visual.gd")
const SpriteRegistryScript := preload("res://scripts/renderers/sprite_registry.gd")
const TeamVisualsScript := preload("res://scripts/renderers/team_visuals.gd")

var _failed: bool = false

func _init() -> void:
	await process_frame

	var owner_id: int = 2
	var visual: Node2D = await _configured_visual(owner_id, 12, 0, 2)

	var projection_sprite: Sprite2D = visual.get_node_or_null("PowerProjection/ProjectionSprite") as Sprite2D
	_assert_true(projection_sprite != null, "projection sprite should exist")
	_assert_true(projection_sprite.material is ShaderMaterial, "projection sprite should use shader material")
	_assert_true(not projection_sprite.visible, "medium flat-top hive should not show old projection sprite")
	var medium_sprite: Sprite2D = visual.get_node_or_null("BaseSpriteLayer/BaseSprite") as Sprite2D
	_assert_true(medium_sprite != null and medium_sprite.texture != null, "medium flat-top hive texture should load")
	_assert_true(medium_sprite.material is ShaderMaterial, "medium owned flat-top hive should use team glow shader")
	if medium_sprite.material is ShaderMaterial:
		var medium_mat: ShaderMaterial = medium_sprite.material as ShaderMaterial
		var white_strength_v: Variant = medium_mat.get_shader_parameter("white_strength")
		var white_strength: float = white_strength_v if typeof(white_strength_v) == TYPE_FLOAT or typeof(white_strength_v) == TYPE_INT else 0.0
		_assert_true(white_strength > 0.9, "medium team shader should colorize white flat-top pixels")
	_assert_true(str(visual.get("_sprite_key")) == "hive.med.p2", "power 12 should resolve to medium hive sprite")
	_assert_true(_registry_path_matches("hive.med.p2", "res://assets/sprites/sf_skin_v1/hive_medium_flatop.png"), "medium hive should use flat-top asset")
	_assert_true(SpriteRegistryScript.hive_sprite_key(2, "Hive", 12) == "hive.med.p2", "renderer fallback should use medium tier for player medium")

	var pip_fill: Polygon2D = visual.get_node_or_null("LaneBudgetIndicators/BudgetPipFill_0") as Polygon2D
	_assert_true(pip_fill != null, "lane budget pip should exist")
	_assert_true(_is_black(pip_fill.color), "available P2 pip should be black")
	_assert_true(pip_fill.color.a > 0.5, "available P2 pip should be visible")

	var small_visual: Node2D = await _configured_visual(1, 5, 0, 1)
	var small_sprite: Sprite2D = small_visual.get_node_or_null("BaseSpriteLayer/BaseSprite") as Sprite2D
	_assert_true(small_sprite != null and small_sprite.texture != null, "small flat-top hive texture should load")
	_assert_true(small_sprite.material is ShaderMaterial, "small owned flat-top hive should use team glow shader")
	_assert_true(str(small_visual.get("_sprite_key")) == "hive.small.p1", "power 5 should resolve to small hive sprite")
	_assert_true(_registry_path_matches("hive.small.p1", "res://assets/sprites/sf_skin_v1/hive_small_flatop.png"), "small hive should use flat-top asset")
	var small_projection: Sprite2D = small_visual.get_node_or_null("PowerProjection/ProjectionSprite") as Sprite2D
	_assert_true(small_projection != null and not small_projection.visible, "small flat-top hive should not show old projection sprite")
	var small_pip_fill: Polygon2D = small_visual.get_node_or_null("LaneBudgetIndicators/BudgetPipFill_0") as Polygon2D
	_assert_true(small_pip_fill != null, "small lane budget pip should exist")
	_assert_true(small_pip_fill.position.x > 8.0, "small flat-top pip should clear the power number")
	_assert_true(small_pip_fill.visible and small_pip_fill.color.a > 0.5, "small lane budget pip should be visible")

	var medium_second_pip: Polygon2D = visual.get_node_or_null("LaneBudgetIndicators/BudgetPipFill_1") as Polygon2D
	_assert_true(medium_second_pip != null, "medium second lane budget pip should exist")
	_assert_true(absf(medium_second_pip.position.x - pip_fill.position.x) >= 24.0, "medium flat-top pips should clear the power number")
	_assert_true(pip_fill.visible and medium_second_pip.visible, "medium lane budget pips should be visible")

	var spent_visual: Node2D = await _configured_visual(owner_id, 50, 3, 3)
	var large_sprite: Sprite2D = spent_visual.get_node_or_null("BaseSpriteLayer/BaseSprite") as Sprite2D
	_assert_true(large_sprite != null and large_sprite.texture != null, "large flat-top hive texture should load")
	var large_projection: Sprite2D = spent_visual.get_node_or_null("PowerProjection/ProjectionSprite") as Sprite2D
	_assert_true(large_projection == null or not large_projection.visible, "large flat-top hive should not show old projection sprite")
	var spent_outline: Line2D = spent_visual.get_node_or_null("LaneBudgetIndicators/BudgetPipOutline_0") as Line2D
	var spent_fill: Polygon2D = spent_visual.get_node_or_null("LaneBudgetIndicators/BudgetPipFill_0") as Polygon2D
	_assert_true(spent_outline != null, "spent P2 pip outline should exist")
	_assert_true(_is_black(spent_outline.default_color), "spent P2 pip outline should be black")
	_assert_true(spent_outline.position.y >= 18.0 and spent_outline.position.y <= 22.0, "large flat-top pip should fit below the number on the top disk")
	_assert_true(spent_fill != null and spent_fill.color.a == 0.0, "spent P2 pip fill should stay transparent")

	var npc_visual: Node2D = await _configured_visual(0, 8, 0, 3)
	var npc_sprite: Sprite2D = npc_visual.get_node_or_null("BaseSpriteLayer/BaseSprite") as Sprite2D
	_assert_true(npc_sprite != null, "NPC base sprite should exist")
	_assert_true(str(npc_visual.get("_sprite_key")) == "hive.small.neutral", "NPC small should resolve to small neutral hive sprite")
	_assert_true(_registry_path_matches("hive.small.neutral", "res://assets/sprites/sf_skin_v1/hive_small_flatop.png"), "NPC small hive should use flat-top asset")
	_assert_true(SpriteRegistryScript.hive_sprite_key(0, "npc_hive", 0) == "hive.small.neutral", "renderer fallback should use small flat-top for NPC small")
	_assert_true(npc_sprite.material is ShaderMaterial, "NPC base sprite should use shader material")
	var npc_mat: ShaderMaterial = npc_sprite.material as ShaderMaterial
	var npc_tint: Color = npc_mat.get_shader_parameter("npc_tint") as Color
	_assert_true(npc_tint.b > npc_tint.r and npc_tint.b > npc_tint.g, "NPC sprite tint should be purple-gray")

	var npc_projection: Sprite2D = npc_visual.get_node_or_null("PowerProjection/ProjectionSprite") as Sprite2D
	_assert_true(npc_projection != null, "NPC projection sprite should exist")
	_assert_true(not npc_projection.visible, "NPC flat-top hive should not show old projection sprite")

	var npc_pip_fill: Polygon2D = npc_visual.get_node_or_null("LaneBudgetIndicators/BudgetPipFill_0") as Polygon2D
	_assert_true(npc_pip_fill != null, "NPC lane budget pip should exist")
	_assert_true(_is_black(npc_pip_fill.color), "NPC lane budget pip should be black")

	if _failed:
		quit(1)
		return
	print("HIVE_PROJECTION_TEAM_COLOR_SMOKE: PASS")
	quit(0)

func _configured_visual(owner_id: int, power: int, lane_budget_used: int, lane_budget_max: int) -> Node2D:
	var visual: Node2D = HiveVisualScript.new()
	root.add_child(visual)
	await process_frame
	visual.call(
		"configure",
		owner_id,
		TeamVisualsScript.owner_color(owner_id),
		24.0,
		power,
		14,
		"Hive",
		lane_budget_used,
		lane_budget_max
	)
	await process_frame
	await process_frame
	return visual

func _is_black(color: Color) -> bool:
	return color.r <= 0.01 and color.g <= 0.01 and color.b <= 0.01

func _registry_path_matches(key: String, path: String) -> bool:
	var registry: SpriteRegistry = SpriteRegistryScript.get_instance()
	if registry == null:
		return false
	return registry.get_tex_path(key) == path

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	_failed = true
	push_error("HIVE_PROJECTION_TEAM_COLOR_SMOKE: %s" % label)
