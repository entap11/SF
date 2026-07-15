extends SceneTree

const Config := preload("res://scripts/renderers/buff_targeting_presentation_config.gd")
const ReceiptsScript := preload("res://scripts/renderers/buff_activation_presentation_receipts.gd")
const FeedbackScript := preload("res://scripts/renderers/buff_canonical_feedback_controller.gd")
const HiveTargetingScript := preload("res://scripts/renderers/buff_hive_targeting_controller.gd")
const LaneTargetingScript := preload("res://scripts/renderers/buff_lane_global_targeting_controller.gd")
const TransactionScript := preload("res://scripts/state/buff_activation_transaction.gd")


class FakeArena:
	extends Node2D

	var conversion_valid: bool = true
	var projection_offset: Vector2 = Vector2.ZERO
	var transform_revision: int = 1

	func root_screen_to_buff_arena_local(root_screen_pos: Vector2) -> Dictionary:
		if not conversion_valid:
			return {"ok": false, "reason": "outside_arena"}
		return {"ok": true, "arena_local_pos": root_screen_pos - projection_offset}

	func buff_arena_local_to_root_screen(arena_local_pos: Vector2) -> Dictionary:
		if not conversion_valid:
			return {"ok": false, "reason": "outside_arena"}
		return {"ok": true, "root_screen_pos": arena_local_pos + projection_offset}

	func buff_arena_local_to_world(arena_local_pos: Vector2) -> Vector2:
		return arena_local_pos

	func get_buff_targeting_transform_signature() -> String:
		return "%d|%s" % [transform_revision, str(projection_offset)]

	func get_buff_global_targeting_query(_root_screen_pos: Vector2) -> Dictionary:
		return {
			"valid": conversion_valid,
			"boundary_arena_local_points": _boundary() if conversion_valid else PackedVector2Array()
		}

	func get_buff_global_presentation_boundary() -> Dictionary:
		return {"valid": conversion_valid, "boundary_arena_local_points": _boundary()}

	func get_buff_presentation_owner_color(_owner_id: int) -> Color:
		return Color(0.95, 0.72, 0.16, 1.0)

	func _boundary() -> PackedVector2Array:
		return PackedVector2Array([
			Vector2(0, 0), Vector2(400, 0), Vector2(400, 300), Vector2(0, 300)
		])


class FakeHiveRenderer:
	extends Node2D

	var probe_visible: bool = true
	var render_instance_id: int = 101

	func get_buff_target_probe(hive_id: int) -> Dictionary:
		if not probe_visible or hive_id != 7:
			return {"ok": false}
		return {
			"ok": true,
			"center_arena_local": Vector2(120, 120),
			"radius_edge_arena_local": Vector2(148, 120),
			"ring_center_arena_local": Vector2(120, 120),
			"base_radius_arena_local": 28.0,
			"render_instance_id": render_instance_id
		}


class FakeLaneRenderer:
	extends Node2D

	var probe_visible: bool = true
	var generation: int = 1
	var path_revision: int = 1
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(40, 220), Vector2(200, 220), Vector2(360, 220)
	])

	func get_buff_target_lane_probe(lane_id: int) -> Dictionary:
		if not probe_visible or lane_id != 9:
			return {"valid": false}
		return {
			"valid": true,
			"renderable": true,
			"points": points,
			"path_revision": path_revision
		}

	func get_buff_target_lane_probe_revision(lane_id: int) -> int:
		return path_revision if probe_visible and lane_id == 9 else -1

	func get_buff_target_lane_generation() -> int:
		return generation


class CanonicalBridge:
	extends Node
	signal canonical_outcome(outcome: Dictionary, presentation_epoch: String)


var _failed: bool = false
var _feedback_started_count: int = 0
var _feedback_ignored_count: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_receipt_identity_and_outcome_matrix()
	_test_presentation_cannot_mutate_transactions()
	await _test_feedback_bridge_lifecycle_and_latency()
	await _test_hive_lifecycle_and_render_rebinding()
	await _test_lane_global_lifecycle_and_dirty_release_gate()
	_test_production_contract_audit()
	if not _failed:
		print("BUFF_TARGETING_LOOP5_HARDENING_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_receipt_identity_and_outcome_matrix() -> void:
	var receipts: RefCounted = ReceiptsScript.new()
	var invalid_cases: Array[Array] = [
		["", 1, "a", "hive", 7, "epoch"],
		["match", 0, "a", "hive", 7, "epoch"],
		["match", 1, "", "hive", 7, "epoch"],
		["match", 1, "a", "hive", -1, "epoch"],
		["match", 1, "a", "global", "not-global", "epoch"],
		["match", 1, "a", "unknown", 7, "epoch"],
		["match", 1, "a", "hive", 7, ""]
	]
	for args: Array in invalid_cases:
		var rejected: Dictionary = receipts.callv("register_submission", args) as Dictionary
		_expect(not bool(rejected.get("ok", false)), "invalid presentation receipt must be rejected: %s" % str(args))
	_expect(int((receipts.snapshot() as Dictionary).get("live_receipt_count", -1)) == 0, "invalid receipts must not allocate history")

	var first: Dictionary = receipts.register_submission("match-a", 1, "duplicate", "hive", 7, "epoch-a", 1000)
	var duplicate: Dictionary = receipts.register_submission("match-a", 1, "duplicate", "lane", 9, "epoch-a", 2000)
	_expect(bool(first.get("ok", false)) and bool(duplicate.get("duplicate", false)), "duplicate receipt registration must be idempotent")
	var duplicate_receipt: Dictionary = duplicate.get("receipt", {}) as Dictionary
	_expect(str(duplicate_receipt.get("target_type", "")) == "hive" and int(duplicate_receipt.get("target_id", -1)) == 7, "duplicate registration must not replace submitted target identity")
	_expect(int(duplicate_receipt.get("submitted_at_msec", -1)) == 1000, "duplicate registration must not extend receipt age")

	var exact_outcome: Dictionary = _outcome("match-a", 1, "duplicate", "executed", "activated", "hive", 7)
	for mismatch in [
		_outcome("wrong-match", 1, "duplicate", "executed", "activated", "hive", 7),
		_outcome("match-a", 2, "duplicate", "executed", "activated", "hive", 7),
		_outcome("match-a", 1, "wrong-activation", "executed", "activated", "hive", 7)
	]:
		_expect(not bool(receipts.consume_canonical_outcome(mismatch, "epoch-a", 1100).get("feedback", false)), "identity mismatch must not flash or consume the legitimate receipt")
	_expect(not bool(receipts.consume_canonical_outcome(exact_outcome, "wrong-epoch", 1100).get("feedback", false)), "epoch mismatch must not consume a legitimate receipt")
	_expect(bool(receipts.consume_canonical_outcome(exact_outcome, "epoch-a", 1100).get("feedback", false)), "exact receipt identity must allow executed/activated feedback")
	_expect(bool(receipts.consume_canonical_outcome(exact_outcome, "epoch-a", 1101).get("duplicate", false)), "canonical replay must not flash twice")

	var non_success_cases: Array[Dictionary] = [
		{"status": "submitted", "reason": "accepted"},
		{"status": "scheduled", "reason": "scheduled"},
		{"status": "submission_rejected", "reason": "transport_rejected"},
		{"status": "deterministic_no_op", "reason": "target_stale"},
		{"status": "deterministic_no_op", "reason": "unavailable"},
		{"status": "deterministic_no_op", "reason": "match_ended"},
		{"status": "executed", "reason": "not_activated"}
	]
	for i in range(non_success_cases.size()):
		var activation_id: String = "non-success-%d" % i
		receipts.register_submission("matrix", 1, activation_id, "global", "global", "epoch-matrix", 2000 + i)
		var outcome: Dictionary = non_success_cases[i].duplicate(true)
		outcome.merge({
			"match_id": "matrix", "owner_id": 1, "activation_id": activation_id,
			"target_type": "global", "target_id": "global"
		}, true)
		_expect(not bool(receipts.consume_canonical_outcome(outcome, "epoch-matrix", 2100 + i).get("feedback", false)), "non-executed/activated outcome must not flash: %s" % str(outcome))

	receipts.register_submission("target", 1, "target-mismatch", "lane", 9, "epoch-target", 3000)
	var target_mismatch: Dictionary = receipts.consume_canonical_outcome(
		_outcome("target", 1, "target-mismatch", "executed", "activated", "lane", 10),
		"epoch-target", 3100
	)
	_expect(str(target_mismatch.get("reason", "")) == "canonical_target_mismatch" and not bool(target_mismatch.get("feedback", false)), "canonical target mismatch must consume cosmetically without feedback")

	receipts.register_submission("timeout", 1, "at-boundary", "global", "global", "epoch-time", 4000)
	_expect(bool(receipts.consume_canonical_outcome(
		_outcome("timeout", 1, "at-boundary", "executed", "activated", "global", "global"),
		"epoch-time", 4000 + Config.ACTIVATION_RECEIPT_TIMEOUT_MSEC
	).get("feedback", false)), "receipt must remain valid through the documented timeout boundary")
	receipts.register_submission("timeout", 1, "expired", "global", "global", "epoch-time", 5000)
	var late: Dictionary = receipts.consume_canonical_outcome(
		_outcome("timeout", 1, "expired", "executed", "activated", "global", "global"),
		"epoch-time", 5000 + Config.ACTIVATION_RECEIPT_TIMEOUT_MSEC + 1
	)
	_expect(not bool(late.get("feedback", false)) and str(late.get("reason", "")) == "receipt_expired", "late authoritative result must stand without cosmetic feedback")

	var bounded: RefCounted = ReceiptsScript.new()
	for i in range(Config.MAX_LIVE_ACTIVATION_RECEIPTS + 12):
		bounded.register_submission("bounded", 1, "live-%03d" % i, "hive", 7, "epoch", 10000)
	var bounded_snapshot: Dictionary = bounded.snapshot()
	_expect(int(bounded_snapshot.get("live_receipt_count", -1)) == Config.MAX_LIVE_ACTIVATION_RECEIPTS, "live receipt history must enforce its exact maximum")
	_expect(int(bounded_snapshot.get("handled_outcome_count", -1)) == 12, "capacity evictions must enter bounded handled history")
	for i in range(Config.MAX_HANDLED_OUTCOMES + 24):
		var activation_id: String = "handled-%03d" % i
		bounded.register_submission("handled", 1, activation_id, "global", "global", "epoch", 20000 + i)
		bounded.consume_canonical_outcome(
			_outcome("handled", 1, activation_id, "deterministic_no_op", "target_stale", "global", "global"),
			"epoch", 20000 + i
		)
	bounded_snapshot = bounded.snapshot()
	_expect(int(bounded_snapshot.get("handled_outcome_count", -1)) == Config.MAX_HANDLED_OUTCOMES, "handled outcome history must enforce its exact maximum")
	_expect(str(bounded_snapshot.get("eviction_rule", "")) == "oldest_submission_then_sequence", "equal-time eviction must use deterministic sequence order")
	bounded.clear()
	bounded_snapshot = bounded.snapshot()
	_expect(int(bounded_snapshot.get("live_receipt_count", -1)) == 0 and int(bounded_snapshot.get("handled_outcome_count", -1)) == 0, "presentation history clear must leave no receipt or replay state")


func _test_presentation_cannot_mutate_transactions() -> void:
	var transactions: RefCounted = TransactionScript.new()
	var request: Dictionary = _request("accepted", "match-authority", 1, "vs", 1, "inventory:accepted")
	_expect(bool(transactions.reserve(request, 1).get("ok", false)), "authority fixture must reserve")
	_expect(bool(transactions.mark_submitted("match-authority", 1, "accepted").get("ok", false)), "authority fixture must submit")

	var receipts: RefCounted = ReceiptsScript.new()
	receipts.register_submission("match-authority", 1, "accepted", "hive", 7, "epoch", 1000)
	receipts.clear()
	var still_submitted: Dictionary = transactions.get_transaction("match-authority", 1, "accepted")
	_expect(str(still_submitted.get("reservation_state", "")) == "submitted", "presentation teardown must not release an accepted reservation")

	receipts.register_submission("match-authority", 1, "accepted", "hive", 7, "epoch", 2000)
	receipts.consume_canonical_outcome(
		_outcome("match-authority", 1, "accepted", "deterministic_no_op", "target_stale", "hive", 7),
		"epoch", 2100
	)
	still_submitted = transactions.get_transaction("match-authority", 1, "accepted")
	_expect(str(still_submitted.get("reservation_state", "")) == "submitted", "cosmetic outcome consumption must not resolve an authoritative transaction")

	var other_match: Dictionary = _request("same-activation", "match-other", 1, "async", 2, "inventory:other")
	_expect(bool(transactions.reserve(other_match, 1).get("ok", false)), "same activation ID in another match must have a separate authority scope")
	var terminated: Array[Dictionary] = transactions.terminate_match("match-authority")
	_expect(terminated.size() == 1, "match termination must release only that match's unresolved reservations")
	_expect(str(transactions.get_transaction("match-other", 1, "same-activation").get("reservation_state", "")) == "reserved", "other-match reservation must survive unrelated termination")

	var vs_two: Dictionary = _request("vs-two", "match-other", 1, "vs", 2, "inventory:vs-two")
	var async_three: Dictionary = _request("async-three", "match-other", 1, "async", 3, "inventory:async-three")
	_expect(str(transactions.reserve(vs_two, 1).get("reason", "")) == "invalid_source_use_ordinal", "VS ordinal two must reject without allocation")
	_expect(str(transactions.reserve(async_three, 1).get("reason", "")) == "invalid_source_use_ordinal", "Async ordinal three must reject without allocation")

	transactions.terminate_match("match-other")
	for i in range(270):
		var terminal_request: Dictionary = _request("terminal-%03d" % i, "terminal-match", 1, "vs", 1, "terminal-charge-%03d" % i)
		transactions.reserve(terminal_request, 1)
		transactions.release("terminal-match", 1, "terminal-%03d" % i, "loop5_bound")
	var performance: Dictionary = transactions.performance_snapshot()
	_expect(int(performance.get("terminal_count", -1)) == 256 and int(performance.get("max_terminal_history", -1)) == 256, "authoritative terminal history must remain bounded")


func _test_feedback_bridge_lifecycle_and_latency() -> void:
	var root := Node2D.new()
	get_root().add_child(root)
	var arena := FakeArena.new()
	root.add_child(arena)
	var hive_renderer := FakeHiveRenderer.new()
	root.add_child(hive_renderer)
	var lane_renderer := FakeLaneRenderer.new()
	root.add_child(lane_renderer)
	var controller: Node2D = FeedbackScript.new()
	root.add_child(controller)
	controller.call("setup", arena, hive_renderer, lane_renderer, "epoch-a")
	controller.connect("feedback_started", Callable(self, "_on_feedback_started"))
	controller.connect("canonical_outcome_ignored", Callable(self, "_on_feedback_ignored"))
	var bridge := CanonicalBridge.new()
	root.add_child(bridge)
	bridge.canonical_outcome.connect(Callable(controller, "handle_canonical_outcome"))

	var target_cases: Array[Dictionary] = [
		{"type": "hive", "id": 7},
		{"type": "lane", "id": 9},
		{"type": "global", "id": "global"}
	]
	var requested_latencies: Array[int] = [10, 20, 30, 40, 50, 60]
	for i in range(requested_latencies.size()):
		var target: Dictionary = target_cases[i % target_cases.size()]
		var activation_id: String = "success-%d" % i
		var now: int = Time.get_ticks_msec()
		controller.call("register_submission_receipt", "bridge", 1, activation_id, target.type, target.id, "epoch-a", now - requested_latencies[i])
		bridge.canonical_outcome.emit(
			_outcome("bridge", 1, activation_id, "executed", "activated", str(target.type), target.id),
			"epoch-a"
		)
	_expect(_feedback_started_count == requested_latencies.size(), "production event bridge must produce exactly one flash per successful receipt")
	var snapshot: Dictionary = controller.call("get_snapshot") as Dictionary
	_expect(int(snapshot.get("active_flash_count", -1)) == requested_latencies.size(), "all target types must create presentation-local flashes")
	_expect(int(snapshot.get("latency_sample_count", -1)) == requested_latencies.size(), "latency count must include successful production-bridge outcomes only")
	_expect(int(snapshot.get("latency_window_sample_count", -1)) == requested_latencies.size(), "latency distribution window must record every current sample")
	_expect(int(snapshot.get("latency_min_msec", -1)) <= int(snapshot.get("latency_p50_msec", -1)), "latency p50 must be ordered after minimum")
	_expect(int(snapshot.get("latency_p50_msec", -1)) <= int(snapshot.get("latency_p95_msec", -1)), "latency p95 must be ordered after p50")
	_expect(int(snapshot.get("latency_p95_msec", -1)) <= int(snapshot.get("latency_p99_msec", -1)), "latency p99 must be ordered after p95")
	_expect(int(snapshot.get("latency_p99_msec", -1)) <= int(snapshot.get("latency_max_msec", -1)), "latency maximum must bound p99")
	_expect(str(snapshot.get("latency_percentile_rule", "")) == "nearest_rank_bounded_window", "latency percentile rule must be explicit")
	print("BUFF_TARGETING_LOOP5_LATENCY_CONTROLLED: samples=%d min_ms=%d p50_ms=%d p95_ms=%d p99_ms=%d max_ms=%d rule=%s" % [
		int(snapshot.get("latency_sample_count", 0)),
		int(snapshot.get("latency_min_msec", 0)),
		int(snapshot.get("latency_p50_msec", 0)),
		int(snapshot.get("latency_p95_msec", 0)),
		int(snapshot.get("latency_p99_msec", 0)),
		int(snapshot.get("latency_max_msec", 0)),
		str(snapshot.get("latency_percentile_rule", ""))
	])

	bridge.canonical_outcome.emit(
		_outcome("bridge", 1, "success-0", "executed", "activated", "hive", 7),
		"epoch-a"
	)
	_expect(_feedback_started_count == requested_latencies.size(), "canonical replay must not create a second flash")

	hive_renderer.probe_visible = false
	controller.call("register_submission_receipt", "bridge", 1, "missing-probe", "hive", 7, "epoch-a", Time.get_ticks_msec())
	bridge.canonical_outcome.emit(
		_outcome("bridge", 1, "missing-probe", "executed", "activated", "hive", 7),
		"epoch-a"
	)
	_expect(_feedback_started_count == requested_latencies.size(), "missing current render probe must skip feedback")

	controller.call("register_submission_receipt", "bridge", 1, "old-epoch", "global", "global", "epoch-a", Time.get_ticks_msec())
	controller.call("set_presentation_epoch", "epoch-b")
	snapshot = controller.call("get_snapshot") as Dictionary
	_expect(int(snapshot.get("live_receipt_count", -1)) == 0 and int(snapshot.get("active_flash_count", -1)) == 0, "Arena epoch replacement must clear old presentation state")
	_expect(int(snapshot.get("latency_sample_count", -1)) == 0 and int(snapshot.get("latency_window_sample_count", -1)) == 0, "latency distribution must not cross Arena epochs")
	bridge.canonical_outcome.emit(
		_outcome("bridge", 1, "old-epoch", "executed", "activated", "global", "global"),
		"epoch-a"
	)
	_expect(_feedback_started_count == requested_latencies.size(), "old Arena outcome must never flash in a new presentation epoch")

	for i in range(Config.MAX_LATENCY_SAMPLES + 9):
		var activation_id: String = "latency-bound-%03d" % i
		controller.call("register_submission_receipt", "bridge", 1, activation_id, "global", "global", "epoch-b", Time.get_ticks_msec() - 1)
		bridge.canonical_outcome.emit(
			_outcome("bridge", 1, activation_id, "executed", "activated", "global", "global"),
			"epoch-b"
		)
	snapshot = controller.call("get_snapshot") as Dictionary
	_expect(int(snapshot.get("latency_sample_count", -1)) == Config.MAX_LATENCY_SAMPLES + 9, "total latency sample count must remain accurate beyond the bounded distribution window")
	_expect(int(snapshot.get("latency_window_sample_count", -1)) == Config.MAX_LATENCY_SAMPLES, "latency distribution storage must enforce its exact maximum")

	controller.call("register_submission_receipt", "bridge", 1, "clear", "global", "global", "epoch-b", Time.get_ticks_msec())
	controller.call("clear_presentation")
	snapshot = controller.call("get_snapshot") as Dictionary
	_expect(int(snapshot.get("live_receipt_count", -1)) == 0 and not bool(snapshot.get("processing", true)), "presentation clear must stop processing when no flashes or receipts remain")
	_expect(_feedback_ignored_count >= 3, "ignored duplicate, missing probe, and old epoch outcomes must be observable")
	root.queue_free()
	await process_frame


func _test_hive_lifecycle_and_render_rebinding() -> void:
	var root := Node2D.new()
	get_root().add_child(root)
	var arena := FakeArena.new()
	root.add_child(arena)
	var renderer := FakeHiveRenderer.new()
	root.add_child(renderer)
	var controller: Node2D = HiveTargetingScript.new()
	root.add_child(controller)
	controller.call("setup", arena, renderer)
	_expect(bool(controller.call("begin_or_update", 10, [7], -1, Vector2(120, 120))), "hive session must start")
	var snapshot: Dictionary = controller.call("get_snapshot") as Dictionary
	_expect(int(snapshot.get("selected_hive_id", -1)) == 7, "visible eligible hive must acquire")

	renderer.probe_visible = false
	controller.call("notify_render_nodes_changed")
	snapshot = controller.call("get_snapshot") as Dictionary
	_expect(int(snapshot.get("selected_hive_id", 99)) == -1 and int(snapshot.get("renderable_hive_count", 99)) == 0, "hidden/freed render probe must immediately clear presentation selection")

	renderer.probe_visible = true
	renderer.render_instance_id = 202
	controller.call("notify_render_nodes_changed")
	var visual: Dictionary = controller.call("get_visual_state_snapshot") as Dictionary
	_expect(int((visual.get(7, {}) as Dictionary).get("render_instance_id", -1)) == 202, "rebound hive probe must use the current render identity")

	arena.projection_offset = Vector2(500, 0)
	arena.transform_revision += 1
	controller.call("_process", 0.0)
	snapshot = controller.call("get_snapshot") as Dictionary
	_expect(int(snapshot.get("selected_hive_id", 99)) == -1, "stationary finger must lose a hive moved outside retention by camera transform")

	arena.conversion_valid = false
	controller.call("_process", 0.0)
	snapshot = controller.call("get_snapshot") as Dictionary
	_expect(not bool(snapshot.get("inside_arena", true)) and int(snapshot.get("selected_hive_id", 99)) == -1, "invalid Arena conversion must clear hive selection")
	_expect(not bool(controller.call("clear", 9, true, "wrong_session")), "old session must not clear a newer hive session")
	_expect(bool(controller.call("clear", 10, true, "lifecycle_end")), "owning hive session must clear")
	snapshot = controller.call("get_snapshot") as Dictionary
	_expect(not bool(snapshot.get("active", true)) and not bool(controller.is_processing()), "hive teardown must stop processing and clear state")
	root.queue_free()
	await process_frame


func _test_lane_global_lifecycle_and_dirty_release_gate() -> void:
	var root := Node2D.new()
	get_root().add_child(root)
	var arena := FakeArena.new()
	root.add_child(arena)
	var renderer := FakeLaneRenderer.new()
	root.add_child(renderer)
	var controller: Node2D = LaneTargetingScript.new()
	root.add_child(controller)
	controller.call("setup", arena, renderer)
	controller.call("begin_or_update", 20, {"ok": true, "target_type": "lane", "eligible_target_ids": [9]}, "", null, Vector2(200, 220))
	await process_frame
	await process_frame
	_expect(bool(controller.call("is_release_ready", 20, "lane")), "rendered lane geometry must become release-ready")

	renderer.generation += 1
	renderer.path_revision += 1
	_expect(not bool(controller.call("is_release_ready", 20, "lane")), "changed but unrendered lane geometry must block submission")
	var dirty: Dictionary = controller.call("get_snapshot") as Dictionary
	_expect(bool(dirty.get("geometry_dirty", false)), "renderer generation change must mark cached lane geometry dirty")
	await process_frame
	await process_frame
	_expect(bool(controller.call("is_release_ready", 20, "lane")), "lane may submit only after rebuilt geometry has rendered")

	renderer.probe_visible = false
	renderer.generation += 1
	controller.call("notify_render_nodes_changed")
	var snapshot: Dictionary = controller.call("get_snapshot") as Dictionary
	_expect(int(snapshot.get("selected_lane_id", 99)) == -1 and not bool(controller.call("is_release_ready", 20, "lane")), "missing lane probe must clear selection and block release")
	_expect(bool(controller.call("clear", 20, true, "map_rebuild")), "lane session must clear on map rebuild")
	snapshot = controller.call("get_snapshot") as Dictionary
	_expect(not bool(snapshot.get("active", true)) and int(snapshot.get("geometry_cache_size", 99)) == 0 and not bool(snapshot.get("processing", true)), "lane teardown must clear cache and stop processing")

	arena.conversion_valid = true
	controller.call("begin_or_update", 21, {"ok": true, "target_type": "global", "eligible_target_ids": ["global"]}, "", null, Vector2(100, 100))
	_expect(bool(controller.call("is_release_ready", 21, "global")), "valid global boundary must become release-ready")
	arena.conversion_valid = false
	controller.call("update_finger", 21, Vector2(100, 100))
	_expect(not bool(controller.call("is_release_ready", 21, "global")), "invalid Arena conversion must clear global release readiness")
	controller.call("clear", 21, true, "focus_lost")
	root.queue_free()
	await process_frame


func _test_production_contract_audit() -> void:
	var shell_source: String = FileAccess.get_file_as_string("res://scripts/shell.gd")
	var arena_source: String = FileAccess.get_file_as_string("res://scripts/arena.gd")
	var receipt_source: String = FileAccess.get_file_as_string("res://scripts/renderers/buff_activation_presentation_receipts.gd")
	var feedback_source: String = FileAccess.get_file_as_string("res://scripts/renderers/buff_canonical_feedback_controller.gd")
	var hive_renderer_source: String = FileAccess.get_file_as_string("res://scripts/renderers/hive_renderer.gd")
	var lane_renderer_source: String = FileAccess.get_file_as_string("res://scripts/renderers/lane_renderer.gd")
	_expect(shell_source.count("const MATCH_BUFF_TARGETING_ENABLED: bool = false") == 1, "production targeting gate must remain exactly false")
	_expect(arena_source.count("buff_canonical_outcome_recorded.emit(outcome.duplicate(true), _buff_presentation_epoch)") == 2, "executed and no-op outcomes must share the production presentation bridge")
	_expect(not shell_source.contains("BUFF_PENDING") and not feedback_source.contains("pending_state"), "pending treatment must remain absent without production latency evidence")
	for forbidden: String in ["submit_buff_activation", "mark_committed", "resolve_canonical_outcome", "terminate_match(", "consume_buff("]:
		_expect(not receipt_source.contains(forbidden) and not feedback_source.contains(forbidden), "presentation feedback must not own gameplay transaction operation: %s" % forbidden)
	_expect(hive_renderer_source.contains("_clear_buff_target_presentation(\"hive_renderer_clear\")"), "hive renderer reconstruction must clear targeting presentation")
	_expect(lane_renderer_source.contains("_clear_buff_target_lane_probes(\"renderer_teardown\")"), "lane renderer teardown must clear targeting probes")


func _outcome(
	match_id: String,
	owner_id: int,
	activation_id: String,
	status: String,
	reason: String,
	target_type: String,
	target_id: Variant
) -> Dictionary:
	return {
		"match_id": match_id,
		"owner_id": owner_id,
		"activation_id": activation_id,
		"status": status,
		"reason": reason,
		"target_type": target_type,
		"target_id": target_id
	}


func _request(
	activation_id: String,
	match_id: String,
	owner_id: int,
	source_kind: String,
	source_use_ordinal: int,
	charge_key: String
) -> Dictionary:
	return {
		"match_id": match_id,
		"owner_id": owner_id,
		"activation_id": activation_id,
		"buff_id": "buff_unit_speed_classic",
		"tier": "classic",
		"source_kind": source_kind,
		"source_use_ordinal": source_use_ordinal,
		"inventory_revision": "loop5-revision",
		"charge_key": charge_key,
		"slot_index": 0,
		"target_type": "hive",
		"target_id": 7
	}


func _on_feedback_started(_activation_id: String, _target_type: String, _target_id: Variant, _latency_msec: int) -> void:
	_feedback_started_count += 1


func _on_feedback_ignored(_activation_id: String, _reason: String) -> void:
	_feedback_ignored_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_TARGETING_LOOP5_HARDENING_SMOKE: %s" % message)
