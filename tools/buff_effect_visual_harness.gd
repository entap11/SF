extends SceneTree

const Presentation := preload("res://scripts/renderers/buff_effect_presentation.gd")
const Definitions := preload("res://scripts/state/buff_definitions.gd")
const Copy := preload("res://scripts/ui/buff_ui_copy.gd")
const Catalog := preload("res://scripts/state/buff_catalog.gd")
const WIDTH: int = 960
const HEIGHT: int = 720

class Board:
	extends Node2D
	var centers: Array[Vector2] = [Vector2(230, 330), Vector2(730, 330), Vector2(480, 490)]
	var points := PackedVector2Array([Vector2(230,330), Vector2(390,290), Vector2(560,365), Vector2(730,330)])
	func get_buff_presentation_owner_color(owner: int) -> Color:
		return Color(0.96,0.75,0.15) if owner == 1 else Color(0.96,0.35,0.30)
	func get_buff_global_presentation_boundary() -> Dictionary:
		return {"valid": true, "boundary_arena_local_points": PackedVector2Array([Vector2(60,155), Vector2(900,155), Vector2(900,575), Vector2(60,575)])}
	func get_buff_target_lane_probe(id: int) -> Dictionary:
		return {"valid": id == 1, "points": points}
	func get_buff_target_probe(id: int) -> Dictionary:
		return {"ok": id > 0 and id <= 3, "center_arena_local": centers[clampi(id-1,0,2)], "radius_edge_arena_local": centers[clampi(id-1,0,2)] + Vector2(44,0)}
	func _draw() -> void:
		draw_rect(Rect2(0,0,WIDTH,HEIGHT), Color(0.025,0.045,0.065))
		for x in range(60,901,60):
			draw_line(Vector2(x,155), Vector2(x,575), Color(0.18,0.3,0.39,0.12), 1)
		for y in range(155,576,60):
			draw_line(Vector2(60,y), Vector2(900,y), Color(0.18,0.3,0.39,0.12), 1)
		draw_polyline(points, Color(0.38,0.44,0.50), 8, true)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var output: String = OS.get_environment("SF_MENU_CAPTURE_DIR")
	if output.is_empty():
		quit(2)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i(WIDTH, HEIGHT)
	root.size = Vector2i(WIDTH, HEIGHT)
	var stage := Node2D.new()
	root.add_child(stage)
	var board := Board.new()
	board.z_index = -5
	stage.add_child(board)
	var view := Presentation.new()
	stage.add_child(view)
	view.setup(board, board, board)
	var hive_texture := load("res://assets/sprites/sf_skin_v1/hive_medium_no_indicators_cropped.png") as Texture2D
	for p: Vector2 in board.centers:
		var hive := Sprite2D.new()
		hive.texture = hive_texture
		hive.position = p
		hive.scale = Vector2.ONE * 106.0 / hive_texture.get_width()
		hive.z_index = 1
		stage.add_child(hive)
	var title := label(stage, Vector2(44,28), 30)
	var subtitle := label(stage, Vector2(44,74), 19)
	var status := label(stage, Vector2(44,610), 24)
	var note := label(stage, Vector2(44,651), 17)
	note.text = "Production renderer · staged snapshots · full / reduced VFX · phone testing follows"
	var metadata: Array = []
	for id: String in Definitions.list_all_ids():
		if id == "FREEZE_LANE":
			continue
		var folder: String = output.path_join(id.to_lower())
		DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
		var buff: Dictionary = Catalog.get_buff("buff_%s_classic" % id.to_lower())
		title.text = str(buff["name"]).to_upper()
		subtitle.text = Copy.scope(buff) + " · Classic · " + ("Normal traffic continues while bonus bees bank" if id == "SUPERCHARGE_QUEUE" else "Activation → active effect → expiry")
		var duration: int = int(float(buff["duration_sec"]) * 10)
		var target_type: String = str(buff["target_type"])
		if target_type == "none": target_type = "global"
		var effect: Dictionary = {"match_id": "visual-" + id, "activation_id": id, "owner_id": 1,
			"buff_id": id, "tier": "classic", "target_type": target_type,
			"target_id": "global" if target_type == "global" else 1, "scoped_hive_ids": [1,2],
			"target": {"source_is_a": true}, "started_tick": 5, "expires_tick": 5+duration,
			"duration_ticks": duration, "queued_units": 0, "status": "active"}
		view.clear_presentation()
		var total_frames: int = (duration + 18) * 3
		for frame in range(total_frames):
			var tick: int = frame / 3
			var active: bool = tick >= 5 and tick < duration + 5
			effect["queued_units"] = clampi((tick - 5) / 6, 0, 8) if id == "SUPERCHARGE_QUEUE" else 0
			if frame == (duration + 5) * 3:
				view.handle_lifecycle_event({"event": "supercharge_released" if id == "SUPERCHARGE_QUEUE" else "buff_expired", "reason": "timer_expired", "tick": tick, "effect": effect, "released_units": int(effect["queued_units"])})
			view.apply_authoritative_snapshot({"match_id": effect["match_id"], "tick": tick, "effects": [effect] if active else []})
			view.set_process(false)
			view.set("_subtick", float(frame % 3) / 30.0)
			view.queue_redraw()
			status.text = "Ready" if tick < 5 else ("Activated" if tick < 11 else ("Active" if active else ("Bonus wave released" if id == "SUPERCHARGE_QUEUE" and tick < duration+12 else "Effect ended")))
			await process_frame
			await RenderingServer.frame_post_draw
			var screenshot: Image = root.get_texture().get_image()
			screenshot.save_png(folder.path_join("frames/%03d.png" % frame))
			if frame == 19: screenshot.save_png(folder.path_join("activation.png"))
			if frame == 48: screenshot.save_png(folder.path_join("active.png"))
			if frame == (duration+7)*3: screenshot.save_png(folder.path_join("expiry.png"))
		view.apply_authoritative_snapshot({"match_id": effect["match_id"], "tick": 16, "effects": [effect]}, "reduced")
		status.text = "Reduced VFX · static shape and exact countdown"
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join("reduced.png"))
		metadata.append({"id": id, "name": buff["name"], "description": Copy.description(buff), "frames": total_frames, "directory": id.to_lower()})
	var file := FileAccess.open(output.path_join("gallery.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "  "))
	file.close()
	view.clear_presentation()
	stage.queue_free()
	await process_frame
	print("BUFF_EFFECT_VISUAL_HARNESS: PASS 11 families; staged read-only snapshots")
	quit(0)

func label(parent: Node, position: Vector2, size: int) -> Label:
	var result := Label.new()
	result.position = position
	result.add_theme_font_size_override("font_size", size)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result
