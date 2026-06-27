extends SceneTree

const VsSpectatorRuntimeScript := preload("res://scripts/state/vs_spectator_runtime.gd")

class FakeSpectatorHandshake:
	extends Node

	var join_calls: int = 0
	var poll_calls: int = 0
	var leave_calls: int = 0

	func join_spectate(grant_token: String, session_id: String = "", spectator_uid: String = "") -> Dictionary:
		join_calls += 1
		return {
			"ok": not grant_token.is_empty() and not session_id.is_empty(),
			"spectator": {
				"session_id": session_id,
				"spectator_uid": spectator_uid,
				"delay_sec": 20,
				"live": false
			},
			"session": {
				"id": session_id,
				"status": "started",
				"host": {"uid": "host", "ready": false},
				"guest": {"uid": "guest", "ready": false}
			}
		}

	func poll_spectator_events(grant_token: String, session_id: String = "", after_seq: int = 0) -> Dictionary:
		poll_calls += 1
		if grant_token.is_empty() or session_id.is_empty():
			return {"ok": false, "err": "invalid_spectator_grant"}
		return {
			"ok": true,
			"latest_seq": 1,
			"delay_sec": 20,
			"live": false,
			"events": [
				{"seq": 1, "uid": "host", "command": {"kind": "lane_intent", "src": 1, "dst": 2}}
			] if after_seq < 1 else []
		}

	func poll_spectator_snapshots(grant_token: String, session_id: String = "", after_seq: int = 0) -> Dictionary:
		if grant_token.is_empty() or session_id.is_empty():
			return {"ok": false, "err": "invalid_spectator_grant"}
		return {
			"ok": true,
			"latest_seq": 1,
			"delay_sec": 20,
			"live": false,
			"snapshots": [
				{"seq": 1, "uid": "host", "snapshot": _sample_visual_snapshot()}
			] if after_seq < 1 else []
		}

	func _sample_visual_snapshot() -> Dictionary:
		return {
			"frame_index": 0,
			"replay": {
				"map": {
					"hives": [[1, 0.0, 0.0, 1], [2, 100.0, 0.0, 2]],
					"lane_candidates": [[1, 2]]
				},
				"frames": [
					{"t": 0, "h": [[1, 1, 20], [2, 2, 20]], "l": [[1, 1, 2, 1, 0]], "u": []}
				]
			}
		}

	func leave_spectate(grant_token: String) -> Dictionary:
		leave_calls += 1
		return {"ok": not grant_token.is_empty(), "closed": true}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var fake := FakeSpectatorHandshake.new()
	get_root().add_child(fake)
	var runtime: Node = VsSpectatorRuntimeScript.new()
	get_root().add_child(runtime)
	await process_frame

	if runtime.has_method("publish_intent") or runtime.has_method("set_ready") or runtime.has_method("apply_lane_intent"):
		push_error("VS_SPECTATOR_RUNTIME_SMOKE: runtime exposes player input methods")
		quit(1)
		return

	runtime.call("configure", "SPECTATE_SESSION", "grant_token", "observer", "Observer", fake)
	var join_result: Dictionary = runtime.call("join") as Dictionary
	if not bool(join_result.get("ok", false)):
		push_error("VS_SPECTATOR_RUNTIME_SMOKE: join failed %s" % str(join_result))
		quit(1)
		return
	var poll_result: Dictionary = runtime.call("poll_once") as Dictionary
	if not bool(poll_result.get("ok", false)):
		push_error("VS_SPECTATOR_RUNTIME_SMOKE: poll failed %s" % str(poll_result))
		quit(1)
		return
	var events: Array = runtime.call("get_event_buffer") as Array
	if events.size() != 1:
		push_error("VS_SPECTATOR_RUNTIME_SMOKE: expected one buffered event got %d" % events.size())
		quit(1)
		return
	var snapshot_result: Dictionary = runtime.call("poll_snapshots_once") as Dictionary
	if not bool(snapshot_result.get("ok", false)):
		push_error("VS_SPECTATOR_RUNTIME_SMOKE: snapshot poll failed %s" % str(snapshot_result))
		quit(1)
		return
	var snapshots: Array = runtime.call("get_snapshot_buffer") as Array
	if snapshots.size() != 1:
		push_error("VS_SPECTATOR_RUNTIME_SMOKE: expected one buffered snapshot got %d" % snapshots.size())
		quit(1)
		return
	var snapshot: Dictionary = runtime.call("get_debug_snapshot") as Dictionary
	if int(snapshot.get("delay_sec", 0)) != 20 or bool(snapshot.get("live", true)):
		push_error("VS_SPECTATOR_RUNTIME_SMOKE: delay/live metadata mismatch %s" % str(snapshot))
		quit(1)
		return
	if int(snapshot.get("snapshot_count", 0)) != 1:
		push_error("VS_SPECTATOR_RUNTIME_SMOKE: debug snapshot did not count visual snapshot %s" % str(snapshot))
		quit(1)
		return
	if snapshot.has("local_seat") or snapshot.has("remote_seat") or snapshot.has("ready"):
		push_error("VS_SPECTATOR_RUNTIME_SMOKE: snapshot includes player runtime fields %s" % str(snapshot))
		quit(1)
		return
	var leave_result: Dictionary = runtime.call("leave") as Dictionary
	if not bool(leave_result.get("ok", false)):
		push_error("VS_SPECTATOR_RUNTIME_SMOKE: leave failed %s" % str(leave_result))
		quit(1)
		return
	snapshot = runtime.call("get_debug_snapshot") as Dictionary
	if bool(snapshot.get("active", true)):
		push_error("VS_SPECTATOR_RUNTIME_SMOKE: runtime still active after leave %s" % str(snapshot))
		quit(1)
		return
	print("VS_SPECTATOR_RUNTIME_SMOKE: PASS")
	quit(0)
