@tool
extends Node2D
## Continuous chitin/metal wall, with details spaced by distance along the path.
## All inputs are read-only projections of the authoritative barrier segments.
var points := PackedVector2Array()
var _seam: Line2D
var _pulse := 0.0
var _last_energy := -1.0

func setup(vertices: PackedVector2Array, start_cap: bool, end_cap: bool) -> void:
	points = vertices
	_line("GroundShadow", 28.0, Color(0.005, 0.008, 0.012, 0.28), Vector2(8, 5), -9)
	_line("ContactShadow", 21.0, Color(0.005, 0.008, 0.012, 0.65), Vector2(2, 2), -9)
	_line("Foundation", 20.0, Color("181d26"), Vector2.ZERO, -8)
	_line("FoundationBevel", 16.5, Color("424c5a"), Vector2(-0.5, -0.8), -7)
	_line("SideFace", 14.0, Color("111620"), Vector2(0, -3), -6)
	_line("TopRim", 14.0, Color("687582"), Vector2(-0.7, -8), -5)
	_line("TopPlate", 11.5, Color("343f4d"), Vector2(0, -7.4), -4)
	_line("InsetChannel", 5.0, Color("151c26"), Vector2(0, -7.2), -3)
	_seam = _line("EnergySeam", 1.6, Color(0.53, 0.64, 0.71, 0.66), Vector2(0, -7.2), -2)
	# Details are independent of how many vertices the artist needed to draw.
	var distance_to_next := 96.0
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		while distance_to_next < length:
			_brace(a.lerp(b, distance_to_next / length), (b - a).angle(), false)
			distance_to_next += 144.0
		distance_to_next -= length
	if start_cap: _brace(points[0], (points[1] - points[0]).angle(), true)
	if end_cap: _brace(points[-1], (points[-1] - points[-2]).angle(), true)

func _line(label: String, width: float, color: Color, offset: Vector2, depth: int) -> Line2D:
	var line := Line2D.new()
	line.name = label
	line.points = points
	line.width = width
	line.default_color = color
	line.position = offset
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.round_precision = 8
	line.antialiased = true
	line.z_as_relative = false
	line.z_index = depth
	add_child(line)
	return line

func _brace(p: Vector2, angle: float, terminal: bool) -> void:
	var brace := Node2D.new()
	brace.position = p + Vector2(0, -5)
	brace.rotation = angle
	brace.z_as_relative = false
	brace.z_index = -1
	add_child(brace)
	var half_width := 8.0 if terminal else 3.5
	_polygon(brace, PackedVector2Array([Vector2(-half_width - 2, -12), Vector2(half_width, -12), Vector2(half_width + 3, -7), Vector2(half_width + 3, 10), Vector2(-half_width, 10), Vector2(-half_width - 2, 5)]), Color("111722"))
	_polygon(brace, PackedVector2Array([Vector2(-half_width, -11), Vector2(half_width - 1, -11), Vector2(half_width + 1, -7), Vector2(half_width + 1, 5), Vector2(-half_width, 5)]), Color("536171"))
	_polygon(brace, PackedVector2Array([Vector2(-half_width + 1, -8), Vector2(half_width - 1, -8), Vector2(half_width - 1, 4), Vector2(-half_width + 1, 4)]), Color("293543"))
	if terminal:
		_polygon(brace, PackedVector2Array([Vector2(-3, -4), Vector2(3, -4), Vector2(3, 0), Vector2(-3, 0)]), Color("c5ab69"))

func _polygon(parent: Node2D, vertices: PackedVector2Array, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = vertices
	poly.color = color
	poly.antialiased = true
	parent.add_child(poly)

func trigger_block_pulse(_kind: String) -> void:
	_pulse = 1.0

func tick_visuals(delta: float) -> void:
	_pulse = maxf(0.0, _pulse - maxf(delta, 0.0) * 1.35)
	if is_equal_approx(_pulse, _last_energy) or _seam == null: return
	_last_energy = _pulse
	_seam.default_color = Color(0.53, 0.64, 0.71, 0.66).lerp(Color(0.96, 0.84, 0.54, 1), _pulse * _pulse)
