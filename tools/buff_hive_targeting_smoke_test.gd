extends SceneTree

const ControllerScript := preload("res://scripts/renderers/buff_hive_targeting_controller.gd")
const HiveNodeScene := preload("res://scenes/hive/HiveNode.tscn")

class FakeArena:
	extends Node2D
	var projection_scale: Vector2 = Vector2.ONE
	var projection_offset: Vector2 = Vector2.ZERO
	var conversion_valid: bool = true

	func root_screen_to_buff_arena_local(root_screen_pos: Vector2) -> Dictionary:
		if not conversion_valid:
			return {"ok": false, "reason": "outside_world_viewport"}
		return {
			"ok": true,
			"arena_local_pos": Vector2(
				(root_screen_pos.x - projection_offset.x) / projection_scale.x,
				(root_screen_pos.y - projection_offset.y) / projection_scale.y
			)
		}

	func buff_arena_local_to_root_screen(arena_local_pos: Vector2) -> Dictionary:
		return {
			"ok": true,
			"root_screen_pos": arena_local_pos * projection_scale + projection_offset
		}

	func buff_arena_local_to_world(arena_local_pos: Vector2) -> Vector2:
		return arena_local_pos


var _failed: bool = false
var _shell_selected_id: int = -1
var _selection_events: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := await _build_fixture(32)
	var arena: FakeArena = fixture.arena
	var renderer: Node2D = fixture.renderer
	var controller: Node2D = fixture.controller
	var nodes: Dictionary = fixture.nodes
	controller.connect("selection_changed", Callable(self, "_on_selection_changed"))
	_expect(not (controller is CollisionObject2D), "target overlay must have no collision or picking surface")

	var node1: Node2D = nodes[1]
	var node2: Node2D = nodes[2]
	var node3: Node2D = nodes[3]
	node1.position = Vector2(0.0, 0.0)
	node2.position = Vector2(100.0, 0.0)
	node3.position = Vector2(12.0, 0.0)
	var node1_scale: Vector2 = node1.scale
	var node1_position: Vector2 = node1.position
	var collision: CollisionShape2D = node1.get_node("CollisionShape2D") as CollisionShape2D
	var collision_radius: float = (collision.shape as CircleShape2D).radius

	_shell_selected_id = -1
	controller.call("begin_or_update", 10, [2, 1], _shell_selected_id, Vector2(0.0, 0.0))
	_expect(_shell_selected_id == 1, "nearest cached-eligible hive should be acquired")
	var visual: Dictionary = controller.call("get_visual_state_snapshot") as Dictionary
	_expect(visual.size() == 2 and visual.has(1) and visual.has(2), "only cached eligible stable IDs should illuminate")
	_expect(not visual.has(3), "nearby enemy/ineligible hive should remain unchanged")
	_expect(bool((visual[1] as Dictionary).get("previewed", false)), "selected hive should receive preview treatment")
	_expect(not bool((visual[2] as Dictionary).get("previewed", true)), "ordinary eligible hive should not receive preview treatment")
	_expect(
		float((visual[1] as Dictionary).get("preview_ring_radius_local", 0.0))
		> float((visual[1] as Dictionary).get("eligible_ring_radius_local", 0.0)),
		"preview exterior ring should extend beyond ordinary eligibility ring"
	)

	controller.call("set_phase_override", 0.25)
	visual = controller.call("get_visual_state_snapshot") as Dictionary
	_expect(
		is_equal_approx(float((visual[1] as Dictionary).get("pulse_phase", -1.0)), 0.25)
		and is_equal_approx(float((visual[2] as Dictionary).get("pulse_phase", -1.0)), 0.25),
		"all eligible hives should share one synchronized pulse phase"
	)
	controller.call("clear_phase_override")

	# Equivalent-distance ordering must ignore eligible-array and node insertion order.
	controller.call("update_finger", 10, Vector2(50.0, 0.0))
	_shell_selected_id = -1
	controller.call("begin_or_update", 11, [2, 1], _shell_selected_id, Vector2(50.0, 0.0))
	_expect(_shell_selected_id == 1, "equivalent-distance tie should choose the lower stable hive ID")

	# Retention and strict switch margin.
	node2.position = Vector2(60.0, 0.0)
	_shell_selected_id = -1
	controller.call("begin_or_update", 12, [1, 2], _shell_selected_id, Vector2(0.0, 0.0))
	controller.call("update_finger", 12, Vector2(27.0, 0.0))
	_expect(_shell_selected_id == 1, "switch margin should retain the current hive under thumb tremble")
	controller.call("update_finger", 12, Vector2(40.0, 0.0))
	_expect(_shell_selected_id == 2, "meaningfully closer challenger should replace the retained hive")

	# Retention with no challenger, followed by immediate Shell clearing.
	_shell_selected_id = -1
	controller.call("begin_or_update", 13, [1], _shell_selected_id, Vector2(0.0, 0.0))
	controller.call("update_finger", 13, Vector2(60.0, 0.0))
	_expect(_shell_selected_id == 1, "larger retention range should keep selection beyond acquisition")
	controller.call("update_finger", 13, Vector2(90.0, 0.0))
	_expect(_shell_selected_id == -1, "leaving retention with no candidate should clear Shell selection immediately")

	# Hidden render nodes and invalid conversion clear both presentation and Shell state.
	_shell_selected_id = -1
	controller.call("begin_or_update", 14, [1], _shell_selected_id, Vector2.ZERO)
	node1.visible = false
	controller.call("force_recompute", "hidden_probe")
	_expect(_shell_selected_id == -1, "hidden selected hive should clear Shell selection")
	_expect((controller.call("get_visual_state_snapshot") as Dictionary).is_empty(), "hidden hive should not illuminate")
	node1.visible = true
	controller.call("force_recompute", "visible_again")
	_expect(_shell_selected_id == 1, "same cached preview may reacquire a visible hive")
	arena.conversion_valid = false
	controller.call("force_recompute", "outside_arena")
	_expect(_shell_selected_id == -1, "invalid Arena conversion should clear Shell selection")
	_expect(not bool((controller.call("get_snapshot") as Dictionary).get("inside_arena", true)), "invalid conversion should hide all targeting presentation")
	arena.conversion_valid = true
	_shell_selected_id = -1
	controller.call("begin_or_update", 14, [99], _shell_selected_id, Vector2.ZERO)
	_expect(_shell_selected_id == -1 and (controller.call("get_visual_state_snapshot") as Dictionary).is_empty(), "missing cached-eligible render node should neither illuminate nor remain selected")

	# Camera/canvas motion is handled without a new pointer movement event.
	node2.position = Vector2(100.0, 0.0)
	arena.projection_offset = Vector2.ZERO
	_shell_selected_id = -1
	controller.call("begin_or_update", 15, [1, 2], _shell_selected_id, Vector2.ZERO)
	_expect(_shell_selected_id == 1, "stationary finger should initially acquire hive 1")
	arena.projection_offset = Vector2(-100.0, 0.0)
	controller.call("force_recompute", "camera_changed")
	_expect(_shell_selected_id == 2, "camera motion under a stationary finger should recompute from cached IDs")
	arena.projection_offset = Vector2.ZERO

	# The visual drag offset is never supplied to acquisition.
	_shell_selected_id = -1
	controller.call("begin_or_update", 16, [1, 2], _shell_selected_id, Vector2.ZERO)
	_expect(_shell_selected_id == 1, "unshifted fingertip should drive acquisition independently of overlay offset")

	# No presentation operation may alter authoritative-looking roots or collision.
	_expect(node1.position == node1_position, "target presentation must not move HiveNode root")
	_expect(node1.scale == node1_scale, "Loop 2 must not scale HiveNode root")
	_expect(is_equal_approx((collision.shape as CircleShape2D).radius, collision_radius), "target presentation must not alter collision")

	# Old generations cannot clear or update a newer session.
	controller.call("begin_or_update", 20, [1], _shell_selected_id, Vector2.ZERO)
	controller.call("begin_or_update", 21, [2], -1, Vector2(100.0, 0.0))
	_expect(not bool(controller.call("clear", 20, true, "stale_callback")), "stale generation cleanup should be ignored")
	_expect(int((controller.call("get_snapshot") as Dictionary).get("pointer_session_id", 0)) == 21, "newer targeting generation should remain active")

	# Individual disappearance and renderer teardown clear before reuse/rebind.
	_shell_selected_id = -1
	controller.call("begin_or_update", 22, [1], _shell_selected_id, Vector2.ZERO)
	_expect(_shell_selected_id == 1, "disappearance fixture should start selected")
	(renderer.get("hive_nodes_by_id") as Dictionary).erase(1)
	node1.queue_free()
	controller.call("notify_render_nodes_changed")
	_expect(_shell_selected_id == -1, "freed selected render node should clear Shell selection immediately")
	renderer.call("_clear_hive_nodes")
	var after_renderer_clear: Dictionary = controller.call("get_snapshot") as Dictionary
	_expect(not bool(after_renderer_clear.get("active", true)), "renderer rebuild/teardown should clear presentation")
	_expect(_shell_selected_id == -1, "renderer teardown should clear Shell selection")

	# Rebuild for bounded upper-count movement instrumentation.
	await _repopulate_renderer(renderer, nodes, 32)
	var typical_ids: Array = [1, 2, 3, 4, 5, 6]
	var typical_nodes_before: int = _count_nodes(fixture.root)
	controller.call("begin_or_update", 29, typical_ids, -1, Vector2.ZERO)
	var typical_started_us: int = Time.get_ticks_usec()
	for i in range(5000):
		controller.call("update_finger", 29, Vector2(float(i % 320), float((i / 7) % 120)))
	var typical_elapsed_us: int = Time.get_ticks_usec() - typical_started_us
	var typical_nodes_after: int = _count_nodes(fixture.root)
	_expect(typical_nodes_after == typical_nodes_before, "typical movement should not allocate presentation nodes")
	print("BUFF_HIVE_TARGETING_PERF_TYPICAL: eligible=%d events=%d elapsed_us=%d avg_us=%.4f nodes_before=%d nodes_after=%d material_growth=0" % [
		typical_ids.size(),
		5000,
		typical_elapsed_us,
		float(typical_elapsed_us) / 5000.0,
		typical_nodes_before,
		typical_nodes_after
	])
	controller.call("clear", 29, true, "typical_perf_complete")
	var upper_ids: Array = []
	for hive_id in range(1, 33):
		upper_ids.append(hive_id)
	var node_count_before: int = _count_nodes(fixture.root)
	_shell_selected_id = -1
	controller.call("begin_or_update", 30, upper_ids, -1, Vector2.ZERO)
	var started_us: int = Time.get_ticks_usec()
	for i in range(5000):
		controller.call("update_finger", 30, Vector2(float(i % 320), float((i / 7) % 120)))
	var elapsed_us: int = Time.get_ticks_usec() - started_us
	var node_count_after: int = _count_nodes(fixture.root)
	var perf: Dictionary = controller.call("get_snapshot") as Dictionary
	_expect(node_count_after == node_count_before, "movement should not allocate presentation nodes")
	_expect(controller.get_child_count() == 0, "overlay should use one draw node without per-hive children")
	print("BUFF_HIVE_TARGETING_PERF: eligible=%d events=%d elapsed_us=%d avg_us=%.4f nodes_before=%d nodes_after=%d material_growth=0" % [
		upper_ids.size(),
		5000,
		elapsed_us,
		float(elapsed_us) / 5000.0,
		node_count_before,
		node_count_after
	])
	_expect(int(perf.get("movement_event_count", 0)) >= 5000, "performance fixture should count bounded movement events")

	controller.call("clear", 30, true, "test_teardown")
	_expect((controller.call("get_visual_state_snapshot") as Dictionary).is_empty(), "teardown should leave no target effects")
	_expect(not controller.is_processing(), "target overlay should stop processing when inactive")
	fixture.root.queue_free()
	if not _failed:
		print("BUFF_HIVE_TARGETING_SMOKE: PASS")
	quit(1 if _failed else 0)


func _build_fixture(hive_count: int) -> Dictionary:
	var root := Node2D.new()
	root.name = "BuffHiveTargetFixture"
	get_root().add_child(root)
	var arena := FakeArena.new()
	arena.name = "FakeArena"
	root.add_child(arena)
	var map_root := Node2D.new()
	map_root.name = "MapRoot"
	root.add_child(map_root)
	var renderer_script: Script = load("res://scripts/renderers/hive_renderer.gd") as Script
	var renderer: Node2D = renderer_script.new() as Node2D
	renderer.name = "HiveRenderer"
	map_root.add_child(renderer)
	var controller: Node2D = ControllerScript.new()
	controller.name = "BuffHiveTargetPresentation"
	map_root.add_child(controller)
	controller.call("setup", arena, renderer)
	var nodes: Dictionary = {}
	await _repopulate_renderer(renderer, nodes, hive_count)
	return {"root": root, "arena": arena, "renderer": renderer, "controller": controller, "nodes": nodes}


func _repopulate_renderer(renderer: Node2D, nodes: Dictionary, hive_count: int) -> void:
	for hive_id in range(1, hive_count + 1):
		var node: Node2D = HiveNodeScene.instantiate() as Node2D
		node.name = "HiveNode_%d" % hive_id
		renderer.add_child(node)
		node.set("hive_id", hive_id)
		node.position = Vector2(float((hive_id - 1) % 8) * 80.0, float((hive_id - 1) / 8) * 80.0)
		nodes[hive_id] = node
		(renderer.get("hive_nodes_by_id") as Dictionary)[hive_id] = node
	await process_frame
	for hive_id in range(1, hive_count + 1):
		var node: Node = nodes[hive_id]
		node.call("apply_render", 1 if hive_id != 3 else 2, 10, 27.0, Color(0.25, 0.8, 1.0, 1.0), 14, "Hive", 0, 3)
	await process_frame


func _on_selection_changed(_pointer_session_id: int, hive_id: int, reason: String) -> void:
	_shell_selected_id = hive_id
	_selection_events.append({"hive_id": hive_id, "reason": reason})


func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_HIVE_TARGETING_SMOKE: %s" % message)
