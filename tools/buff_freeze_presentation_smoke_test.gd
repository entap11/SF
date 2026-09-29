extends SceneTree

const Presentation := preload("res://scripts/renderers/buff_freeze_lane_presentation.gd")
const BuffSystem := preload("res://scripts/sim/authoritative_buff_system.gd")

class ProbeLane:
	extends Node2D
	var renderable: bool = true
	func get_buff_target_lane_probe(lane_id: int) -> Dictionary:
		return {"valid": renderable and lane_id == 1, "points": PackedVector2Array([Vector2(50, 50), Vector2(200, 80), Vector2(350, 40)])}

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var lane := ProbeLane.new()
	var view := Presentation.new()
	get_root().add_child(lane)
	get_root().add_child(view)
	view.setup(null, lane)
	var state := GameState.new()
	state.init_demo_map()
	state.rebuild_indexes()
	var activated: Dictionary = BuffSystem.activate(state, {"match_id": "freeze-visual", "activation_id": "freeze-one", "owner_id": 1,
		"buff_id": "buff_freeze_lane_classic", "tier": "classic", "target_type": "lane", "target_id": 1, "source_slot_index": 0})
	_expect(bool(activated.get("ok", false)), "fixture activates through authoritative system")
	var input: Dictionary = BuffSystem.snapshot(state)
	var before: String = JSON.stringify(input)
	view.apply_authoritative_snapshot(input)
	_expect(JSON.stringify(input) == before and JSON.stringify(BuffSystem.snapshot(state)) == before, "presentation never mutates its input or simulation")
	_expect(view.get_snapshot()["active_count"] == 1, "active freeze projects one effect")
	_expect(view.get_snapshot()["markers"][0]["remaining_ms"] == 5000, "Classic countdown starts at actual five seconds")
	var arena_script: Script = load("res://scripts/arena.gd") as Script
	var arena: Node = arena_script.new()
	var buff_state := BuffState.new()
	buff_state.configure_loadout([{"id": "buff_freeze_lane_classic", "tier": "classic"}])
	buff_state.apply_authoritative_projection(1, input, 1000)
	var hud: Dictionary = arena.call("_buff_ui_player_snapshot", 1, buff_state, 1000) as Dictionary
	_expect(hud["slots"][0]["duration_ms"] == 5000 and hud["slots"][0]["remaining_ms"] == 5000, "Arena forwards canonical effect duration to the HUD")
	arena.free()
	view._process(30.0)
	_expect(view.get_snapshot()["markers"][0]["remaining_ms"] == 5000, "wall time cannot expire frozen simulation time")
	state.tick = 25
	view.apply_authoritative_snapshot(BuffSystem.snapshot(state))
	_expect(view.get_snapshot()["markers"][0]["remaining_ms"] == 2500, "countdown follows authoritative tick")
	lane.renderable = false
	_expect(not view.get_snapshot()["markers"][0]["renderable"], "missing/hidden rendered lane suppresses geometry")
	lane.renderable = true
	state.tick = 50
	BuffSystem.tick(state)
	view.apply_authoritative_snapshot(BuffSystem.snapshot(state))
	_expect(view.get_snapshot()["active_count"] == 0 and view.get_snapshot()["thaw_count"] == 1, "canonical expiry starts cosmetic thaw with no active timer")
	state.tick = 56
	view.apply_authoritative_snapshot(BuffSystem.snapshot(state))
	_expect(view.get_snapshot()["thaw_count"] == 0 and not view.is_processing(), "thaw retires and idle renderer stops processing")
	view.apply_authoritative_snapshot(input)
	var loss := input.duplicate(true)
	loss["tick"] = 20
	loss["effects"] = []
	view.apply_authoritative_snapshot(loss)
	_expect(view.get_snapshot()["active_count"] == 0 and view.get_snapshot()["thaw_count"] == 0, "early target loss clears without expiry animation")
	view.apply_authoritative_snapshot(input, "reduced")
	var expiry := input.duplicate(true)
	expiry["tick"] = 50
	expiry["effects"] = []
	view.apply_authoritative_snapshot(expiry, "reduced")
	_expect(view.get_snapshot()["thaw_count"] == 0, "reduced-motion mode clears without animated shatter")
	view.apply_authoritative_snapshot(input)
	var other_match := input.duplicate(true)
	other_match["match_id"] = "new-match"
	view.apply_authoritative_snapshot(other_match)
	_expect(view.get_snapshot()["active_count"] == 0, "old-match effects do not cross the presentation epoch")
	var many := input.duplicate(true)
	var other_effect: Dictionary = (many["effects"][0] as Dictionary).duplicate(true)
	other_effect["activation_id"] = "freeze-two"
	other_effect["owner_id"] = 2
	many["effects"].append(other_effect)
	view.apply_authoritative_snapshot(many)
	_expect(view.get_snapshot()["active_count"] == 2, "two owners on the same lane retain distinct countdowns")
	for i in range(100):
		view.apply_authoritative_snapshot(many)
	_expect(view.get_child_count() == 0 and view.get_snapshot()["active_count"] == 2, "repeated snapshots do not grow nodes or effects")
	view.clear_presentation()
	_expect(not view.is_processing() and view.get_snapshot()["active_count"] == 0, "match teardown clears all presentation")
	lane.queue_free()
	view.queue_free()
	await process_frame
	if not _failed:
		print("BUFF_FREEZE_PRESENTATION_SMOKE: PASS")
	quit(1 if _failed else 0)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error("BUFF_FREEZE_PRESENTATION_SMOKE: " + message)
