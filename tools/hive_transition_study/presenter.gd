extends Node2D
## A presentation-only study. Inputs are tier samples, never mutable game objects.
## A single bounded body quad and contact quad; no frame-created nodes or tweens.
const BODY_SHADER = preload("res://tools/hive_transition_study/transform.gdshader")
const CONTACT_SHADER = preload("res://tools/hive_transition_study/contact.gdshader")
const HEIGHTS = [0.65, 0.767, 0.871]
var textures: Array[Texture2D] = []
var body: Polygon2D
var contact: Polygon2D
var body_material: ShaderMaterial
var contact_material: ShaderMaterial
var from_tier: int = 1
var to_tier: int = 1
var elapsed: float = 0.0
var reduced: bool = false
var running: bool = false
var owner_color := Color(1.0, 0.77, 0.08)
var pose: Dictionary = {}

func configure(source_textures: Array[Texture2D], tint: Color) -> void:
    textures=source_textures
    owner_color=tint
    contact_material=ShaderMaterial.new()
    contact_material.shader=CONTACT_SHADER
    contact=_quad(Rect2(-100,62,200,58),contact_material)
    body_material=ShaderMaterial.new()
    body_material.shader=BODY_SHADER
    body=_quad(Rect2(-128,-146,256,256),body_material)
    body_material.set_shader_parameter("owner_color",tint)
    contact_material.set_shader_parameter("owner_color",tint)
    begin(1,1)
    set_elapsed(1.0)

func _quad(rect: Rect2, mat: ShaderMaterial) -> Polygon2D:
    var quad:=Polygon2D.new()
    quad.polygon=PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)])
    quad.uv=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
    mat.set_shader_parameter("quad_origin",rect.position)
    mat.set_shader_parameter("quad_size",rect.size)
    quad.material=mat
    add_child(quad)
    return quad

func begin(old_tier: int, new_tier: int, low_motion: bool=false) -> void:
    from_tier=clampi(old_tier,1,3)
    to_tier=clampi(new_tier,1,3)
    reduced=low_motion
    elapsed=0.0
    running=from_tier!=to_tier
    body_material.set_shader_parameter("before_tex",textures[from_tier-1])
    body_material.set_shader_parameter("after_tex",textures[to_tier-1])
    body_material.set_shader_parameter("before_size",_size_for(from_tier))
    body_material.set_shader_parameter("after_size",_size_for(to_tier))
    body_material.set_shader_parameter("direction",1.0 if to_tier>=from_tier else -1.0)
    body_material.set_shader_parameter("reduced",1.0 if reduced else 0.0)
    set_elapsed(0.0)

func _size_for(tier: int) -> Vector2:
    var tex: Texture2D=textures[tier-1]
    var height: float=HEIGHTS[tier-1]
    return Vector2(height*float(tex.get_width())/float(tex.get_height())*0.90,height)

static func sample(time: float, old_tier: int, new_tier: int, low_motion: bool=false) -> Dictionary:
    var up: bool=new_tier>old_tier
    var duration: float=0.66 if up else 0.49
    var t: float=maxf(0.0,time)
    if low_motion:
        return {"reveal":smoothstep(0.0,0.13,t),"charge":0.0,"band_energy":0.0,"settle":0.0,"body_scale":1.0,"ground":0.0,"done":t>=0.13}
    if old_tier==new_tier or t>=duration:
        return {"reveal":1.0,"charge":0.0,"band_energy":0.0,"settle":0.0,"body_scale":1.0,"ground":0.0,"done":true}
    var start: float=0.17 if up else 0.075
    var end: float=0.46 if up else 0.34
    var reveal_t: float=smoothstep(start,end,t)
    var charge_t: float=smoothstep(0.0,0.12 if up else 0.06,t)*(1.0-smoothstep(start,end+0.04,t))
    var band: float=smoothstep(start-0.025,start+0.028,t)*(1.0-smoothstep(end-0.015,end+0.055,t))
    var settle_t: float=clampf((t-end)/(duration-end),0.0,1.0)
    var compression: float=-0.018*charge_t if up else -0.007*charge_t
    var rebound: float=sin(settle_t*PI)*exp(-settle_t*2.4)*(0.023 if up else -0.010)
    return {"reveal":reveal_t,"charge":charge_t*(1.0 if up else 0.22),"band_energy":band*(1.0 if up else 0.48),"settle":sin(settle_t*PI),"body_scale":1.0+compression+rebound,"ground":(charge_t*0.40+band*0.58+sin(settle_t*PI)*0.40)*(1.0 if up else 0.40),"done":false}

func set_elapsed(seconds: float) -> void:
    elapsed=maxf(0.0,seconds)
    pose=sample(elapsed,from_tier,to_tier,reduced)
    running=not pose.done
    var height: float=maxf(HEIGHTS[from_tier-1],HEIGHTS[to_tier-1])
    var top: float=0.44-height*0.87
    var bottom: float=0.405
    var sweep: float=lerpf(bottom,top,pose.reveal) if to_tier>=from_tier else lerpf(top,bottom,pose.reveal)
    body_material.set_shader_parameter("sweep",sweep)
    for key in ["reveal","charge","band_energy","settle","body_scale"]:
        body_material.set_shader_parameter(key,pose[key])
    contact_material.set_shader_parameter("energy",pose.ground)
    contact_material.set_shader_parameter("arrival",pose.reveal)

func advance(delta: float) -> void:
    if running:
        set_elapsed(elapsed+maxf(delta,0.0))

func cancel() -> void:
    set_elapsed(1.0)
