extends SceneTree

const SpriteRegistryScript := preload("res://scripts/renderers/sprite_registry.gd")

var _failed: bool = false

func _init() -> void:
	await process_frame

	var registry: SpriteRegistry = SpriteRegistryScript.get_instance()
	await process_frame
	_assert_true(registry != null, "registry should be available")
	if registry == null:
		quit(1)
		return

	registry.prewarm_hive_textures()

	for tier_key in ["small", "med", "large"]:
		var neutral_tex: Texture2D = registry.get_tex("hive.%s.neutral" % tier_key)
		_assert_true(neutral_tex != null, "neutral %s hive texture should load" % tier_key)
		for owner_key in ["p1", "p2", "p3", "p4"]:
			var owner_tex: Texture2D = registry.get_tex("hive.%s.%s" % [tier_key, owner_key])
			_assert_true(owner_tex == neutral_tex, "%s %s should reuse the tier texture" % [tier_key, owner_key])

	var alpha_cache: Dictionary = registry.get("_tex_alpha_cache") as Dictionary
	_assert_true(alpha_cache.size() <= 3, "hive prewarm should convert each tier once")
	for cache_key_any in alpha_cache.keys():
		_assert_true(not str(cache_key_any).contains("hive_large_flatop_alpha.png"), "large hive should bypass runtime alpha conversion")

	if _failed:
		quit(1)
		return
	print("SPRITE_REGISTRY_HIVE_PREWARM_SMOKE: PASS")
	quit(0)

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	_failed = true
	push_error("SPRITE_REGISTRY_HIVE_PREWARM_SMOKE: %s" % label)
