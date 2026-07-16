extends SceneTree

const HiveRendererScript := preload("res://scripts/renderers/hive_renderer.gd")

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("swarmfront/arena/dynamic_hive_shadows_enabled", true)
	var renderer: Node2D = HiveRendererScript.new() as Node2D
	root.add_child(renderer)
	renderer.call("set_model", {
		"iid": 9001,
		"cell_size": 64,
		"clock": {
			"started": true,
			"elapsed_ms": 0,
			"duration_ms": 300000,
			"regulation_duration_ms": 300000,
			"in_overtime": false
		},
		"hives": [
			{
				"id": 1,
				"x": 2,
				"y": 2,
				"owner_id": 1,
				"pwr": 6,
				"growth_tier": 1,
				"lane_budget_used": 0,
				"lane_budget_max": 1,
				"kind": "Hive"
			},
			{
				"id": 2,
				"x": 5,
				"y": 2,
				"owner_id": 2,
				"pwr": 14,
				"growth_tier": 2,
				"lane_budget_used": 0,
				"lane_budget_max": 2,
				"kind": "Hive"
			},
			{
				"id": 3,
				"x": 8,
				"y": 2,
				"owner_id": 1,
				"pwr": 30,
				"growth_tier": 3,
				"lane_budget_used": 0,
				"lane_budget_max": 3,
				"kind": "Hive"
			}
		],
		"lanes": []
	})
	await process_frame
	var controller_snapshot: Dictionary = renderer.call("get_match_shadow_debug_snapshot") as Dictionary
	_expect(bool(controller_snapshot.get("enabled", false)), "renderer controller should be enabled")
	_expect(int(controller_snapshot.get("material_count", 0)) == 3, "renderer should own three shared tier materials")
	var nodes: Dictionary = renderer.call("get_hive_nodes_by_id") as Dictionary
	_expect(nodes.size() == 3, "renderer should create all three fixture hives")
	for hive_id in [1, 2, 3]:
		var hive: Node = nodes.get(hive_id, null) as Node
		_expect(hive != null, "fixture hive %d should exist" % hive_id)
		if hive == null:
			continue
		var shadow_snapshot: Dictionary = hive.call("get_match_shadow_debug_snapshot") as Dictionary
		_expect(bool(shadow_snapshot.get("visible", false)), "fixture hive %d shadow should be visible" % hive_id)
		_expect(bool(shadow_snapshot.get("has_material", false)), "fixture hive %d should have a shadow material" % hive_id)
		_expect(bool(shadow_snapshot.get("has_texture", false)), "fixture hive %d should have a shadow texture" % hive_id)
		_expect(bool(shadow_snapshot.get("contact_visible", false)), "fixture hive %d contact shadow should be visible" % hive_id)
	if _failed:
		quit(1)
		return
	print("MATCH_SHADOW_RENDERER_SMOKE: PASS")
	quit(0)

func _expect(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("MATCH_SHADOW_RENDERER_SMOKE: %s" % message)
