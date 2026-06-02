extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var arena_scene: PackedScene = load("res://scenes/Arena.tscn") as PackedScene
	if arena_scene == null:
		_fail("Arena scene missing")
		return
	var arena: Node2D = arena_scene.instantiate() as Node2D
	if arena == null:
		_fail("Arena instantiate failed")
		return
	get_root().add_child(arena)
	await process_frame
	var state := GameState.new()
	state.hives = [
		HiveData.new(1, Vector2i(1, 1), 1, 10, "Hive", 18.0, Vector2(1.0, 1.0)),
		HiveData.new(2, Vector2i(12, 20), 2, 10, "Hive", 18.0, Vector2(12.0, 20.0))
	]
	arena.set("state", state)
	await process_frame
	var ops_state: Node = get_root().get_node_or_null("OpsState")
	if ops_state == null:
		_fail("OpsState missing")
		return
	ops_state.set("match_phase", ops_state.MatchPhase.PREMATCH)
	ops_state.set("match_roster", [{"seat": 1, "is_local": true, "active": true}])
	var cam: Camera2D = arena.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		_fail("Camera2D missing")
		return
	var expected_pos := Vector2(321.0, 654.0)
	var expected_zoom := Vector2(1.7, 1.7)
	cam.global_position = expected_pos
	cam.zoom = expected_zoom
	arena.call("_start_prematch_hive_focus_sequence")
	await process_frame
	await create_timer(0.45).timeout
	if cam.global_position.distance_to(expected_pos) > 0.01:
		_fail("prematch hive pulse moved camera: %s" % str(cam.global_position))
		return
	if (cam.zoom - expected_zoom).length() > 0.001:
		_fail("prematch hive pulse changed zoom: %s" % str(cam.zoom))
		return
	print("PREMATCH_HIVE_PULSE_CAMERA_STATIC_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("PREMATCH_HIVE_PULSE_CAMERA_STATIC_SMOKE: %s" % message)
	quit(1)
