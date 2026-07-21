extends SceneTree

const SpriteRegistryScript := preload("res://scripts/renderers/sprite_registry.gd")
const EXPECTED_REGION := Rect2(0.0, 376.0, 1536.0, 232.0)

var _failed := false

func _init() -> void:
	var registry: SpriteRegistry = SpriteRegistryScript.new()
	var texture: Texture2D = registry.get_tex("lane.points")
	_expect(texture is AtlasTexture, "lane.points must resolve to manifest-trimmed AtlasTexture")
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		_expect(atlas.region == EXPECTED_REGION, "lane.points region mismatch: %s" % str(atlas.region))
		_expect(atlas.atlas != null, "lane.points atlas source missing")
		if atlas.atlas != null:
			_expect(Vector2i(atlas.atlas.get_width(), atlas.atlas.get_height()) == Vector2i(1536, 1024), "lane.points source size changed")
	var source := FileAccess.get_file_as_string("res://scripts/renderers/lane_renderer.gd")
	_expect(not source.contains("get_image()"), "LaneRenderer must not read textures back at runtime")
	_expect(not source.contains("get_pixel("), "LaneRenderer must not scan texture pixels at runtime")

	registry.free()
	if _failed:
		quit(1)
		return
	print("LANE_TEXTURE_METADATA_SMOKE_PASS")
	quit(0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("LANE_TEXTURE_METADATA_SMOKE_FAIL: %s" % message)
