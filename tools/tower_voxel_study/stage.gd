extends Node2D

const Debris=preload("res://tools/tower_voxel_study/debris.gd")
const BeeShader=preload("res://tools/tower_voxel_study/bee.gdshader")
const TowerShader=preload("res://tools/tower_voxel_study/tower.gdshader")
const SHOT_TRAVEL: float=0.14
const GOLD:=Color(1.0,0.824,0.0)
const RED:=Color(0.898,0.224,0.208)
const GREEN:=Color(0.133,0.545,0.227)
const BLUE:=Color(0.078,0.282,0.745)
var debris: Node2D
var schedule: Array[Dictionary]=[]
var bee_pool: Array[Sprite2D]=[]
var tower_positions: Array[Vector2]=[]
var muzzle_positions: Array[Vector2]=[]
var time_sec: float=0.0
var previous_time: float=-1.0
var cursor: int=0
var hero: bool=false
var bright: bool=false

func configure(bee: Image, tower: Texture2D, detail: bool) -> void:
	hero=detail
	debris=Debris.new()
	debris.configure(bee,128 if hero else 640)
	add_child(debris)
	var texture:=ImageTexture.create_from_image(bee)
	for i in range(16):
		var sprite:=Sprite2D.new()
		sprite.texture=texture
		sprite.scale=Vector2.ONE*Debris.BEE_BOX/float(bee.get_width())
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var mat:=ShaderMaterial.new()
		mat.shader=BeeShader
		sprite.material=mat
		sprite.visible=false
		sprite.z_index=2
		bee_pool.append(sprite)
		add_child(sprite)
	tower_positions.assign([Vector2(28,27)] if hero else [Vector2(75,148),Vector2(490,345)])
	for at in tower_positions:
		# The atlas contains a baked checkerboard and grey cast shadow. A study-only
		# canvas contour clips those outside the existing tower; the source is unchanged.
		var tower_sprite:=Polygon2D.new()
		var contour:=PackedVector2Array([Vector2(160,39),Vector2(192,45),Vector2(205,100),Vector2(217,170),Vector2(244,245),Vector2(270,263),Vector2(307,270),Vector2(324,290),Vector2(341,329),Vector2(303,351),Vector2(270,355),Vector2(260,378),Vector2(237,399),Vector2(187,401),Vector2(140,378),Vector2(144,361),Vector2(91,348),Vector2(44,357),Vector2(1,333),Vector2(17,297),Vector2(26,280),Vector2(80,262),Vector2(95,241),Vector2(109,184),Vector2(123,93)])
		tower_sprite.uv=contour
		var polygon:=PackedVector2Array()
		for point in contour:
			polygon.append(point-Vector2(177.5,208.5))
		tower_sprite.polygon=polygon
		tower_sprite.antialiased=true
		tower_sprite.texture=tower
		tower_sprite.position=at-Vector2(0,46)
		tower_sprite.scale=Vector2.ONE*(94.0/tower.get_height())
		tower_sprite.z_index=1
		var tower_mat:=ShaderMaterial.new()
		tower_mat.shader=TowerShader
		tower_mat.set_shader_parameter("team",GOLD if at==tower_positions[0] else BLUE.lightened(0.22))
		tower_sprite.material=tower_mat
		add_child(tower_sprite)
		muzzle_positions.append(at-Vector2(0,83))
	_build_schedule()

func _build_schedule() -> void:
	schedule.clear()
	if hero:
		for i in range(2):
			var time: float=1.30+float(i)*8.0
			var heading:=Vector2(0.16,-1).normalized()
			schedule.append({"time":time,"hit":Vector2(108,-9),"muzzle":muzzle_positions[0],"heading":heading,
				"angle":heading.angle()+PI*0.5,"tint":GOLD if i==0 else BLUE.lightened(0.15),"seed":414+i*149,"tower":0})
	else:
		for i in range(26):
			var tower_index: int=i%2
			var at: Vector2=Vector2(254,129) if tower_index==0 else Vector2(331,277)
			at+=Vector2(sin(float(i)*2.4)*12,cos(float(i)*1.7)*16)
			var heading:=Vector2(0.18,1).normalized() if tower_index==0 else Vector2(-0.28,-1).normalized()
			schedule.append({"time":1.30+float(i)*0.34,"hit":at,"muzzle":muzzle_positions[tower_index],"heading":heading,
				"angle":heading.angle()+PI*0.5,"tint":RED if tower_index==0 else GOLD,"seed":300+i*61,"tower":tower_index})

func set_time(at_sec: float) -> void:
	if at_sec<previous_time:
		debris.clear()
		cursor=0
	while cursor<schedule.size() and float(schedule[cursor].time)<=at_sec:
		var event: Dictionary=schedule[cursor]
		debris.add_hit(event.time,event.hit,(event.hit-event.muzzle).normalized(),event.angle,event.tint,event.seed)
		cursor+=1
	time_sec=at_sec
	previous_time=at_sec
	debris.set_time(at_sec)
	for bee in bee_pool:
		bee.visible=false
	var index: int=0
	for event in schedule:
		var before: float=float(event.time)-at_sec
		if before<=0 or before>1.1 or index>=bee_pool.size():
			continue
		var bee: Sprite2D=bee_pool[index]
		bee.visible=true
		bee.position=event.hit-event.heading*before*(27.0 if hero else 75.0)
		bee.rotation=event.angle
		bee.modulate.a=1.0-smoothstep(0.85,1.1,before)
		(bee.material as ShaderMaterial).set_shader_parameter("team",event.tint)
		index+=1
	queue_redraw()

func _draw() -> void:
	if hero:
		var hit:=Vector2(108,-9)
		var heading:=Vector2(0.16,-1).normalized()
		draw_line(hit-heading*103,hit+heading*60,Color(0.36,0.49,0.60,0.075),14,true)
		draw_line(hit-heading*103,hit+heading*60,Color(0.37,0.49,0.57,0.23),1,true)
	for at in tower_positions:
		draw_set_transform(at-Vector2(0,3),0,Vector2(1,0.33))
		for ring in range(5):
			draw_circle(Vector2.ZERO,39-ring*3.0,Color(0.005,0.008,0.014,0.045))
	draw_set_transform(Vector2.ZERO)
	# Small local glow layers keep the bolt readable without a full-screen bloom pass.
	for event in schedule:
		var age: float=time_sec-float(event.time)
		var muzzle: Vector2=event.muzzle
		var hit: Vector2=event.hit
		var direction: Vector2=(hit-muzzle).normalized()
		var shot_color:=Color(0.70,0.90,1.0)
		if age>=-SHOT_TRAVEL and age<0:
			var travel: float=(age+SHOT_TRAVEL)/SHOT_TRAVEL
			var head: Vector2=muzzle.lerp(hit,travel)
			var tail: Vector2=head-direction*minf(19.0,muzzle.distance_to(head))
			draw_line(tail,head,Color(shot_color,0.06),9.0,true)
			draw_line(tail,head,Color(shot_color,0.20),4.5,true)
			draw_line(tail,head,Color(0.81,0.94,1,0.95),1.7,true)
			draw_line(head-direction*4,head,Color.WHITE,0.8,true)
			var muzzle_energy: float=pow(1.0-travel,2.0)
			draw_circle(muzzle,5.0,Color(shot_color,muzzle_energy*0.12))
			draw_circle(muzzle,1.6,Color(0.92,0.98,1,muzzle_energy))
		if age>=0 and age<0.105:
			var energy: float=pow(1.0-age/0.105,2.0)
			draw_line(hit-direction*8,hit+direction*12,Color(shot_color,energy*0.17),7.0,true)
			draw_line(hit-direction*4,hit+direction*8,Color(0.92,0.98,1,energy),1.7,true)
			var cross_dir:=direction.orthogonal()
			draw_line(hit-cross_dir*5,hit+cross_dir*5,Color(0.8,0.93,1,energy*0.6),0.9,true)
		if age>=0 and age<0.19:
			for i in range(3):
				var d: Vector2=direction.rotated((i-1)*0.32)
				var pos: Vector2=hit+d*(age*(105+i*32))
				draw_line(pos-d*3.0,pos,Color(0.9,0.94,1,(1.0-age/0.19)*0.7),0.65,true)
