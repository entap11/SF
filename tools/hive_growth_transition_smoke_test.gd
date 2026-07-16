extends SceneTree

const HiveRendererScript := preload("res://scripts/renderers/hive_renderer.gd")

var _failed: bool = false
var _transition_starts: int = 0
var _reveal_starts: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var renderer := HiveRendererScript.new()
	get_root().add_child(renderer)
	renderer.setup(null, null, null)
	await process_frame

	renderer.set_model(_model(101, 9, 1, 1))
	await process_frame
	_expect(int(renderer.get_growth_debug_snapshot().get("active_count", -1)) == 0, "initial canonical model must not animate")
	var hive: Node = renderer.get_hive_node_by_id(1)
	_expect(hive != null, "initial hive render node must exist")
	var transition: Node = hive.get_node_or_null("Visual/FxLayer/HiveGrowthTransition")
	_expect(transition != null, "growth transition component must exist")
	if transition != null:
		transition.connect("transition_started", Callable(self, "_on_transition_started"))
		transition.connect("final_ring_reveal_started", Callable(self, "_on_final_ring_reveal_started"))

	renderer.set_model(_model(101, 10, 2, 2))
	await process_frame
	_expect(_transition_starts == 1, "9 to 10 must trigger exactly once")
	_expect(int(renderer.get_growth_debug_snapshot().get("active_count", 0)) == 1, "9 to 10 transition must be active")
	_expect(int(transition.call("get_debug_snapshot").get("ring_count", 0)) == 2, "small to medium must use exactly two rings")
	_expect(int(hive.get("growth_tier")) == 1, "presentation tier must remain small before the final ring reveal")
	var visual: Node = hive.get_node_or_null("Visual")
	_expect(str(visual.get("_sprite_key")) == "hive.med.p1", "final medium sprite must be applied immediately under the effect")
	var base_sprite: Sprite2D = hive.get_node_or_null("Visual/BaseSpriteLayer/BaseSprite") as Sprite2D
	_expect(base_sprite != null and base_sprite.texture != null and base_sprite.visible, "final medium base sprite must remain visible during the effect")
	_expect((visual.get("_lane_budget_pips") as Array).size() == 1, "new lane pip must remain staged before final-ring reveal")

	renderer.set_model(_model(101, 10, 2, 2))
	await process_frame
	_expect(_transition_starts == 1, "duplicate canonical model must not retrigger")
	renderer.set_model(_model(101, 11, 2, 2))
	await process_frame
	_expect(_transition_starts == 1, "non-threshold power increase must not trigger")
	await create_timer(0.22).timeout
	_expect(_reveal_starts == 1, "small to medium final ring must emit one reveal event")
	_expect(int(hive.get("growth_tier")) == 2, "presentation tier must commit at final-ring reveal")
	_expect((visual.get("_lane_budget_pips") as Array).size() == 2, "new lane pip must commit at final-ring reveal")
	await create_timer(0.76).timeout
	_expect(int(renderer.get_growth_debug_snapshot().get("active_count", 0)) == 0, "transition must finish cleanly")
	_expect(base_sprite != null and base_sprite.texture != null and base_sprite.visible, "final medium base sprite must remain visible after the effect")

	renderer.set_model(_model(101, 25, 3, 3))
	await process_frame
	_expect(_transition_starts == 2, "24/25 tier entry must trigger from the current medium tier")
	_expect(int(transition.call("get_debug_snapshot").get("ring_count", 0)) == 3, "medium to large must use exactly three rings")
	_expect(str(visual.get("_sprite_key")) == "hive.large.p1", "final large sprite must be applied immediately")
	_expect(base_sprite != null and base_sprite.texture != null and base_sprite.visible, "final large base sprite must be visible")
	await create_timer(0.76).timeout

	renderer.set_model(_model(101, 9, 1, 1))
	await process_frame
	_expect(_transition_starts == 2, "downgrade must not animate")
	renderer.set_model(_model(101, 25, 3, 3))
	await process_frame
	_expect(_transition_starts == 3, "tier-one to tier-three jump must produce one transition")
	_expect(int(transition.call("get_debug_snapshot").get("ring_count", 0)) == 3, "small to large jump must use three rings, not five")
	await create_timer(0.76).timeout
	var component_children: int = transition.get_child_count()

	renderer.set_model(_model(101, 9, 1, 1))
	await process_frame
	renderer.set_model(_model(101, 10, 2, 2))
	await process_frame
	await create_timer(0.76).timeout
	_expect(transition.get_child_count() == component_children, "repeated transitions must keep a stable component node count")

	renderer.setup(null, null, null)
	renderer.set_model(_model(101, 25, 3, 3))
	await process_frame
	_expect(_transition_starts == 4, "renderer setup must reseed without replaying growth")
	_expect(int(renderer.get_growth_debug_snapshot().get("active_count", 0)) == 0, "renderer setup must cancel active presentation")

	renderer.set_model({"hives": [{"id": 1, "pwr": 5, "lane_budget_max": 1}]})
	await process_frame
	renderer.set_model(_model(202, 25, 3, 3))
	await process_frame
	_expect(_transition_starts == 4, "noncanonical map model followed by canonical initialization must not animate")

	renderer.animations_enabled = false
	renderer.set_model(_model(202, 9, 1, 1))
	await process_frame
	renderer.set_model(_model(202, 10, 2, 2))
	await process_frame
	_expect(_transition_starts == 4, "disabled animations must suppress a live growth edge")
	_expect(str(visual.get("_sprite_key")) == "hive.med.p1", "disabled animations must still apply the final canonical sprite")
	_expect(int(renderer.get_growth_debug_snapshot().get("active_count", 0)) == 0, "disabled animations must leave no active presentation")

	renderer.animations_enabled = true
	renderer.set_model(_model(202, 9, 1, 1))
	await process_frame
	renderer.set_model(_model(202, 10, 2, 2))
	await process_frame
	_expect(_transition_starts == 5, "new live edge after re-enabling animations must animate")
	renderer.call("_on_app_backgrounded", "test", 0, 0)
	await process_frame
	_expect(int(renderer.get_growth_debug_snapshot().get("active_count", 0)) == 0, "app backgrounding must cancel presentation immediately")
	_expect(base_sprite != null and base_sprite.texture != null and base_sprite.visible, "background cancellation must leave the final canonical sprite visible")

	renderer.set_model(_model(202, 25, 3, 3))
	await process_frame
	_expect(_transition_starts == 6, "subsequent live growth edge must animate after lifecycle cancellation")
	renderer.set_model(_empty_model(202))
	await process_frame
	await process_frame
	_expect(renderer.get_hive_ids().is_empty(), "removed hive must release its render node")
	_expect(int(renderer.get_growth_debug_snapshot().get("active_count", 0)) == 0, "hive removal must cancel presentation state")

	if _failed:
		quit(1)
		return
	print("HIVE_GROWTH_TRANSITION_SMOKE: PASS")
	quit(0)

func _model(iid: int, power: int, tier: int, lane_budget_max: int) -> Dictionary:
	return {
		"iid": iid,
		"cell_size": 64,
		"sim_running": true,
		"hives": [{
			"id": 1,
			"x": 4.0,
			"y": 5.0,
			"owner_id": 1,
			"pwr": power,
			"growth_tier": tier,
			"lane_budget_used": 0,
			"lane_budget_max": lane_budget_max,
			"kind": "Hive"
		}],
		"lanes": []
	}

func _empty_model(iid: int) -> Dictionary:
	return {
		"iid": iid,
		"cell_size": 64,
		"sim_running": true,
		"hives": [],
		"lanes": []
	}

func _on_transition_started(_old_tier: int, _new_tier: int) -> void:
	_transition_starts += 1

func _on_final_ring_reveal_started(_new_tier: int) -> void:
	_reveal_starts += 1

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("HIVE_GROWTH_TRANSITION_SMOKE: %s" % message)
