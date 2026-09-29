extends SceneTree

const Catalog := preload("res://scripts/state/buff_catalog.gd")
const ROOT_PATH: String = "HUDCanvasLayer/HUDRoot/BufferBackdropLayer/BufferRoot/BottomBufferBackground/"

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var output: String = OS.get_environment("SF_MENU_CAPTURE_DIR")
	if output.is_empty():
		quit(2)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i(1080, 1000)
	root.size = Vector2i(1080, 1000)
	var background := ColorRect.new()
	background.color = Color(0.035,0.055,0.08)
	background.size = Vector2(1080,1000)
	root.add_child(background)
	var shell: Node = load("res://scenes/Shell.tscn").instantiate()
	for i in range(3):
		var strip: Control = shell.get_node(ROOT_PATH + "BuffSlotsStrip").duplicate()
		strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		strip.position = Vector2(410, 115 + i*265)
		strip.size = Vector2(640,200)
		strip.visible = true
		root.add_child(strip)
		shell.call("_compact_player_strip", strip)
		var slots: Array = []
		for index in range(3):
			var buff: Dictionary = Catalog.get_buff(["buff_freeze_lane_classic", "buff_supercharge_queue_premium", "buff_hive_shield_single_elite"][index])
			var data: Dictionary = buff.duplicate(true)
			data.merge({"locked": index == 2 and i == 0, "active": index == 0 and i == 1,
				"consumed": index == 0 and i == 2, "remaining_ms": 2500 if i == 1 else 0,
				"duration_ms": 5000, "uses_total": 2 if i == 2 else 1, "uses_remaining": 0 if index == 0 and i == 2 else 1}, true)
			slots.append(data)
		strip.call("apply_snapshot", {"pid": 1, "slots_active": 3, "slots": slots, "chill_remaining_ms": 12500 if i == 1 else 0})
		var opponent: Control = shell.get_node(ROOT_PATH + "OpponentBuffStrip").duplicate()
		opponent.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		opponent.position = Vector2(40, 125 + i*265)
		opponent.size = Vector2(320,155)
		opponent.visible = true
		root.add_child(opponent)
		opponent.call("set_used_slots", [0] if i > 0 else [])
		var title := Label.new()
		title.text = ["Ready · overtime slot locked", "Active · exact simulation countdown", "Async · exhausted / one use left"][i]
		title.position = Vector2(40,55+i*265)
		title.add_theme_font_size_override("font_size", 28)
		root.add_child(title)
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("player-opponent-strips.png"))
	shell.free()
	print("BUFF_STRIP_VISUAL_HARNESS: PASS production strip controls; staged snapshots")
	quit(0)
