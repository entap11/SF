extends SceneTree

const SETTINGS_LANE_VISUAL_HIERARCHY_ENABLED: String = "swarmfront/arena/lane_visual_hierarchy_enabled"
const LaneVisualHierarchyScript: Script = preload("res://scripts/renderers/lane_visual_hierarchy.gd")

var _failed: bool = false

func _initialize() -> void:
	ProjectSettings.set_setting(SETTINGS_LANE_VISUAL_HIERARCHY_ENABLED, true)
	await process_frame

	var embedded_lane: Dictionary = {
		"lane_id": 1,
		"a_id": 1,
		"b_id": 2,
		"send_a": true,
		"send_b": false
	}
	var active_lane: Dictionary = embedded_lane.duplicate(true)
	active_lane["intent"] = "swarm"
	var contested_lane: Dictionary = embedded_lane.duplicate(true)
	contested_lane["send_b"] = true

	_expect_true(str(LaneVisualHierarchyScript.call("state_for_lane", embedded_lane)) == "embedded", "Normal one-way lane should derive embedded state")
	_expect_true(str(LaneVisualHierarchyScript.call("state_for_lane", active_lane)) == "active", "Emphasized/swarm lane should derive active state")
	_expect_true(str(LaneVisualHierarchyScript.call("state_for_lane", contested_lane)) == "contested", "Two-way lane should derive contested state")
	_expect_true(bool(LaneVisualHierarchyScript.call("is_enabled")), "Feature flag should be readable from project settings")

	var arena_scene: PackedScene = load("res://scenes/Arena.tscn") as PackedScene
	_expect_true(arena_scene != null, "Arena scene should load with lane hierarchy helper")
	if arena_scene != null:
		var arena: Node = arena_scene.instantiate()
		var lane_renderer: Node = arena.get_node_or_null("MapRoot/LaneRenderer")
		_expect_true(lane_renderer != null, "Arena scene should expose LaneRenderer")
		if lane_renderer != null:
			_expect_true(str(lane_renderer.call("lane_visual_state_for_lane", contested_lane)) == "contested", "Scene LaneRenderer should delegate visual state derivation")
		arena.free()

	var embedded_profile: Dictionary = LaneVisualHierarchyScript.call("profile_for_state", "embedded") as Dictionary
	var active_profile: Dictionary = LaneVisualHierarchyScript.call("profile_for_state", "active") as Dictionary
	var contested_profile: Dictionary = LaneVisualHierarchyScript.call("profile_for_state", "contested") as Dictionary
	_expect_true(int(embedded_profile.get("z_index", 0)) < int(active_profile.get("z_index", 0)), "Embedded lanes should sit below active lanes")
	_expect_true(int(active_profile.get("z_index", 0)) < int(contested_profile.get("z_index", 0)), "Contested lanes should sit above active lanes")
	_expect_true(float(embedded_profile.get("alpha", 0.0)) < float(active_profile.get("alpha", 0.0)), "Embedded lanes should be dimmer than active lanes")
	_expect_true(float(active_profile.get("alpha", 0.0)) < float(contested_profile.get("alpha", 0.0)), "Contested lanes should be brighter than active lanes")
	_expect_true(float(embedded_profile.get("width", 0.0)) < float(active_profile.get("width", 0.0)), "Embedded lanes should be narrower than active lanes")
	_expect_true(float(active_profile.get("width", 0.0)) < float(contested_profile.get("width", 0.0)), "Contested lanes should be wider than active lanes")
	_expect_true(float(embedded_profile.get("brightness", 1.0)) < float(active_profile.get("brightness", 1.0)), "Embedded lanes should be darker than active lanes")
	_expect_true(float(active_profile.get("brightness", 1.0)) < float(contested_profile.get("brightness", 1.0)), "Contested lanes should be brighter than active lanes")
	_expect_true(float(embedded_profile.get("saturation", 1.0)) < float(active_profile.get("saturation", 1.0)), "Embedded lanes should be more desaturated than active lanes")
	_expect_true(float(active_profile.get("saturation", 1.0)) < float(contested_profile.get("saturation", 1.0)), "Contested lanes should be most saturated")
	_expect_true(not bool(embedded_profile.get("pulse_enabled", true)), "Embedded lanes should not pulse")
	_expect_true(bool(contested_profile.get("pulse_enabled", false)), "Contested lanes may pulse")
	var bright_yellow: Color = Color(1.0, 0.92, 0.0, 1.0)
	var embedded_color: Color = LaneVisualHierarchyScript.call("apply_profile_to_color", bright_yellow, embedded_profile, 0) as Color
	var contested_color: Color = LaneVisualHierarchyScript.call("apply_profile_to_color", bright_yellow, contested_profile, 0) as Color
	_expect_true(embedded_color.a < contested_color.a, "Embedded lane color should be more transparent than contested")
	_expect_true(_color_luma(embedded_color) < _color_luma(contested_color), "Embedded lane color should be darker than contested")

	var entry: Dictionary = {}
	var changed_first: bool = bool(LaneVisualHierarchyScript.call("sync_entry_profile", entry, embedded_lane, true))
	var changed_second: bool = bool(LaneVisualHierarchyScript.call("sync_entry_profile", entry, embedded_lane, true))
	_expect_true(changed_first, "First profile sync should update the cache")
	_expect_true(not changed_second, "Repeated same-state profile sync should do nothing")
	_expect_true(str(entry.get("visual_state", "")) == "embedded", "Entry should cache embedded visual state")

	var lane_before: Dictionary = contested_lane.duplicate(true)
	LaneVisualHierarchyScript.call("sync_entry_profile", entry, contested_lane, false)
	_expect_true(str(entry.get("visual_state", "")) == "contested", "Entry should cache contested visual state")
	_expect_true(contested_lane == lane_before, "Visual profile sync should not mutate lane input data")

	if not _failed:
		print("LANE_VISUAL_HIERARCHY_SMOKE: PASS")
	quit(1 if _failed else 0)

func _expect_true(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("LANE_VISUAL_HIERARCHY_SMOKE: %s" % message)

func _color_luma(color: Color) -> float:
	return (color.r * 0.299) + (color.g * 0.587) + (color.b * 0.114)
