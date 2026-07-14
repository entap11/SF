extends SceneTree

const HiveTargetingScript := preload("res://scripts/renderers/buff_hive_targeting_controller.gd")
const LaneTargetingScript := preload("res://scripts/renderers/buff_lane_global_targeting_controller.gd")
const FeedbackScript := preload("res://scripts/renderers/buff_canonical_feedback_controller.gd")
const HiveNodeScene := preload("res://scenes/hive/HiveNode.tscn")
const Config := preload("res://scripts/renderers/buff_targeting_presentation_config.gd")
const TeamVisuals := preload("res://scripts/renderers/team_visuals.gd")

class ProductionPresentationBridge:
	extends Node2D
	signal buff_canonical_outcome_recorded(outcome: Dictionary, presentation_epoch: String)
	var map_root: Node2D = null
	var lane_targeting: Node = null
	var viewport_size: Vector2 = Vector2(960, 640)

	func root_screen_to_buff_arena_local(root_screen_pos: Vector2) -> Dictionary:
		if not Rect2(Vector2.ZERO, viewport_size).has_point(root_screen_pos):
			return {"ok": false, "reason": "outside_world_viewport"}
		return {"ok": true, "arena_local_pos": map_root.to_local(root_screen_pos)}

	func buff_arena_local_to_root_screen(arena_local_pos: Vector2) -> Dictionary:
		return {"ok": true, "root_screen_pos": map_root.to_global(arena_local_pos)}

	func buff_arena_local_to_world(arena_local_pos: Vector2) -> Vector2:
		return map_root.to_global(arena_local_pos)

	func get_buff_targeting_transform_signature() -> String:
		return str(map_root.global_transform)

	func get_buff_global_presentation_boundary() -> Dictionary:
		return {
			"valid": true,
			"boundary_arena_local_points": PackedVector2Array([
				Vector2(20, 20), Vector2(820, 20), Vector2(820, 500), Vector2(20, 500)
			])
		}

	func get_buff_global_targeting_query(root_screen_pos: Vector2) -> Dictionary:
		var playfield := Rect2(Vector2(20, 20), Vector2(900, 500))
		var result: Dictionary = get_buff_global_presentation_boundary()
		result["valid"] = playfield.has_point(root_screen_pos)
		return result

	func notify_buff_lane_render_nodes_changed() -> void:
		if lane_targeting != null:
			lane_targeting.call("notify_render_nodes_changed")

	func get_buff_presentation_owner_color(owner_id: int) -> Color:
		return TeamVisuals.owner_color(owner_id)


class FingerSilhouette:
	extends Node2D
	func _ready() -> void:
		z_as_relative = false
		z_index = 80
		queue_redraw()
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 49.0, Color(0.035, 0.045, 0.065, 0.86))
		draw_arc(Vector2.ZERO, 49.0, 0.0, TAU, 72, Color(0.88, 0.91, 0.98, 0.62), 2.0, true)


class ArenaBackdrop:
	extends Node2D
	func _ready() -> void:
		z_index = -100
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(960, 640)), Color(0.025, 0.042, 0.062, 1.0))
		for x in range(0, 961, 64):
			draw_line(Vector2(x, 0), Vector2(x, 640), Color(0.18, 0.23, 0.30, 0.12), 1.0)
		for y in range(0, 641, 64):
			draw_line(Vector2(0, y), Vector2(960, y), Color(0.18, 0.23, 0.30, 0.12), 1.0)


var _output_dir: String = "res://artifacts/buff_targeting_loop4"
var _capture_size := Vector2i(960, 640)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(_capture_size)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
	var root_node := Node2D.new()
	root_node.name = "Loop4ProductionPresentationEvidence"
	get_root().add_child(root_node)
	root_node.add_child(ArenaBackdrop.new())

	var arena := ProductionPresentationBridge.new()
	root_node.add_child(arena)
	var map_root := Node2D.new()
	map_root.name = "MapRoot"
	map_root.position = Vector2(65, 45)
	root_node.add_child(map_root)
	arena.map_root = map_root

	var hive_renderer_script: Script = load("res://scripts/renderers/hive_renderer.gd") as Script
	var hive_renderer: Node2D = hive_renderer_script.new()
	hive_renderer.name = "HiveRenderer"
	map_root.add_child(hive_renderer)
	var lane_renderer_script: Script = load("res://scripts/renderers/lane_renderer.gd") as Script
	var lane_renderer: Node2D = lane_renderer_script.new()
	lane_renderer.name = "LaneRenderer"
	map_root.add_child(lane_renderer)
	lane_renderer.call("setup", null, null, arena)

	var hive_targeting: Node2D = HiveTargetingScript.new()
	hive_targeting.name = "BuffHiveTargetPresentation"
	map_root.add_child(hive_targeting)
	hive_targeting.call("setup", arena, hive_renderer)
	var lane_targeting: Node2D = LaneTargetingScript.new()
	lane_targeting.name = "BuffLaneGlobalTargetPresentation"
	map_root.add_child(lane_targeting)
	lane_targeting.call("setup", arena, lane_renderer)
	arena.lane_targeting = lane_targeting
	var feedback: Node2D = FeedbackScript.new()
	feedback.name = "BuffCanonicalFeedbackPresentation"
	map_root.add_child(feedback)
	feedback.call("setup", arena, hive_renderer, lane_renderer, "loop4-epoch")
	arena.buff_canonical_outcome_recorded.connect(Callable(feedback, "handle_canonical_outcome"))

	var hive_specs: Array[Dictionary] = [
		{"id": 1, "owner": 1, "power": 14, "pos": Vector2(130, 145)},
		{"id": 2, "owner": 1, "power": 36, "pos": Vector2(400, 155)},
		{"id": 3, "owner": 1, "power": 58, "pos": Vector2(675, 140)},
		{"id": 4, "owner": 3, "power": 28, "pos": Vector2(170, 400)},
		{"id": 5, "owner": 4, "power": 45, "pos": Vector2(650, 405)}
	]
	var hive_nodes: Dictionary = {}
	for spec: Dictionary in hive_specs:
		var hive: Node2D = HiveNodeScene.instantiate()
		var hive_id: int = int(spec.get("id", 0))
		hive.name = "HiveNode_%d" % hive_id
		hive.position = spec.get("pos", Vector2.ZERO) as Vector2
		hive.set("hive_id", hive_id)
		hive_renderer.add_child(hive)
		(hive_renderer.get("hive_nodes_by_id") as Dictionary)[hive_id] = hive
		hive_nodes[hive_id] = hive
	await process_frame
	for spec: Dictionary in hive_specs:
		var hive_id: int = int(spec.get("id", 0))
		(hive_nodes[hive_id] as Node).call(
			"apply_render", int(spec.get("owner", 0)), int(spec.get("power", 0)), 29.0,
			TeamVisuals.owner_color(int(spec.get("owner", 0))), 14, "Hive", 1, 3
		)

	lane_renderer.call("set_hive_nodes", hive_nodes)
	lane_renderer.call("set_model", {
		"map_id": "loop4_visual_production_fixture",
		"cell_size": 64,
		"sim_running": true,
		"sim_time_s": 4.0,
		"hives": [
			{"id": 1, "owner_id": 1}, {"id": 2, "owner_id": 1}, {"id": 3, "owner_id": 1},
			{"id": 4, "owner_id": 3}, {"id": 5, "owner_id": 4}
		],
		"lanes": [
			{"lane_id": 9, "a_id": 1, "b_id": 3, "send_a": true, "send_b": false},
			{"lane_id": 10, "a_id": 4, "b_id": 5, "send_a": false, "send_b": true},
			{"lane_id": 11, "a_id": 2, "b_id": 5, "send_a": true, "send_b": false}
		]
	})
	for _i in range(12):
		await process_frame

	# Drag icon is offset, while acquisition remains at the unshifted fingertip.
	var fingertip: Vector2 = map_root.to_global(Vector2(400, 155))
	var finger := FingerSilhouette.new()
	finger.position = fingertip
	root_node.add_child(finger)
	var drag_icon := TextureRect.new()
	drag_icon.name = "ProductionBuffDragOverlay"
	drag_icon.texture = load("res://assets/sprites/sf_skin_v1/buffs/hive_global_production_classic.png") as Texture2D
	drag_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_icon.size = Config.DRAG_OVERLAY_SIZE_UI_PX
	drag_icon.position = fingertip + Config.TOUCH_OVERLAY_OFFSET_ROOT_SCREEN_PX - drag_icon.size * 0.5
	drag_icon.z_index = 90
	root_node.add_child(drag_icon)
	hive_targeting.call("begin_or_update", 7001, [1, 2, 3, 4, 5], -1, fingertip)
	hive_targeting.call("set_phase_override", 0.0)
	await _wait_seconds(0.16)
	await _capture("tuned_yellow_eligible_pulse_low.png")
	hive_targeting.call("set_phase_override", 1.0)
	await _wait_seconds(0.16)
	await _capture("tuned_preview_high_under_thumb.png")

	# Production lane targeting at two phases, including selected treatment beyond
	# the simulated thumb, then the same geometry under an alternate transform.
	hive_targeting.call("clear", 7001, true, "visual_lane_transition")
	fingertip = map_root.to_global(Vector2(400, 145))
	finger.position = fingertip
	drag_icon.texture = load("res://assets/sprites/sf_skin_v1/buffs/unit_lane_speed_classic.png") as Texture2D
	drag_icon.position = fingertip + Config.TOUCH_OVERLAY_OFFSET_ROOT_SCREEN_PX - drag_icon.size * 0.5
	var lane_preview := {"ok": true, "target_type": "lane", "eligible_target_ids": [9, 10, 11]}
	lane_targeting.call("begin_or_update", 7002, lane_preview, "", null, fingertip)
	lane_targeting.call("set_phase_override", 0.08)
	await _wait_seconds(0.12)
	await _capture("multiple_eligible_lanes_phase_008_phone.png")
	lane_targeting.call("set_phase_override", 0.58)
	await _wait_seconds(0.12)
	await _capture("selected_lane_under_thumb_phase_058_phone.png")
	map_root.scale = Vector2(0.86, 0.86)
	map_root.position = Vector2(145, 68)
	fingertip = map_root.to_global(Vector2(400, 145))
	finger.position = fingertip
	drag_icon.position = fingertip + Config.TOUCH_OVERLAY_OFFSET_ROOT_SCREEN_PX - drag_icon.size * 0.5
	lane_targeting.call("force_recompute", "loop4_alternate_aspect_zoom")
	await _wait_seconds(0.14)
	await _capture("selected_lane_alternate_aspect_zoom.png")
	map_root.scale = Vector2.ONE
	map_root.position = Vector2(65, 45)

	# Global uses only the whole-arena boundary and no individual target.
	fingertip = Vector2(760, 450)
	finger.position = fingertip
	drag_icon.texture = load("res://assets/sprites/sf_skin_v1/buffs/unit_global_speed_classic.png") as Texture2D
	drag_icon.position = fingertip + Config.TOUCH_OVERLAY_OFFSET_ROOT_SCREEN_PX - drag_icon.size * 0.5
	var global_preview := {"ok": true, "target_type": "global", "eligible_target_ids": ["global"]}
	lane_targeting.call("begin_or_update", 7003, global_preview, "", null, fingertip)
	lane_targeting.call("set_phase_override", 0.42)
	await _wait_seconds(0.12)
	await _capture("valid_global_boundary_no_individual_target.png")
	lane_targeting.call("clear", 7003, true, "visual_snapback_transition")

	# The recording shows the exact configured short trajectory with the source
	# icon held fixed, matching Shell's generation-bound production tween.
	var source_icon := TextureRect.new()
	source_icon.name = "StationarySourceStripIcon"
	source_icon.texture = drag_icon.texture
	source_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	source_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	source_icon.size = Config.DRAG_OVERLAY_SIZE_UI_PX
	source_icon.position = Vector2(82, 552)
	source_icon.z_index = 90
	root_node.add_child(source_icon)
	finger.visible = false
	drag_icon.position = Vector2(780, 505)
	await _capture("invalid_snapback_start_source_fixed.png")
	var snap_tween: Tween = root_node.create_tween()
	snap_tween.tween_property(
		drag_icon, "position", source_icon.position,
		Config.INVALID_RELEASE_SNAP_BACK_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait_seconds(Config.INVALID_RELEASE_SNAP_BACK_SECONDS * 0.45)
	await _capture("invalid_snapback_mid_source_fixed.png")
	await _wait_seconds(Config.INVALID_RELEASE_SNAP_BACK_SECONDS * 0.65 + 0.04)
	await _capture("invalid_snapback_complete.png")
	source_icon.visible = false
	drag_icon.visible = false

	# Success enters only through the canonical bridge and flashes the submitted hive.
	feedback.call("register_submission_receipt", "loop4-match", 1, "success-hive", "hive", 2, "loop4-epoch", Time.get_ticks_msec())
	arena.buff_canonical_outcome_recorded.emit({
		"match_id": "loop4-match", "owner_id": 1, "activation_id": "success-hive",
		"status": "executed", "reason": "activated", "target_type": "hive", "target_id": 2
	}, "loop4-epoch")
	await _wait_seconds(0.08)
	await _capture("canonical_success_hive_team_flash.png")
	await _wait_seconds(Config.SUCCESS_FLASH_DURATION_SECONDS + 0.08)

	# A canonical rejection traverses the same bridge and remains flash-free for
	# the complete success-flash window.
	feedback.call("register_submission_receipt", "loop4-match", 1, "rejected-lane", "lane", 9, "loop4-epoch", Time.get_ticks_msec())
	arena.buff_canonical_outcome_recorded.emit({
		"match_id": "loop4-match", "owner_id": 1, "activation_id": "rejected-lane",
		"status": "deterministic_no_op", "reason": "target_stale"
	}, "loop4-epoch")
	await _capture("canonical_rejection_no_flash_start.png")
	await _wait_seconds(Config.SUCCESS_FLASH_DURATION_SECONDS + 0.08)
	await _capture("canonical_rejection_no_flash_full_window.png")

	feedback.call("register_submission_receipt", "loop4-match", 1, "success-lane", "lane", 9, "loop4-epoch", Time.get_ticks_msec())
	arena.buff_canonical_outcome_recorded.emit({
		"match_id": "loop4-match", "owner_id": 1, "activation_id": "success-lane",
		"status": "executed", "reason": "activated", "target_type": "lane", "target_id": 9
	}, "loop4-epoch")
	await _wait_seconds(0.08)
	await _capture("canonical_success_lane_team_flash.png")
	await _wait_seconds(Config.SUCCESS_FLASH_DURATION_SECONDS + 0.12)

	feedback.call("register_submission_receipt", "loop4-match", 1, "success-global", "global", "global", "loop4-epoch", Time.get_ticks_msec())
	arena.buff_canonical_outcome_recorded.emit({
		"match_id": "loop4-match", "owner_id": 1, "activation_id": "success-global",
		"status": "executed", "reason": "activated", "target_type": "global", "target_id": "global"
	}, "loop4-epoch")
	await _wait_seconds(0.08)
	await _capture("canonical_success_global_team_flash.png")
	await _wait_seconds(Config.SUCCESS_FLASH_DURATION_SECONDS + 0.12)
	await _capture("cleanup_all_targeting_feedback_cleared.png")

	var snapshot: Dictionary = feedback.call("get_snapshot") as Dictionary
	print("BUFF_TARGETING_LOOP4_VISUAL: PASS latency_samples=%d latency_max_ms=%d active_flashes=%d" % [
		int(snapshot.get("latency_sample_count", 0)),
		int(snapshot.get("latency_max_msec", 0)),
		int(snapshot.get("active_flash_count", 0))
	])
	root_node.queue_free()
	quit(0)


func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _capture(filename: String) -> void:
	for _i in range(3):
		await process_frame
	var image: Image = get_root().get_texture().get_image()
	if image.get_width() >= _capture_size.x and image.get_height() >= _capture_size.y:
		image = image.get_region(Rect2i(0, 0, _capture_size.x, _capture_size.y))
	var path: String = ProjectSettings.globalize_path(_output_dir.path_join(filename))
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("BUFF_TARGETING_LOOP4_VISUAL: capture failed %s error=%d" % [path, error])
		quit(1)
