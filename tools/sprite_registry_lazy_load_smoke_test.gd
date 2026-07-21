extends SceneTree

const SpriteRegistryScript := preload("res://scripts/renderers/sprite_registry.gd")

var _failed: bool = false

func _init() -> void:
	var registry: SpriteRegistry = SpriteRegistryScript.new()
	var lane_path: String = registry.get_tex_path("lane.points")
	_expect(not lane_path.is_empty(), "manifest metadata should resolve lane.points")
	_expect(_loaded_textures(registry).is_empty(), "manifest parsing must not load texture resources")
	_expect(registry.get_scale("hive.small.neutral") > 1.0, "manifest scale metadata should remain available")
	_expect(_loaded_textures(registry).is_empty(), "metadata reads must not load texture resources")

	var lane_texture: Texture2D = registry.get_tex("lane.points")
	_expect(lane_texture is AtlasTexture, "lane.points should load its trimmed AtlasTexture on demand")
	_expect(_loaded_textures(registry).size() == 1, "one requested key should create one texture-cache entry")
	_expect(registry.get_tex("lane.points") == lane_texture, "repeated requests should reuse the cached texture")
	_expect(_loaded_textures(registry).size() == 1, "a cached request must not grow the texture cache")

	_expect(registry.has_tex("ui.mm.play.normal"), "has_tex should preserve resource-availability semantics")
	_expect(_loaded_textures(registry).size() == 2, "has_tex should load only the inspected key")
	_expect(not _loaded_textures(registry).has("ui.mm.play.hover"), "a sibling key sharing the path must remain lazy")

	registry.set_skin(SpriteRegistryScript.DEFAULT_MANIFEST_PATH)
	_expect(_loaded_textures(registry).is_empty(), "changing skins should discard loaded texture entries")
	_expect(registry.get_tex_path("lane.points") == lane_path, "skin reload should preserve manifest paths")
	var paths: Dictionary = registry.get("_paths_by_key") as Dictionary
	for key_v in paths.keys():
		var key: String = str(key_v)
		_expect(registry.has_tex(key), "manifest texture should remain loadable on demand: %s" % key)
	_expect(_loaded_textures(registry).size() == paths.size(), "every manifest key should preserve its texture construction contract")

	registry.free()
	if _failed:
		quit(1)
		return
	print("SPRITE_REGISTRY_LAZY_LOAD_SMOKE: PASS")
	quit(0)

func _loaded_textures(registry: SpriteRegistry) -> Dictionary:
	return registry.get("_textures_by_key") as Dictionary

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SPRITE_REGISTRY_LAZY_LOAD_SMOKE: %s" % message)
