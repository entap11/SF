class_name WorldViewportFit
extends SubViewportContainer

@export var world_viewport_path: NodePath = NodePath("WorldViewport")

# Insets (px). These define the play-surface box relative to the window.
@export var inset_left_px: float = 0.0
@export var inset_right_px: float = 0.0
@export var inset_top_px: float = 220.0
@export var inset_bottom_px: float = 180.0

# Positive values reduce the top inset (allowing overlap into the top buffer).
# Can be negative if you want extra gutter above.
@export var top_overlap_px: float = 0.0

@export var debug_print: bool = false
@export var show_debug_outline: bool = false

var root_viewport: Viewport = null
var _debug_outline: ColorRect = null

func _ready() -> void:
	if debug_print:
		print("WVF_READY:", get_path())
	root_viewport = get_viewport()
	_apply_layout()
	if root_viewport != null and not root_viewport.size_changed.is_connected(_apply_layout):
		root_viewport.size_changed.connect(_apply_layout)

func _apply_layout() -> void:
	# Explicit anchors + position/size (no gutters horizontally)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0

	var effective_top_px: float = inset_top_px - top_overlap_px
	offset_left = inset_left_px
	offset_top = effective_top_px
	offset_right = -inset_right_px
	offset_bottom = -inset_bottom_px

	clip_contents = true

	# Force the SubViewport render target to match the container rect
	var world_viewport_container: Control = self
	var subviewport_container: SubViewportContainer = self
	var sv: SubViewport = get_node_or_null(world_viewport_path) as SubViewport
	var vp_visible: Vector2 = Vector2.ZERO
	var vp: Viewport = get_viewport()
	if vp != null:
		vp_visible = vp.get_visible_rect().size
	var offs: Array = [inset_left_px, effective_top_px, inset_right_px, inset_bottom_px]
	var vp_w: float = vp_visible.x
	var vp_h: float = vp_visible.y
	var container_pos: Vector2 = Vector2(inset_left_px, effective_top_px)
	var container_size: Vector2 = Vector2(
		maxf(1.0, vp_w - inset_left_px - inset_right_px),
		maxf(1.0, vp_h - effective_top_px - inset_bottom_px)
	)
	world_viewport_container.position = container_pos
	world_viewport_container.size = container_size

	if subviewport_container != null:
		subviewport_container.stretch = true
		subviewport_container.stretch_shrink = 1
		subviewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		subviewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		subviewport_container.size = container_size
		if subviewport_container != world_viewport_container:
			subviewport_container.anchor_left = 0.0
			subviewport_container.anchor_top = 0.0
			subviewport_container.anchor_right = 1.0
			subviewport_container.anchor_bottom = 1.0
			subviewport_container.offset_left = 0.0
			subviewport_container.offset_top = 0.0
			subviewport_container.offset_right = 0.0
			subviewport_container.offset_bottom = 0.0

	var sv_size: Vector2i = Vector2i.ZERO
	if sv != null:
		var w: int = max(1, int(container_size.x))
		var h: int = max(1, int(container_size.y))
		sv_size = Vector2i(w, h)
		if sv.size != sv_size:
			sv.size = sv_size

	if show_debug_outline:
		if _debug_outline == null or not is_instance_valid(_debug_outline):
			var outline: ColorRect = ColorRect.new()
			outline.name = "WVF_DebugOutline"
			outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			outline.color = Color(1, 1, 1, 0)
			outline.z_as_relative = false
			outline.z_index = 1000
			var sb: StyleBoxFlat = StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)
			sb.set_border_width_all(2)
			sb.border_color = Color(1, 1, 1, 1)
			outline.add_theme_stylebox_override("panel", sb)
			world_viewport_container.call_deferred("add_child", outline)
			_debug_outline = outline
		if _debug_outline != null and is_instance_valid(_debug_outline):
			_debug_outline.anchor_left = 0.0
			_debug_outline.anchor_top = 0.0
			_debug_outline.anchor_right = 0.0
			_debug_outline.anchor_bottom = 0.0
			_debug_outline.position = Vector2.ZERO
			_debug_outline.size = world_viewport_container.size
	elif _debug_outline != null and is_instance_valid(_debug_outline):
		_debug_outline.queue_free()
		_debug_outline = null

	if debug_print:
		print(
			"WVF_LAYOUT:",
			get_path(),
			" vp=",
			str(vp_visible),
			" container=",
			str(container_size),
			" sv=",
			str(sv_size if sv != null else Vector2i.ZERO),
			" offs=",
			offs
		)
	if debug_print:
		call_deferred("_wvf_post_audit", vp_visible, container_size)

func _wvf_post_audit(vp_sz: Vector2, intended_container: Vector2) -> void:
	if not debug_print:
		return
	var world_viewport_container: Control = self
	var subviewport_container: SubViewportContainer = self
	var subviewport: SubViewport = get_node_or_null(world_viewport_path) as SubViewport
	var actual_c: Vector2 = world_viewport_container.size
	var actual_sv: Vector2 = Vector2(-1, -1)
	if subviewport != null:
		actual_sv = Vector2(float(subviewport.size.x), float(subviewport.size.y))
	var actual_svc: Vector2 = Vector2(-1, -1)
	if subviewport_container != null:
		actual_svc = subviewport_container.size
	print(
		"WVF_POST:",
		get_path(),
		" vp=",
		vp_sz,
		" intended_container=",
		intended_container,
		" actual_container=",
		actual_c,
		" sv=",
		actual_sv,
		" svc=",
		actual_svc,
		" c_gt=",
		world_viewport_container.get_global_transform_with_canvas()
	)
	# --- Camera framing audit (read-only) ---
	if is_instance_valid(subviewport):
		var cam: Camera2D = subviewport.get_camera_2d()
		if cam != null:
			var limits: Vector4 = Vector4(
				cam.limit_left,
				cam.limit_top,
				cam.limit_right,
				cam.limit_bottom
			)
			print(
				"WVF_CAM:",
				" cam_path=",
				cam.get_path(),
				" pos=",
				cam.global_position,
				" zoom=",
				cam.zoom,
				" rot=",
				cam.global_rotation,
				" limits(LTRB)=",
				limits,
				" screen_center=",
				cam.get_screen_center_position()
			)
		else:
			print("WVF_CAM: <no Camera2D active in subviewport>")
	# --- Rect + world-scale audit (read-only) ---
	if is_instance_valid(world_viewport_container) and (world_viewport_container is Control):
		var cgr: Rect2 = (world_viewport_container as Control).get_global_rect()
		print("WVF_RECTS: container_global_rect=", cgr)

	if is_instance_valid(subviewport_container) and (subviewport_container is Control):
		var sgr: Rect2 = (subviewport_container as Control).get_global_rect()
		print(
			"WVF_RECTS: svc_global_rect=",
			sgr,
			" svc_scale=",
			(subviewport_container as Control).scale
		)

	# --- World root audit: Arena / MapRoot scale + rough bounds ---
	if is_instance_valid(subviewport):
		var arena: Node = subviewport.get_node_or_null("Arena")
		if arena != null and (arena is Node2D):
			var a2: Node2D = arena as Node2D
			print("WVF_WORLD: Arena scale=", a2.scale, " gp=", a2.global_position)

			var map_root: Node = a2.get_node_or_null("MapRoot")
			if map_root != null and (map_root is Node2D):
				var mr: Node2D = map_root as Node2D
				print("WVF_WORLD: MapRoot scale=", mr.scale, " gp=", mr.global_position)

				var grid: Node = mr.get_node_or_null("Grid")
				if grid != null and (grid is Node2D):
					var g: Node2D = grid as Node2D
					print("WVF_WORLD: Grid scale=", g.scale, " gp=", g.global_position)
		else:
			print("WVF_WORLD: Arena node not found at subviewport/Arena")
	# schedule a late audit (after map apply / one or two frames)
	call_deferred("_wvf_late_world_bounds_audit")

func _wvf_late_world_bounds_audit() -> void:
	# wait a couple frames so MAP_APPLY has definitely run
	await get_tree().process_frame
	await get_tree().process_frame

	var subviewport: SubViewport = get_node_or_null(world_viewport_path) as SubViewport
	if not is_instance_valid(subviewport):
		print("WVF_BOUNDS: <no subviewport>")
		return

	var arena: Node = subviewport.get_node_or_null("Arena")
	if arena == null:
		print("WVF_BOUNDS: <no Arena>")
		return

	var map_root: Node = arena.get_node_or_null("MapRoot")
	if map_root == null:
		print("WVF_BOUNDS: <no MapRoot>")
		return

	var min_v: Vector2 = Vector2(INF, INF)
	var max_v: Vector2 = Vector2(-INF, -INF)
	var count: int = 0

	# track a few worst offenders by distance from origin
	var offenders: Array = [] # each: { "d": float, "p": Vector2, "path": NodePath, "name": String }

	var _push_offender: Callable = func(n: Node2D, p: Vector2) -> void:
		var d: float = p.length()
		offenders.append({ "d": d, "p": p, "path": n.get_path(), "name": n.name })
		offenders.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["d"] > b["d"])
		if offenders.size() > 8:
			offenders.resize(8)

	var stack: Array[Node] = [map_root]
	while stack.size() > 0:
		var n: Node = stack.pop_back() as Node
		for c in n.get_children():
			if c is Node:
				stack.append(c)

		if n is Node2D and not (n is Camera2D):
			var n2: Node2D = n as Node2D
			var p: Vector2 = n2.global_position
			if is_finite(p.x) and is_finite(p.y):
				min_v.x = min(min_v.x, p.x)
				min_v.y = min(min_v.y, p.y)
				max_v.x = max(max_v.x, p.x)
				max_v.y = max(max_v.y, p.y)
				count += 1

				# If it's far away or suspicious sentinel-ish, record it
				if abs(p.x) > 5000.0 or abs(p.y) > 5000.0 or (p.x <= -99990.0 and p.y <= -99990.0):
					_push_offender.call(n2, p)

	if count == 0:
		print("WVF_BOUNDS: <no Node2D points under MapRoot>")
		return

	var size: Vector2 = max_v - min_v
	print(
		"WVF_BOUNDS:",
		" node2d_count=",
		count,
		" min=",
		min_v,
		" max=",
		max_v,
		" size=",
		size
	)
	var center: Vector2 = (min_v + max_v) * 0.5
	var cam: Camera2D = subviewport.get_camera_2d()
	if cam != null:
		print(
			"WVF_CENTER:",
			" board_center=",
			center,
			" cam_pos=",
			cam.global_position,
			" cam_screen_center=",
			cam.get_screen_center_position(),
			" zoom=",
			cam.zoom
		)
	else:
		print("WVF_CENTER: <no camera>")

	if offenders.size() > 0:
		print("WVF_OFFENDERS (furthest / suspicious):")
		for o in offenders:
			print("  - d=", o["d"], " p=", o["p"], " name=", o["name"], " path=", o["path"])
