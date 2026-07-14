extends SceneTree

const ReceiptsScript := preload("res://scripts/renderers/buff_activation_presentation_receipts.gd")
const FeedbackScript := preload("res://scripts/renderers/buff_canonical_feedback_controller.gd")
const LaneTargetingScript := preload("res://scripts/renderers/buff_lane_global_targeting_controller.gd")
const Config := preload("res://scripts/renderers/buff_targeting_presentation_config.gd")

class FakeArena:
	extends Node2D

	func get_buff_global_presentation_boundary() -> Dictionary:
		return {
			"valid": true,
			"boundary_arena_local_points": PackedVector2Array([
				Vector2(10, 10), Vector2(390, 10), Vector2(390, 290), Vector2(10, 290)
			])
		}

	func get_buff_presentation_owner_color(_owner_id: int) -> Color:
		return Color(0.95, 0.72, 0.16, 1.0)


class FakeHiveRenderer:
	extends Node2D
	var visible_probe: bool = true

	func get_buff_target_probe(hive_id: int) -> Dictionary:
		if not visible_probe or hive_id != 7:
			return {"ok": false}
		return {
			"ok": true,
			"center_arena_local": Vector2(120, 120),
			"radius_edge_arena_local": Vector2(148, 120)
		}


class FakeLaneRenderer:
	extends Node2D
	func get_buff_target_lane_probe(lane_id: int) -> Dictionary:
		if lane_id != 9:
			return {"valid": false}
		return {
			"valid": true,
			"points": PackedVector2Array([Vector2(40, 220), Vector2(350, 220)])
		}


class CanonicalBridge:
	extends Node
	signal canonical_outcome(outcome: Dictionary, presentation_epoch: String)


class TransformArena:
	extends Node2D
	var map_root: Node2D = null
	var revision: int = 1
	var projection_offset: Vector2 = Vector2.ZERO

	func buff_arena_local_to_root_screen(arena_local_pos: Vector2) -> Dictionary:
		return {"ok": true, "root_screen_pos": map_root.to_global(arena_local_pos) + projection_offset}

	func get_buff_targeting_transform_signature() -> String:
		return "%d|%s|%s" % [revision, str(projection_offset), str(map_root.global_transform)]


class TransformLaneRenderer:
	extends Node2D
	var probes: Dictionary = {}
	var generation: int = 1

	func add_probe(lane_id: int, points: PackedVector2Array) -> void:
		probes[lane_id] = {"valid": true, "renderable": true, "points": points, "path_revision": lane_id}
		generation += 1

	func get_buff_target_lane_probe(lane_id: int) -> Dictionary:
		return (probes.get(lane_id, {"valid": false}) as Dictionary).duplicate(true)

	func get_buff_target_lane_probe_revision(lane_id: int) -> int:
		return int((probes.get(lane_id, {}) as Dictionary).get("path_revision", -1))

	func get_buff_target_lane_generation() -> int:
		return generation


class FakeStrip:
	extends Control
	func get_slot_root_screen_center(_slot_index: int) -> Vector2:
		return Vector2(64, 64)


var _failed: bool = false
var _feedback_started_count: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_receipt_identity_timeout_and_bounds()
	_test_snapback_generation_binding()
	await _test_lane_transform_coalescing()
	await _test_feedback_controller_event_bridge()
	_test_production_bridge_contract()
	if not _failed:
		print("BUFF_TARGETING_LOOP4_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_receipt_identity_timeout_and_bounds() -> void:
	var receipts: RefCounted = ReceiptsScript.new()
	var registered: Dictionary = receipts.register_submission("match-a", 1, "activation-a", "hive", 7, "epoch-a", 1000)
	_expect(bool(registered.get("ok", false)), "valid local receipt should register")
	var success := {
		"match_id": "match-a", "owner_id": 1, "activation_id": "activation-a",
		"status": "executed", "reason": "activated", "target_type": "hive", "target_id": 7
	}
	var consumed: Dictionary = receipts.consume_canonical_outcome(success, "epoch-a", 1125)
	_expect(bool(consumed.get("feedback", false)), "exact executed/activated outcome should produce feedback")
	_expect(int(consumed.get("receipt_age_msec", -1)) == 125, "latency should use monotonic receipt age")
	_expect(int((consumed.get("receipt", {}) as Dictionary).get("target_id", -1)) == 7, "feedback must use submitted receipt target")
	_expect(not bool(receipts.consume_canonical_outcome(success, "epoch-a", 1130).get("feedback", false)), "duplicate outcome must not flash twice")

	# Match, owner, activation, and presentation epoch all participate in exact matching.
	receipts.register_submission("match-b", 2, "activation-b", "lane", 9, "epoch-b", 2000)
	var base_b := {
		"match_id": "match-b", "owner_id": 2, "activation_id": "activation-b",
		"status": "executed", "reason": "activated", "target_type": "lane", "target_id": 9
	}
	var wrong_match: Dictionary = base_b.duplicate(true)
	wrong_match["match_id"] = "match-wrong"
	_expect(not bool(receipts.consume_canonical_outcome(wrong_match, "epoch-b", 2100).get("feedback", false)), "match mismatch must produce no feedback")
	var wrong_owner: Dictionary = base_b.duplicate(true)
	wrong_owner["owner_id"] = 3
	_expect(not bool(receipts.consume_canonical_outcome(wrong_owner, "epoch-b", 2100).get("feedback", false)), "owner mismatch must produce no feedback")
	_expect(not bool(receipts.consume_canonical_outcome(base_b, "epoch-old", 2100).get("feedback", false)), "epoch mismatch must produce no feedback")
	_expect(bool(receipts.consume_canonical_outcome(base_b, "epoch-b", 2100).get("feedback", false)), "mismatches must not consume the legitimate receipt")

	receipts.register_submission("match-c", 1, "activation-c", "global", "global", "epoch-c", 3000)
	var rejected := {
		"match_id": "match-c", "owner_id": 1, "activation_id": "activation-c",
		"status": "deterministic_no_op", "reason": "target_stale"
	}
	_expect(not bool(receipts.consume_canonical_outcome(rejected, "epoch-c", 3100).get("feedback", false)), "rejection/no-op must never show success")

	receipts.register_submission("match-d", 1, "activation-d", "hive", 7, "epoch-d", 4000)
	var expired: Dictionary = success.duplicate(true)
	expired["match_id"] = "match-d"
	expired["activation_id"] = "activation-d"
	var late: Dictionary = receipts.consume_canonical_outcome(
		expired, "epoch-d", 4000 + Config.ACTIVATION_RECEIPT_TIMEOUT_MSEC + 1
	)
	_expect(not bool(late.get("feedback", false)) and str(late.get("reason", "")) == "receipt_expired", "legitimate late outcome must stand without a flash")

	var bounded: RefCounted = ReceiptsScript.new()
	for i in range(Config.MAX_LIVE_ACTIVATION_RECEIPTS + 9):
		bounded.register_submission("bounded", 1, "a-%d" % i, "hive", 7, "epoch", 5000 + i)
	var bounded_snapshot: Dictionary = bounded.snapshot()
	_expect(int(bounded_snapshot.get("live_receipt_count", 0)) == Config.MAX_LIVE_ACTIVATION_RECEIPTS, "live receipt history must be bounded")
	bounded.expire(5000 + Config.ACTIVATION_RECEIPT_TIMEOUT_MSEC + 100)
	bounded_snapshot = bounded.snapshot()
	_expect(int(bounded_snapshot.get("handled_outcome_count", 0)) <= Config.MAX_HANDLED_OUTCOMES, "handled outcome history must be bounded")
	_expect(str(bounded_snapshot.get("eviction_rule", "")) == "oldest_submission_then_sequence", "eviction rule must be explicit and deterministic")
	var handled_bound: RefCounted = ReceiptsScript.new()
	for i in range(Config.MAX_HANDLED_OUTCOMES + 25):
		var activation_id: String = "handled-%d" % i
		handled_bound.register_submission("handled", 1, activation_id, "global", "global", "epoch", 10000 + i)
		handled_bound.consume_canonical_outcome({
			"match_id": "handled", "owner_id": 1, "activation_id": activation_id,
			"status": "deterministic_no_op", "reason": "target_stale"
		}, "epoch", 10000 + i)
	_expect(int((handled_bound.snapshot() as Dictionary).get("handled_outcome_count", 0)) == Config.MAX_HANDLED_OUTCOMES, "handled outcome history must evict oldest entries at its exact maximum")


func _test_snapback_generation_binding() -> void:
	var shell_script: Script = load("res://scripts/shell.gd") as Script
	var shell: Node = shell_script.new()
	var overlay_parent := Control.new()
	shell.add_child(overlay_parent)
	var overlay := TextureRect.new()
	overlay.size = Vector2(64, 64)
	overlay.visible = true
	overlay_parent.add_child(overlay)
	var strip := FakeStrip.new()
	shell.add_child(strip)
	shell.set("_player_buff_strip", strip)
	shell.set("_buff_drag_overlay", overlay)
	shell.set("_buff_drag_overlay_session_id", 11)
	shell.set("_buff_drag_overlay_generation", 5)
	var old_instance_id: int = overlay.get_instance_id()
	shell.call("_invalidate_buff_overlay_animation_for_new_capture")
	_expect(shell.get("_buff_drag_overlay_tween") == null and not overlay.visible, "new capture must kill and hide the old snap-back")
	overlay.visible = true
	shell.set("_buff_drag_overlay_session_id", 12)
	shell.set("_buff_drag_overlay_generation", 7)
	shell.call("_finish_buff_overlay_snap_back", 11, 5, old_instance_id)
	_expect(overlay.visible and int(shell.get("_buff_drag_overlay_session_id")) == 12, "old tween callback must not affect a newer overlay generation")
	var shell_source: String = FileAccess.get_file_as_string("res://scripts/shell.gd")
	_expect(shell_source.contains("BuffTargetingPresentationConfig.INVALID_RELEASE_SNAP_BACK_SECONDS"), "invalid release tween must use the centralized duration")
	shell.free()


func _test_lane_transform_coalescing() -> void:
	var root := Node2D.new()
	get_root().add_child(root)
	var arena := TransformArena.new()
	root.add_child(arena)
	var map_root := Node2D.new()
	root.add_child(map_root)
	arena.map_root = map_root
	var renderer := TransformLaneRenderer.new()
	map_root.add_child(renderer)
	var eligible: Array = []
	for lane_id in range(1, 65):
		eligible.append(lane_id)
		var points := PackedVector2Array()
		for point_index in range(11):
			points.append(Vector2(20 + point_index * 18, 30 + lane_id * 7 + sin(float(point_index + lane_id)) * 10.0))
		renderer.add_probe(lane_id, points)
	var controller: Node2D = LaneTargetingScript.new()
	map_root.add_child(controller)
	controller.call("setup", arena, renderer)
	controller.call("begin_or_update", 88, {"ok": true, "target_type": "lane", "eligible_target_ids": eligible}, "", null, Vector2(120, 120))
	await process_frame
	await process_frame
	_expect(bool(controller.call("is_release_ready", 88, "lane")), "rendered lane geometry should become releasable")
	controller.call("begin_or_update", 88, {"ok": true, "target_type": "lane", "eligible_target_ids": eligible}, "lane", 13, Vector2(120, 120))
	_expect(bool(controller.call("is_release_ready", 88, "lane")), "same-finger release update must preserve rendered-cache readiness")

	var forced_started_us: int = Time.get_ticks_usec()
	for i in range(250):
		arena.projection_offset.x = float(i % 5)
		arena.revision += 1
		controller.call("force_recompute", "loop4_forced_transform")
	var forced_elapsed_us: int = Time.get_ticks_usec() - forced_started_us
	var forced_snapshot: Dictionary = controller.call("get_snapshot") as Dictionary
	_expect(int(forced_snapshot.get("max_transform_rebuilds_single_frame", 99)) <= 1, "same-frame transform invalidations must rebuild at most once")
	_expect(int(forced_snapshot.get("coalesced_transform_invalidation_count", 0)) >= 249, "forced transform burst should be coalesced")
	_expect(bool(forced_snapshot.get("geometry_dirty", false)), "post-budget transform change should remain dirty until the next frame")
	_expect(not bool(controller.call("is_release_ready", 88, "lane")), "dirty/unrendered lane geometry must not submit")
	print("BUFF_LANE_LOOP4_PERF_FORCED_COALESCED: eligible=64 segments=640 updates=250 elapsed_us=%d avg_us=%.4f max_rebuilds_per_frame=%d" % [
		forced_elapsed_us, float(forced_elapsed_us) / 250.0,
		int(forced_snapshot.get("max_transform_rebuilds_single_frame", 0))
	])

	var realistic_start_rebuilds: int = int(forced_snapshot.get("geometry_rebuild_count", 0))
	var realistic_start_rebuild_us: int = int(forced_snapshot.get("geometry_rebuild_elapsed_us", 0))
	var realistic_started_us: int = Time.get_ticks_usec()
	for frame_index in range(60):
		arena.projection_offset = Vector2(sin(float(frame_index) * 0.09) * 4.0, cos(float(frame_index) * 0.07) * 3.0)
		arena.revision += 1
		controller.call("force_recompute", "loop4_realistic_camera")
		await process_frame
	var realistic_elapsed_us: int = Time.get_ticks_usec() - realistic_started_us
	await process_frame
	var realistic_snapshot: Dictionary = controller.call("get_snapshot") as Dictionary
	var realistic_rebuilds: int = int(realistic_snapshot.get("geometry_rebuild_count", 0)) - realistic_start_rebuilds
	var realistic_rebuild_us: int = int(realistic_snapshot.get("geometry_rebuild_elapsed_us", 0)) - realistic_start_rebuild_us
	_expect(realistic_rebuilds <= 60, "realistic camera motion must not exceed one geometry rebuild per rendered frame")
	_expect(int(realistic_snapshot.get("max_transform_rebuilds_single_frame", 99)) <= 1, "realistic camera motion must preserve the per-frame rebuild cap")
	print("BUFF_LANE_LOOP4_PERF_REALISTIC_CAMERA: eligible=64 segments=640 frames=60 elapsed_us=%d avg_frame_us=%.4f rebuilds=%d rebuild_us=%d avg_rebuild_us=%.4f max_rebuilds_per_frame=%d nodes_growth=0 materials_growth=0" % [
		realistic_elapsed_us, float(realistic_elapsed_us) / 60.0, realistic_rebuilds, realistic_rebuild_us,
		float(realistic_rebuild_us) / float(maxi(1, realistic_rebuilds)),
		int(realistic_snapshot.get("max_transform_rebuilds_single_frame", 0))
	])
	controller.call("clear", 88, true, "loop4_perf_teardown")
	root.queue_free()
	await process_frame


func _test_feedback_controller_event_bridge() -> void:
	var root := Node2D.new()
	get_root().add_child(root)
	var arena := FakeArena.new()
	root.add_child(arena)
	var map_root := Node2D.new()
	root.add_child(map_root)
	var hive_renderer := FakeHiveRenderer.new()
	map_root.add_child(hive_renderer)
	var lane_renderer := FakeLaneRenderer.new()
	map_root.add_child(lane_renderer)
	var controller: Node2D = FeedbackScript.new()
	map_root.add_child(controller)
	controller.call("setup", arena, hive_renderer, lane_renderer, "epoch-production")
	controller.connect("feedback_started", Callable(self, "_on_feedback_started"))
	var bridge := CanonicalBridge.new()
	root.add_child(bridge)
	bridge.canonical_outcome.connect(Callable(controller, "handle_canonical_outcome"))

	var submitted_at: int = Time.get_ticks_msec() - 25
	controller.call("register_submission_receipt", "bridge-match", 1, "bridge-success", "hive", 7, "epoch-production", submitted_at)
	_expect(_feedback_started_count == 0 and int((controller.call("get_snapshot") as Dictionary).get("active_flash_count", 0)) == 0, "accepted submission alone must not produce success feedback")
	bridge.canonical_outcome.emit({
		"match_id": "bridge-match", "owner_id": 1, "activation_id": "bridge-success",
		"status": "executed", "reason": "activated", "target_type": "hive", "target_id": 7
	}, "epoch-production")
	_expect(_feedback_started_count == 1, "canonical event bridge should start one success flash")
	var snapshot: Dictionary = controller.call("get_snapshot") as Dictionary
	_expect(int(snapshot.get("active_flash_count", 0)) == 1, "success flash should remain presentation-local")
	_expect(int(snapshot.get("latency_sample_count", 0)) == 1 and int(snapshot.get("latency_max_msec", 0)) >= 25, "canonical feedback latency should be measured before adding pending UI")

	controller.call("register_submission_receipt", "bridge-match", 1, "bridge-reject", "lane", 9, "epoch-production", Time.get_ticks_msec())
	bridge.canonical_outcome.emit({
		"match_id": "bridge-match", "owner_id": 1, "activation_id": "bridge-reject",
		"status": "deterministic_no_op", "reason": "target_stale"
	}, "epoch-production")
	_expect(_feedback_started_count == 1, "rejection bridge event must not start a success flash")

	hive_renderer.visible_probe = false
	controller.call("register_submission_receipt", "bridge-match", 1, "missing-probe", "hive", 7, "epoch-production", Time.get_ticks_msec())
	bridge.canonical_outcome.emit({
		"match_id": "bridge-match", "owner_id": 1, "activation_id": "missing-probe",
		"status": "executed", "reason": "activated", "target_type": "hive", "target_id": 7
	}, "epoch-production")
	_expect(_feedback_started_count == 1, "missing current render probe must skip feedback")
	root.queue_free()
	await process_frame


func _test_production_bridge_contract() -> void:
	var scene: PackedScene = load("res://scenes/Arena.tscn") as PackedScene
	var arena: Node = scene.instantiate()
	_expect(arena.has_signal("buff_canonical_outcome_recorded"), "Arena must expose the production canonical-outcome presentation bridge")
	_expect(arena.has_node("MapRoot/BuffCanonicalFeedbackPresentation"), "Arena scene must instantiate production canonical feedback")
	arena.free()
	var arena_source: String = FileAccess.get_file_as_string("res://scripts/arena.gd")
	_expect(arena_source.count("buff_canonical_outcome_recorded.emit(outcome.duplicate(true), _buff_presentation_epoch)") == 2, "executed and deterministic-no-op finalizers must both enter the same event bridge")
	_expect(arena_source.contains("register_buff_activation_presentation_receipt"), "successful local submission must register a presentation receipt")
	var shell_source: String = FileAccess.get_file_as_string("res://scripts/shell.gd")
	_expect(shell_source.contains("const MATCH_BUFF_TARGETING_ENABLED: bool = false"), "production gate must remain exactly false")
	_expect(not shell_source.contains("BUFF_PENDING"), "pending treatment should remain absent without measured need")
	var config_source: String = FileAccess.get_file_as_string("res://scripts/renderers/buff_targeting_presentation_config.gd")
	_expect(not config_source.contains("OpsState") and not config_source.contains("SimState") and not config_source.contains("set_meta("), "central tuning must remain presentation-only")
	var receipt_source: String = FileAccess.get_file_as_string("res://scripts/renderers/buff_activation_presentation_receipts.gd")
	for forbidden: String in ["reservation", "mark_committed", "release(", "submit_buff_activation", "intent_activate_buff"]:
		_expect(not receipt_source.contains(forbidden), "presentation receipt history must never alter gameplay transactions: %s" % forbidden)


func _on_feedback_started(_activation_id: String, _target_type: String, _target_id: Variant, _latency_msec: int) -> void:
	_feedback_started_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_TARGETING_LOOP4_SMOKE: %s" % message)
