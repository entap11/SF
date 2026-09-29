extends SceneTree

const Body := preload("res://tools/hive_transition_study/presenter.gd")
const Existing := preload("res://tools/hive_pressure_study/pressure_v1.gd")
const Candidate := preload("res://tools/hive_pressure_study/pressure.gd")
const Rules := preload("res://scripts/hive/hive_distress_rules.gd")
const Layout := preload("res://tools/hive_transition_study/study.gd")
const SEGMENT_SEC := 2.4
var font: FontFile
var textures: Array[Texture2D] = []
var bodies: Array[Node2D] = []
var effects: Array[Node2D] = []
var indicators: Array[Node2D] = []
var panels: Array[Panel] = []
var fields: Array[Node2D] = []
var stage: Node2D
var caption: Label
var phase_label: Label
var output: String
var previous_segment := -1
var previous_event := -1
var time := 0.0
var preview_paused := false
var speed := 1.0
var capture := false
var preview_motion := "full"

class CombatField:
	extends Node2D
	var phase := 0.0
	func _draw() -> void:
		for x in range(28,630,52):
			draw_line(Vector2(x,490),Vector2(x,650),Color(0.22,0.35,0.42,0.12),1.0)
		for y in range(490,651,40):
			draw_line(Vector2(18,y),Vector2(614,y),Color(0.22,0.35,0.42,0.12),1.0)
		var starts := [Vector2(18,635),Vector2(20,510),Vector2(275,650),Vector2(596,625)]
		var ends := [Vector2(605,510),Vector2(595,635),Vector2(365,493),Vector2(112,515)]
		for i in range(4):
			var a: Vector2 = starts[i]
			var b: Vector2 = ends[i]
			var color := Color(0.27,0.57,0.67) if i%2 else Color(0.76,0.48,0.22)
			draw_line(a,b,Color(color,0.32),1.1,true)
			var heading := (b-a).normalized()
			var normal := Vector2(-heading.y,heading.x)
			for j in range(6):
				var t := fposmod(phase*0.16+float(j)/6.0+float(i)*0.13,1.0)
				var at := a.lerp(b,t)
				draw_colored_polygon(PackedVector2Array([at+heading*3.8,at-heading*2.3+normal*2.0,at-heading*2.3-normal*2.0]),color.lightened(0.25))

func _init() -> void:
	call_deferred("run")

func label(text: String, at: Vector2, size: int, color := Color(0.89,0.92,0.94)) -> Label:
	var node := Label.new()
	node.text = text
	node.position = at
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	stage.add_child(node)
	return node

func run() -> void:
	output = OS.get_environment("SF_PRESSURE_OUTPUT")
	preview_motion = OS.get_environment("SF_PRESSURE_MOTION")
	if preview_motion.is_empty(): preview_motion = "full"
	capture = "--capture" in OS.get_cmdline_user_args() or "--stills" in OS.get_cmdline_user_args()
	font = FontFile.new()
	assert(font.load_dynamic_font("res://assets/Iceland-Regular.ttf") == OK)
	root.size = Vector2i(1440,1000)
	root.content_scale_size = Vector2i(1440,1000)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_title("Swarmfront — Hive pressure study")
	RenderingServer.set_default_clear_color(Color(0.030,0.038,0.047))
	for name in ["hive_small_flatop.png","hive_medium_flatop.png","hive_large_flatop_alpha.png"]:
		var source := Image.load_from_file(ProjectSettings.globalize_path("res://assets/"+name))
		source.generate_mipmaps()
		textures.append(ImageTexture.create_from_image(source))
	stage = Node2D.new()
	root.add_child(stage)
	label("SWARMFRONT   /   MATERIAL & MOTION",Vector2(64,36),23,Color(0.60,0.69,0.76))
	label("Hive pressure",Vector2(61,79),68)
	label("Brighter onset. White-hot vents. A clear warning pulse.",Vector2(64,158),27,Color(0.65,0.73,0.79))
	for x in [64,744]:
		var panel := Panel.new()
		panel.position = Vector2(x,224)
		panel.size = Vector2(632,665)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.039,0.049,0.059)
		style.border_color = Color(0.15,0.19,0.22)
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		panel.add_theme_stylebox_override("panel",style)
		panel.clip_contents = true
		stage.add_child(panel)
		panels.append(panel)
		var field := CombatField.new()
		panel.add_child(field)
		fields.append(field)
	label("PREVIOUS   /   SUBTLE",Vector2(92,244),25,Color(0.61,0.69,0.75))
	label("REVISED   /   COMBAT READABILITY",Vector2(772,244),25,Color(0.95,0.79,0.52))
	for column in range(2):
		var x := 380.0+680.0*column
		add_hive(Vector2(x,471),1.55,column == 1,Color(1.0,0.77,0.08))
		add_hive(Vector2(x-136,789),0.54,column == 1,Color(1.0,0.77,0.08))
		add_hive(Vector2(x+136,789),0.54,column == 1,Color(0.29,0.82,1.0))
		label("BUSY FIELD   /   COMPACT SCALE",Vector2(x-285,709),19,Color(0.47,0.58,0.67))
		var line := Line2D.new()
		line.z_index = -1
		line.points = PackedVector2Array([Vector2(x-127,838),Vector2(x+124,838)])
		line.width = 1.1
		line.default_color = Color(0.35,0.53,0.61,0.48)
		stage.add_child(line)
	caption = label("",Vector2(64,909),29)
	phase_label = label("",Vector2(64,950),21,Color(0.65,0.72,0.77))
	if capture:
		await capture_review()
		return
	root.window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_SPACE: preview_paused = not preview_paused
			if event.keycode == KEY_S: speed = 0.25 if speed == 1.0 else 1.0
			if event.keycode == KEY_ESCAPE: quit())
	process_frame.connect(func():
		if not preview_paused:
			time += root.get_process_delta_time()*speed
			step(time,root.get_process_delta_time()*speed))

func add_hive(at: Vector2, size: float, candidate: bool, tint: Color) -> void:
	var body := Body.new()
	var panel: Panel = panels[1 if candidate else 0]
	panel.add_child(body)
	body.configure(textures,tint)
	body.position = at-panel.position
	body.scale = Vector2.ONE*size
	var effect: Node2D = Candidate.new() if candidate else Existing.new()
	body.add_child(effect)
	effect.z_index = 0 # Keep the close-up inside its comparison panel.
	var indicator := Layout.Indicators.new()
	indicator.font = font
	indicator.accent = tint
	indicator.z_index = 30
	body.add_child(indicator)
	bodies.append(body)
	effects.append(effect)
	indicators.append(indicator)

func step(seconds: float, delta: float) -> void:
	for field in fields:
		field.phase = seconds if preview_motion == "full" else 0.0
		field.queue_redraw()
	var segment := int(seconds/SEGMENT_SEC)%4
	var local := fposmod(seconds,SEGMENT_SEC)
	if segment != previous_segment:
		previous_segment = segment
		previous_event = -1
		for i in range(effects.size()):
			effects[i].reset_presentation()
			var tier := 2 if segment == 1 else 1
			bodies[i].begin(tier,tier)
			bodies[i].set_elapsed(1.0)
			var size: Vector2 = bodies[i]._size_for(tier)*256.0
			effects[i].position = Vector2(0,94.64-size.y*0.88)
			indicators[i].position = Vector2(0,94.64-size.y*0.99)
			indicators[i].tier = tier
			indicators[i].power = [5,24,9,5][segment]
			indicators[i].queue_redraw()
		caption.text = ["ACTIVE PRESSURE   /   6 → 5 → 4 → 3", "TIER LOSS   /   LARGE → MEDIUM", "TIER LOSS   /   MEDIUM → SMALL", "RECOVERY   /   PRESSURE RELEASES"][segment]
	var event := 0
	if segment == 0: event = 2 if local>=1.0 else 1 if local>=0.5 else 0
	if segment == 3: event = 1 if local>=0.7 else 0
	if event != previous_event:
		previous_event = event
		for i in range(effects.size()):
			var tier := 2 if segment == 1 else 1
			var size: Vector2 = bodies[i]._size_for(tier)*256.0
			var old_power: int = [6-event,30,10,6][segment]
			var new_power: int = [5-event,24,9,5][segment]
			if segment == 3 and event == 1: old_power=5; new_power=6
			var pressure: String = Rules.classify_pressure_transition(true,1,1,1,old_power,new_power,segment==0 or segment==3)
			var burst: String = Rules.classify_tier_rupture(3 if segment==1 else 2 if segment==2 else 1,tier) if event==0 else Rules.BURST_NONE
			effects[i].apply_presentation(1, effects[i].position, bodies[i].owner_color, preview_motion, {
				"pressure_transition":pressure,"burst_kind":burst,"play_pressure_entry":pressure==Rules.PRESSURE_TRIGGER and event==0,
				"critical_surge_delay":Rules.CRITICAL_ENTRY_HANDOFF_SEC,
				"current_size":size,"pre_transition_size":bodies[i]._size_for(tier+1)*256.0 if segment in [1,2] else size
			},segment==0 or segment==3)
			indicators[i].power=new_power
			indicators[i].queue_redraw()
	for effect in effects:
		effect._process(delta)
		effect.set_process(false)
	for i in range(3):
		var current: Dictionary = effects[i].get_debug_snapshot()
		var refined: Dictionary = effects[i+3].get_debug_snapshot()
		for key in ["state","critical_active","pressure_hold_remaining","current_intensity","minor_rupture_count","major_rupture_count","critical_entry_count","pulse_index"]:
			assert(current[key] == refined[key], "Pressure candidate changed timing: " + key)
		assert(effects[i+3].get_child_count() == 0, "Pressure candidate allocated children")
	phase_label.text = "%.2f s   ·   Same pressure triggers and timing   ·   Close-up + compact scale" % local

func capture_review() -> void:
	DirAccess.make_dir_recursive_absolute(output+"/frames")
	var stills := "--stills" in OS.get_cmdline_user_args()
	for frame in range(576):
		step(float(frame)/60.0,1.0/60.0)
		if stills and frame not in [15,38,85,153,173,300,325,475,500]: continue
		await process_frame
		RenderingServer.force_draw(false)
		var path := output+"/frames/%04d.png"%frame
		assert(root.get_texture().get_image().save_png(path)==OK)
	print("HIVE_PRESSURE_REVIEW: PASS — inherited pressure rules, 576 fixed presentation samples")
	quit()
