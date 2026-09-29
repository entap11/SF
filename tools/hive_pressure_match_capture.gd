extends SceneTree
## Full Campaign scene and canonical simulation. Only player intents are scripted;
## this harness never assigns hive power, ownership, units or pressure samples.
const Catalog := preload("res://scripts/state/campaign_catalog.gd")
var output: String
var events: Array[Dictionary] = []
var captured := 0
var first_pressure_ms := -1
var interaction_events: Array[Dictionary] = []
var interaction_serials: Dictionary = {}
var review_hive_id := -1

func _init() -> void:
	call_deferred("run")

func run() -> void:
	output = OS.get_environment("SF_PRESSURE_MATCH_OUTPUT")
	if output.is_empty() or not OS.get_user_data_dir().contains("SwarmfrontPressureChecks-") or DisplayServer.get_name() == "headless":
		push_error("Run through tools/run_hive_pressure_checks.py --capture")
		quit(2)
		return
	root.size = Vector2i(720, 1565)
	root.content_scale_size = Vector2i(1080, 2348)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_title("Swarmfront — integrated pressure match")
	# Desktop window occlusion must not stall startup's frame-post-draw prewarm.
	# This capture is deliberately not a frame-time benchmark.
	process_frame.connect(force_capture_draw)
	var profile: Node = root.get_node("ProfileManager")
	profile.call("smoke_force_identity_state", "01900000-0000-7000-8000-000000000003", "ABC 125", "Pressure Review", true, true)
	profile.call("mark_onboarding_complete")
	profile.call("mark_tutorial_controls_completed")
	profile.call("mark_controls_hint_seen")
	var runtime: Node = root.get_node("CampaignRuntime")
	var level: Dictionary = Catalog.levels()[0]
	var launch: Dictionary = runtime.call("request_launch", str(level.id), "campaign")
	if not bool(launch.get("ok", false)):
		push_error("Pressure capture launch failed: " + str(launch))
		quit(1)
		return
	var ops: Node = root.get_node("OpsState")
	# Startup includes asynchronous resource work measured in wall time; fixed
	# presentation frames may advance much faster while the window is covered.
	var launch_deadline := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < launch_deadline:
		await process_frame
		if current_scene != null and current_scene.name == "Shell" and int(ops.get("match_phase")) == 1:
			break
	if int(ops.get("match_phase")) != 1:
		push_error("Pressure capture did not reach RUNNING; scene=%s phase=%s" % [str(current_scene), str(ops.get("match_phase"))])
		quit(1)
		return
	var arena: Node = current_scene.find_child("Arena", true, false)
	var renderer: Node = arena.find_child("HiveRenderer", true, false)
	var last_intent_ms := -2000
	var previous_pressure := 0
	var interaction_review := "--interaction-review" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	for frame in range(10800):
		await process_frame
		var elapsed := int(ops.get("match_elapsed_ms"))
		if elapsed - last_intent_ms >= 2000 and first_pressure_ms < 0:
			last_intent_ms = elapsed
			request_player_routes(ops)
		var snapshot: Dictionary = renderer.call("get_distress_debug_snapshot")
		var pressure := int(snapshot.get("pressure_count", 0))
		if pressure != previous_pressure:
			events.append({"sim_ms": elapsed, "pressure_count": pressure, "hives": snapshot.get("by_hive", {})})
			previous_pressure = pressure
		if pressure > 0 and first_pressure_ms < 0:
			first_pressure_ms = elapsed
			print("HIVE_PRESSURE_MATCH: pressure observed at ", elapsed)
			if interaction_review:
				for hive_id in snapshot.by_hive:
					if bool(snapshot.by_hive[hive_id].pressure_active):
						review_hive_id = int(hive_id)
						break
		if first_pressure_ms >= 0:
			if interaction_review:
				var api: Object = arena.get("api")
				if captured in [0, 130]:
					api.call("set_selected_hive_id", review_hive_id)
				elif captured == 100:
					api.call("clear_selection")
				elif captured == 190:
					api.call("set_selected_hive_id", 1)
				for hive_id in renderer.get_hive_ids():
					var hive: Node = renderer.get_hive_node_by_id(hive_id)
					var pose: Dictionary = hive.call("get_interaction_debug_snapshot")
					var serial: int = int(pose.get("capture_serial", 0))
					var key: Array = [serial, bool(pose.get("selected", false))]
					if interaction_serials.get(hive_id, []) != key:
						interaction_serials[hive_id] = key
						interaction_events.append({"frame": captured, "sim_ms": elapsed, "hive_id": hive_id,
							"owner_id": hive.owner_id, "power": hive.power, "pose": pose})
			RenderingServer.force_draw(false)
			var result := root.get_texture().get_image().save_png(output.path_join("frames/%04d.png" % captured))
			if result != OK:
				push_error("Pressure capture image failed: " + str(result))
				quit(1)
				return
			captured += 1
			if captured >= 240:
				break
		if int(ops.get("match_phase")) != 1 and first_pressure_ms < 0:
			break
	var evidence := {"engine": Engine.get_version_info(), "renderer": "gl_compatibility", "level": level,
		"frames": captured, "fps": 30,
		"viewport": [root.get_texture().get_width(), root.get_texture().get_height()],
		"requested_viewport": [720, 1565], "first_pressure_ms": first_pressure_ms,
		"events": events, "source": "Production Campaign, Arena, SimRunner and bot; scripted local-player lane intents",
		"interaction_review": interaction_review, "review_hive_id": review_hive_id, "interaction_events": interaction_events,
		"limits": "Desktop capture with fixed presentation delta and synchronous frame readback; not phone performance evidence"}
	var file := FileAccess.open(output.path_join("match-evidence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "  "))
	if captured != 240 or first_pressure_ms < 0:
		push_error("No complete pressure sequence captured: " + str(evidence))
		quit(1)
		return
	if interaction_review:
		var observed_capture := false
		var observed_selection := false
		for event in interaction_events:
			observed_capture = observed_capture or bool(event.pose.capture_active)
			observed_selection = observed_selection or bool(event.pose.selected)
		if not observed_capture or not observed_selection:
			push_error("Interaction review must observe actual capture and selection")
			quit(1)
			return
	print("HIVE_PRESSURE_MATCH_CAPTURE: PASS frames=", captured, " pressure_sim_ms=", first_pressure_ms)
	# Let the live scene leave the tree before the engine exits. Release the
	# simulation service bindings after evidence is written, including its
	# UnitSystem -> WinSystem -> GameState reference cycle.
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var runner: Node = arena.get("sim_runner")
	var units: UnitSystem = runner.get("unit_system")
	units.bind_state(null)
	units.win_system = null
	runtime.call("finish_session")
	ops.call("set_match_telemetry_collector", null)
	current_scene.queue_free()
	current_scene = null
	for i in range(20):
		await process_frame
	quit()

func force_capture_draw() -> void:
	RenderingServer.force_draw(false)

func request_player_routes(ops: Node) -> void:
	var state: GameState = ops.call("get_state")
	for hive in state.hives:
		if hive.owner_id != 1:
			continue
		var targets: Array = state.hives.duplicate()
		targets.sort_custom(func(a: HiveData, b: HiveData) -> bool:
			return hive.grid_pos.distance_squared_to(a.grid_pos) < hive.grid_pos.distance_squared_to(b.grid_pos))
		for target in targets:
			if target.owner_id == 1:
				continue
			var result: Dictionary = ops.call("apply_lane_intent", hive.id, target.id, "attack")
			if bool(result.get("ok", false)):
				break
