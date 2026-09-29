extends SceneTree

const Record := preload("res://scripts/state/beta_capture_record.gd")
const Collector := preload("res://scripts/state/match_telemetry_collector.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var context := {"capture_id": "a".repeat(32), "owner_key": "b".repeat(64), "build": "2026092802",
		"source_sha256": "c".repeat(64), "engine": "4.7.1", "platform": "iOS", "status": "interrupted",
		"sim_ms": 1000, "winner_seat": 0, "metadata": {"map_id": "simple_syrup", "mode": "1V1"}}
	var payload := {"metadata": {"local_player_id": "PRIVATE_UUID", "players": [
		{"seat": 1, "display_name": "PRIVATE_NAME", "is_cpu": false, "is_local": true}]},
		"events": [{"e": 9, "t": 500, "p": 1, "intent": "attack", "src": 1, "dst": 2, "ok": true,
			"access_token": "PRIVATE_SECRET", "observation": {"private": "PRIVATE_VALUE"}}],
		"replay": {"frames": [{"t": 500, "h": [[1, 1, 10]], "l": [], "u": [[1, 2, 3]]}]}}
	var original := JSON.stringify(payload)
	var projected := Record.project(payload, context)
	check(JSON.stringify(payload) == original, "projection must not mutate source data")
	check(not "PRIVATE" in JSON.stringify(projected), "private fields leaked")
	check(projected.events.size() == 1 and projected.frames.size() == 1, "gameplay evidence missing")
	check(not projected.frames[0].has("u"), "strategic capture unexpectedly copied unit replay")
	var path: String = "user://beta_capture_smoke/" + str(context.capture_id) + ".json.gz"
	check(Record.write_atomic(projected, path).ok, "checkpoint save failed")
	check(Record.read_record(path).status == "interrupted", "restart must retain interrupted checkpoint")
	var digest := FileAccess.get_sha256(path)
	check(not Record.acknowledge(path, {"ok": true, "capture_id": context.capture_id, "sha256": "bad"}, digest), "wrong hash removed queued evidence")
	check(not Record.acknowledge(path, {"ok": true, "capture_id": "different", "sha256": digest}, digest), "wrong id removed queued evidence")
	check(not Record.acknowledge(path, {"ok": false, "capture_id": context.capture_id, "sha256": digest}, digest), "rejected upload removed queued evidence")
	projected.status = "completed"
	check(Record.write_atomic(projected, path).ok, "completed replacement failed")
	check(not Record.acknowledge(path, {"ok": true, "capture_id": context.capture_id, "sha256": digest}, digest), "stale acknowledgement removed newer evidence")
	digest = FileAccess.get_sha256(path)
	check(Record.acknowledge(path, {"ok": true, "capture_id": context.capture_id, "sha256": digest}, digest), "valid acknowledgement not applied")
	check(not FileAccess.file_exists(path), "acknowledged queue entry survived")
	var collector := Collector.new()
	collector.begin_match("smoke", "beta", "simple_syrup", 2, [1, 2], 1000, {})
	collector.record_action_event(500, 2, "bot_started", {"profile": {"seat": 2, "style": "raider", "tier": "medium", "policy": "baseline_v3"}})
	var from_collector: Dictionary = collector.beta_capture_snapshot(context)
	check(from_collector.profiles.size() == 1, "actual collector must expose effective bot profile")
	check(collector.is_active(), "capture must not finalize gameplay telemetry")
	# Real phone fixtures verify the projection on genuine games, including all command strings.
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--recording="):
			continue
		var input_path := argument.trim_prefix("--recording=")
		var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(input_path))
		var real_context := context.duplicate(true)
		real_context.capture_id = str(input.metadata.bot_evaluation.run_id).sha256_text().substr(0, 32)
		real_context.status = "completed"
		var output := Record.project(input, real_context)
		check(not str(input.metadata.local_player_id) in JSON.stringify(output) if not str(input.metadata.local_player_id).is_empty() else true, "real player identity leaked")
		check(Record.write_atomic(output, "user://beta_capture_smoke/" + real_context.capture_id + ".json.gz").ok, "real match projection save failed")
	var many_events: Array = []
	for i in 20005:
		many_events.append({"e": 9, "t": i})
	var bounded := Record.project({"events": many_events}, context)
	check(bounded.events.size() == 20000 and bounded.dropped_events == 5, "event limit not explicitly reported")
	check(bounded.events[-1].t == 20004, "endgame commands lost at event cap")
	print("BETA_CAPTURE_SMOKE_%s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
