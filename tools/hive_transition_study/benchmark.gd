extends SceneTree
const Presenter=preload("res://tools/hive_transition_study/presenter.gd")
var textures: Array[Texture2D]=[]
var subjects: Array[Node2D]=[]
var frames: int=0
var last_usec: int=0
var idle_ms: Array[float]=[]
var active_ms: Array[float]=[]
var idle_script_ms: Array[float]=[]
var active_script_ms: Array[float]=[]
var output: String
var initial_nodes: int=0
var viewport: SubViewport
var idle_gpu_ms: Array[float]=[]
var active_gpu_ms: Array[float]=[]

func _init() -> void:
    call_deferred("run")

func run() -> void:
    output=OS.get_environment("SF_TRANSITION_OUTPUT")
    root.size=Vector2i(1440,1000)
    RenderingServer.set_default_clear_color(Color(0.04,0.05,0.06))
    viewport=SubViewport.new()
    viewport.size=Vector2i(1440,1000)
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
    var display:=TextureRect.new()
    display.texture=viewport.get_texture()
    root.add_child(display)
    for name in ["hive_small_flatop.png","hive_medium_flatop.png","hive_large_flatop_alpha.png"]:
        var source:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/"+name))
        source.generate_mipmaps()
        textures.append(ImageTexture.create_from_image(source))
    for i in range(24):
        var item:=Presenter.new()
        viewport.add_child(item)
        item.configure(textures,Color.from_hsv(float(i%4)*0.23,0.80,1.0))
        item.position=Vector2(140+(i%6)*228,120+(i/6)*230)
        item.scale=Vector2.ONE*0.85
        item.begin(2,3)
        item.cancel()
        subjects.append(item)
    initial_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
    last_usec=Time.get_ticks_usec()
    process_frame.connect(tick)

func tick() -> void:
    var now: int=Time.get_ticks_usec()
    var wall_ms: float=float(now-last_usec)/1000.0
    last_usec=now
    frames+=1
    var active: bool=frames>420
    var start: int=Time.get_ticks_usec()
    if active:
        for i in range(subjects.size()):
            subjects[i].set_elapsed(fposmod(float(frames-420)/60.0+float(i)*0.025,0.66))
    var script_ms: float=float(Time.get_ticks_usec()-start)/1000.0
    RenderingServer.force_draw(false)
    var gpu_ms: float=RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
    if frames>120 and frames<=420:
        idle_ms.append(wall_ms)
        idle_gpu_ms.append(gpu_ms)
        idle_script_ms.append(script_ms)
    if frames>540:
        active_ms.append(wall_ms)
        active_gpu_ms.append(gpu_ms)
        active_script_ms.append(script_ms)
    if frames>=840:
        var result: Dictionary={"engine":Engine.get_version_info(),"renderer":"gl_compatibility","os":OS.get_name(),"viewport":[1440,1000],"hives":24,"samples_per_phase":300,"idle_frame_ms":summary(idle_ms),"active_frame_ms":summary(active_ms),"idle_presenter_cpu_ms":summary(idle_script_ms),"active_presenter_cpu_ms":summary(active_script_ms),"initial_nodes":initial_nodes,"final_nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"draw_calls":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"idle_gpu_ms":summary(idle_gpu_ms),"active_gpu_ms":summary(active_gpu_ms),"limits":"Desktop isolated fixture, sequential phases, forced draw, no full game or phone certification. Frame intervals include OS scheduling/presentation; CPU timer measures uniform updates only. Zero render statistics mean unavailable, not zero work."}
        viewport.get_texture().get_image().save_png(output.path_join("benchmark-scene.png"))
        var file:=FileAccess.open(output.path_join("desktop-benchmark.json"),FileAccess.WRITE)
        file.store_string(JSON.stringify(result,"  "))
        print("HIVE_TRANSFORMATION_BENCHMARK: PASS ",JSON.stringify(result))
        quit()

func summary(values: Array[float]) -> Dictionary:
    var sorted: Array[float]=values.duplicate()
    sorted.sort()
    return {"median":sorted[sorted.size()/2],"p95":sorted[int(sorted.size()*0.95)],"max":sorted[-1]}
