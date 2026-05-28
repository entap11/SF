extends Node2D

const BEE_TEXTURE: Texture2D = preload("res://assets/sprites/sf_skin_v1/mvp_unit2.png")

const MAX_VISIBLE_BEES: int = 9
const NUMBER_LABEL_SIZE: Vector2 = Vector2(93.6, 60.0)
const NUMBER_FONT_SIZE: int = 38
const BEE_SIZE_PX: float = 43.2
const BEE_OUTLINE_SCALE_MULT: float = 1.32
const BEE_OUTLINE_COLOR: Color = Color(0.02, 0.02, 0.03, 0.98)
const BEE_GLOW_SCALE_MULT: float = 1.72
const BEE_GLOW_ALPHA_MIN: float = 0.18
const BEE_GLOW_ALPHA_MAX: float = 0.42
const BEE_SPRITE_FORWARD_DEG: float = 90.0
const ORBIT_RADIUS_MIN_PX: float = 28.8
const ORBIT_RADIUS_MAX_PX: float = 40.8
const ORBIT_SPEED_BASE: float = 1.85
const ORBIT_SPEED_VARIANCE: float = 0.38
const WOBBLE_AMPLITUDE_PX: float = 2.2
const WOBBLE_SPEED_BASE: float = 5.4
const WOBBLE_SPEED_VARIANCE: float = 1.6
const PULSE_SPEED: float = 4.8
const PULSE_SCALE_AMOUNT: float = 0.055

var _swarm_power: int = 0
var _team_color: Color = Color.WHITE
var _target_direction: Vector2 = Vector2.RIGHT
var _bee_roots: Array[Node2D] = []
var _number_label: Label = null
var _orbit_root: Node2D = null


func _ready() -> void:
	_ensure_children()
	_apply_team_color()
	_sync_bees()
	set_process(true)


func set_swarm_power(value: int) -> void:
	var next_power: int = maxi(0, value)
	if _swarm_power == next_power:
		return
	_swarm_power = next_power
	_update_number_label()
	_sync_bees()


func set_team_color(color: Color) -> void:
	if _team_color.is_equal_approx(color):
		return
	_team_color = color
	_apply_team_color()


func set_target_direction(direction: Vector2) -> void:
	if direction.length_squared() <= 0.000001:
		return
	var normalized := direction.normalized()
	if _target_direction.is_equal_approx(normalized):
		return
	_target_direction = normalized


func _process(_delta: float) -> void:
	var count: int = _bee_roots.size()
	if count <= 0:
		return
	var now_s: float = float(Time.get_ticks_msec()) / 1000.0
	var pulse: float = 0.5 + 0.5 * sin(now_s * PULSE_SPEED)
	scale = Vector2.ONE * (1.0 + PULSE_SCALE_AMOUNT * pulse)
	var bee_rotation: float = _target_direction.angle() + deg_to_rad(BEE_SPRITE_FORWARD_DEG)
	for index in range(count):
		var bee_root: Node2D = _bee_roots[index]
		if bee_root == null:
			continue
		var base_angle: float = TAU * float(index) / float(count)
		var seed: float = _bee_seed(index)
		var orbit_speed: float = ORBIT_SPEED_BASE + lerpf(-ORBIT_SPEED_VARIANCE, ORBIT_SPEED_VARIANCE, seed)
		var wobble_seed: float = _bee_seed(index + 17)
		var radius: float = lerpf(ORBIT_RADIUS_MIN_PX, ORBIT_RADIUS_MAX_PX, wobble_seed)
		var phase: float = TAU * _bee_seed(index + 31)
		var wobble_speed: float = WOBBLE_SPEED_BASE + WOBBLE_SPEED_VARIANCE * _bee_seed(index + 43)
		var wobble: float = sin(now_s * wobble_speed + phase) * WOBBLE_AMPLITUDE_PX
		var angle: float = base_angle + now_s * orbit_speed + sin(now_s * 1.7 + phase) * 0.12
		var radial: float = radius + wobble
		var pos: Vector2 = Vector2(cos(angle), sin(angle)) * radial
		bee_root.position = pos
		bee_root.rotation = bee_rotation
		_apply_bee_glow_pulse(bee_root, pulse)


func _ensure_children() -> void:
	if _number_label == null:
		_number_label = get_node_or_null("NumberLabel") as Label
	if _number_label == null:
		_number_label = Label.new()
		_number_label.name = "NumberLabel"
		add_child(_number_label)
	_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number_label.size = NUMBER_LABEL_SIZE
	_number_label.position = -NUMBER_LABEL_SIZE * 0.5
	_number_label.z_index = 2
	_number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_number_label.add_theme_font_size_override("font_size", NUMBER_FONT_SIZE)
	_number_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.95))
	_number_label.add_theme_constant_override("outline_size", 5)

	if _orbit_root == null:
		_orbit_root = get_node_or_null("BeeOrbitRoot") as Node2D
	if _orbit_root == null:
		_orbit_root = Node2D.new()
		_orbit_root.name = "BeeOrbitRoot"
		add_child(_orbit_root)
	_orbit_root.z_index = 1

	_update_number_label()


func _sync_bees() -> void:
	_ensure_children()
	var visible_count: int = mini(_swarm_power, MAX_VISIBLE_BEES)
	while _bee_roots.size() < visible_count:
		_bee_roots.append(_create_bee_root(_bee_roots.size()))
	while _bee_roots.size() > visible_count:
		var bee_root: Node2D = _bee_roots.pop_back()
		if bee_root != null:
			bee_root.queue_free()
	_apply_team_color()


func _create_bee_root(index: int) -> Node2D:
	var bee_root := Node2D.new()
	bee_root.name = "Bee_%02d" % index
	bee_root.z_index = 1

	var outline_sprite := Sprite2D.new()
	outline_sprite.name = "BeeOutline"
	outline_sprite.centered = true
	outline_sprite.texture = BEE_TEXTURE
	outline_sprite.self_modulate = BEE_OUTLINE_COLOR
	outline_sprite.z_index = 0

	var glow_sprite := Sprite2D.new()
	glow_sprite.name = "BeeGlow"
	glow_sprite.centered = true
	glow_sprite.texture = BEE_TEXTURE
	glow_sprite.self_modulate = _bee_glow_color(0.0)
	glow_sprite.z_index = -1

	var sprite := Sprite2D.new()
	sprite.name = "BeeSprite"
	sprite.centered = true
	sprite.texture = BEE_TEXTURE
	sprite.self_modulate = _bee_color()
	sprite.z_index = 1
	var tex_size: Vector2 = BEE_TEXTURE.get_size()
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		var base_scale := Vector2(BEE_SIZE_PX / tex_size.x, BEE_SIZE_PX / tex_size.y)
		glow_sprite.scale = base_scale * BEE_GLOW_SCALE_MULT
		outline_sprite.scale = base_scale * BEE_OUTLINE_SCALE_MULT
		sprite.scale = base_scale
	bee_root.add_child(glow_sprite)
	bee_root.add_child(outline_sprite)
	bee_root.add_child(sprite)
	_orbit_root.add_child(bee_root)
	return bee_root


func _update_number_label() -> void:
	if _number_label == null:
		return
	_number_label.text = str(_swarm_power)


func _apply_team_color() -> void:
	if _number_label != null:
		var label_color: Color = _team_color.lightened(0.22)
		label_color.a = 1.0
		_number_label.add_theme_color_override("font_color", label_color)
	var bee_color: Color = _bee_color()
	for bee_root in _bee_roots:
		if bee_root == null:
			continue
		var sprite := bee_root.get_node_or_null("BeeSprite") as Sprite2D
		if sprite != null:
			sprite.self_modulate = bee_color
		var outline_sprite := bee_root.get_node_or_null("BeeOutline") as Sprite2D
		if outline_sprite != null:
			outline_sprite.self_modulate = BEE_OUTLINE_COLOR
		var glow_sprite := bee_root.get_node_or_null("BeeGlow") as Sprite2D
		if glow_sprite != null:
			glow_sprite.self_modulate = _bee_glow_color(0.0)


func _bee_color() -> Color:
	var color: Color = _team_color
	color.a = 1.0
	return color


func _bee_glow_color(pulse: float) -> Color:
	var color: Color = _team_color.lightened(0.35)
	color.a = lerpf(BEE_GLOW_ALPHA_MIN, BEE_GLOW_ALPHA_MAX, clampf(pulse, 0.0, 1.0))
	return color


func _apply_bee_glow_pulse(bee_root: Node2D, pulse: float) -> void:
	var glow_sprite := bee_root.get_node_or_null("BeeGlow") as Sprite2D
	if glow_sprite == null:
		return
	glow_sprite.self_modulate = _bee_glow_color(pulse)


func _bee_seed(index: int) -> float:
	var value: int = (index + 1) * 1103515245 + 12345
	value = int(value & 0x7fffffff)
	return float(value % 1000) / 999.0
