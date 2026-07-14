extends SceneTree

class FakeLaneGlobalArena:
	extends Node
	var target_type: String = "lane"
	var selected_lane_id: int = 71
	var submit_call_count: int = 0
	var accepted_count: int = 0
	var clear_call_count: int = 0
	var resolver_call_count: int = 0
	var conversion_call_count: int = 0
	var canonical_accept: bool = true
	var last_submission: Dictionary = {}

	func get_buff_activation_source_snapshot(pid: int, slot_index: int) -> Dictionary:
		var buff_id: String = "buff_lane_freeze_classic" if target_type == "lane" else "buff_unit_speed_classic"
		return {
			"ok": true,
			"owner_id": pid,
			"slot_index": slot_index,
			"inventory_revision": "revision-lane-global",
			"slot": {
				"id": buff_id,
				"inventory_id": buff_id,
				"tier": "classic",
				"active": false,
				"consumed": false,
				"uses_remaining": 1,
				"uses_total": 1
			},
			"source_kind": "vs",
			"source_use_ordinal": 1,
			"charge_key": "inventory:1:%s" % buff_id,
			"quantity": 1
		}

	func preview_buff_targets(_pid: int, _slot_index: int) -> Dictionary:
		return {
			"ok": true,
			"target_type": target_type,
			"eligible_target_ids": [71, 72] if target_type == "lane" else ["global"]
		}

	func update_buff_lane_global_targeting(
		pointer_session_id: int,
		_preview: Dictionary,
		_selected_target_type: String,
		_selected_target_id: Variant,
		root_screen_pos: Vector2
	) -> Dictionary:
		if target_type == "lane":
			return {
				"ok": true,
				"pointer_session_id": pointer_session_id,
				"selected_lane_id": selected_lane_id if root_screen_pos.x >= 0.0 else -1,
				"global_valid": false
			}
		return {
			"ok": true,
			"pointer_session_id": pointer_session_id,
			"selected_lane_id": -1,
			"global_valid": root_screen_pos.x >= 0.0
		}

	func clear_buff_lane_global_targeting(_pointer_session_id: int, _reason: String) -> bool:
		clear_call_count += 1
		return true

	func clear_buff_hive_targeting(_pointer_session_id: int, _reason: String) -> bool:
		return true

	func root_screen_to_buff_arena_local(root_screen_pos: Vector2) -> Dictionary:
		conversion_call_count += 1
		return {"ok": true, "arena_local_pos": root_screen_pos}

	func resolve_buff_release_candidate(_pid: int, _slot_index: int, _arena_local_pos: Vector2) -> Dictionary:
		resolver_call_count += 1
		return {"ok": true, "target_type": target_type, "target_id": 999}

	func submit_buff_activation(pid: int, slot_index: int, submitted_type: String, target_id: Variant) -> Dictionary:
		submit_call_count += 1
		last_submission = {
			"pid": pid,
			"slot_index": slot_index,
			"target_type": submitted_type,
			"target_id": target_id
		}
		if not canonical_accept:
			return {"ok": false, "status": "rejected", "reason": "canonical_target_stale"}
		accepted_count += 1
		return {"ok": true, "status": "submitted"}


var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var shell_script: Script = load("res://scripts/shell.gd") as Script
	var shell: Node = shell_script.new()
	var fake_arena := FakeLaneGlobalArena.new()
	fake_arena.name = "Arena"
	var arena_instance: Node = _arena_instance_with(fake_arena)
	shell.set("_arena_instance", arena_instance)
	shell.set("_buff_ui_last_active_pid", 1)
	var overlay_parent := Control.new()
	var overlay := TextureRect.new()
	overlay.size = Vector2(64.0, 64.0)
	overlay_parent.add_child(overlay)
	shell.set("_buff_drag_overlay", overlay)

	# Lane release submits the exact retained stable ID and performs no second pick.
	fake_arena.target_type = "lane"
	shell.call("_on_player_buff_press_captured", 0, "buff_lane_freeze_classic", "touch", 1, Vector2.ZERO)
	var session: Dictionary = shell.call("get_buff_pointer_session_snapshot") as Dictionary
	var session_id: int = int(session.get("pointer_session_id", 0))
	shell.call("_on_player_buff_pointer_moved", "touch", 1, session_id, Vector2(30, 0))
	fake_arena.selected_lane_id = 72
	shell.call("_on_player_buff_pointer_released", "touch", 1, session_id, Vector2(30, 0))
	_expect(fake_arena.submit_call_count == 1 and fake_arena.accepted_count == 1, "lane release should submit exactly once")
	_expect(fake_arena.last_submission.get("target_type") == "lane" and int(fake_arena.last_submission.get("target_id", -1)) == 72, "lane release should submit the visibly retained stable lane ID")
	_expect(fake_arena.resolver_call_count == 0 and fake_arena.conversion_call_count == 0, "lane release must not perform a second conversion or geometric pick")
	shell.call("_on_player_buff_pointer_released", "touch", 1, session_id, Vector2(30, 0))
	_expect(fake_arena.submit_call_count == 1, "duplicate lane release must not submit twice")

	# No visible lane uses the invalid-release path.
	shell.call("_on_player_buff_press_captured", 0, "buff_lane_freeze_classic", "touch", 2, Vector2.ZERO)
	session = shell.call("get_buff_pointer_session_snapshot") as Dictionary
	session_id = int(session.get("pointer_session_id", 0))
	shell.call("_on_player_buff_pointer_moved", "touch", 2, session_id, Vector2(30, 0))
	shell.call("_on_player_buff_pointer_released", "touch", 2, session_id, Vector2(-1, 0))
	_expect(fake_arena.submit_call_count == 1, "release with no visible lane should submit nothing")

	# Global uses the explicit token once; invalid HUD/playfield presentation submits nothing.
	fake_arena.target_type = "global"
	shell.call("_on_player_buff_press_captured", 0, "buff_unit_speed_classic", "touch", 3, Vector2.ZERO)
	session = shell.call("get_buff_pointer_session_snapshot") as Dictionary
	session_id = int(session.get("pointer_session_id", 0))
	shell.call("_on_player_buff_pointer_moved", "touch", 3, session_id, Vector2(30, 30))
	shell.call("_on_player_buff_pointer_released", "touch", 3, session_id, Vector2(30, 30))
	_expect(fake_arena.submit_call_count == 2 and fake_arena.accepted_count == 2, "valid global release should submit exactly once")
	_expect(fake_arena.last_submission.get("target_type") == "global" and fake_arena.last_submission.get("target_id") == "global", "global release should submit only the explicit global token")
	_expect(not fake_arena.last_submission.has("screen_pos") and not fake_arena.last_submission.has("world_pos"), "global submission must contain no release coordinate")

	shell.call("_on_player_buff_press_captured", 0, "buff_unit_speed_classic", "touch", 4, Vector2.ZERO)
	session = shell.call("get_buff_pointer_session_snapshot") as Dictionary
	session_id = int(session.get("pointer_session_id", 0))
	shell.call("_on_player_buff_pointer_moved", "touch", 4, session_id, Vector2(30, 30))
	shell.call("_on_player_buff_pointer_released", "touch", 4, session_id, Vector2(-1, 30))
	_expect(fake_arena.submit_call_count == 2, "invalid global region should submit nothing")

	# Canonical stale-lane validation still rejects without presentation-side consumption.
	fake_arena.target_type = "lane"
	fake_arena.canonical_accept = false
	fake_arena.selected_lane_id = 71
	shell.call("_on_player_buff_press_captured", 0, "buff_lane_freeze_classic", "touch", 5, Vector2.ZERO)
	session = shell.call("get_buff_pointer_session_snapshot") as Dictionary
	session_id = int(session.get("pointer_session_id", 0))
	shell.call("_on_player_buff_pointer_moved", "touch", 5, session_id, Vector2(30, 0))
	shell.call("_on_player_buff_pointer_released", "touch", 5, session_id, Vector2(30, 0))
	_expect(fake_arena.submit_call_count == 3 and fake_arena.accepted_count == 2, "canonical target staleness should reject at the frozen submission boundary")
	_expect((shell.call("get_buff_pointer_session_snapshot") as Dictionary).is_empty(), "rejected release should clear the pointer session")
	_expect(fake_arena.clear_call_count >= 5, "all release and cancellation exits should clear lane/global presentation")

	var shell_source: String = FileAccess.get_file_as_string("res://scripts/shell.gd")
	_expect(shell_source.contains("const MATCH_BUFF_TARGETING_ENABLED: bool = false"), "production gate must remain false")
	_expect(fake_arena.resolver_call_count == 0 and fake_arena.conversion_call_count == 0, "all lane/global releases must use retained presentation selection")

	arena_instance.free()
	shell.free()
	overlay_parent.free()
	if not _failed:
		print("BUFF_LANE_GLOBAL_RELEASE_SMOKE: PASS")
	quit(1 if _failed else 0)


func _arena_instance_with(arena: Node) -> Node:
	var instance := Node.new()
	var world_layer := Node.new()
	world_layer.name = "WorldCanvasLayer"
	instance.add_child(world_layer)
	var container := Node.new()
	container.name = "WorldViewportContainer"
	world_layer.add_child(container)
	var viewport := Node.new()
	viewport.name = "WorldViewport"
	container.add_child(viewport)
	viewport.add_child(arena)
	return instance


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_LANE_GLOBAL_RELEASE_SMOKE: %s" % message)
