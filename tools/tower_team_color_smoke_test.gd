extends SceneTree

const TowerRendererScript := preload("res://scripts/renderers/tower_renderer.gd")
const TeamVisualsScript := preload("res://scripts/renderers/team_visuals.gd")

var _failed: bool = false

func _init() -> void:
	await process_frame

	var renderer: Node2D = TowerRendererScript.new()
	root.add_child(renderer)
	await process_frame

	var towers: Array = []
	for owner_id in range(1, 5):
		towers.append({
			"id": owner_id,
			"owner_id": owner_id,
			"active": true,
			"tier": owner_id,
			"grid_pos": [owner_id, 1]
		})
	renderer.call("set_model", {
		"cell_size": 64,
		"towers": towers
	})
	await process_frame
	await process_frame

	for owner_id in range(1, 5):
		var sprite: Sprite2D = renderer.get_node_or_null("TowerSprite_%d" % owner_id) as Sprite2D
		_assert_true(sprite != null, "tower sprite should exist for owner %d" % owner_id)
		if sprite == null:
			continue
		_assert_true(sprite.texture != null, "tower sprite should have texture for owner %d" % owner_id)
		_assert_true(sprite.material is ShaderMaterial, "tower sprite should use team color shader for owner %d" % owner_id)
		if not (sprite.material is ShaderMaterial):
			continue
		var mat: ShaderMaterial = sprite.material as ShaderMaterial
		var to_color: Color = mat.get_shader_parameter("to_color") as Color
		var expected: Color = TeamVisualsScript.owner_color(owner_id)
		_assert_true(_colors_close(to_color, expected), "tower owner %d should project its team color" % owner_id)
		_assert_true(float(mat.get_shader_parameter("white_strength")) >= 0.99, "tower owner %d should colorize white tower pixels" % owner_id)

	if _failed:
		quit(1)
		return
	print("TOWER_TEAM_COLOR_SMOKE: PASS")
	quit(0)

func _colors_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= 0.01 and absf(a.g - b.g) <= 0.01 and absf(a.b - b.b) <= 0.01

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	_failed = true
	push_error("TOWER_TEAM_COLOR_SMOKE: %s" % label)
