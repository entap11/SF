extends SceneTree

const Stage=preload("res://tools/tower_voxel_study/stage.gd")
const Debris=preload("res://tools/tower_voxel_study/debris.gd")
const DURATION: float=18.0
const FPS: int=60
var scene_root: Node2D
var detail: Node2D
var field: Node2D
var font: FontFile
var phase_label: Label
var stats_label: Label
var clock_label: Label
var seconds: float=0.0
var speed: float=1.0
var preview_paused: bool=false
var output_dir: String
var captured: bool=false
var background: Control
var bright: bool=false

func _init() -> void:
	call_deferred("run")

func label(value: String, at: Vector2, size: int, color:=Color(0.9,0.93,0.97)) -> Label:
	var n:=Label.new()
	n.text=value
	n.position=at
	n.add_theme_font_override("font",font)
	n.add_theme_font_size_override("font_size",size)
	n.add_theme_color_override("font_color",color)
	scene_root.add_child(n)
	return n

func panel(rect: Rect2, fill: Color) -> Panel:
	var p:=Panel.new()
	p.position=rect.position
	p.size=rect.size
	var style:=StyleBoxFlat.new()
	style.bg_color=fill
	style.border_color=Color(0.14,0.18,0.23)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	p.add_theme_stylebox_override("panel",style)
	p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scene_root.add_child(p)
	return p

func line(a: Vector2,b: Vector2,color: Color,width: float=1.0) -> void:
	var n:=Line2D.new()
	n.points=PackedVector2Array([a,b])
	n.default_color=color
	n.width=width
	n.antialiased=true
	scene_root.add_child(n)

func run() -> void:
	output_dir=OS.get_environment("SF_TOWER_OUTPUT")
	captured="--capture" in OS.get_cmdline_user_args() or "--stills" in OS.get_cmdline_user_args()
	root.size=Vector2i(1440,960)
	root.content_scale_size=Vector2i(1440,960)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_title("Swarmfront — Tower voxel impact study")
	RenderingServer.set_default_clear_color(Color(0.025,0.032,0.043))
	font=FontFile.new()
	assert(font.load_dynamic_font("res://assets/Iceland-Regular.ttf")==OK)
	var bee:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/unit_v5.png"))
	bee.generate_mipmaps()
	var tower_image:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/towers.png"))
	var tower:=ImageTexture.create_from_image(tower_image.get_region(Rect2i(157,437,355,417)))
	scene_root=Node2D.new()
	root.add_child(scene_root)
	label("SWARMFRONT   /   MATERIAL & MOTION",Vector2(48,32),22,Color(0.84,0.71,0.43))
	label("Tower impact",Vector2(45,67),66)
	label("Instant breakup. Directional force. Weight that stays on the battlefield.",Vector2(48,145),25,Color(0.57,0.66,0.74))
	line(Vector2(48,203),Vector2(1392,203),Color(0.16,0.21,0.27))
	label("01   /   IMPACT DETAIL",Vector2(48,226),22,Color(0.74,0.80,0.85))
	label("2.25×",Vector2(619,228),20,Color(0.48,0.58,0.68))
	label("02   /   SUSTAINED FIRE",Vector2(736,226),22,Color(0.74,0.80,0.85))
	label("1× artwork scale",Vector2(1220,228),20,Color(0.48,0.58,0.68))
	background=panel(Rect2(48,270,656,442),Color(0.083,0.098,0.118))
	panel(Rect2(736,270,656,442),Color(0.083,0.098,0.118))
	# Restrained floor references make ground contact and sliding legible.
	for x in range(80,694,32):
		line(Vector2(x,292),Vector2(x,690),Color(0.28,0.36,0.43,0.055))
	for y in range(298,705,32):
		line(Vector2(70,y),Vector2(682,y),Color(0.28,0.36,0.43,0.055))
	for x in range(760,1390,32):
		line(Vector2(x,286),Vector2(x,696),Color(0.28,0.36,0.43,0.055))
	for y in range(302,706,32):
		line(Vector2(755,y),Vector2(1373,y),Color(0.28,0.36,0.43,0.055))
	var field_offset:=Vector2(771,291)
	for ends in [[Vector2(220,38),Vector2(292,385)],[Vector2(398,383),Vector2(291,30)]]:
		line(field_offset+ends[0],field_offset+ends[1],Color(0.36,0.49,0.60,0.075),14)
		line(field_offset+ends[0],field_offset+ends[1],Color(0.37,0.49,0.57,0.23),1)
	detail=Stage.new()
	detail.position=Vector2(90,429)
	detail.scale=Vector2.ONE*2.25
	detail.configure(bee,tower,true)
	scene_root.add_child(detail)
	field=Stage.new()
	field.position=field_offset
	field.configure(bee,tower,false)
	scene_root.add_child(field)
	phase_label=label("",Vector2(48,738),34,Color(0.92,0.79,0.49))
	stats_label=label("",Vector2(736,741),24,Color(0.69,0.78,0.85))
	label("Longer skid. More momentum carried off the path.",Vector2(48,786),22,Color(0.55,0.64,0.73))
	label("Debris spreads into the spaces between lanes.",Vector2(736,786),22,Color(0.55,0.64,0.73))
	line(Vector2(48,847),Vector2(1392,847),Color(0.16,0.21,0.27))
	clock_label=label("",Vector2(48,875),22,Color(0.64,0.72,0.80))
	label("SPACE pause   ·   S slow   ·   R replay   ·   ← → step",Vector2(596,875),21,Color(0.54,0.63,0.72))
	label("ISOLATED VISUAL STUDY  /  SYNTHETIC FIELD  /  NO GAMEPLAY CHANGES",Vector2(48,918),16,Color(0.35,0.45,0.55))
	if "--check" in OS.get_cmdline_user_args():
		check_contract(bee)
		return
	if "--benchmark" in OS.get_cmdline_user_args():
		await benchmark()
		return
	if captured:
		await capture()
		return
	root.window_input.connect(on_input)
	process_frame.connect(tick)
	set_time(0.0)

func set_time(value: float) -> void:
	seconds=value
	detail.set_time(value)
	field.set_time(value)
	var local: float=fposmod(value,8.0)-1.30
	var phase: String="TRACKING"
	if local>=-0.14 and local<0:
		phase="BOLT IN FLIGHT"
	elif local>=0 and local<0.12:
		phase="INSTANT VOXEL BREAKUP"
	elif local>=0.12 and local<0.55:
		phase="FORWARD SCATTER"
	elif local>=0.55 and local<0.95:
		phase="BOUNCE · BOUNCE"
	elif local>=0.95 and local<2.55:
		phase="SKID INTO OPEN FLOOR"
	elif local>=2.55 and local<4.5:
		phase="SETTLED DEBRIS"
	elif local>=4.5:
		phase="STAGGERED DECAY"
	if value>16:
		phase="FIELD CLEARS"
	phase_label.text=phase
	stats_label.text="%d chunks   ·   %d resting" % [field.debris.active_count,field.debris.resting_count]
	clock_label.text="%05.2f s   /   %.2f× speed   /   %d voxels per bee" % [value,speed,detail.debris.samples.size()]

func tick() -> void:
	if preview_paused:
		return
	set_time(fposmod(seconds+root.get_process_delta_time()*speed,DURATION))

func on_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE: preview_paused=not preview_paused
		KEY_S: speed=0.25 if speed==1 else 1.0
		KEY_R: set_time(0.0)
		KEY_LEFT:
			preview_paused=true
			set_time(maxf(0,seconds-1.0/FPS))
		KEY_RIGHT:
			preview_paused=true
			set_time(minf(DURATION-1.0/FPS,seconds+1.0/FPS))
		KEY_ESCAPE: quit()

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir.path_join("frames"))
	var frames: Array=range(int(DURATION*FPS))
	if "--stills" in OS.get_cmdline_user_args():
		frames=[60,76,78,80,86,96,112,136,210,340,440,570,750,950,1079]
	for frame in frames:
		set_time(float(frame)/FPS)
		await process_frame
		RenderingServer.force_draw(false)
		var result: Error=root.get_texture().get_image().save_png(output_dir.path_join("frames/%04d.png" % frame))
		if result!=OK:
			push_error("Capture failed for frame %d" % frame)
			quit(1)
			return
	print("TOWER_VOXEL_CAPTURE: PASS %d frames" % frames.size())
	quit()

func check_contract(bee: Image) -> void:
	var p:=Debris.new()
	p.configure(bee,640)
	root.add_child(p)
	assert(p.samples.size()>=20 and p.samples.size()<=40,"Expected a readable coarse silhouette")
	assert(p.add_hit(0,Vector2.ZERO,Vector2.RIGHT,0,Color.GOLD,912))
	var one: Dictionary=p.pieces[0].duplicate(true)
	var first_pose: Dictionary=Debris.pose(one,0)
	assert((first_pose.position as Vector2).distance_to(p.samples[0].offset)<0.001,"Breakup must start in the bee silhouette")
	var landed: Dictionary=Debris.pose(one,float(one.settle)+0.25)
	assert(landed.resting and landed.height==0,"Fragments must stop bouncing")
	assert(landed.position.x>first_pose.position.x,"Shot must carry debris forward")
	for piece in p.pieces:
		for contact in [float(piece.first),float(piece.first)+float(piece.second),float(piece.bounce_end),float(piece.settle)]:
			var before: Dictionary=Debris.pose(piece,contact-0.00001)
			var after: Dictionary=Debris.pose(piece,contact+0.00001)
			assert(before.position.distance_to(after.position)<0.02,"Bounce must be continuous")
		assert(Debris.pose(piece,20).is_empty(),"Expired debris must disappear")
	var direct: Dictionary=Debris.pose(one,0.72)
	for hz in [30,60,120]:
		for i in range(hz):
			p.set_time(float(i)/hz)
		var stepped: Dictionary=Debris.pose(one,0.72)
		assert(direct==stepped,"Equal elapsed time must give equal motion")
	var children: int=p.get_child_count()
	var base_fade: float=p.pieces[0].fade_at
	for i in range(1,13):
		p.add_hit(float(i)*0.2,Vector2.ZERO,Vector2.RIGHT,0,Color.RED,100+i)
	assert(float(p.pieces[0].fade_at)<base_fade,"Crowding should shorten old debris life")
	for piece in p.pieces:
		assert(float(piece.fade_at)>=float(piece.time)+float(piece.settle)+Debris.MIN_REST_SEC,"Crowding must preserve the bounce and minimum rest")
	for i in range(200):
		p.add_hit(3.0,Vector2.ZERO,Vector2.RIGHT,0,Color.GOLD,1000+i)
	assert(p.pieces.size()<=p.capacity and p.events.size()<=Debris.MAX_EVENTS,"Storage must be bounded")
	assert(p.rejected_events>0,"Extreme overload must obey capacity")
	assert(p.get_child_count()==children,"Impact must not create nodes")
	p.set_time(30)
	assert(p.active_count==0 and p.blocks.multimesh.visible_instance_count==0,"Reset must hide all instances")
	p.clear()
	assert(p.pieces.is_empty() and p.events.is_empty(),"Clear must release presentation records")
	set_time(4.1)
	var expected: Array=[]
	for piece in field.debris.pieces:
		expected.append(Debris.pose(piece,4.1))
	set_time(0)
	for i in range(247):
		set_time(float(i)/60.0)
	var actual: Array=[]
	for piece in field.debris.pieces:
		actual.append(Debris.pose(piece,4.1))
	assert(expected==actual,"Seeking and chronological playback must agree")
	set_time(DURATION)
	assert(field.debris.active_count==0,"Sustained-fire debris must clear by the end")
	check_slide_clearance(p)
	print("TOWER_VOXEL_CHECK: PASS silhouette, directional force, continuous bounces/skid, fixed-time sampling, crowd decay, capacity, node reuse, seek/replay, cleanup, lane clearance")
	quit()

func check_slide_clearance(p: Node2D) -> void:
	var lanes: Array=[ [Vector2(220,38),Vector2(292,385)], [Vector2(398,383),Vector2(291,30)] ]
	var total: int=0
	var clear_count: int=0
	var slide_lengths: Array[float]=[]
	var worst_hit_clearance: float=1.0
	for event in field.schedule:
		p.clear()
		p.add_hit(0,event.hit,(event.hit-event.muzzle).normalized(),event.angle,event.tint,event.seed)
		var hit_clear: int=0
		for piece in p.pieces:
			var start: Dictionary=Debris.pose(piece,float(piece.bounce_end))
			var finish: Dictionary=Debris.pose(piece,float(piece.settle))
			var later: Dictionary=Debris.pose(piece,float(piece.settle)+0.5)
			assert(finish.resting and not finish.sliding,"Rest should start only after the skid ends")
			assert(finish.position==later.position,"Resting chunks must stop drifting")
			slide_lengths.append((finish.floor_pos as Vector2).distance_to(start.floor_pos))
			var overlaps_lane: bool=false
			for lane in lanes:
				var closest: Vector2=Geometry2D.get_closest_point_to_segment(finish.position,lane[0],lane[1])
				# Include the cube's projected extent, not just its centre.
				if closest.distance_to(finish.position)<=7.0+float(piece.size)*0.85:
					overlaps_lane=true
			if not overlaps_lane:
				hit_clear+=1
				clear_count+=1
			total+=1
		worst_hit_clearance=minf(worst_hit_clearance,float(hit_clear)/p.pieces.size())
	slide_lengths.sort()
	var median_slide: float=slide_lengths[slide_lengths.size()/2]
	var clear_fraction: float=float(clear_count)/total
	var report: Dictionary={"sampled_hits":field.schedule.size(),"chunks":total,"fully_outside_both_lanes":clear_count,
		"clear_fraction":clear_fraction,"minimum_per_hit_clear_fraction":worst_hit_clearance,"median_slide_px":median_slide}
	var file:=FileAccess.open(output_dir.path_join("slide-clearance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("SLIDE_CLEARANCE: "+JSON.stringify(report))
	assert(median_slide>=30.0,"The ground slide should be visibly substantial")
	assert(clear_fraction>=0.80,"Most settled fragments should clear both visible lanes")
	for event in detail.schedule:
		p.clear()
		p.add_hit(0,event.hit,(event.hit-event.muzzle).normalized(),event.angle,event.tint,event.seed)
		for piece in p.pieces:
			for age in [0.0,float(piece.first),float(piece.bounce_end),float(piece.settle)]:
				var sampled: Dictionary=Debris.pose(piece,age)
				var screen_pos: Vector2=detail.position+(sampled.position as Vector2)*detail.scale
				var margin: float=float(piece.size)*detail.scale.x*0.85
				assert(Rect2(48,270,656,442).grow(-margin).has_point(screen_pos),"Detail framing must retain the whole spill")

func benchmark() -> void:
	var results: Dictionary={"engine":Engine.get_version_info(),"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"samples":240}
	for mode in ["idle","sustained"]:
		var cpu: Array[float]=[]
		var frame_times: Array[float]=[]
		var previous: int=Time.get_ticks_usec()
		for i in range(270):
			var start: int=Time.get_ticks_usec()
			set_time(0.0 if mode=="idle" else 4.0+float(i)/120.0)
			var work: float=float(Time.get_ticks_usec()-start)/1000.0
			await process_frame
			RenderingServer.force_draw(false)
			var now: int=Time.get_ticks_usec()
			if i>=30:
				cpu.append(work)
				frame_times.append(float(now-previous)/1000.0)
			previous=now
		cpu.sort()
		frame_times.sort()
		results[mode]={"cpu_median_ms":cpu[120],"cpu_p95_ms":cpu[228],"frame_median_ms":frame_times[120],"frame_p95_ms":frame_times[228],"chunks":field.debris.active_count+detail.debris.active_count}
	var file:=FileAccess.open(output_dir.path_join("desktop-benchmark.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	print("TOWER_VOXEL_BENCHMARK: PASS "+JSON.stringify(results))
	quit()
