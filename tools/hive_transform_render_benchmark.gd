extends SceneTree
## Native renderer stress fixture: 24 simultaneous upgrades, reusable render nodes.
const Renderer := preload("res://scripts/renderers/hive_renderer.gd")
var renderer: Node2D
var viewport: SubViewport
var components: Array[Node] = []
var frame := 0
var last_us := 0
var iid := 3000
var node_count := 0
var idle: Array[float] = []
var active: Array[float] = []
var cpu: Array[float] = []
var final_nodes := 0
var draws_idle := 0
var draws_active := 0
var cycle_sec := 1.0

func _init() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1440,1000)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1440,1000)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	root.add_child(display)
	renderer = Renderer.new()
	viewport.add_child(renderer)
	renderer.setup(null,null,null)
	renderer.set_model(model(25,3))
	await process_frame
	for id in renderer.get_hive_ids():
		components.append(renderer.get_hive_node_by_id(id).get_node("Visual/FxLayer/HiveGrowthTransition"))
	node_count = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	last_us = Time.get_ticks_usec()
	process_frame.connect(tick)

func model(power: int, tier: int) -> Dictionary:
	var hives: Array = []
	for i in range(24):
		hives.append({"id":i+1,"x":1.0+(i%6)*3.65,"y":1.2+(i/6)*3.7,"owner_id":1+i%4,"pwr":power,"growth_tier":tier,"lane_budget_used":0,"lane_budget_max":tier,"kind":"Hive"})
	return {"iid":iid,"sim_running":true,"viewer_owner_id":1,"cell_size":64,"hives":hives,"lanes":[]}

func tick() -> void:
	var now := Time.get_ticks_usec()
	var ms := float(now-last_us)/1000.0
	last_us = now
	frame += 1
	var busy := frame > 360
	if busy:
		cycle_sec += root.get_process_delta_time()
	if busy and cycle_sec >= 0.62:
		cycle_sec = 0.0
		iid += 1
		renderer.set_model(model(9,1))
		renderer.set_model(model(25,3))
	var cost := float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0
	RenderingServer.force_draw(false)
	if frame > 120 and frame <= 360:
		idle.append(ms)
		draws_idle = viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	if frame > 480:
		active.append(ms)
		cpu.append(cost)
		draws_active = viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	if frame == 720:
		final_nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var result := {"hives":24,"samples":240,"viewport":[1440,1000],"renderer":"gl_compatibility","engine":Engine.get_version_info().string,"idle_ms":stats(idle),"active_ms":stats(active),"engine_process_ms":stats(cpu),"initial_nodes":node_count,"final_nodes":final_nodes,"draw_calls_idle":draws_idle,"draw_calls_active":draws_active,"limits":"Desktop native renderer fixture; sequential phases and forced draw; frame intervals include scheduling. Not a full-match or phone certification. Zero counters mean unavailable."}
		var output := OS.get_environment("SF_TRANSFORM_BENCHMARK_OUTPUT")
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"  "))
		print("HIVE_TRANSFORM_RENDER_BENCHMARK: PASS ",JSON.stringify(result))
		quit()

func stats(values: Array[float]) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	return {"median":sorted[sorted.size()/2],"p95":sorted[int(sorted.size()*0.95)],"max":sorted[-1]}
