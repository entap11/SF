extends SceneTree

const HiveRendererScript := preload("res://scripts/renderers/hive_renderer.gd")
const HiveDistressRules := preload("res://scripts/hive/hive_distress_rules.gd")
const HiveGrowthRules := preload("res://scripts/sim/hive_growth_rules.gd")

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_rules()
	var renderer := HiveRendererScript.new()
	get_root().add_child(renderer)
	renderer.setup(null, null, null)
	await process_frame

	# Tier ruptures are one-shot structural events and do not require pressure.
	await _set_model(renderer, 501, 30, 1, 1, false)
	_expect(_burst(renderer) == HiveDistressRules.BURST_NONE, "initial large hive must seed silently")
	var minor_before: int = _count(renderer, "minor_rupture_count")
	await _set_model(renderer, 501, 24, 1, 1, false)
	_expect(_burst(renderer) == HiveDistressRules.BURST_MINOR_RUPTURE, "25-to-24 tier loss must emit a minor rupture")
	_expect(_count(renderer, "minor_rupture_count") == minor_before + 1, "minor rupture must emit once")
	await _set_model(renderer, 501, 23, 1, 1, false)
	_expect(_count(renderer, "minor_rupture_count") == minor_before + 1, "same-tier decline must not replay minor rupture")

	await _set_model(renderer, 502, 10, 1, 1, false)
	var major_before: int = _count(renderer, "major_rupture_count")
	await _set_model(renderer, 502, 9, 1, 1, false)
	_expect(_burst(renderer) == HiveDistressRules.BURST_MAJOR_RUPTURE, "10-to-9 tier loss must emit a major rupture")
	_expect(_count(renderer, "major_rupture_count") == major_before + 1, "major rupture must emit once")
	_expect(not _pressure_active(renderer), "tier rupture alone must not sustain pressure")

	# Low power and even first-observation hostile commitment are insufficient.
	var entry_before: int = _count(renderer, "critical_entry_count")
	await _set_model(renderer, 503, 4, 1, 1, true)
	_expect(not _pressure_active(renderer), "first observation below five must seed silently")
	_expect(_count(renderer, "critical_entry_count") == entry_before, "silent seed must not invent pressure entry")

	# A genuine hostile decline into the danger range triggers and refreshes.
	await _set_model(renderer, 504, 6, 1, 1, true)
	entry_before = _count(renderer, "critical_entry_count")
	await _set_model(renderer, 504, 5, 1, 1, true)
	_expect(_pressure_active(renderer), "hostile 6-to-5 decline must trigger pressure")
	_expect(_transition(renderer) == HiveDistressRules.PRESSURE_TRIGGER, "6-to-5 must classify as trigger")
	_expect(_count(renderer, "critical_entry_count") == entry_before + 1, "first pressure edge must emit one entry burst")
	await create_timer(0.22).timeout
	await _set_model(renderer, 504, 4, 1, 1, true)
	_expect(_pressure_active(renderer), "continued hostile decline must refresh pressure")
	_expect(float(_snapshot(renderer).get("pressure_hold_remaining", 0.0)) > 0.58, "decline must refresh the bounded hold")
	_expect(_count(renderer, "critical_entry_count") == entry_before + 1, "refresh must not replay entry burst")

	# Unchanged power only consumes the existing hold, then settles completely.
	await _set_model(renderer, 504, 4, 1, 1, true)
	_expect(_transition(renderer) == HiveDistressRules.PRESSURE_HOLD, "unchanged pressured snapshot must classify as hold")
	await create_timer(HiveDistressRules.PRESSURE_HOLD_SEC + 0.24).timeout
	_expect(not _pressure_active(renderer), "unchanged low power must expire after the bounded hold")
	_expect(float(_snapshot(renderer).get("current_intensity", 1.0)) <= 0.01, "expired pressure must finish its recovery fade")

	# Recovery and loss of genuine hostile commitment clear immediately.
	await _set_model(renderer, 505, 6, 1, 1, true)
	await _set_model(renderer, 505, 5, 1, 1, true)
	await _set_model(renderer, 505, 6, 1, 1, true)
	_expect(not _pressure_active(renderer), "power recovery must clear pressure immediately")
	_expect(_transition(renderer) == HiveDistressRules.PRESSURE_CLEAR, "recovery must classify as clear")
	await _set_model(renderer, 505, 5, 1, 1, true)
	_expect(_pressure_active(renderer), "later valid decline may retrigger")
	await _set_model(renderer, 505, 5, 1, 1, false)
	_expect(not _pressure_active(renderer), "loss of hostile commitment must clear pressure")

	# A decline without committed hostile force is never eligible.
	await _set_model(renderer, 506, 6, 1, 1, false)
	await _set_model(renderer, 506, 5, 1, 1, false)
	_expect(not _pressure_active(renderer), "6-to-5 without hostile commitment must not trigger")

	# Capture clears the old owner and silently seeds the new owner.
	await _set_model(renderer, 507, 6, 2, 1, true)
	await _set_model(renderer, 507, 4, 1, 1, true)
	_expect(not _pressure_active(renderer), "capture into low power must seed silently")
	_expect(_transition(renderer) == HiveDistressRules.PRESSURE_RESET, "owner change must reset pressure history")
	_expect(_capture_suppressed(renderer), "owner change must preserve capture precedence")
	await _set_model(renderer, 507, 5, 1, 1, true)
	_expect(not _pressure_active(renderer), "captured hive recovery must remain clear")
	await _set_model(renderer, 507, 4, 1, 1, true)
	_expect(_pressure_active(renderer), "captured hive may trigger after a later valid decline")

	# Match/viewer reconstruction reseeds without historical pressure or rupture.
	await _set_model(renderer, 508, 4, 1, 1, true)
	_expect(not _pressure_active(renderer), "new match instance must reseed low power silently")
	entry_before = _count(renderer, "critical_entry_count")
	await _set_model(renderer, 508, 4, 1, 2, true)
	await _set_model(renderer, 508, 4, 1, 1, true)
	_expect(not _pressure_active(renderer), "viewer identity change must reseed without pressure")
	_expect(_count(renderer, "critical_entry_count") == entry_before, "viewer reseed must not replay entry")

	# Upward growth owns recovery and suppresses the distress component.
	await _set_model(renderer, 509, 6, 1, 1, true)
	await _set_model(renderer, 509, 5, 1, 1, true)
	await _set_model(renderer, 509, 10, 1, 1, true)
	var recovery: Dictionary = _snapshot(renderer)
	_expect(bool(recovery.get("growth_suppressed", false)), "growth recovery must suppress distress")
	_expect(not bool(recovery.get("pressure_active", true)), "growth recovery must clear pressure immediately")
	await create_timer(0.78).timeout
	_expect(not bool(_snapshot(renderer).get("growth_suppressed", true)), "growth completion must release distress suppression")

	# Repeated activation retains a fixed component and material.
	await _set_model(renderer, 510, 6, 1, 1, true)
	await _set_model(renderer, 510, 5, 1, 1, true)
	var hive: Node = renderer.get_hive_node_by_id(1)
	var component: Node = hive.get_node_or_null("Visual/FxLayer/HiveDistressLight") if hive != null else null
	var child_count: int = component.get_child_count() if component != null else -1
	var material_id: int = int(_snapshot(renderer).get("material_instance_id", 0))
	for i in range(20):
		await _set_model(renderer, 510, 6, 1, 1, true)
		await _set_model(renderer, 510, 5, 1, 1, true)
	_expect(component != null and component.get_child_count() == child_count, "repeated pressure must not grow component nodes")
	_expect(int(renderer.get_distress_debug_snapshot().get("max_component_child_count", -1)) == 0, "distress must retain its zero-child draw path")
	_expect(int(_snapshot(renderer).get("material_instance_id", -1)) == material_id, "repeated pressure must retain one material")

	renderer.call("_on_app_backgrounded", "test", 0, 0)
	await process_frame
	_expect(bool(_snapshot(renderer).get("lifecycle_suspended", false)), "backgrounding must suspend presentation motion")
	renderer.call("_on_app_foregrounded", "test", 0, 0)
	await process_frame
	_expect(not bool(_snapshot(renderer).get("lifecycle_suspended", true)), "foregrounding must resume presentation")

	renderer.clear_all()
	await process_frame
	_expect(renderer.get_hive_ids().is_empty(), "renderer cleanup must release all distress components")

	if _failed:
		quit(1)
		return
	print("HIVE_DISTRESS_LIGHT_SMOKE: PASS")
	quit(0)

func _test_rules() -> void:
	_expect(
		HiveDistressRules.classify_pressure_transition(false, 1, 1, 1, 4, 4, true)
		== HiveDistressRules.PRESSURE_RESET,
		"invalid history must reset"
	)
	_expect(
		HiveDistressRules.classify_pressure_transition(true, 1, 1, 1, 6, 5, true)
		== HiveDistressRules.PRESSURE_TRIGGER,
		"hostile 6-to-5 must trigger"
	)
	_expect(
		HiveDistressRules.classify_pressure_transition(true, 1, 1, 1, 5, 5, true)
		== HiveDistressRules.PRESSURE_HOLD,
		"unchanged hostile sample must hold"
	)
	_expect(
		HiveDistressRules.classify_pressure_transition(true, 1, 1, 1, 5, 6, true)
		== HiveDistressRules.PRESSURE_CLEAR,
		"recovery must clear"
	)
	_expect(
		HiveDistressRules.classify_pressure_transition(true, 1, 1, 1, 6, 5, false)
		== HiveDistressRules.PRESSURE_CLEAR,
		"missing hostile commitment must clear"
	)
	_expect(
		HiveDistressRules.classify_tier_rupture(HiveGrowthRules.TIER_LARGE, HiveGrowthRules.TIER_MEDIUM)
		== HiveDistressRules.BURST_MINOR_RUPTURE,
		"large-to-medium must classify as minor rupture"
	)
	_expect(
		HiveDistressRules.classify_tier_rupture(HiveGrowthRules.TIER_MEDIUM, HiveGrowthRules.TIER_SMALL)
		== HiveDistressRules.BURST_MAJOR_RUPTURE,
		"medium-to-small must classify as major rupture"
	)

func _set_model(
	renderer: Node,
	iid: int,
	power: int,
	owner_id: int = 1,
	viewer_owner_id: int = 1,
	pressure: bool = true
) -> void:
	renderer.set_model({
		"iid": iid,
		"cell_size": 64,
		"sim_running": true,
		"viewer_owner_id": viewer_owner_id,
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
	})
	await process_frame

func _snapshot(renderer: Node) -> Dictionary:
	var all: Dictionary = renderer.call("get_distress_debug_snapshot") as Dictionary
	return (all.get("by_hive", {}) as Dictionary).get(1, {}) as Dictionary

func _burst(renderer: Node) -> String:
	return str(_snapshot(renderer).get("burst_kind", "missing"))

func _pressure_active(renderer: Node) -> bool:
	return bool(_snapshot(renderer).get("pressure_active", false))

func _transition(renderer: Node) -> String:
	return str(_snapshot(renderer).get("pressure_transition", "missing"))

func _count(renderer: Node, key: String) -> int:
	return int(_snapshot(renderer).get(key, -1))

func _capture_suppressed(renderer: Node) -> bool:
	return bool(_snapshot(renderer).get("capture_suppressed", false))

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("HIVE_DISTRESS_LIGHT_SMOKE: %s" % message)
