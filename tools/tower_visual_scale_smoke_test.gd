extends SceneTree

const SETTINGS_POLISH_ENABLED: String = "swarmfront/arena/premium_polish_enabled"
const SETTINGS_TOWER_VISUAL_SCALE: String = "swarmfront/arena/tower_visual_scale"
const SETTINGS_COMPARISON_MODE: String = "swarmfront/arena/polish_comparison_mode"
const TowerRendererScript: Script = preload("res://scripts/renderers/tower_renderer.gd")

var _failed: bool = false

func _initialize() -> void:
	ProjectSettings.set_setting(SETTINGS_POLISH_ENABLED, false)
	ProjectSettings.set_setting(SETTINGS_TOWER_VISUAL_SCALE, 1.0)
	ProjectSettings.set_setting(SETTINGS_COMPARISON_MODE, "settings")
	await process_frame

	var renderer: Node2D = TowerRendererScript.new() as Node2D
	root.add_child(renderer)
	await process_frame

	var tower: Dictionary = {
		"id": 1,
		"owner_id": 1,
		"active": true,
		"tier": 1,
		"pos_px": Vector2(240.0, 320.0)
	}
	var model: Dictionary = {
		"cell_size": 64,
		"towers": [tower]
	}
	renderer.call("set_model", model)
	await process_frame

	var sprite: Sprite2D = renderer.get_node_or_null("TowerSprite_1") as Sprite2D
	_expect_true(sprite != null, "Tower sprite should be created")
	if sprite == null:
		_finish(renderer)
		return
	var base_sprite_scale: Vector2 = sprite.scale
	var base_world_pos: Vector2 = renderer.call("_tower_world_pos", tower) as Vector2
	var base_model_pos: Vector2 = tower["pos_px"] as Vector2

	ProjectSettings.set_setting(SETTINGS_TOWER_VISUAL_SCALE, 1.25)
	renderer.call("apply_visual_settings")
	await process_frame
	var scaled_world_pos: Vector2 = renderer.call("_tower_world_pos", tower) as Vector2
	var scaled_model_pos: Vector2 = tower["pos_px"] as Vector2
	_expect_approx(sprite.scale.x, base_sprite_scale.x * 1.25, 0.0001, "Tower sprite X scale should apply project visual multiplier")
	_expect_approx(sprite.scale.y, base_sprite_scale.y * 1.25, 0.0001, "Tower sprite Y scale should apply project visual multiplier")
	_expect_true(scaled_world_pos == base_world_pos, "Tower world position helper should not change with visual scale")
	_expect_true(scaled_model_pos == base_model_pos, "Tower render model should not be mutated by visual scale")
	_expect_no_physics_nodes(renderer)

	ProjectSettings.set_setting(SETTINGS_COMPARISON_MODE, "tower_150")
	renderer.call("apply_visual_settings")
	await process_frame
	_expect_approx(sprite.scale.x, base_sprite_scale.x * 1.50, 0.0001, "Comparison tower_150 should force 1.5 visual scale")
	_expect_approx(sprite.scale.y, base_sprite_scale.y * 1.50, 0.0001, "Comparison tower_150 should force 1.5 visual scale")

	ProjectSettings.set_setting(SETTINGS_COMPARISON_MODE, "baseline")
	renderer.call("apply_visual_settings")
	await process_frame
	_expect_approx(sprite.scale.x, base_sprite_scale.x, 0.0001, "Baseline comparison should restore 1.0 visual scale")
	_expect_approx(sprite.scale.y, base_sprite_scale.y, 0.0001, "Baseline comparison should restore 1.0 visual scale")

	_finish(renderer)

func _finish(renderer: Node) -> void:
	if renderer != null:
		renderer.free()
	if not _failed:
		print("TOWER_VISUAL_SCALE_SMOKE: PASS")
	quit(1 if _failed else 0)

func _expect_no_physics_nodes(root_node: Node) -> void:
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		_expect_true(not (node is CollisionObject2D), "Tower visual scale should not create CollisionObject2D nodes")
		_expect_true(not (node is CollisionShape2D), "Tower visual scale should not create CollisionShape2D nodes")
		_expect_true(not (node is CollisionPolygon2D), "Tower visual scale should not create CollisionPolygon2D nodes")
		for child in node.get_children():
			stack.append(child)

func _expect_approx(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) <= tolerance:
		return
	_failed = true
	push_error("TOWER_VISUAL_SCALE_SMOKE: %s actual=%s expected=%s" % [message, str(actual), str(expected)])

func _expect_true(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("TOWER_VISUAL_SCALE_SMOKE: %s" % message)
