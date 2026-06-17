extends SceneTree

const SETTINGS_POLISH_ENABLED: String = "swarmfront/arena/premium_polish_enabled"
const SETTINGS_TOWER_VISUAL_SCALE: String = "swarmfront/arena/tower_visual_scale"
const SETTINGS_COMPARISON_MODE: String = "swarmfront/arena/polish_comparison_mode"
const MANIFEST_PATH: String = "res://assets/sprites/arena_polish/arena_polish_manifest.json"
const ArenaPolishLayerScript: Script = preload("res://scripts/renderers/arena_polish_layer.gd")
const POLISH_Z_INDEX: int = -15

var _failed: bool = false

func _initialize() -> void:
	ProjectSettings.set_setting(SETTINGS_POLISH_ENABLED, false)
	ProjectSettings.set_setting(SETTINGS_TOWER_VISUAL_SCALE, 1.25)
	ProjectSettings.set_setting(SETTINGS_COMPARISON_MODE, "settings")
	await process_frame

	var arena_source: String = FileAccess.get_file_as_string("res://scripts/arena.gd")
	_expect_true(arena_source.contains("func apply_arena_visual_comparison_mode"), "Arena should expose a visual comparison mode helper")
	_expect_true(arena_source.contains("func arena_visual_comparison_modes"), "Arena should expose available visual comparison modes")
	_expect_true(DirAccess.dir_exists_absolute("res://assets/sprites/arena_polish/props"), "Arena polish props folder should be tracked")
	_expect_true(DirAccess.dir_exists_absolute("res://assets/sprites/arena_polish/vfx"), "Arena polish vfx folder should be tracked")
	_expect_true(DirAccess.dir_exists_absolute("res://assets/sprites/arena_polish/lighting"), "Arena polish lighting folder should be tracked")
	_expect_true(FileAccess.file_exists(MANIFEST_PATH), "Arena polish manifest should exist")

	var arena_scene: PackedScene = load("res://scenes/Arena.tscn") as PackedScene
	_expect_true(arena_scene != null, "Arena scene should load")
	if arena_scene != null:
		var arena: Node = arena_scene.instantiate()
		var scene_layer: Node = arena.get_node_or_null("MapRoot/ArenaPolishLayer")
		_expect_true(scene_layer != null, "Arena scene should include MapRoot/ArenaPolishLayer")
		if scene_layer != null:
			_expect_true(scene_layer.get_script() == ArenaPolishLayerScript, "Scene polish layer should use ArenaPolishLayer script")
			_expect_true(scene_layer.get_parent().name == "MapRoot", "Polish layer should live under MapRoot")
			_expect_true((scene_layer as CanvasItem).visible == false, "Polish layer should be hidden by default")
			_expect_true((scene_layer as CanvasItem).z_index == POLISH_Z_INDEX, "Polish layer should stay below gameplay objects")
			_expect_no_physics_nodes(scene_layer)
		arena.free()

	var layer: Node2D = ArenaPolishLayerScript.new() as Node2D
	root.add_child(layer)
	await process_frame
	_expect_true(layer.visible == false, "Runtime polish layer should honor disabled default")
	_expect_true(bool(layer.get_meta("render_only", false)), "Layer should be marked render-only")
	_expect_true(bool(layer.get_meta("premium_arena_polish", false)), "Layer should be marked as arena polish")
	_expect_true(bool(layer.get_meta("gameplay_affects_state", true)) == false, "Layer should be marked non-gameplay")
	_expect_true(float(layer.call("tower_visual_scale")) == 1.25, "Tower visual scale setting should be readable")
	var manifest: Dictionary = layer.call("manifest") as Dictionary
	_expect_true(int(manifest.get("version", 0)) == 1, "Manifest should load with version 1")
	_expect_true((layer.call("manifest_errors") as PackedStringArray).is_empty(), "Manifest should validate cleanly")
	_expect_true((layer.call("approved_entries") as Array).is_empty(), "Manifest should place no assets until entries are added")

	ProjectSettings.set_setting(SETTINGS_POLISH_ENABLED, true)
	layer.call("apply_runtime_settings")
	_expect_true(layer.visible == true, "Runtime polish layer should show when enabled")
	ProjectSettings.set_setting(SETTINGS_POLISH_ENABLED, false)
	layer.call("apply_runtime_settings")
	_expect_true(layer.visible == false, "Runtime polish layer should hide when disabled")

	ArenaPolishLayerScript.call("apply_comparison_mode", "tower_150")
	layer.call("apply_runtime_settings")
	_expect_true(layer.visible == true, "Tower comparison mode should enable polish visibility")
	_expect_true(float(layer.call("tower_visual_scale")) == 1.50, "Tower comparison mode should force requested visual scale")
	ArenaPolishLayerScript.call("apply_comparison_mode", "baseline")
	layer.call("apply_runtime_settings")
	_expect_true(layer.visible == false, "Baseline comparison mode should hide polish visibility")
	_expect_true(float(layer.call("tower_visual_scale")) == 1.0, "Baseline comparison mode should force 1.0 tower scale")
	layer.free()

	if not _failed:
		print("ARENA_POLISH_LAYER_SMOKE: PASS")
	quit(1 if _failed else 0)

func _expect_no_physics_nodes(root_node: Node) -> void:
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		_expect_true(not (node is CollisionObject2D), "Polish layer should not include CollisionObject2D nodes")
		_expect_true(not (node is CollisionShape2D), "Polish layer should not include CollisionShape2D nodes")
		_expect_true(not (node is CollisionPolygon2D), "Polish layer should not include CollisionPolygon2D nodes")
		for child in node.get_children():
			stack.append(child)

func _expect_true(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("ARENA_POLISH_LAYER_SMOKE: %s" % message)
