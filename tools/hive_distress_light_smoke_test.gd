extends SceneTree

const HiveRendererScript := preload("res://scripts/renderers/hive_renderer.gd")
const HiveDistressRules := preload("res://scripts/hive/hive_distress_rules.gd")

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_rules()
	var renderer := HiveRendererScript.new()
	get_root().add_child(renderer)
	renderer.setup(null, null, null)
	await process_frame

	renderer.set_model(_model(501, 1, 7, true))
	await process_frame
	_expect(_state(renderer, 1) == "normal", "power above critical entry must remain normal")

	renderer.set_model(_model(501, 1, 6, true))
	await process_frame
	_expect(_state(renderer, 1) == "critical", "viewer-owned hive at power 6 with real pressure must become critical")

	renderer.set_model(_model(501, 1, 8, true))
	await process_frame
	_expect(_state(renderer, 1) == "critical", "critical state must remain active inside the exit hysteresis band")

	renderer.set_model(_model(501, 1, 9, true))
	await process_frame
	_expect(_state(renderer, 1) == "normal", "critical state must exit at power 9")

	renderer.set_model(_model(501, 1, 3, true))
	await process_frame
	_expect(_state(renderer, 1) == "imminent", "power 3 must enter imminent state")

	renderer.set_model(_model(501, 1, 4, true))
	await process_frame
	_expect(_state(renderer, 1) == "imminent", "imminent state must remain active below its exit threshold")

	renderer.set_model(_model(501, 1, 5, true))
	await process_frame
	_expect(_state(renderer, 1) == "critical", "imminent recovery at power 5 must step down to critical")

	renderer.set_model(_model(501, 1, 5, false))
	await process_frame
	_expect(_state(renderer, 1) == "normal", "loss of genuine hostile force must clear distress eligibility")

	renderer.set_model(_model(501, 2, 2, true))
	await process_frame
	_expect(_state(renderer, 1) == "normal", "enemy-owned hive must not warn the viewing player")

	renderer.set_model(_model(501, 1, 2, true))
	await process_frame
	_expect(_capture_suppressed(renderer, 1), "ownership change must give the capture beat visual precedence")
	await create_timer(0.15).timeout
	_expect(_state(renderer, 1) == "imminent", "new viewer-owned state may reevaluate after capture precedence releases")

	var hive: Node = renderer.get_hive_node_by_id(1)
	_expect(hive != null, "distress integration must use the real hive node")
	renderer.set_model(_model(501, 1, 6, true))
	await process_frame
	renderer.set_model(_model(501, 1, 10, true))
	await process_frame
	var recovery_growth: Dictionary = hive.call("get_distress_debug_snapshot") as Dictionary
	_expect(bool(recovery_growth.get("growth_suppressed", false)), "recovery jump across a growth threshold must give growth visual precedence")
	_expect(str(recovery_growth.get("state", "")) == "normal", "recovery jump must leave the distress state immediately")
	await create_timer(0.78).timeout
	_expect(_state(renderer, 1) == "normal", "distress must remain off after the recovery growth settles")

	if hive != null:
		renderer.set_model(_model(501, 1, 2, true))
		await process_frame
		hive.call("_set_distress_growth_suppressed", true)
		var suppressed: Dictionary = hive.call("get_distress_debug_snapshot") as Dictionary
		_expect(bool(suppressed.get("growth_suppressed", false)), "growth must suppress distress")
		_expect(float(suppressed.get("current_intensity", 1.0)) == 0.0, "growth suppression must clear the plume immediately")
		hive.call("_set_distress_growth_suppressed", false)
		await process_frame
		_expect(not bool((hive.call("get_distress_debug_snapshot") as Dictionary).get("growth_suppressed", true)), "distress must reevaluate after growth releases")

	renderer.animations_enabled = false
	renderer.set_model(_model(501, 1, 2, true))
	await process_frame
	_expect(_motion_mode(renderer, 1) == "none", "disabled animation mode must retain only the static warning treatment")
	renderer.animations_enabled = true

	var component: Node = hive.get_node_or_null("Visual/FxLayer/HiveDistressLight") if hive != null else null
	var child_count: int = component.get_child_count() if component != null else -1
	var material_instance_id: int = int(
		(hive.call("get_distress_debug_snapshot") as Dictionary).get("material_instance_id", 0)
	) if hive != null else 0
	for i in range(12):
		renderer.set_model(_model(501, 1, 6 if i % 2 == 0 else 9, true))
		await process_frame
	_expect(component != null and component.get_child_count() == child_count, "repeated activation must not grow component nodes")
	_expect(int(renderer.get_distress_debug_snapshot().get("max_component_child_count", -1)) == 0, "distress component must use a fixed zero-child drawing path")
	_expect(
		int((hive.call("get_distress_debug_snapshot") as Dictionary).get("material_instance_id", -1))
		== material_instance_id,
		"repeated activation must retain one bounded component material"
	)

	renderer.call("_on_app_backgrounded", "test", 0, 0)
	await process_frame
	_expect(_lifecycle_suspended(renderer, 1), "backgrounding must suspend presentation motion")
	renderer.call("_on_app_foregrounded", "test", 0, 0)
	await process_frame
	_expect(not _lifecycle_suspended(renderer, 1), "foregrounding must resume presentation cleanly")

	renderer.clear_all()
	await process_frame
	_expect(renderer.get_hive_ids().is_empty(), "renderer cleanup must release all distress components with their hives")

	if _failed:
		quit(1)
		return
	print("HIVE_DISTRESS_LIGHT_SMOKE: PASS")
	quit(0)

func _test_rules() -> void:
	_expect(
		HiveDistressRules.next_state(HiveDistressRules.STATE_NORMAL, 1, 1, 6, true)
		== HiveDistressRules.STATE_CRITICAL,
		"rule mapper must enter critical at 6"
	)
	_expect(
		HiveDistressRules.next_state(HiveDistressRules.STATE_NORMAL, 1, 1, 3, true)
		== HiveDistressRules.STATE_IMMINENT,
		"rule mapper must enter imminent at 3"
	)
	_expect(
		HiveDistressRules.next_state(HiveDistressRules.STATE_NORMAL, 1, 2, 1, true)
		== HiveDistressRules.STATE_NORMAL,
		"rule mapper must remain viewer-relative"
	)
	_expect(
		HiveDistressRules.next_state(HiveDistressRules.STATE_CRITICAL, 1, 1, 2, false)
		== HiveDistressRules.STATE_NORMAL,
		"rule mapper must require live hostile pressure"
	)

func _model(iid: int, owner_id: int, power: int, pressure: bool) -> Dictionary:
	return {
		"iid": iid,
		"cell_size": 64,
		"sim_running": true,
		"viewer_owner_id": 1,
		"hives": [{
			"id": 1,
			"x": 4.0,
			"y": 5.0,
			"owner_id": owner_id,
			"pwr": power,
			"growth_tier": HiveGrowthRules.tier_for_power(power),
			"lane_budget_used": 0,
			"lane_budget_max": HiveGrowthRules.lane_budget_for_power(power),
			"hostile_capture_pressure": pressure,
			"kind": "Hive"
		}],
		"lanes": []
	}

func _hive_snapshot(renderer: Node, hive_id: int) -> Dictionary:
	var all: Dictionary = renderer.call("get_distress_debug_snapshot") as Dictionary
	return (all.get("by_hive", {}) as Dictionary).get(hive_id, {}) as Dictionary

func _state(renderer: Node, hive_id: int) -> String:
	return str(_hive_snapshot(renderer, hive_id).get("state", "missing"))

func _capture_suppressed(renderer: Node, hive_id: int) -> bool:
	return bool(_hive_snapshot(renderer, hive_id).get("capture_suppressed", false))

func _motion_mode(renderer: Node, hive_id: int) -> String:
	return str(_hive_snapshot(renderer, hive_id).get("motion_mode", "missing"))

func _lifecycle_suspended(renderer: Node, hive_id: int) -> bool:
	return bool(_hive_snapshot(renderer, hive_id).get("lifecycle_suspended", false))

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("HIVE_DISTRESS_LIGHT_SMOKE: %s" % message)
