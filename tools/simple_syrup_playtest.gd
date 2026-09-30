extends SceneTree
## Offline session setup and optional player intents. Simulation owns all gameplay.
var capture := false
var variant := "start"
var structure := "tower"
var output := ""
var map_path := ""
var events: Array = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture": capture = true
		elif arg.begins_with("--variant="): variant = arg.trim_prefix("--variant=")
		elif arg.begins_with("--structure="): structure = arg.trim_prefix("--structure=")
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func run() -> void:
	if not OS.get_user_data_dir().contains("SwarmfrontMapReview-"):
		push_error("Use tools/run_simple_syrup_review.py for isolated offline play")
		quit(2)
		return
	if variant not in ["start", "center", "original"] or structure not in ["tower", "barracks"]:
		quit(2)
		return
	root.size = Vector2i(720, 1565)
	root.content_scale_size = Vector2i(1080, 2348)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_title("Simple Syrup — %s / %s" % [variant, structure])
	if capture: process_frame.connect(func(): RenderingServer.force_draw(false))
	var profile: Node = root.get_node("ProfileManager")
	profile.call("smoke_force_identity_state", "01900000-0000-7000-8000-000000000003", "ABC 125", "Map Review", true, true)
	profile.call("mark_onboarding_complete")
	profile.call("mark_tutorial_controls_completed")
	profile.call("mark_controls_hint_seen")
	root.get_node("CampaignRuntime").call("finish_session")
	map_path = "res://maps/simple_syrup/MAP_simple_syrup__TB__1p.json" if variant == "original" else "res://maps/_future/simple_syrup/MAP_simple_syrup__%s_%s__1p.json" % [variant.to_upper(), "T" if structure == "tower" else "B"]
	var setup := {
		"start_game": true, "vs_mode": "1V1", "practice": true,
		"vs_practice": true, "vs_ranked": false, "vs_economic": false,
		"economic": false, "vs_price_usd": 0, "vs_wager_cents": 0,
		"vs_paid_entry": false, "vs_free_roll": true, "vs_sync_start": true,
		"vs_sync_join_sec": 0, "vs_window_sec": 0, "vs_required_players": 2,
		"vs_open_slots": 0, "vs_stage_map_paths": [map_path],
		"vs_stage_current_index": 0, "vs_stage_round_results": [],
		"vs_handshake_session_id": "", "vs_handshake_role": "host",
		"vs_roster": [], "vs_cpu_style": "balancer", "vs_cpu_tier": "medium",
		"vs_assigned_players": ["You", "Balancer CPU"],
		"vs_local_profile": {"uid": profile.call("get_user_id"), "name": "You", "display_name": "You"},
		"vs_remote_profile": {"uid": "map_review_balancer", "name": "Balancer CPU", "display_name": "Balancer CPU", "is_cpu": true, "seat": 2, "style": "balancer", "tier": "medium"},
		"vs_match_randomizer": {"hit": false, "seed": 9292026}
	}
	for key in setup: set_meta(key, setup[key])
	if change_scene_to_file("res://scenes/Shell.tscn") != OK:
		quit(1)
		return
	if not capture: return
	DirAccess.make_dir_recursive_absolute(output)
	var ops: Node = root.get_node("OpsState")
	var deadline := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.name == "Shell" and int(ops.get("match_phase")) == 1: break
	if int(ops.get("match_phase")) != 1:
		push_error("Syrup review did not reach a running match")
		quit(1)
		return
	var state: GameState = ops.call("get_state")
	if not _check_controls(state):
		quit(1)
		return
	var initial := _board(state)
	await _capture("opening")
	var next_intent := 0
	var captured_mid := false
	deadline = Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline and int(ops.get("match_phase")) == 1:
		await process_frame
		var elapsed := int(ops.get("match_elapsed_ms"))
		if elapsed >= next_intent:
			next_intent = elapsed + 2500
			_request_routes(ops, state, elapsed)
		if elapsed >= 20000 and not captured_mid:
			await _capture("20s")
			captured_mid = true
		if elapsed >= 60000: break
	await _capture("later")
	if not _check_controls(state):
		quit(1)
		return
	var report := {"map_path": map_path, "variant": variant, "structure": structure,
		"initial": initial, "final": _board(state), "sim_ms": int(ops.get("match_elapsed_ms")), "intents": events,
		"note": "Desktop rendering at phone aspect, scripted local-player intents versus production Balancer CPU; not a human or device playtest."}
	var f := FileAccess.open(output.path_join("%s_%s.json" % [variant, structure]), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	if not captured_mid or events.is_empty():
		push_error("Capture requires 20s of actual simulation and accepted lane intents")
		quit(1)
		return
	print("SIMPLE_SYRUP_PLAYTEST: PASS ", variant, " ", structure, " sim_ms=", report.sim_ms)
	var arena: Node = current_scene.find_child("Arena", true, false)
	if arena != null:
		var runner: Node = arena.get("sim_runner")
		if runner != null:
			var units: UnitSystem = runner.get("unit_system")
			if units != null:
				units.bind_state(null)
				units.win_system = null
	ops.call("set_match_telemetry_collector", null)
	current_scene.queue_free()
	current_scene = null
	for i in range(20): await process_frame
	quit()

func _board(state: GameState) -> Dictionary:
	var hives: Array = []
	for hive in state.hives:
		hives.append({"id": hive.id, "owner": hive.owner_id, "power": hive.power, "pos": [hive.render_grid_pos.x, hive.render_grid_pos.y]})
	return {"hives": hives, "towers": state.towers.duplicate(true), "barracks": state.barracks.duplicate(true), "active_lanes": state.lanes.size()}

func _check_controls(state: GameState) -> bool:
	if variant == "original": return true
	var rows: Array = state.towers if structure == "tower" else state.barracks
	var opposite: Array = state.barracks if structure == "tower" else state.towers
	if rows.size() != 2 or not opposite.is_empty() or state.hives.size() != 7:
		push_error("Wrong candidate loaded into real match")
		return false
	for row in rows:
		var bottom: bool = row.grid_pos[1] > 13.5
		var expected: Array = ([1, 2, 3] if bottom else [5, 6, 7]) if variant == "start" else ([2, 3, 4] if bottom else [4, 5, 6])
		var actual: Array = row.control_hive_ids.duplicate()
		actual.sort()
		if actual != expected:
			push_error("Real match changed authored control triangle: %s != %s" % [actual, expected])
			return false
	return true

func _request_routes(ops: Node, state: GameState, elapsed: int) -> void:
	for hive in state.hives:
		if hive.owner_id != 1: continue
		var targets: Array = state.hives.duplicate()
		targets.sort_custom(func(a: HiveData, b: HiveData) -> bool:
			var da := hive.render_grid_pos.distance_squared_to(a.render_grid_pos)
			var db := hive.render_grid_pos.distance_squared_to(b.render_grid_pos)
			return a.id < b.id if is_equal_approx(da, db) else da < db)
		for target in targets:
			if target.owner_id == 1: continue
			var result: Dictionary = ops.call("apply_lane_intent", hive.id, target.id, "attack")
			if bool(result.get("ok", false)):
				events.append({"sim_ms": elapsed, "from": hive.id, "to": target.id})
				break

func _capture(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	var error := screenshot.save_png(output.path_join("%s_%s_%s.png" % [variant, structure, label]))
	if error != OK: push_error("Cannot save map review capture")
