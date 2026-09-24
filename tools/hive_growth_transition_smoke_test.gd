extends SceneTree

const Renderer := preload("res://scripts/renderers/hive_renderer.gd")
const Timing := preload("res://scripts/hive/hive_transition_timing.gd")
var _failed := false
var _starts := 0
var _reveals := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var renderer := Renderer.new()
	root.add_child(renderer)
	renderer.setup(null, null, null)
	await process_frame
	renderer.set_model(_model(101, 9, 1))
	var hive: Node = renderer.get_hive_node_by_id(1)
	var transition: Node = hive.get_node("Visual/FxLayer/HiveGrowthTransition")
	var visual: Node = hive.get_node("Visual")
	var base: Sprite2D = hive.get_node("Visual/BaseSpriteLayer/BaseSprite")
	transition.transition_started.connect(func(_a: int, _b: int): _starts += 1)
	transition.reveal_started.connect(func(_a: int): _reveals += 1)
	_expect(not transition.is_active(), "initial canonical sample must seed silently")
	var model := _model(101, 10, 2)
	var original := model.duplicate(true)
	renderer.set_model(model)
	transition.set_debug_elapsed(0.0)
	_expect(model == original, "presentation must never mutate its canonical input")
	_expect(_starts == 1 and transition.is_active(), "small to medium must start once")
	_expect(not base.visible, "proxy must cover the final sprite during reveal")
	_expect(base.texture != null and str(visual.get("_sprite_key")) == "hive.med.p1", "final canonical texture must already be installed")
	_expect((visual.get("_lane_budget_pips") as Array).size() == 2, "lane indicators must immediately reflect canonical budget")
	var material_ids: Array = transition.get_debug_snapshot().material_instance_ids
	var children: int = transition.get_child_count()
	var pip_nodes: Array = visual.get_node("LaneBudgetIndicators").get_children()
	var port_nodes: Array = visual.get_node("LanePortLayer").get_children()
	renderer.set_model(model)
	renderer.set_model(_model(101, 11, 2))
	_expect(_starts == 1, "duplicate samples and same-tier changes must not restart animation")
	renderer.set_selected_hive(1, Color.WHITE)
	transition.set_debug_elapsed(0.28)
	var surface := transition.get_node("TransformSurface").material as ShaderMaterial
	_expect(float(surface.get_shader_parameter("selected_hot")) == 1.0, "selection changes must reach the animated shell")
	_expect(is_equal_approx(float(surface.get_shader_parameter("selected_metal_lift")), float(base.material.get_shader_parameter("selected_metal_lift"))),
		"animated shell must preserve the live selection's metal lighting")
	_expect(is_equal_approx(float(surface.get_shader_parameter("selected_hot_edge")), float(base.material.get_shader_parameter("selected_hot_edge"))),
		"animated shell must preserve the live selection's edge lighting")
	renderer.clear_selected_hive()
	transition.set_debug_elapsed(0.29)
	_expect(float(surface.get_shader_parameter("selected_hot")) == 0.0, "deselection must reach the animated shell")
	_expect(_reveals == 1, "one reveal event per transition")
	_expect(hive.growth_tier == 2, "presentation footprint must commit at reveal")
	transition.set_debug_elapsed(0.8)
	_expect(not transition.is_active() and base.visible, "completion restores final sprite")

	# Both directions, tier jumps and reversals use the canonical edges.
	for edge in [[25,3],[24,2],[9,1],[25,3],[9,1],[10,2]]:
		var previous_starts := _starts
		renderer.set_model(_model(101, edge[0], edge[1]))
		_expect(_starts == previous_starts + 1, "each tier edge must produce one transform")
		transition.set_debug_elapsed(0.22)
		_expect(visual.get_node("LaneBudgetIndicators").get_children() == pip_nodes, "budget indicators must be reused across tier edges")
		_expect(visual.get_node("LanePortLayer").get_children() == port_nodes, "lane ports must be reused across tier edges")
		_expect(transition.get_debug_snapshot().material_instance_ids == material_ids, "materials must be reused")
		_expect(transition.get_child_count() == children, "node count must stay bounded")
	transition.set_debug_elapsed(1.0)
	var before := _starts
	renderer.set_model(_model(101, 25, 3, 2))
	_expect(_starts == before and not transition.is_active() and base.visible, "ownership change must cancel without a false tier celebration")
	renderer.set_model(_model(101, 24, 2, 2))
	_expect(transition.is_active(), "subsequent same-owner edge resumes presentation")
	renderer.animations_enabled = false
	renderer.set_model(_model(101, 24, 2, 2))
	_expect(not transition.is_active() and base.visible, "disabling motion mid-transition restores canonical sprite")
	renderer.animations_enabled = true
	renderer.set_model(_model(101, 25, 3, 2))
	renderer.call("_on_app_backgrounded", "test", 0, 0)
	_expect(not transition.is_active() and base.visible, "background cancellation restores canonical sprite")
	renderer.set_model(_model(101, 24, 2, 2))
	renderer.set_model(_model(202, 9, 1))
	_expect(not transition.is_active(), "state identity change reseeds silently")
	renderer.set_model(_model(202, 10, 2))
	var viewer_change := _model(202, 10, 2)
	viewer_change.viewer_owner_id = 2
	renderer.set_model(viewer_change)
	_expect(not transition.is_active(), "viewer identity change cancels")

	# A live switch to the reduced preference cancels an in-flight full sweep.
	viewer_change.hives[0].pwr = 25
	viewer_change.hives[0].growth_tier = 3
	viewer_change.hives[0].lane_budget_max = 3
	renderer.set_model(viewer_change)
	var profile := root.get_node("ProfileManager")
	var was_enabled: bool = profile.is_gpu_vfx_enabled()
	profile.set_gpu_vfx_enabled(false)
	renderer.set_model(viewer_change)
	_expect(not transition.is_active() and base.visible, "reduced preference interrupts a full sweep")
	profile.set_gpu_vfx_enabled(was_enabled)

	# Reduced mode has a short dissolve with no travel/scale/halo.
	transition.capture_old_sprite(base, visual.get("_current_size"))
	transition.play(visual.get("_current_size"), Vector2.ZERO, Color.GOLD, 1, 2, {}, "reduced")
	transition.set_debug_elapsed(0.065)
	_expect(transition.is_active() and transition.get_debug_snapshot().visible_ring_count == 0, "reduced motion has no sweep")
	transition.set_debug_elapsed(0.14)
	_expect(not transition.is_active() and base.visible, "reduced dissolve completes cleanly")
	for tiers in [[1,2],[2,3],[3,2],[2,1]]:
		var elapsed := 0.0
		for i in range(15):
			elapsed += 1.0 / 60.0
		var a := Timing.sample(elapsed, tiers[0], tiers[1])
		var b := Timing.sample(0.25, tiers[0], tiers[1])
		_expect(is_equal_approx(a.reveal, b.reveal) and is_equal_approx(a.body_scale, b.body_scale), "presentation sampling must be independent of frame partition")
		var low := Timing.sample(0.065, tiers[0], tiers[1], true)
		_expect(low.body_scale == 1.0 and low.band_energy == 0.0, "low motion never moves or flashes")
	# A simultaneous storm keeps canonical values current with bounded full VFX.
	var storm := _model(304, 9, 1)
	for id in range(2, 13):
		var item: Dictionary = storm.hives[0].duplicate(true)
		item.id = id
		item.x = float(id)
		storm.hives.append(item)
	renderer.set_model(storm)
	for item: Dictionary in storm.hives:
		item.pwr = 25
		item.growth_tier = 3
		item.lane_budget_max = 3
	storm.hives.reverse()
	renderer.set_model(storm)
	var full_count := 0
	for id in range(1, 13):
		var node: Node = renderer.get_hive_node_by_id(id)
		var state: Dictionary = node.get_growth_transition_debug_snapshot()
		full_count += int(state.mode == "full")
		_expect(state.mode == ("full" if id <= Renderer.MAX_FULL_HIVE_TRANSFORMS else "reduced"), "storm priority must be stable regardless of model order")
		_expect(node.power == 25, "effect budgeting must not defer canonical power")
	_expect(full_count == Renderer.MAX_FULL_HIVE_TRANSFORMS, "storm must respect full-effect budget")

	var empty := _model(202, 10, 2)
	empty.hives = []
	renderer.set_model(empty)
	await process_frame
	_expect(renderer.get_hive_ids().is_empty(), "removal releases render nodes")
	if not _failed:
		print("HIVE_GROWTH_TRANSITION_SMOKE: PASS")
	quit(1 if _failed else 0)

func _model(iid: int, power: int, tier: int, owner: int = 1) -> Dictionary:
	return {"iid": iid, "cell_size": 64, "sim_running": true, "viewer_owner_id": 1,
		"hives": [{"id":1, "x":4.0, "y":5.0, "owner_id":owner, "pwr":power,
		"growth_tier":tier, "lane_budget_used":0, "lane_budget_max":tier,
		"hostile_capture_pressure":false, "kind":"Hive"}], "lanes":[]}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("HIVE_GROWTH_TRANSITION_SMOKE: " + message)
