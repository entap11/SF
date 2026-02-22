extends SceneTree

const FloorRendererScript := preload("res://scripts/renderers/floor_renderer.gd")
const InfluenceSystemScript := preload("res://scripts/fx/arena_floor_influence_system.gd")

func _init() -> void:
	var arena_root: Node2D = Node2D.new()
	arena_root.name = "ArenaRoot"
	root.add_child(arena_root)

	var map_root: Node2D = Node2D.new()
	map_root.name = "MapRoot"
	arena_root.add_child(map_root)

	var pools_root: Node2D = Node2D.new()
	pools_root.name = "PoolsRoot"
	arena_root.add_child(pools_root)

	var floor_renderer: FloorRenderer = FloorRendererScript.new()
	floor_renderer.name = "FloorRenderer"
	map_root.add_child(floor_renderer)
	var base_floor: Sprite2D = Sprite2D.new()
	base_floor.name = "BaseFloor"
	floor_renderer.add_child(base_floor)
	var overlay_floor: Sprite2D = Sprite2D.new()
	overlay_floor.name = "FloorOverlay"
	floor_renderer.add_child(overlay_floor)

	await process_frame
	floor_renderer.configure(8, 12, 64.0, Vector2.ZERO)

	var influence_system: Node = InfluenceSystemScript.new()
	influence_system.name = "ArenaFloorInfluenceSystem"
	pools_root.add_child(influence_system)
	if influence_system.has_method("setup"):
		influence_system.call("setup", map_root, pools_root, floor_renderer)
	if influence_system.has_method("apply_render_model"):
		influence_system.call("apply_render_model", {
			"clock": {"elapsed_ms": 30000},
			"hives": [
				{"id": 1, "owner_id": 1, "pos": Vector2(128.0, 192.0)},
				{"id": 2, "owner_id": 2, "pos": Vector2(320.0, 224.0)}
			],
			"towers": [
				{"id": 10, "owner_id": 1, "pos_px": Vector2(192.0, 320.0)}
			],
			"barracks": [
				{"id": 20, "owner_id": 2, "pos_px": Vector2(384.0, 448.0)}
			]
		})

	await process_frame
	var viewport_node: Node = pools_root.get_node_or_null("InfluenceViewport")
	if viewport_node == null:
		viewport_node = pools_root.get_node_or_null("ArenaFloorInfluenceSystem/InfluenceViewport")
	if viewport_node == null:
		push_error("FLOOR_INFLUENCE_SMOKE: missing InfluenceViewport under PoolsRoot")
		quit(1)
		return
	if not (viewport_node is SubViewport):
		push_error("FLOOR_INFLUENCE_SMOKE: InfluenceViewport is not SubViewport")
		quit(1)
		return
	var viewport: SubViewport = viewport_node as SubViewport
	if viewport.size.x <= 0 or viewport.size.y <= 0:
		push_error("FLOOR_INFLUENCE_SMOKE: invalid viewport size")
		quit(1)
		return
	var tex: Texture2D = viewport.get_texture()
	if tex == null:
		push_error("FLOOR_INFLUENCE_SMOKE: missing viewport texture")
		quit(1)
		return
	var img: Image = tex.get_image()
	if img != null:
		var max_r: float = 0.0
		var max_g: float = 0.0
		var max_b: float = 0.0
		var max_a: float = 0.0
		var w: int = img.get_width()
		var h: int = img.get_height()
		for y in range(h):
			for x in range(w):
				var c: Color = img.get_pixel(x, y)
				max_r = maxf(max_r, c.r)
				max_g = maxf(max_g, c.g)
				max_b = maxf(max_b, c.b)
				max_a = maxf(max_a, c.a)
		print("FLOOR_INFLUENCE_SMOKE: maxima r=%.4f g=%.4f b=%.4f a=%.4f" % [max_r, max_g, max_b, max_a])
	else:
		print("FLOOR_INFLUENCE_SMOKE: image readback unavailable in this renderer")
	print("FLOOR_INFLUENCE_SMOKE: PASS")
	quit(0)
