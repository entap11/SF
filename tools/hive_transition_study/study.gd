extends SceneTree

const Presenter = preload("res://tools/hive_transition_study/presenter.gd")
var study_font: FontFile
const TINTS = [Color(1.0,0.77,0.08),Color(1.0,0.15,0.22),Color(0.30,0.83,1.0),Color(0.53,0.94,0.29)]
const CHANGES = [[1,2],[2,3],[3,2],[2,1]]
var textures: Array[Texture2D] = []
var presenters: Array[Node2D] = []
var scene_root: Node2D
var field: Node2D
var hero_label: Label
var phase_label: Label
var clock_label: Label
var indicators: Array[Node2D] = []
var seconds: float = 0.0
var speed: float = 1.0
var preview_paused: bool = false
var reduced: bool = false
var previous_segment: int = -1
var manual_transition: int = -1
var output_dir: String
var capture_mode: bool = false
var times: Array[float] = []

class Indicators:
    extends Node2D
    var font: Font
    var tier: int = 1
    var power: int = 9
    var accent: Color=Color.WHITE
    func _draw() -> void:
        draw_string_outline(font,Vector2(-48,0),str(power),HORIZONTAL_ALIGNMENT_CENTER,96,38,3,Color(0.018,0.022,0.03))
        draw_string(font,Vector2(-48,0),str(power),HORIZONTAL_ALIGNMENT_CENTER,96,38,Color(0.95,0.97,1.0))
        for i in range(tier):
            var center:=Vector2((i-(tier-1)*0.5)*17,14)
            var points:=PackedVector2Array()
            for j in range(6):
                points.append(center+Vector2.from_angle(PI*0.5+j*TAU/6.0)*5.4)
            draw_colored_polygon(points,accent)

class Field:
    extends Node2D
    var time: float=0.0
    var anchors: Array[Vector2]=[]
    var lanes: Array[Vector2i]=[]
    var style: StyleBoxFlat
    func _init() -> void:
        style=_box(Color(0.044,0.055,0.066),Color(0.12,0.145,0.165))
    func _draw() -> void:
        var rect:=Rect2(823,264,549,525)
        draw_style_box(style,rect)
        for i in range(8):
            var y: float=294+i*64
            draw_line(Vector2(843,y),Vector2(1352,y),Color(0.16,0.19,0.21,0.11),1.0)
        for i in range(lanes.size()):
            var link: Vector2i=lanes[i]
            var a: Vector2=anchors[link.x]+Vector2(0,45)
            var b: Vector2=anchors[link.y]+Vector2(0,45)
            var color: Color=Color(0.20,0.44,0.52,0.52) if i%2==0 else Color(0.55,0.40,0.19,0.42)
            draw_line(a,b,Color(color,0.065),6.0,true)
            draw_line(a,b,color,1.1,true)
            for j in range(3):
                var u: float=fposmod(time*0.12+float(j)/3.0+float(i)*0.11,1.0)
                var center: Vector2=a.lerp(b,u)
                var heading: Vector2=(b-a).normalized()
                var ortho:=Vector2(-heading.y,heading.x)
                draw_colored_polygon(PackedVector2Array([center+heading*3.0,center-heading*2.0+ortho*1.6,center-heading*2.0-ortho*1.6]),Color(0.72,0.81,0.84,0.80))
    func _box(fill: Color, border: Color) -> StyleBoxFlat:
        var style:=StyleBoxFlat.new()
        style.bg_color=fill
        style.border_color=border
        style.set_border_width_all(1)
        style.set_corner_radius_all(16)
        return style

func _init() -> void:
    call_deferred("run")

func label(text: String, at: Vector2, size: int, color: Color=Color(0.92,0.94,0.96)) -> Label:
    var node:=Label.new()
    node.text=text
    node.position=at
    node.add_theme_font_override("font",study_font)
    node.add_theme_font_size_override("font_size",size)
    node.add_theme_color_override("font_color",color)
    scene_root.add_child(node)
    return node

func run() -> void:
    output_dir=OS.get_environment("SF_TRANSITION_OUTPUT")
    capture_mode="--capture" in OS.get_cmdline_user_args() or "--stills" in OS.get_cmdline_user_args()
    study_font=FontFile.new()
    assert(study_font.load_dynamic_font("res://assets/Iceland-Regular.ttf")==OK)
    root.size=Vector2i(1440,1000)
    root.content_scale_size=Vector2i(1440,1000)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    DisplayServer.window_set_title("Swarmfront — Hive transformation study")
    RenderingServer.set_default_clear_color(Color(0.032,0.040,0.049))
    for path in ["hive_small_flatop.png","hive_medium_flatop.png","hive_large_flatop_alpha.png"]:
        var source:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/"+path))
        source.generate_mipmaps()
        textures.append(ImageTexture.create_from_image(source))
    scene_root=Node2D.new()
    root.add_child(scene_root)
    label("SWARMFRONT   /   MATERIAL & MOTION",Vector2(64,38),23,Color(0.68,0.74,0.79))
    label("Hive transformation",Vector2(61,80),68)
    label("Core charge. Fitted energy sweep. Mechanical settling.",Vector2(64,158),26,Color(0.62,0.69,0.75))
    var rule:=Line2D.new()
    rule.points=PackedVector2Array([Vector2(64,220),Vector2(1376,220)])
    rule.default_color=Color(0.21,0.24,0.27)
    rule.width=1.0
    scene_root.add_child(rule)
    label("DETAIL   /   2.4×",Vector2(64,249),22,Color(0.62,0.69,0.75))
    label("BATTLEFIELD CONTEXT   /   COMPACT SCALE",Vector2(823,230),20,Color(0.62,0.69,0.75))
    field=Field.new()
    field.anchors.assign([Vector2(947,333),Vector2(1249,350),Vector2(1097,493),Vector2(938,648),Vector2(1256,649)])
    field.lanes.assign([Vector2i(0,2),Vector2i(1,2),Vector2i(2,3),Vector2i(2,4),Vector2i(0,3),Vector2i(1,4)])
    scene_root.add_child(field)
    _add_presenter(Vector2(405,526),2.4,TINTS[0],true)
    for i in range(field.anchors.size()):
        _add_presenter(field.anchors[i],0.52,TINTS[i%4],false)
    hero_label=label("SMALL  →  MEDIUM",Vector2(64,813),40)
    phase_label=label("",Vector2(66,864),25,Color(0.87,0.75,0.51))
    clock_label=label("",Vector2(823,813),23,Color(0.73,0.79,0.84))
    label("SPACE pause   •   1–4 transition   •   S slow   •   R reduced motion",Vector2(64,940),23,Color(0.58,0.65,0.71))
    label("Existing hive artwork · visual study",Vector2(992,945),18,Color(0.43,0.50,0.56))
    if not capture_mode:
        root.window_input.connect(on_input)
    if "--check" in OS.get_cmdline_user_args():
        check_contract()
        return
    if capture_mode:
        await capture()
        return
    process_frame.connect(tick)

func _add_presenter(at: Vector2, scale_value: float, tint: Color, hero: bool) -> void:
    var presenter:=Presenter.new()
    scene_root.add_child(presenter)
    presenter.position=at
    presenter.scale=Vector2.ONE*scale_value
    presenter.configure(textures,tint)
    presenters.append(presenter)
    var status:=Indicators.new()
    status.font=study_font
    status.position=at+Vector2(0,-111*scale_value)
    status.scale=Vector2.ONE*(1.1 if hero else 0.58)
    status.accent=tint.lerp(Color.WHITE,0.85)
    status.z_index=5
    scene_root.add_child(status)
    indicators.append(status)

func set_time(time: float) -> void:
    seconds=time
    var segment: int=int(floor(seconds/2.1))%4 if manual_transition<0 else manual_transition
    var local: float=fposmod(seconds,2.1)-0.48
    var change: Array=CHANGES[segment]
    if segment!=previous_segment:
        previous_segment=segment
        for p in presenters:
            p.begin(change[0],change[1],reduced)
        hero_label.text=["SMALL  →  MEDIUM","MEDIUM  →  LARGE","LARGE  →  MEDIUM","MEDIUM  →  SMALL"][segment]
    for i in range(presenters.size()):
        var p: Node2D=presenters[i]
        var offset: float=0.0 if i==0 or i==3 else float(i%3)*0.15
        var current: float=local-offset
        p.set_elapsed(maxf(current,0.0))
        var tier: int=change[0] if current<0.0 else change[1]
        if current<0.0:
            p.body_material.set_shader_parameter("reveal",0.0)
        var indicator: Node2D=indicators[i]
        indicator.tier=tier
        indicator.power=([9,24,35][tier-1] if current<0 else [9,10,25][tier-1])
        indicator.queue_redraw()
    var total: float=0.66 if segment<2 else 0.49
    var stage: String="READY" if local<0 else ("SETTLED" if local>total else ("CHARGE" if local<0.17 else ("TRANSFORM" if local<0.46 else "SEAT & SETTLE")))
    if reduced:
        stage="REDUCED MOTION  /  SHORT DISSOLVE"
    phase_label.text=stage
    clock_label.text="%s     /     %s" % ["¼ SPEED" if speed<1 else "NORMAL SPEED", "PAUSED" if preview_paused else "LOOPING ALL FOUR TRANSITIONS"]
    field.time=time
    field.queue_redraw()

func tick() -> void:
    if not preview_paused:
        set_time(seconds+root.get_process_delta_time()*speed)

func on_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_SPACE:
            preview_paused=not preview_paused
        KEY_S:
            speed=0.25 if speed==1.0 else 1.0
        KEY_R:
            reduced=not reduced
            previous_segment=-1
            seconds=0.0
        KEY_1,KEY_2,KEY_3,KEY_4:
            manual_transition=event.keycode-KEY_1
            previous_segment=-1
            seconds=0.0
        KEY_A:
            manual_transition=-1
        KEY_ESCAPE:
            quit()
    set_time(seconds)

func capture() -> void:
    DirAccess.make_dir_recursive_absolute(output_dir.path_join("frames"))
    var frame_numbers: Array=range(504)
    if "--stills" in OS.get_cmdline_user_args():
        frame_numbers=[0,36,42,46,50,54,63,168,177,298,308,420]
    for frame in frame_numbers:
        set_time(float(frame)/60.0)
        await process_frame
        RenderingServer.force_draw(false)
        var error: Error=root.get_texture().get_image().save_png(output_dir.path_join("frames/%04d.png" % frame))
        if error!=OK:
            push_error("Capture failed")
            quit(1)
            return
    print("HIVE_TRANSFORMATION_CAPTURE: PASS %d frames at 60 fps" % frame_numbers.size())
    quit()

func check_contract() -> void:
    var passed: int=0
    for pair in CHANGES:
        var p: Node2D=presenters[0]
        p.begin(pair[0],pair[1])
        var count: int=p.get_child_count()
        p.set_elapsed(0.25)
        var expected: Dictionary=p.pose.duplicate()
        p.begin(pair[0],pair[1])
        for i in range(15):
            p.advance(1.0/60.0)
        for key in expected:
            if expected[key] is float:
                assert(is_equal_approx(expected[key],p.pose[key]),"Update-frequency drift")
        for i in range(100):
            p.begin(pair[0],pair[1])
            p.set_elapsed(0.20)
            p.begin(pair[1],pair[0])
            p.cancel()
        assert(p.get_child_count()==count,"Transition allocated nodes")
        assert(not p.running and p.pose.reveal==1.0 and p.pose.band_energy==0.0,"Cleanup failed")
        p.begin(pair[0],pair[1],true)
        p.set_elapsed(0.05)
        assert(p.pose.band_energy==0 and p.pose.body_scale==1.0,"Reduced motion moved body")
        p.set_elapsed(0.2)
        assert(not p.running)
        passed+=1
    print("HIVE_TRANSFORMATION_CHECK: PASS %d transitions, 400 interruptions, timing equivalence, reduced motion, fixed node count" % passed)
    quit()
