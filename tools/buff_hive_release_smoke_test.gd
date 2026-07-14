extends SceneTree

class FakeHiveArena:
	extends Node
	var selected_to_return: int = 11
	var submit_call_count: int = 0
	var accepted_count: int = 0
	var consumption_count: int = 0
	var resolver_call_count: int = 0
	var conversion_call_count: int = 0
	var clear_call_count: int = 0
	var canonical_accept: bool = true
	var last_submission: Dictionary = {}

	func get_buff_activation_source_snapshot(pid: int, slot_index: int) -> Dictionary:
		return {
			"ok": true,
			"owner_id": pid,
			"slot_index": slot_index,
			"inventory_revision": "revision-hive",
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
		return {"ok": true, "target_type": "hive", "eligible_target_ids": [11, 12]}

	func update_buff_hive_targeting(
		pointer_session_id: int,
		_preview: Dictionary,
		_selected_hive_id: int,
		root_screen_pos: Vector2
	) -> Dictionary:
		return {
			"ok": true,
			"pointer_session_id": pointer_session_id,
			"selected_hive_id": selected_to_return if root_screen_pos.x >= 0.0 else -1,
			"inside_arena": root_screen_pos.x >= 0.0
		}

	func clear_buff_hive_targeting(_pointer_session_id: int, _reason: String) -> bool:
		clear_call_count += 1
		return true

	func root_screen_to_buff_arena_local(root_screen_pos: Vector2) -> Dictionary:
		conversion_call_count += 1
		return {"ok": true, "arena_local_pos": root_screen_pos}

	func resolve_buff_release_candidate(_pid: int, _slot_index: int, _arena_local_pos: Vector2) -> Dictionary:
		resolver_call_count += 1
		return {"ok": true, "target_type": "hive", "target_id": 999}

	func submit_buff_activation(pid: int, slot_index: int, target_type: String, target_id: Variant) -> Dictionary:
		submit_call_count += 1
		last_submission = {
			"pid": pid,
			"slot_index": slot_index,
			"target_type": target_type,
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
	var ShellScript: Script = load("res://scripts/shell.gd") as Script
	var shell: Node = ShellScript.new()
	var fake_arena := FakeHiveArena.new()
	fake_arena.name = "Arena"
	var arena_instance := _arena_instance_with(fake_arena)
	shell.set("_arena_instance", arena_instance)
	shell.set("_buff_ui_last_active_pid", 1)
	var overlay_parent := Control.new()
	var overlay := TextureRect.new()
	overlay.size = Vector2(64.0, 64.0)
	overlay_parent.add_child(overlay)
	shell.set("_buff_drag_overlay", overlay)

	# Hysteresis-selected ID, not a release-time geometry re-pick, is submitted once.
	shell.call("_on_player_buff_press_captured", 0, "buff_swarm_damage_classic", "touch", 1, Vector2.ZERO)
	var session: Dictionary = shell.call("get_buff_pointer_session_snapshot") as Dictionary
	var session_id: int = int(session.get("pointer_session_id", 0))
	shell.call("_on_player_buff_pointer_moved", "touch", 1, session_id, Vector2(30.0, 0.0))
	fake_arena.selected_to_return = 12
	shell.call("_on_player_buff_pointer_released", "touch", 1, session_id, Vector2(30.0, 0.0))
	_expect(fake_arena.submit_call_count == 1 and fake_arena.accepted_count == 1, "valid hive release should submit exactly once")
	_expect(fake_arena.last_submission.get("target_id") == 12, "release should submit the presentation-selected stable hive ID")
	_expect(fake_arena.resolver_call_count == 0, "hive release must not perform a conflicting one-shot geometry re-pick")
	_expect(fake_arena.conversion_call_count == 0, "hive release conversion should remain inside the presentation controller seam")
	shell.call("_on_player_buff_pointer_released", "touch", 1, session_id, Vector2(30.0, 0.0))
	_expect(fake_arena.submit_call_count == 1, "duplicate hive release must not submit twice")

	# No visible selection at release uses the existing invalid-release behavior.
	fake_arena.selected_to_return = 11
	shell.call("_on_player_buff_press_captured", 0, "buff_swarm_damage_classic", "touch", 2, Vector2.ZERO)
	session = shell.call("get_buff_pointer_session_snapshot") as Dictionary
	session_id = int(session.get("pointer_session_id", 0))
	shell.call("_on_player_buff_pointer_moved", "touch", 2, session_id, Vector2(30.0, 0.0))
	shell.call("_on_player_buff_pointer_released", "touch", 2, session_id, Vector2(-1.0, 0.0))
	_expect(fake_arena.submit_call_count == 1, "release with no visibly selected hive should submit nothing")
	_expect((shell.call("get_buff_pointer_session_snapshot") as Dictionary).is_empty(), "invalid hive release should clear the pointer session")

	# Loop 0 may reject the cached stable ID without consumption.
	fake_arena.canonical_accept = false
	fake_arena.selected_to_return = 11
	shell.call("_on_player_buff_press_captured", 0, "buff_swarm_damage_classic", "touch", 3, Vector2.ZERO)
	session = shell.call("get_buff_pointer_session_snapshot") as Dictionary
	session_id = int(session.get("pointer_session_id", 0))
	shell.call("_on_player_buff_pointer_moved", "touch", 3, session_id, Vector2(30.0, 0.0))
	shell.call("_on_player_buff_pointer_released", "touch", 3, session_id, Vector2(30.0, 0.0))
	_expect(fake_arena.submit_call_count == 2 and fake_arena.accepted_count == 1, "canonical stale target should be rejected at the existing submission boundary")
	_expect(fake_arena.consumption_count == 0, "canonical rejection must not consume the buff")
	_expect(fake_arena.clear_call_count >= 3, "submission and invalid exits should clear presentation idempotently")
	_expect((shell.call("get_buff_pointer_session_snapshot") as Dictionary).is_empty(), "canonical rejection should clear presentation session")

	var shell_source: String = FileAccess.get_file_as_string("res://scripts/shell.gd")
	_expect(shell_source.contains("const MATCH_BUFF_TARGETING_ENABLED: bool = false"), "production gate must remain false")
	_expect(not fake_arena.last_submission.has("screen_pos") and not fake_arena.last_submission.has("pointer_session_id"), "presentation fields must not enter submission")

	arena_instance.free()
	shell.free()
	overlay_parent.free()
	if not _failed:
		print("BUFF_HIVE_RELEASE_SMOKE: PASS")
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
	push_error("BUFF_HIVE_RELEASE_SMOKE: %s" % message)
