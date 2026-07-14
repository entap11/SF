extends SceneTree

const ControllerScript := preload("res://scripts/renderers/buff_lane_global_targeting_controller.gd")

class FakeArena:
	extends Node2D
	var projection_scale: Vector2 = Vector2.ONE
	var projection_offset: Vector2 = Vector2.ZERO
	var transform_revision: int = 1
	var conversion_valid: bool = true
	var playfield_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(900.0, 650.0))
	var exclusion_rects: Array[Rect2] = [Rect2(0.0, 570.0, 900.0, 80.0)]

	func buff_arena_local_to_root_screen(arena_local_pos: Vector2) -> Dictionary:
		if not conversion_valid:
			return {"ok": false}
		return {"ok": true, "root_screen_pos": arena_local_pos * projection_scale + projection_offset}

	func get_buff_targeting_transform_signature() -> int:
		return transform_revision

	func get_buff_global_targeting_query(root_screen_pos: Vector2) -> Dictionary:
		var valid: bool = conversion_valid and playfield_rect.has_point(root_screen_pos)
		for rect in exclusion_rects:
			if rect.has_point(root_screen_pos):
				valid = false
		var points := PackedVector2Array([
			playfield_rect.position,
			Vector2(playfield_rect.end.x, playfield_rect.position.y),
			playfield_rect.end,
			Vector2(playfield_rect.position.x, playfield_rect.end.y)
		])
		return {"valid": valid, "boundary_arena_local_points": points if valid else PackedVector2Array()}


class FakeLaneRenderer:
	extends Node2D
	var probes: Dictionary = {}
	var generation: int = 1

	func set_probe(lane_id: int, points: PackedVector2Array, renderable: bool = true) -> void:
		var old_revision: int = int((probes.get(lane_id, {}) as Dictionary).get("path_revision", 0))
		probes[lane_id] = {
			"valid": renderable,
			"renderable": renderable,
			"lane_id": lane_id,
			"points": points,
			"path_revision": old_revision + 1
		}
		generation += 1

	func remove_probe(lane_id: int) -> void:
		probes.erase(lane_id)
		generation += 1

	func get_buff_target_lane_probe(lane_id: int) -> Dictionary:
		return (probes.get(lane_id, {"valid": false, "lane_id": lane_id}) as Dictionary).duplicate(true)

	func get_buff_target_lane_generation() -> int:
		return generation

	func get_buff_target_lane_probe_revision(lane_id: int) -> int:
		var probe: Dictionary = probes.get(lane_id, {}) as Dictionary
		return int(probe.get("path_revision", -1)) if bool(probe.get("valid", false)) else -1


var _failed: bool = false
var _selected_type: String = ""
var _selected_id: Variant = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var fixture: Dictionary = _build_fixture()
	var root: Node2D = fixture.root
	var arena: FakeArena = fixture.arena
	var renderer: FakeLaneRenderer = fixture.renderer
	var controller: Node2D = fixture.controller
	controller.connect("selection_changed", Callable(self, "_on_selection_changed"))
	_expect(not (controller is CollisionObject2D), "target overlay must have no collision or picking surface")

	renderer.set_probe(1, PackedVector2Array([Vector2(40, 100), Vector2(360, 100)]))
	renderer.set_probe(2, PackedVector2Array([Vector2(40, 150), Vector2(360, 150)]))
	renderer.set_probe(3, PackedVector2Array([Vector2(40, 100), Vector2(360, 100)]))
	var lane_preview: Dictionary = {"ok": true, "target_type": "lane", "eligible_target_ids": [2, 1]}
	_selected_type = ""
	_selected_id = null
	controller.call("begin_or_update", 10, lane_preview, "", null, Vector2(200, 100))
	_expect(_selected_type == "lane" and int(_selected_id) == 1, "nearest cached-eligible lane should be selected")
	var visual: Dictionary = controller.call("get_visual_state_snapshot") as Dictionary
	var lanes: Dictionary = visual.get("lanes", {}) as Dictionary
	_expect(lanes.size() == 2 and lanes.has(1) and lanes.has(2), "only cached eligible lane IDs should illuminate")
	_expect(not lanes.has(3), "overlapping ineligible lane must remain unchanged")
	_expect(bool((lanes[1] as Dictionary).get("selected", false)), "selected lane treatment should be active")
	_expect(float((lanes[1] as Dictionary).get("selected_width_px", 0.0)) > float((lanes[2] as Dictionary).get("eligible_width_px", 0.0)), "selected lane treatment should be thicker")
	controller.call("set_phase_override", 0.37)
	visual = controller.call("get_visual_state_snapshot") as Dictionary
	lanes = visual.get("lanes", {}) as Dictionary
	_expect(is_equal_approx(float((lanes[1] as Dictionary).get("pulse_phase", -1.0)), 0.37) and is_equal_approx(float((lanes[2] as Dictionary).get("pulse_phase", -1.0)), 0.37), "eligible lanes must share one absolute presentation phase")
	controller.call("clear_phase_override")

	# Rendered segment distance, including a curved/polyline interior, drives acquisition.
	renderer.set_probe(4, PackedVector2Array([Vector2(20, 330), Vector2(180, 250), Vector2(340, 330)]))
	controller.call("begin_or_update", 11, {"ok": true, "target_type": "lane", "eligible_target_ids": [4]}, "", null, Vector2(180, 250))
	_expect(int(_selected_id) == 4, "touch near a rendered path interior should acquire even when far from endpoints")
	controller.call("update_finger", 11, Vector2(180, 185))
	_expect(_selected_id == null, "touch outside acquisition and retention should select no lane")

	# Retention and strict challenger margin prevent chatter between parallel lanes.
	controller.call("begin_or_update", 12, lane_preview, "", null, Vector2(200, 100))
	controller.call("update_finger", 12, Vector2(200, 126))
	_expect(int(_selected_id) == 1, "strict switch margin should retain the selected parallel lane")
	controller.call("update_finger", 12, Vector2(200, 140))
	_expect(int(_selected_id) == 2, "meaningfully closer parallel lane should win the strict switch rule")
	controller.call("begin_or_update", 13, {"ok": true, "target_type": "lane", "eligible_target_ids": [1]}, "", null, Vector2(200, 100))
	controller.call("update_finger", 13, Vector2(200, 160))
	_expect(int(_selected_id) == 1, "retention radius should hold beyond acquisition")
	controller.call("update_finger", 13, Vector2(200, 165))
	_expect(_selected_id == null, "leaving retention should clear selection immediately")

	# Crossing ties are deterministic and retain the selected stable lane.
	renderer.set_probe(5, PackedVector2Array([Vector2(40, 400), Vector2(360, 520)]))
	renderer.set_probe(6, PackedVector2Array([Vector2(40, 520), Vector2(360, 400)]))
	var crossing := {"ok": true, "target_type": "lane", "eligible_target_ids": [6, 5]}
	controller.call("begin_or_update", 14, crossing, "", null, Vector2(200, 460))
	_expect(int(_selected_id) == 5, "equivalent crossing tie should use ascending stable lane ID")
	controller.call("update_finger", 14, Vector2(201, 460))
	_expect(int(_selected_id) == 5, "crossing should retain the selected lane without a strict challenger win")

	# Missing/hidden/rebuilt paths and stationary-finger transform changes clear or update immediately.
	controller.call("begin_or_update", 15, lane_preview, "", null, Vector2(200, 100))
	renderer.set_probe(1, PackedVector2Array([Vector2(40, 100), Vector2(360, 100)]), false)
	controller.call("notify_render_nodes_changed")
	_expect(_selected_id == null, "hidden selected lane must clear Shell selection")
	renderer.set_probe(1, PackedVector2Array([Vector2(40, 100), Vector2(360, 100)]), true)
	controller.call("notify_render_nodes_changed")
	_expect(int(_selected_id) == 1, "same cached eligible set may reacquire a rebuilt renderable lane")
	arena.projection_offset = Vector2(0, -50)
	arena.transform_revision += 1
	controller.call("force_recompute", "camera_changed")
	_expect(int(_selected_id) == 2, "stationary-finger camera change should recompute from cached eligible IDs")
	arena.projection_offset = Vector2.ZERO
	arena.transform_revision += 1
	renderer.remove_probe(2)
	controller.call("notify_render_nodes_changed")
	_expect(int(_selected_id) == 1, "removed selected lane should fall back to nearest eligible rendered lane")

	# Stale pointer-generation callbacks cannot clear a newer presentation session.
	controller.call("begin_or_update", 20, lane_preview, "", null, Vector2(200, 100))
	controller.call("begin_or_update", 21, {"ok": true, "target_type": "lane", "eligible_target_ids": [1]}, "", null, Vector2(200, 100))
	_expect(not bool(controller.call("clear", 20, true, "stale_generation")), "stale generation cleanup must be ignored")
	_expect(int((controller.call("get_snapshot") as Dictionary).get("pointer_session_id", 0)) == 21, "newer generation should remain active")

	# Global targeting uses one valid-playfield query and never lights a lane.
	var global_preview := {"ok": true, "target_type": "global", "eligible_target_ids": ["global"]}
	controller.call("begin_or_update", 30, global_preview, "", null, Vector2(450, 300))
	_expect(_selected_type == "global" and _selected_id == "global", "valid playfield position should retain explicit global target")
	visual = controller.call("get_visual_state_snapshot") as Dictionary
	_expect(bool(visual.get("global_valid", false)) and (visual.get("lanes", {}) as Dictionary).is_empty(), "global presentation should illuminate only the boundary")
	controller.call("update_finger", 30, Vector2(450, 600))
	_expect(_selected_id == null and not bool((controller.call("get_visual_state_snapshot") as Dictionary).get("global_valid", true)), "excluded HUD/strip region should clear global immediately")
	arena.conversion_valid = false
	controller.call("update_finger", 30, Vector2(450, 300))
	_expect(_selected_id == null, "invalid conversion context should reject global")
	arena.conversion_valid = true

	var exclusions: Array[Rect2] = [Rect2(0, 570, 900, 80), Rect2(100, 100, 80, 80)]
	var arena_script: Script = load("res://scripts/arena.gd") as Script
	_expect(bool(arena_script.call("buff_global_position_valid_for_rects", Vector2(450, 300), Rect2(0, 0, 900, 650), exclusions, true)), "central playfield policy should accept unobstructed Arena position")
	_expect(not bool(arena_script.call("buff_global_position_valid_for_rects", Vector2(450, 600), Rect2(0, 0, 900, 650), exclusions, true)), "central playfield policy should exclude strip/HUD rect")
	_expect(not bool(arena_script.call("buff_global_position_valid_for_rects", Vector2(120, 120), Rect2(0, 0, 900, 650), exclusions, true)), "central playfield policy should exclude modal/menu rect")
	_expect(not bool(arena_script.call("buff_global_position_valid_for_rects", Vector2(-1, 300), Rect2(0, 0, 900, 650), exclusions, true)), "central playfield policy should exclude safe margin outside playfield")
	_expect(not bool(arena_script.call("buff_global_position_valid_for_rects", Vector2(450, 300), Rect2(0, 0, 900, 650), exclusions, false)), "central playfield policy should reject invalid conversion")

	# Cached geometry performance: representative polylines, crossings, and upper-bound fixture.
	var typical_ids: Array = []
	for lane_id in range(101, 113):
		typical_ids.append(lane_id)
		renderer.set_probe(lane_id, _polyline_for(lane_id, 7, 18.0))
	var typical_preview := {"ok": true, "target_type": "lane", "eligible_target_ids": typical_ids}
	var nodes_before: int = _count_nodes(root)
	controller.call("begin_or_update", 40, typical_preview, "", null, Vector2(180, 200))
	var typical_started_us: int = Time.get_ticks_usec()
	for i in range(3000):
		controller.call("update_finger", 40, Vector2(float(i % 600), float(80 + (i / 11) % 420)))
	var typical_elapsed_us: int = Time.get_ticks_usec() - typical_started_us
	var typical_snapshot: Dictionary = controller.call("get_snapshot") as Dictionary
	_expect(_count_nodes(root) == nodes_before, "typical movement must not allocate presentation nodes")
	print("BUFF_LANE_TARGETING_PERF_TYPICAL: eligible=12 segments=72 events=3000 elapsed_us=%d avg_us=%.4f cache_rebuilds=%d cache_rebuild_us=%d nodes_before=%d nodes_after=%d material_growth=0" % [
		typical_elapsed_us,
		float(typical_elapsed_us) / 3000.0,
		int(typical_snapshot.get("geometry_rebuild_count", 0)),
		int(typical_snapshot.get("geometry_rebuild_elapsed_us", 0)),
		nodes_before,
		_count_nodes(root)
	])
	var crowded_ids: Array = []
	for lane_id in range(201, 265):
		crowded_ids.append(lane_id)
		renderer.set_probe(lane_id, _polyline_for(lane_id, 11, 9.0))
	var crowded_preview := {"ok": true, "target_type": "lane", "eligible_target_ids": crowded_ids}
	controller.call("begin_or_update", 41, crowded_preview, "", null, Vector2(180, 200))
	var crowded_started_us: int = Time.get_ticks_usec()
	for i in range(2000):
		controller.call("update_finger", 41, Vector2(float(i % 720), float(60 + (i / 13) % 500)))
	var crowded_elapsed_us: int = Time.get_ticks_usec() - crowded_started_us
	var crowded_snapshot: Dictionary = controller.call("get_snapshot") as Dictionary
	_expect(_count_nodes(root) == nodes_before, "crowded movement must not allocate presentation nodes")
	_expect(int(crowded_snapshot.get("geometry_cache_size", 0)) == 64, "crowded cache should remain bounded to eligible lane IDs")
	print("BUFF_LANE_TARGETING_PERF_CROWDED: eligible=64 segments=640 events=2000 elapsed_us=%d avg_us=%.4f cache_rebuilds=%d cache_rebuild_us=%d nodes_before=%d nodes_after=%d material_growth=0" % [
		crowded_elapsed_us,
		float(crowded_elapsed_us) / 2000.0,
		int(crowded_snapshot.get("geometry_rebuild_count", 0)),
		int(crowded_snapshot.get("geometry_rebuild_elapsed_us", 0)),
		nodes_before,
		_count_nodes(root)
	])
	var transform_started_us: int = Time.get_ticks_usec()
	for i in range(250):
		arena.projection_offset.x = float(i % 5)
		arena.transform_revision += 1
		controller.call("force_recompute", "stationary_camera_perf")
	var transform_elapsed_us: int = Time.get_ticks_usec() - transform_started_us
	_expect(_count_nodes(root) == nodes_before, "stationary-finger transform rebuilds must not allocate nodes")
	print("BUFF_LANE_TARGETING_PERF_STATIONARY_CAMERA: eligible=64 segments=640 updates=250 elapsed_us=%d avg_us=%.4f nodes_before=%d nodes_after=%d material_growth=0" % [
		transform_elapsed_us,
		float(transform_elapsed_us) / 250.0,
		nodes_before,
		_count_nodes(root)
	])
	arena.projection_offset = Vector2.ZERO

	controller.call("clear", 41, true, "test_teardown")
	_expect(not controller.is_processing(), "inactive targeting overlay should stop processing")
	_expect((controller.call("get_visual_state_snapshot") as Dictionary).get("lanes", {}).is_empty(), "teardown should clear all lane effects")
	var shell_source: String = FileAccess.get_file_as_string("res://scripts/shell.gd")
	_expect(shell_source.contains("const MATCH_BUFF_TARGETING_ENABLED: bool = false"), "production gate must remain false")
	root.queue_free()
	if not _failed:
		print("BUFF_LANE_GLOBAL_TARGETING_SMOKE: PASS")
	quit(1 if _failed else 0)


func _build_fixture() -> Dictionary:
	var root := Node2D.new()
	root.name = "BuffLaneGlobalTargetFixture"
	get_root().add_child(root)
	var arena := FakeArena.new()
	arena.name = "FakeArena"
	root.add_child(arena)
	var map_root := Node2D.new()
	map_root.name = "MapRoot"
	root.add_child(map_root)
	var renderer := FakeLaneRenderer.new()
	renderer.name = "LaneRenderer"
	map_root.add_child(renderer)
	var controller: Node2D = ControllerScript.new() as Node2D
	controller.name = "BuffLaneGlobalTargetPresentation"
	map_root.add_child(controller)
	controller.call("setup", arena, renderer)
	return {"root": root, "arena": arena, "renderer": renderer, "controller": controller}


func _polyline_for(lane_id: int, point_count: int, spacing: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var base_y: float = 40.0 + float(lane_id % 48) * 10.0
	for i in range(point_count):
		points.append(Vector2(20.0 + float(i) * spacing, base_y + sin(float(i + lane_id) * 0.7) * 22.0))
	return points


func _on_selection_changed(_pointer_session_id: int, target_type: String, target_id: Variant, _reason: String) -> void:
	_selected_type = target_type
	_selected_id = target_id


func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_LANE_GLOBAL_TARGETING_SMOKE: %s" % message)
