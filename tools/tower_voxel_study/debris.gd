extends Node2D
## Disposable presentation only. Explicit event times, seeded local variation,
## analytic trajectories and bounded instancing; never reads or writes SimState.

const CubeShader = preload("res://tools/tower_voxel_study/voxel.gdshader")
const ShadowShader = preload("res://tools/tower_voxel_study/shadow.gdshader")
const GRID: int = 12
const BEE_BOX: float = 63.86688 # 20 * 2.52 * 1.44 * .88: production texture box.
const GRAVITY: float = 380.0
const FADE_SEC: float = 0.85
const MIN_REST_SEC: float = 1.3
const MAX_EVENTS: int = 64
const LOCAL_RADIUS: float = 92.0
const AIR_DRAG: float = 0.8
const REBOUND_DRAG: float = 0.65
const FIRST_CONTACT_RETENTION: float = 0.92
const SLIDE_CONTACT_RETENTION: float = 0.94

var capacity: int = 640
var samples: Array[Dictionary] = []
var events: Array[Dictionary] = []
var pieces: Array[Dictionary] = []
var blocks: MultiMeshInstance2D
var shadows: MultiMeshInstance2D
var active_count: int = 0
var resting_count: int = 0
var time_sec: float = 0.0
var rejected_events: int = 0

func configure(source: Image, budget: int = 640) -> void:
	capacity=maxi(32,budget)
	_sample_silhouette(source)
	blocks=_batch(_cube_mesh(),CubeShader,capacity)
	shadows=_batch(QuadMesh.new(),ShadowShader,capacity)
	shadows.z_index=-1
	# QuadMesh defaults to one metre, which is one pixel in this canvas.
	(shadows.multimesh.mesh as QuadMesh).size=Vector2.ONE
	add_child(shadows)
	add_child(blocks)

func _batch(mesh: Mesh, shader: Shader, count: int) -> MultiMeshInstance2D:
	var node:=MultiMeshInstance2D.new()
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_2D
	mm.use_colors=true
	mm.use_custom_data=true
	mm.mesh=mesh
	mm.instance_count=count
	mm.visible_instance_count=0
	node.multimesh=mm
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	node.material=mat
	return node

func _cube_mesh() -> ArrayMesh:
	var vertices:=PackedVector3Array()
	var uv:=PackedVector2Array()
	var axes: Array[Vector3]=[Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
	for face in range(6):
		var normal: Vector3=axes[face]
		var u: Vector3=Vector3.UP if face<2 else Vector3.RIGHT
		var v: Vector3=normal.cross(u)
		var corners: Array[Vector3]=[]
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			corners.append((normal+u*corner.x+v*corner.y)*0.5)
		for index in [0,1,2,0,2,3]:
			var p: Vector3=corners[index]
			vertices.append(Vector3(p.x,p.y,0))
			uv.append(Vector2(p.z,float(face)))
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uv
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _sample_silhouette(source: Image) -> void:
	samples.clear()
	for y in range(GRID):
		for x in range(GRID):
			var rgba:=Color(0,0,0,0)
			var coverage: float=0.0
			for sy in range(5):
				for sx in range(5):
					var px: int=mini(source.get_width()-1,int((x+(sx+0.5)/5.0)*source.get_width()/GRID))
					var py: int=mini(source.get_height()-1,int((y+(sy+0.5)/5.0)*source.get_height()/GRID))
					var c: Color=source.get_pixel(px,py)
					if c.r>0.7 and c.b>0.7 and c.g<0.3:
						continue
					coverage+=c.a
					rgba+=c*c.a
			if coverage/25.0<0.33:
				continue
			var sampled: Color=rgba/maxf(coverage,0.001)
			sampled.a=1.0
			samples.append({"offset":(Vector2(x+0.5,y+0.5)/GRID-Vector2.ONE*0.5)*BEE_BOX,"color":sampled,"size":BEE_BOX/GRID})

static func variation(seed_value: int, channel: int) -> float:
	# Private integer hash. Does not consume the engine/global gameplay RNG.
	var h: int=(seed_value*374761393+channel*668265263)&0x7fffffff
	h=((h^(h>>13))*1274126177)&0x7fffffff
	return float(h^(h>>16))/2147483647.0

static func tint_sample(c: Color, tint: Color) -> Color:
	if c.r>c.b*1.4+0.05 and c.g>c.b*1.3+0.03:
		c=c.lerp(tint*(0.32+maxf(c.r,maxf(c.g,c.b))*0.8),0.90)
	c.a=1.0
	return c

func clear() -> void:
	events.clear()
	pieces.clear()
	active_count=0
	resting_count=0
	if blocks!=null:
		blocks.multimesh.visible_instance_count=0
		shadows.multimesh.visible_instance_count=0

func add_hit(at_sec: float, hit: Vector2, shot_direction: Vector2, bee_angle: float, tint: Color, event_seed: int) -> bool:
	# A streaming caller may retire fully expired records at the next event.
	for i in range(pieces.size()-1,-1,-1):
		if float(pieces[i].fade_at)+FADE_SEC<=at_sec:
			pieces.remove_at(i)
	for i in range(events.size()-1,-1,-1):
		if float(events[i].time)+8.0<at_sec:
			events.remove_at(i)
	# Hard capacity preserves fresh trajectories; overload admits whole bees only.
	if pieces.size()+samples.size()>capacity or events.size()>=MAX_EVENTS:
		rejected_events+=1
		return false
	var direction:=shot_direction.normalized() if shot_direction.length_squared()>0.0001 else Vector2.RIGHT
	var nearby: int=0
	for event in events:
		if (event.hit as Vector2).distance_to(hit)<LOCAL_RADIUS and at_sec-float(event.time)<4.0:
			nearby+=1
	# Crowding schedules an earlier fade; its start never cuts through the bounce.
	for piece in pieces:
		if (piece.hit as Vector2).distance_to(hit)>LOCAL_RADIUS:
			continue
		var pressure_end: float=at_sec+maxf(0.25,1.7-float(nearby)*0.22)
		piece.fade_at=minf(float(piece.fade_at),maxf(float(piece.time)+float(piece.settle)+MIN_REST_SEC,pressure_end))
	events.append({"time":at_sec,"hit":hit})
	for index in range(samples.size()):
		var sample: Dictionary=samples[index]
		var seed_value: int=event_seed*101+index*13
		var size: float=float(sample.size)*lerpf(0.82,1.02,variation(seed_value,0))
		var height: float=lerpf(13.0,19.0,variation(seed_value,1))
		var lift: float=lerpf(34.0,73.0,variation(seed_value,2))
		var first: float=(lift+sqrt(lift*lift+2.0*GRAVITY*height))/GRAVITY
		var contact_speed: float=GRAVITY*first-lift
		var restitution: float=lerpf(0.31,0.44,variation(seed_value,3))
		var second: float=2.0*contact_speed*restitution/GRAVITY
		var third: float=second*0.36
		var bounce_end: float=first+second+third
		var slide_duration: float=lerpf(1.15,1.75,variation(seed_value,15))
		var settle: float=bounce_end+slide_duration
		# A few heavy fragments stay close; most carry the shot's momentum into
		# the empty floor. There is no attraction to, or teleport off, a lane.
		var heavy: bool=variation(seed_value,14)<0.10
		var speed: float=lerpf(110.0,150.0,variation(seed_value,5))
		if heavy:
			speed*=lerpf(0.20,0.36,variation(seed_value,16))
		var velocity: Vector2=direction.rotated(lerpf(-0.36,0.36,variation(seed_value,4)))*speed
		var resting_layer: float=minf(1.9,float(nearby)*0.16)*variation(seed_value,13)
		pieces.append({
			"time":at_sec,"hit":hit,"origin":hit+(sample.offset as Vector2).rotated(bee_angle)+Vector2(0,height),
			"velocity":velocity,"height":height,"lift":lift,"first":first,"second":second,"third":third,
			"bounce_end":bounce_end,"slide_duration":slide_duration,"settle":settle,
			"contact_speed":contact_speed,"restitution":restitution,"size":size,"color":tint_sample(sample.color,tint),
			"phase":Vector3(variation(seed_value,6),variation(seed_value,7),variation(seed_value,8))*TAU,
			"spin":Vector3(3.1,4.2,3.8)*lerpf(-1.4,1.4,variation(seed_value,9)),
			"rest_angle":floor(variation(seed_value,10)*4.0)*PI*0.5+lerpf(-0.15,0.15,variation(seed_value,11)),
			"floor":resting_layer,
			"fade_at":at_sec+lerpf(4.5,6.7,variation(seed_value,12))
		})
	return true

static func pose(piece: Dictionary, at_sec: float) -> Dictionary:
	var age: float=at_sec-float(piece.time)
	if age<0.0 or at_sec>=float(piece.fade_at)+FADE_SEC:
		return {}
	var first: float=piece.first
	var second: float=piece.second
	var third: float=piece.third
	var h: float=0.0
	var distance_time: float=horizontal_travel(piece,age)
	var bounces: int=0
	if age<first:
		h=float(piece.height)+float(piece.lift)*age-0.5*GRAVITY*age*age
	else:
		var after: float=age-first
		bounces=1
		if after<second:
			h=0.5*GRAVITY*after*(second-after)
		elif after<second+third:
			var final_hop: float=after-second
			h=0.5*GRAVITY*final_hop*(third-final_hop)
			bounces=2
		else:
			bounces=3
	var floor_pos: Vector2=piece.origin+piece.velocity*distance_time
	var flatten: float=smoothstep(first,float(piece.bounce_end)+0.14,age)
	var slide_blend: float=smoothstep(float(piece.bounce_end),float(piece.settle),age)
	var angles: Vector3=piece.phase+piece.spin*minf(age,float(piece.bounce_end))
	var rest:=Vector3(0,0,float(piece.rest_angle))
	angles=Vector3(lerp_angle(angles.x,rest.x,flatten),lerp_angle(angles.y,rest.y,flatten),lerp_angle(angles.z,rest.z,slide_blend))
	# The first sample retains the lattice; tumbling opens over the first 55 ms.
	angles=Vector3.ZERO.lerp(angles,smoothstep(0.0,0.055,age))
	var decay: float=smoothstep(float(piece.fade_at),float(piece.fade_at)+FADE_SEC,at_sec)
	return {"position":floor_pos-Vector2(0,maxf(0,h)+float(piece.floor)),"floor_pos":floor_pos,
		"height":maxf(0,h),"angles":angles,"size":float(piece.size)*(1.0-decay*0.72),
		"alpha":1.0-decay,"hot":pow(maxf(0,1.0-age/0.105),2.0)*0.48,"bounces":bounces,
		"sliding":age>=float(piece.bounce_end) and age<float(piece.settle),"resting":age>=float(piece.settle)}

static func horizontal_travel(piece: Dictionary, age: float) -> float:
	var first: float=piece.first
	var distance_time: float=(1.0-exp(-AIR_DRAG*minf(age,first)))/AIR_DRAG
	if age<=first:
		return distance_time
	var rebound_duration: float=float(piece.second)+float(piece.third)
	var rebound_time: float=minf(age-first,rebound_duration)
	var contact_speed: float=exp(-AIR_DRAG*first)*FIRST_CONTACT_RETENTION
	distance_time+=contact_speed*(1.0-exp(-REBOUND_DRAG*rebound_time))/REBOUND_DRAG
	if age<=float(piece.bounce_end):
		return distance_time
	var slide_duration: float=piece.slide_duration
	var slide_time: float=minf(age-float(piece.bounce_end),slide_duration)
	var slide_speed: float=contact_speed*exp(-REBOUND_DRAG*rebound_duration)*SLIDE_CONTACT_RETENTION
	# Constant floor friction integrates to a finite skid with zero final speed.
	# Ground travel is continuous at each contact and exactly stationary afterward.
	distance_time+=slide_speed*(slide_time-0.5*slide_time*slide_time/slide_duration)
	return distance_time

func set_time(at_sec: float) -> void:
	time_sec=at_sec
	active_count=0
	resting_count=0
	for piece in pieces:
		var p: Dictionary=pose(piece,at_sec)
		if p.is_empty():
			continue
		var slot: int=active_count
		var size: float=p.size
		var tr:=Transform2D(0,Vector2.ONE*size,0,p.position)
		blocks.multimesh.set_instance_transform_2d(slot,tr)
		var c: Color=piece.color
		c.a=p.alpha
		blocks.multimesh.set_instance_color(slot,c)
		var angles: Vector3=p.angles
		blocks.multimesh.set_instance_custom_data(slot,Color(angles.x,angles.y,angles.z,float(p.hot)))
		var spread: float=1.0+float(p.height)*0.026
		shadows.multimesh.set_instance_transform_2d(slot,Transform2D(0,Vector2(size*1.65,size*0.80)*spread,0,p.floor_pos))
		shadows.multimesh.set_instance_color(slot,Color(1,1,1,float(p.alpha)*0.40/(1.0+float(p.height)*0.06)))
		active_count+=1
		if p.resting:
			resting_count+=1
	blocks.multimesh.visible_instance_count=active_count
	shadows.multimesh.visible_instance_count=active_count
