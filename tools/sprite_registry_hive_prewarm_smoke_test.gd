extends SceneTree

const SpriteRegistryScript := preload("res://scripts/renderers/sprite_registry.gd")
const HiveRendererScript := preload("res://scripts/renderers/hive_renderer.gd")
const StartupHitchDiagnosticScript := preload("res://scripts/dev/startup_hitch_diagnostic.gd")

const OUTPUT_PATH: String = "user://startup_hitch_diagnostic/sprite_registry_hive_prewarm_smoke.json"

var _failed: bool = false

func _init() -> void:
	await process_frame

	var registry: SpriteRegistry = SpriteRegistryScript.get_instance()
	await process_frame
	_assert_true(registry != null, "registry should be available")
	if registry == null:
		quit(1)
		return

	var diagnostic: Node = StartupHitchDiagnosticScript.new()
	diagnostic.name = "SpriteRegistryHivePrewarmDiagnostic"
	root.add_child(diagnostic)
	_assert_true(bool(diagnostic.call("configure", {
		"output_path": OUTPUT_PATH,
		"window_seconds": 5.0,
		"launch_classification": "smoke",
		"source_commit": "smoke"
	})), "diagnostic should configure")
	diagnostic.set_process(false)

	var hive_renderer: Node = HiveRendererScript.new()
	hive_renderer.name = "HiveRendererPrewarmProbe"
	root.add_child(hive_renderer)
	hive_renderer.call("_prewarm_hive_sprite_cache")
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

	var report: Dictionary = diagnostic.call("complete", "smoke_complete") as Dictionary
	var markers: Array = report.get("markers", []) as Array
	var registry_started: Array = markers.filter(
		func(marker: Dictionary) -> bool: return str(marker.get("name", "")) == "sprite_registry_hive_prewarm_started"
	)
	var registry_completed: Array = markers.filter(
		func(marker: Dictionary) -> bool: return str(marker.get("name", "")) == "sprite_registry_hive_prewarm_completed"
	)
	var key_markers: Array = markers.filter(
		func(marker: Dictionary) -> bool: return str(marker.get("name", "")).begins_with("sprite_registry_hive_prewarm_key_")
	)
	var renderer_started: Array = markers.filter(
		func(marker: Dictionary) -> bool: return str(marker.get("name", "")) == "hive_sprite_prewarm_started"
	)
	var renderer_completed: Array = markers.filter(
		func(marker: Dictionary) -> bool: return str(marker.get("name", "")) == "hive_sprite_prewarm_completed"
	)
	_assert_true(renderer_started.size() == 1, "renderer prewarm should emit one bounded start marker")
	_assert_true(renderer_completed.size() == 1, "renderer prewarm should emit one bounded completion marker")
	_assert_true(registry_started.size() == 1, "registry prewarm should emit one bounded start marker")
	_assert_true(registry_completed.size() == 1, "registry prewarm should emit one bounded completion marker")
	_assert_true(key_markers.size() == 15, "registry prewarm should emit one bounded marker for each hive key")
	if registry_completed.size() == 1:
		var completed_detail: Dictionary = (registry_completed[0] as Dictionary).get("detail", {}) as Dictionary
		_assert_true(int(completed_detail.get("keys_attempted", 0)) == 15, "completion marker should retain attempted-key count")
		_assert_true(int(completed_detail.get("keys_available", 0)) == 15, "completion marker should retain available-key count")
		print("SPRITE_REGISTRY_HIVE_PREWARM_DURATION_MS: %.3f" % float(completed_detail.get("duration_ms", -1.0)))
	_assert_true(bool((report.get("protected_state_integrity", {}) as Dictionary).get("pass", false)), "diagnostic markers must not mutate protected state")
	hive_renderer.queue_free()
	diagnostic.queue_free()
	await process_frame
	if FileAccess.file_exists(OUTPUT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUTPUT_PATH))

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
