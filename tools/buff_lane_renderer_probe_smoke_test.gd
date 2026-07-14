extends SceneTree

class ProbeArena:
	extends Node2D
	var notification_count: int = 0

	func notify_buff_lane_render_nodes_changed() -> void:
		notification_count += 1


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var renderer_script: Script = load("res://scripts/renderers/lane_renderer.gd") as Script
	var root := Node2D.new()
	get_root().add_child(root)
	var arena := ProbeArena.new()
	root.add_child(arena)
	var renderer: Node2D = renderer_script.new() as Node2D
	renderer.name = "LaneRenderer"
	renderer.set("arena", arena)
	root.add_child(renderer)
	await process_frame

	var original_transform: Transform2D = renderer.transform
	var original_points := PackedVector2Array([Vector2(20, 30), Vector2(120, 60), Vector2(240, 35)])
	_expect(bool(renderer.call("_sync_buff_target_lane_probe", 17, original_points, true)), "production renderer should accept a read-only rendered-path probe")
	var probe: Dictionary = renderer.call("get_buff_target_lane_probe", 17) as Dictionary
	_expect(bool(probe.get("valid", false)), "renderable stable lane probe should be exposed")
	_expect(int(probe.get("lane_id", -1)) == 17 and (probe.get("points", PackedVector2Array()) as PackedVector2Array) == original_points, "probe should preserve stable ID and actual centerline points")
	var revision: int = int(probe.get("path_revision", 0))
	var generation: int = int(renderer.call("get_buff_target_lane_generation"))
	_expect(not bool(renderer.call("_sync_buff_target_lane_probe", 17, original_points, true)), "unchanged rendered path should not churn its presentation revision")
	_expect(int(renderer.call("get_buff_target_lane_generation")) == generation, "unchanged path should retain geometry generation")

	var changed_points := PackedVector2Array([Vector2(20, 30), Vector2(120, 80), Vector2(240, 35)])
	_expect(bool(renderer.call("_sync_buff_target_lane_probe", 17, changed_points, true)), "dynamic rendered-path change should revision the probe")
	probe = renderer.call("get_buff_target_lane_probe", 17) as Dictionary
	_expect(int(probe.get("path_revision", 0)) > revision, "path change should advance the presentation revision")
	_expect(renderer.transform == original_transform, "probe maintenance must not mutate lane renderer transform")

	renderer.call("_clear_lane_sprites")
	probe = renderer.call("get_buff_target_lane_probe", 17) as Dictionary
	_expect(not bool(probe.get("valid", true)), "renderer rebuild/pool-style cleanup should invalidate the stale stable-ID probe")
	_expect(arena.notification_count >= 1, "renderer cleanup should notify active targeting presentation")
	_expect(renderer.get_child_count() >= 0, "probe cleanup should not create collision or picking nodes")

	root.queue_free()
	if not _failed:
		print("BUFF_LANE_RENDERER_PROBE_SMOKE: PASS")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_LANE_RENDERER_PROBE_SMOKE: %s" % message)
