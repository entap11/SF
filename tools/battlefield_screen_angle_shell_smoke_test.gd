extends SceneTree

var _failed: bool = false


class FakeStudyShell:
	extends Node
	var toggle_count: int = 0

	func get_battlefield_screen_angle_study_snapshot() -> Dictionary:
		return {
			"available": true,
			"armed": true,
			"arena_present": true,
			"screen_angle_deg": 4.0,
			"applied": true,
			"input_mapping": "SubViewport canvas transform inverse"
		}

	func set_battlefield_screen_angle_degrees(_value: float) -> Dictionary:
		return {"ok": true, "applied": true}

	func toggle_battlefield_screen_angle_ab() -> Dictionary:
		toggle_count += 1
		return {"ok": true, "applied": true}


func _initialize() -> void:
	# Exercise the real shell controller against a minimal live SubViewport camera.
	# Avoid booting simulation or mutating OpsState: this is strictly presentation proof.
	var shell_scene := load("res://scenes/Shell.tscn") as PackedScene
	if shell_scene == null:
		push_error("BATTLEFIELD_SCREEN_ANGLE_SHELL_SMOKE: failed to load Shell.tscn")
		quit(1)
		return
	# Instantiate without entering the tree so shell boot code and simulation remain idle.
	var shell: Node = shell_scene.instantiate()
	var arena_instance := Node.new()
	var world_layer := Node.new()
	world_layer.name = "WorldCanvasLayer"
	var container := SubViewportContainer.new()
	container.name = "WorldViewportContainer"
	container.size = Vector2(820.0, 1320.0)
	var subviewport := SubViewport.new()
	subviewport.name = "WorldViewport"
	subviewport.size = Vector2i(820, 1320)
	subviewport.disable_3d = true
	var arena := Node2D.new()
	arena.name = "Arena"
	var map_root := Node2D.new()
	map_root.name = "MapRoot"
	map_root.position = Vector2(41.0, -33.0)
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.position = Vector2(410.0, 660.0)
	camera.zoom = Vector2(1.17, 1.17)
	camera.ignore_rotation = true

	root.add_child(arena_instance)
	arena_instance.add_child(world_layer)
	world_layer.add_child(container)
	container.add_child(subviewport)
	subviewport.add_child(arena)
	arena.add_child(map_root)
	arena.add_child(camera)
	shell.set("_arena_instance", arena_instance)
	await process_frame
	camera.make_current()
	await process_frame

	_expect(shell.has_method("set_battlefield_screen_angle_degrees"), "shell angle setter must exist")
	_expect(shell.has_method("toggle_battlefield_screen_angle_ab"), "shell same-state A/B method must exist")
	var baseline_camera_rotation: float = camera.rotation
	var baseline_ignore_rotation: bool = camera.ignore_rotation
	var baseline_camera_position: Vector2 = camera.global_position
	var baseline_camera_zoom: Vector2 = camera.zoom
	var baseline_map_transform: Transform2D = map_root.global_transform

	var candidate: Dictionary = shell.call("set_battlefield_screen_angle_degrees", 4.0) as Dictionary
	_expect(bool(candidate.get("applied", false)), "+4° candidate must apply to the live camera")
	_expect(is_equal_approx(camera.rotation_degrees, -4.0), "+4° screen angle must use -4° camera roll")
	_expect(not camera.ignore_rotation, "candidate camera must honor roll")
	_expect(camera.global_position.is_equal_approx(baseline_camera_position), "camera roll must not change camera position")
	_expect(camera.zoom.is_equal_approx(baseline_camera_zoom), "camera roll must not change zoom")
	_expect(map_root.global_transform.is_equal_approx(baseline_map_transform), "camera roll must not change world coordinates")

	var candidate_snapshot: Dictionary = shell.call("get_battlefield_screen_angle_study_snapshot") as Dictionary
	_expect(str(candidate_snapshot.get("mode", "")) == "candidate", "snapshot must identify candidate mode")
	_expect(bool(candidate_snapshot.get("applied", false)), "candidate snapshot must report LIVE")
	_expect(not bool(candidate_snapshot.get("world_coordinates_changed", true)), "snapshot must report unchanged world coordinates")
	_expect(not bool(candidate_snapshot.get("gameplay_state_changed", true)), "snapshot must report unchanged gameplay state")
	_expect(str(candidate_snapshot.get("input_mapping", "")).find("canvas transform inverse") >= 0, "snapshot must identify inverse input mapping")

	var baseline: Dictionary = shell.call("toggle_battlefield_screen_angle_ab") as Dictionary
	_expect(bool(baseline.get("applied", false)), "A/B must restore baseline")
	_expect(is_equal_approx(camera.rotation, baseline_camera_rotation), "baseline must restore original camera rotation")
	_expect(camera.ignore_rotation == baseline_ignore_rotation, "baseline must restore original ignore_rotation")
	_expect(map_root.global_transform.is_equal_approx(baseline_map_transform), "A/B baseline must preserve world coordinates")

	arena_instance.queue_free()
	shell.free()
	await process_frame
	await _test_shell_study_panel()
	await _test_shell_menu_entry()
	if not _failed:
		print("BATTLEFIELD_SCREEN_ANGLE_SHELL_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_shell_study_panel() -> void:
	var fake_shell := FakeStudyShell.new()
	fake_shell.name = "Shell"
	root.add_child(fake_shell)
	var hud_root := Control.new()
	hud_root.name = "HUDRoot"
	hud_root.size = Vector2(1080.0, 1920.0)
	fake_shell.add_child(hud_root)
	var overlay_script := load("res://scripts/ui/pvp_debug_overlay.gd") as Script
	_expect(overlay_script != null, "debug/telemetry overlay script must load")
	if overlay_script == null:
		fake_shell.queue_free()
		await process_frame
		return
	var overlay: Control = overlay_script.new() as Control
	hud_root.add_child(overlay)
	await process_frame
	overlay.call("_refresh_visibility")
	var panel: Control = overlay.get_node_or_null("BattlefieldScreenAngleStudy") as Control
	_expect(panel != null, "debug/telemetry overlay must contain the angle study panel")
	_expect(panel != null and panel.visible, "study panel must be visible for a live debug Arena")
	var ab_button: Button = panel.find_child("SameStateAB", true, false) as Button if panel != null else null
	_expect(ab_button != null, "study panel must expose same-state A/B")
	if ab_button != null:
		ab_button.pressed.emit()
	_expect(fake_shell.toggle_count == 1, "A/B button must route through the shell controller")
	fake_shell.queue_free()
	await process_frame


func _test_shell_menu_entry() -> void:
	var shell_scene := load("res://scenes/Shell.tscn") as PackedScene
	_expect(shell_scene != null, "Shell scene must load for menu-entry proof")
	if shell_scene == null:
		return
	var shell: Node = shell_scene.instantiate()
	root.add_child(shell)
	await process_frame
	await process_frame
	var button: Button = shell.get_node_or_null("MenuRoot/MenuPanel/VBox/ButtonsRow/ScreenAngleStudyButton") as Button
	_expect(button != null, "ANGLE A/B TEST must occupy the shell grid slot under Mode")
	_expect(button != null and button.visible, "ANGLE A/B TEST must be visible in debug")
	_expect(button != null and button.text == "ANGLE A/B TEST", "shell entry must have a discoverable label")
	if button != null:
		button.pressed.emit()
	await process_frame
	var picker: Control = shell.get_node_or_null("MenuRoot/MenuPanel/MapPickerPanel") as Control
	_expect(picker != null and picker.visible, "ANGLE A/B TEST must open map selection")
	var snapshot: Dictionary = shell.call("get_battlefield_screen_angle_study_snapshot") as Dictionary
	_expect(bool(snapshot.get("armed", false)), "shell menu entry must arm the live study")
	shell.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BATTLEFIELD_SCREEN_ANGLE_SHELL_SMOKE: %s" % message)
