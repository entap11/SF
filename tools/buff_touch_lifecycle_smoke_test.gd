extends SceneTree

class FakeArena:
	extends Node
	var submit_count: int = 0
	var source_revision: String = "revision-a"
	var source_available: bool = true
	var candidate_ok: bool = true
	var last_submission: Dictionary = {}
	var last_conversion_root: Vector2 = Vector2.INF

	func get_buff_activation_source_snapshot(pid: int, slot_index: int) -> Dictionary:
		if not source_available:
			return {"ok": false, "reason": "slot_missing"}
		return {
			"ok": true,
			"owner_id": pid,
			"slot_index": slot_index,
			"inventory_revision": source_revision,
			"slot": {
				"id": "buff_swarm_damage_classic",
				"inventory_id": "buff_swarm_damage_classic",
				"tier": "classic",
				"active": false,
				"consumed": false,
				"uses_remaining": 1,
				"uses_total": 1
			},
			"source_kind": "vs",
			"source_use_ordinal": 1,
			"charge_key": "inventory:1:buff_swarm_damage_classic",
			"quantity": 1
		}

	func preview_buff_targets(_pid: int, _slot_index: int) -> Dictionary:
		return {"ok": true, "target_type": "global", "eligible_target_ids": ["global"]}

	func update_buff_lane_global_targeting(
		pointer_session_id: int,
		_preview: Dictionary,
		_selected_target_type: String,
		_selected_target_id: Variant,
		root_screen_pos: Vector2
	) -> Dictionary:
		var conversion: Dictionary = root_screen_to_buff_arena_local(root_screen_pos)
		return {
			"ok": true,
			"pointer_session_id": pointer_session_id,
			"selected_lane_id": -1,
			"global_valid": candidate_ok and bool(conversion.get("ok", false))
		}

	func clear_buff_lane_global_targeting(_pointer_session_id: int, _reason: String) -> bool:
		return true

	func clear_buff_hive_targeting(_pointer_session_id: int, _reason: String) -> bool:
		return true

	func root_screen_to_buff_arena_local(root_screen_pos: Vector2) -> Dictionary:
		last_conversion_root = root_screen_pos
		return {"ok": true, "arena_local_pos": root_screen_pos}

	func resolve_buff_release_candidate(_pid: int, _slot_index: int, _arena_local_pos: Vector2) -> Dictionary:
		if not candidate_ok:
			return {"ok": false, "reason": "release_target_ineligible"}
		return {"ok": true, "target_type": "global", "target_id": "global"}

	func submit_buff_activation(pid: int, slot_index: int, target_type: String, target_id: Variant) -> Dictionary:
		submit_count += 1
		last_submission = {
			"pid": pid,
			"slot_index": slot_index,
			"target_type": target_type,
			"target_id": target_id
		}
		return {"ok": true, "status": "submitted"}


var _failed: bool = false


func _init() -> void:
	await process_frame
	var ShellScript: Script = load("res://scripts/shell.gd") as Script
	if ShellScript == null or not ShellScript.can_instantiate():
		push_error("BUFF_TOUCH_LIFECYCLE_SMOKE: Shell script failed to load")
		quit(1)
		return
	var shell: Node = ShellScript.new()
	var fake_arena := FakeArena.new()
	fake_arena.name = "Arena"
	var arena_instance := _arena_instance_with(fake_arena)
	shell.set("_arena_instance", arena_instance)
	shell.set("_buff_ui_last_active_pid", 1)
	var overlay_parent := Control.new()
	var test_overlay := TextureRect.new()
	test_overlay.size = Vector2(64.0, 64.0)
	overlay_parent.add_child(test_overlay)
	shell.set("_buff_drag_overlay", test_overlay)

	shell.call("_on_player_buff_press_captured", 0, "buff_swarm_damage_classic", "touch", 11, Vector2(100.0, 100.0))
	var captured: Dictionary = shell.call("get_buff_pointer_session_snapshot") as Dictionary
	var first_session_id: int = int(captured.get("pointer_session_id", 0))
	_expect(first_session_id > 0 and str(captured.get("state", "")) == "captured", "Shell should own captured session")
	_expect(bool(shell.call("should_suppress_buff_pointer_event", "touch", 11, "press")), "captured press should be suppressed at Arena boundary")
	_expect(not bool(shell.call("should_suppress_buff_pointer_event", "touch", 12, "move")), "foreign touch should remain available")

	shell.call("_on_player_buff_pointer_moved", "touch", 12, first_session_id, Vector2(300.0, 100.0))
	var after_foreign: Dictionary = shell.call("get_buff_pointer_session_snapshot") as Dictionary
	_expect((after_foreign.get("current_root_screen_pos", Vector2.ZERO) as Vector2) == Vector2(100.0, 100.0), "foreign touch must not move session")
	shell.call("_on_player_buff_pointer_moved", "touch", 11, first_session_id, Vector2(110.0, 100.0))
	_expect(str((shell.call("get_buff_pointer_session_snapshot") as Dictionary).get("state", "")) == "captured", "below slop should remain captured")
	shell.call("_on_player_buff_pointer_moved", "touch", 11, first_session_id, Vector2(119.0, 100.0))
	_expect(str((shell.call("get_buff_pointer_session_snapshot") as Dictionary).get("state", "")) == "dragging", "crossing slop should enter dragging")
	_expect(test_overlay.position.distance_to(Vector2(87.0, 12.0)) <= 0.01, "touch overlay should use the 56-logical-pixel presentation offset")
	shell.call("_on_player_buff_pointer_released", "touch", 11, first_session_id, Vector2(220.0, 140.0))
	_expect(fake_arena.submit_count == 1, "valid release should submit exactly once")
	_expect((shell.call("get_buff_pointer_session_snapshot") as Dictionary).is_empty(), "touch session should clear after submission")
	_expect(bool(shell.call("should_suppress_buff_pointer_event", "touch", 11, "release")), "release guard should outlive touch cleanup for current dispatch")
	shell.call("_on_player_buff_pointer_released", "touch", 11, first_session_id, Vector2(220.0, 140.0))
	_expect(fake_arena.submit_count == 1, "duplicate release must not submit twice")
	_expect(fake_arena.last_submission == {"pid": 1, "slot_index": 0, "target_type": "global", "target_id": "global"}, "submission boundary should contain stable target identity only")
	_expect(fake_arena.last_conversion_root == Vector2(220.0, 140.0), "target conversion must use the unshifted fingertip rather than overlay position")
	_expect(not fake_arena.last_submission.has("touch_id") and not fake_arena.last_submission.has("screen_pos") and not fake_arena.last_submission.has("pointer_session_id"), "transient pointer data must not enter submission")
	_expect(not bool(shell.call("cancel_buff_pointer_session", "background_after_submission")), "post-submission lifecycle cleanup must not touch canonical work")

	shell.call("_on_player_buff_press_captured", 0, "buff_swarm_damage_classic", "touch", 3, Vector2.ZERO)
	var pre_cancel: Dictionary = shell.call("get_buff_pointer_session_snapshot") as Dictionary
	var pre_cancel_id: int = int(pre_cancel.get("pointer_session_id", 0))
	shell.call("_on_player_buff_pointer_moved", "touch", 3, pre_cancel_id, Vector2(30.0, 0.0))
	shell.call("_on_buff_pointer_app_backgrounded", "smoke", 0, 0)
	_expect((shell.call("get_buff_pointer_session_snapshot") as Dictionary).is_empty(), "backgrounding before submission should cancel")
	_expect(fake_arena.submit_count == 1, "pre-submission cancellation must consume/submit nothing")
	_expect(not bool(shell.call("cancel_buff_pointer_session", "duplicate_cancel")), "cancellation should be idempotent")

	shell.call("_on_player_buff_press_captured", 0, "buff_swarm_damage_classic", "touch", 4, Vector2.ZERO)
	var changed: Dictionary = shell.call("get_buff_pointer_session_snapshot") as Dictionary
	var changed_id: int = int(changed.get("pointer_session_id", 0))
	shell.call("_on_player_buff_pointer_moved", "touch", 4, changed_id, Vector2(30.0, 0.0))
	fake_arena.source_revision = "revision-b"
	shell.call("_on_player_buff_pointer_released", "touch", 4, changed_id, Vector2(10.0, 10.0))
	_expect(fake_arena.submit_count == 1, "inventory revision change should cancel before submission")

	fake_arena.source_revision = "revision-b"
	fake_arena.candidate_ok = false
	shell.call("_on_player_buff_press_captured", 0, "buff_swarm_damage_classic", "mouse", 0, Vector2.ZERO)
	var mouse_session: Dictionary = shell.call("get_buff_pointer_session_snapshot") as Dictionary
	var mouse_session_id: int = int(mouse_session.get("pointer_session_id", 0))
	shell.call("_on_player_buff_pointer_moved", "mouse", 0, mouse_session_id, Vector2(30.0, 0.0))
	shell.call("_on_player_buff_pointer_released", "mouse", 0, mouse_session_id, Vector2(50.0, 20.0))
	_expect(fake_arena.submit_count == 1, "invalid mouse release should submit nothing through the shared contract")

	fake_arena.candidate_ok = true
	fake_arena.source_available = true
	shell.call("_on_player_buff_press_captured", 0, "buff_swarm_damage_classic", "touch", 15, Vector2.ZERO)
	var lost_source_session: Dictionary = shell.call("get_buff_pointer_session_snapshot") as Dictionary
	var lost_source_id: int = int(lost_source_session.get("pointer_session_id", 0))
	shell.call("_on_player_buff_pointer_moved", "touch", 15, lost_source_id, Vector2(30.0, 0.0))
	fake_arena.source_available = false
	shell.call("_on_player_buff_pointer_released", "touch", 15, lost_source_id, Vector2(50.0, 20.0))
	_expect(fake_arena.submit_count == 1, "source slot loss should cancel before submission")

	var shell_source: String = FileAccess.get_file_as_string("res://scripts/shell.gd")
	var arena_source: String = FileAccess.get_file_as_string("res://scripts/arena.gd")
	_expect(not shell_source.contains("call(\"request_buff_drop\""), "production Shell must not call legacy request_buff_drop")
	_expect(arena_source.contains("resolve_buff_release_candidate -> submit_buff_activation"), "legacy wrapper should explicitly delegate to stable-ID boundary")
	var slot_only_start: int = arena_source.find("func _try_activate_buff_slot")
	var slot_only_end: int = arena_source.find("func _reset_sim_state", slot_only_start)
	var slot_only_body: String = arena_source.substr(slot_only_start, slot_only_end - slot_only_start) if slot_only_start >= 0 and slot_only_end > slot_only_start else ""
	_expect(not slot_only_body.contains("submit_buff_activation"), "slot-only compatibility endpoint must not activate or consume")
	_expect(shell_source.contains("const MATCH_BUFF_TARGETING_ENABLED: bool = false"), "production gate must remain false")

	arena_instance.free()
	shell.free()
	overlay_parent.free()
	if not _failed:
		print("BUFF_TOUCH_LIFECYCLE_SMOKE: PASS")
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
	push_error("BUFF_TOUCH_LIFECYCLE_SMOKE: %s" % message)
