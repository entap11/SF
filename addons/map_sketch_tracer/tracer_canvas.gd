@tool
extends Control
class_name MapSketchCanvas

const Compiler = preload("res://tools/map_sketch_compile.gd")
const Layout = preload("res://scripts/maps/map_layout_contract.gd")
const Finalizer = preload("res://tools/map_authoring_finalize_lib.gd")
const WallRendererScript = preload("res://scripts/renderers/wall_renderer.gd")
const COLS := 18
const ROWS := 28
const AUTOSAVE := "user://map_sketch_draft_v2.json"

signal status_changed(message: String)
signal hover_changed(message: String)
signal draft_changed

var draft: Dictionary = new_draft()
var mode := "select"
var place_type := "hive"
var place_owner := "P1"
var preview_mode := "layout"
var show_connections := false
var show_barriers := true
var sketch_texture: Texture2D
var sketch_opacity := 0.35
var zoom := 1.0
var pan := Vector2.ZERO
var _stroke: Array = []
var _drag_index := -1
var _selected_node := -1
var _selected_wall := -1
var _selected_slot := -1
var _drag_slot := -1
var _panning := false
var _align_first := Vector2(-1, -1)
var _history: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _compiled: Dictionary = {}
var _issues: Array = []
var _connections: Array = []
var _walls: Node2D
var _barrier_overlay: Node2D
var _dirty := true

static func new_draft() -> Dictionary:
	return {"_schema": "swarmfront.map.draft.v1", "id": "MAP_custom__SBASE__1p", "name": "Untitled map",
		"map_usage": "campaign", "mode": "1p", "layout_symmetry": {"kind": "none", "center": [8.5, 13.5]},
		"defaults": {"player_start_power": 10, "npc_start_power": 5}, "nodes": [], "structure_slots": [],
		"authoring": {"single_sector": false, "wall_strokes": []}}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_walls = WallRendererScript.new()
	add_child(_walls)
	_barrier_overlay = Node2D.new()
	_barrier_overlay.z_index = 100
	add_child(_barrier_overlay)
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: queue_redraw()

func _scale_factor() -> float:
	return maxf(1.0, minf((size.x - 44.0) / COLS, (size.y - 44.0) / ROWS)) * zoom

func _origin() -> Vector2:
	return (size - Vector2(COLS, ROWS) * _scale_factor()) * 0.5 + pan

func _screen(p: Vector2) -> Vector2:
	return _origin() + (p + Vector2(0.5, 0.5)) * _scale_factor()

func _grid(p: Vector2) -> Vector2:
	return (p - _origin()) / _scale_factor() - Vector2(0.5, 0.5)

func _inside(p: Vector2) -> bool:
	return p.x >= -0.5 and p.y >= -0.5 and p.x < COLS - 0.5 and p.y < ROWS - 0.5

func set_mode(value: String) -> void:
	mode = value
	_stroke.clear()
	_align_first = Vector2(-1, -1)
	queue_redraw()

func set_place_type(value: String) -> void: place_type = value
func set_place_owner(value: String) -> void: place_owner = value
func set_sketch_opacity(value: float) -> void:
	sketch_opacity = value
	queue_redraw()
func clear_sketch() -> void:
	_checkpoint()
	sketch_texture = null
	draft.authoring.erase("sketch_path")
	_changed()

func set_policy(usage: String, symmetry: String) -> void:
	_checkpoint()
	draft.map_usage = usage
	draft.layout_symmetry = {"kind": symmetry, "center": draft.layout_symmetry.get("center", [8.5, 13.5])}
	draft.authoring.single_sector = symmetry != "none"
	var count: int = Layout.PRESETS.get(symmetry, []).size()
	draft.mode = "4p" if count == 4 else "1p"
	draft.player_buckets = ["4P_FFA", "2V2"] if count == 4 else ["1P"]
	draft.strict_player_buckets = true
	_changed()

func load_sketch(path: String) -> bool:
	var img := Image.new()
	if img.load(path) != OK:
		status_changed.emit("Could not open sketch")
		return false
	sketch_texture = ImageTexture.create_from_image(img)
	draft.authoring.sketch_path = path
	draft.authoring.erase("sketch_crop")
	_changed()
	status_changed.emit("Sketch loaded. Use Align sketch to crop screenshot margins; click opposite grid corners.")
	return true

func load_draft(path: String) -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("authoring") is Dictionary or not data.get("nodes") is Array:
		status_changed.emit("Choose an authoring draft, not a compiled map")
		return false
	var base := new_draft()
	for key in ["authoring", "layout_symmetry", "defaults"]:
		if data.has(key) and not data[key] is Dictionary:
			status_changed.emit("Invalid draft field: " + key)
			return false
		var value: Dictionary = base[key].duplicate(true)
		value.merge(data.get(key, {}), true)
		data[key] = value
	base.merge(data, true)
	var compiled: Dictionary = Compiler.compile(base)
	if not compiled.ok:
		status_changed.emit("Cannot open draft: " + "; ".join(compiled.errors))
		return false
	_checkpoint()
	draft = base
	_reset_selection()
	_changed()
	return true

func save_draft(path: String) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(draft, "  ") + "\n")
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK

func _checkpoint() -> void:
	_history.append(draft.duplicate(true))
	if _history.size() > 60: _history.pop_front()
	_redo.clear()

func undo() -> void:
	if _history.is_empty(): return
	_redo.append(draft.duplicate(true))
	draft = _history.pop_back()
	_reset_selection()
	_changed()

func redo() -> void:
	if _redo.is_empty(): return
	_history.append(draft.duplicate(true))
	draft = _redo.pop_back()
	_reset_selection()
	_changed()

func _reset_selection() -> void:
	_selected_node = -1
	_selected_wall = -1
	_selected_slot = -1
	_drag_index = -1
	_drag_slot = -1
	_stroke.clear()
	var sketch: String = str(draft.get("authoring", {}).get("sketch_path", ""))
	sketch_texture = null
	if FileAccess.file_exists(sketch):
		var img := Image.new()
		if img.load(sketch) == OK: sketch_texture = ImageTexture.create_from_image(img)

func _changed() -> void:
	_dirty = true
	_refresh()
	draft_changed.emit()
	if not save_draft(AUTOSAVE): status_changed.emit("Draft autosave failed. Save a draft before closing.")

func _refresh() -> void:
	var result: Dictionary = Compiler.compile(draft)
	_compiled = result.get("data", {})
	_issues = result.get("errors", []).duplicate()
	if not _compiled.is_empty():
		_issues.append_array(Layout.validate(_compiled).errors)
	_connections.clear()
	if show_connections and not _compiled.is_empty():
		# Preview uses the real loader conversion and GameState connection rule.
		var Loader = preload("res://scripts/maps/map_loader.gd")
		var expanded: Dictionary = Loader._expand_v1xy_compact_if_needed(_compiled, "authoring-preview")
		var model: Dictionary = Loader._load_v1xy(expanded, "authoring-preview")
		if not model.is_empty():
			var state := GameState.new()
			state.load_from_map_dict(model)
			for a in state.hives:
				for b in state.hives:
					if a.id < b.id and state.can_connect(a.id, b.id):
						_connections.append([state._hive_render_grid_pos(a), state._hive_render_grid_pos(b)])
	_dirty = true
	queue_redraw()

func validate_map(_map_name: String = "", _description: String = "") -> Dictionary:
	var result: Dictionary = Finalizer.finalize_map(draft)
	if result.ok:
		var path := "user://map_studio_validation.json"
		var runtime_check: Dictionary = Finalizer.save_json(path, result.data)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if not runtime_check.ok:
			result.ok = false
			result.errors.append(str(runtime_check.err))
	return result

func export_json(_map_name: String = "", _description: String = "") -> String:
	var result := validate_map()
	return JSON.stringify(result.data, "  ") if result.ok else ""

func export_json_to_path(path: String, _map_name: String = "", _description: String = "") -> bool:
	var result := validate_map()
	if not result.ok:
		status_changed.emit("Export blocked: " + "; ".join(result.errors))
		return false
	var saved: Dictionary = Finalizer.save_json(path, result.data)
	status_changed.emit("Validated map exported: " + path if saved.ok else "Export blocked: " + str(saved.err))
	return saved.ok

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var p := _grid(event.position)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = minf(4, zoom * 1.12)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = maxf(0.5, zoom / 1.12)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_MIDDLE: _panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_stroke.clear()
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			if mode == "align" and event.pressed:
				_align_click(event.position)
			elif event.pressed and _inside(p):
				if mode in ["curve", "straight"]: _stroke = [[p.x, p.y]]
				elif mode == "corners": _stroke.append([p.x, p.y])
				elif mode == "place": _place(p.round() if place_type == "slot" else p.snapped(Vector2(0.5, 0.5)))
				else: _select(p)
			elif not event.pressed:
				if mode in ["curve", "straight"]: _finish_stroke()
				if _drag_index >= 0 or _drag_slot >= 0:
					_drag_index = -1
					_drag_slot = -1
					_changed()
	elif event is InputEventMouseMotion:
		var p := _grid(event.position)
		var hive_point := p.snapped(Vector2(0.5, 0.5))
		hover_changed.emit("Cell %s, %s" % [hive_point.x, hive_point.y])
		if _panning: pan += event.relative
		elif _inside(p):
			if _drag_index >= 0:
				draft.nodes[_drag_index].pos = {"x": hive_point.x, "y": hive_point.y}
				_refresh()
			elif _drag_slot >= 0:
				draft.structure_slots[_drag_slot].pos = {"x": roundi(p.x), "y": roundi(p.y)}
				_refresh()
			elif mode in ["curve", "straight"] and not _stroke.is_empty():
				if Layout.point(_stroke[-1]).distance_to(p) > 0.10: _stroke.append([p.x, p.y])
		queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not has_focus() or not event is InputEventKey or not event.pressed: return
	if event.keycode == KEY_ENTER: _finish_stroke()
	elif event.keycode == KEY_ESCAPE:
		_stroke.clear()
		queue_redraw()
	elif event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		_checkpoint()
		if _selected_node >= 0 and _selected_node < draft.nodes.size(): draft.nodes.remove_at(_selected_node)
		elif _selected_wall >= 0 and _selected_wall < draft.authoring.wall_strokes.size(): draft.authoring.wall_strokes.remove_at(_selected_wall)
		elif _selected_slot >= 0 and _selected_slot < draft.structure_slots.size(): draft.structure_slots.remove_at(_selected_slot)
		_reset_selection()
		_changed()
	elif event.keycode == KEY_Z and (event.ctrl_pressed or event.meta_pressed):
		if event.shift_pressed: redo()
		else: undo()

func _place(p: Vector2) -> void:
	_checkpoint()
	var id := "h_%d" % Time.get_ticks_usec()
	if place_type == "slot":
		draft.structure_slots.append({"id": id, "pos": {"x": p.x, "y": p.y}, "allowed": ["tower", "barracks"]})
	else:
		draft.nodes.append({"id": id, "kind": "hive", "pos": {"x": p.x, "y": p.y}, "owner": "NPC" if place_type == "npc" else place_owner})
	_changed()

func _select(p: Vector2) -> void:
	_selected_node = -1
	_selected_wall = -1
	_selected_slot = -1
	for i in range(draft.nodes.size()):
		if Layout.point(draft.nodes[i]).distance_to(p) < 0.65:
			_checkpoint()
			_selected_node = i
			_drag_index = i
			return
	for i in range(draft.structure_slots.size()):
		if Layout.point(draft.structure_slots[i]).distance_to(p) < 0.65:
			_checkpoint()
			_selected_slot = i
			_drag_slot = i
			return
	var closest := 0.5
	for i in range(draft.authoring.wall_strokes.size()):
		var pts: Array = draft.authoring.wall_strokes[i].points
		for j in range(pts.size() - 1):
			var distance: float = Layout.Schema._point_segment_distance(p, Layout.point(pts[j]), Layout.point(pts[j + 1]))
			if distance < closest:
				closest = distance
				_selected_wall = i
	queue_redraw()

func _finish_stroke() -> void:
	if _stroke.size() < 2:
		_stroke.clear()
		return
	_checkpoint()
	if mode == "straight": _stroke = [_stroke[0], _stroke[-1]]
	draft.authoring.wall_strokes.append({"id": "wall_%d" % Time.get_ticks_usec(), "points": _stroke.duplicate(true), "smooth": mode == "curve"})
	_stroke.clear()
	_changed()

func _image_rect() -> Rect2:
	var image_size := Vector2(sketch_texture.get_size())
	var factor := minf(size.x / image_size.x, size.y / image_size.y)
	return Rect2((size - image_size * factor) / 2, image_size * factor)

func _align_click(p: Vector2) -> void:
	if sketch_texture == null: return
	var rect := _image_rect()
	if not rect.has_point(p): return
	var pixel := (p - rect.position) / rect.size * Vector2(sketch_texture.get_size())
	if _align_first.x < 0:
		_align_first = pixel
		status_changed.emit("Now click the opposite corner of the drawing grid")
	else:
		var minimum := _align_first.min(pixel)
		var extent := (_align_first - pixel).abs()
		if extent.x < 10 or extent.y < 10: return
		draft.authoring.sketch_crop = [minimum.x, minimum.y, extent.x, extent.y]
		mode = "select"
		_changed()
		status_changed.emit("Sketch aligned to 18×28")

func _draw() -> void:
	var origin := _origin()
	var cell := _scale_factor()
	var board := Rect2(origin, Vector2(COLS, ROWS) * cell)
	draw_rect(Rect2(Vector2.ZERO, size), Color("10141c"))
	if mode == "align" and sketch_texture != null:
		draw_texture_rect(sketch_texture, _image_rect(), false)
		if _walls != null: _walls.visible = false
		return
	draw_rect(board, Color("202936"))
	if sketch_texture != null and preview_mode == "sketch":
		var crop: Array = draft.authoring.get("sketch_crop", [0, 0, sketch_texture.get_width(), sketch_texture.get_height()])
		draw_texture_rect_region(sketch_texture, board, Rect2(crop[0], crop[1], crop[2], crop[3]), Color(1, 1, 1, sketch_opacity))
	for x in range(COLS + 1): draw_line(origin + Vector2(x * cell, 0), origin + Vector2(x * cell, ROWS * cell), Color(0.5, 0.6, 0.75, 0.10))
	for y in range(ROWS + 1): draw_line(origin + Vector2(0, y * cell), origin + Vector2(COLS * cell, y * cell), Color(0.5, 0.6, 0.75, 0.10))
	var font := ThemeDB.fallback_font
	for x in range(COLS): draw_string(font, origin + Vector2((x + 0.3) * cell, -4), str(x), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8091a6"))
	for y in range(ROWS): draw_string(font, origin + Vector2(-20, (y + 0.65) * cell), str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8091a6"))
	for connection in _connections: draw_line(_screen(connection[0]), _screen(connection[1]), Color(0.3, 0.9, 0.75, 0.25), 1, true)
	var segments: Array = Layout.walls(_compiled)
	if _walls != null:
		_walls.visible = preview_mode == "finished"
		if _dirty:
			var world: Array = []
			for segment in segments: world.append({"a": segment.a * 64, "b": segment.b * 64})
			_walls.set_wall_segments(world)
			_raise_preview_layers(_walls)
			for child in _barrier_overlay.get_children(): child.free()
			for segment in world:
				var line := Line2D.new()
				line.points = PackedVector2Array([segment.a, segment.b])
				line.width = 2.5
				line.default_color = Color("e6b76c")
				line.antialiased = true
				_barrier_overlay.add_child(line)
			_dirty = false
		_walls.position = origin + Vector2(0.5, 0.5) * cell
		_walls.scale = Vector2.ONE * cell / 64.0
		_barrier_overlay.position = _walls.position
		_barrier_overlay.scale = _walls.scale
		_barrier_overlay.visible = show_barriers and preview_mode == "finished"
	if preview_mode != "finished" or show_barriers:
		for segment in segments: draw_line(_screen(segment.a), _screen(segment.b), Color("e6b76c"), 2.0, true)
	for hive in Layout.hive_entries(_compiled):
		var color: Color = [Color("91a3ba"), Color("e9b852"), Color("ec757a"), Color("71aef2"), Color("8ac997")][clampi(hive.owner, 0, 4)]
		draw_circle(_screen(hive.pos), cell * 0.30, color)
		draw_arc(_screen(hive.pos), cell * 0.40, 0, TAU, 24, color.darkened(0.4), 1, true)
		if hive.owner > 0: draw_string(font, _screen(hive.pos) + Vector2(-6, -cell * 0.5), "P%d" % hive.owner, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
	for slot in _compiled.get("structure_slots", []): draw_rect(Rect2(_screen(Layout.point(slot)) - Vector2.ONE * cell * 0.25, Vector2.ONE * cell * 0.5), Color("a994d0"), false, 2)
	if _selected_node >= 0 and _selected_node < draft.nodes.size(): draw_circle(_screen(Layout.point(draft.nodes[_selected_node])), cell * 0.5, Color.WHITE, false, 2)
	if _selected_slot >= 0 and _selected_slot < draft.structure_slots.size(): draw_circle(_screen(Layout.point(draft.structure_slots[_selected_slot])), cell * 0.5, Color.WHITE, false, 2)
	if preview_mode == "sketch" or _selected_wall >= 0:
		for i in range(draft.authoring.wall_strokes.size()):
			if preview_mode != "sketch" and i != _selected_wall: continue
			var pts: Array = draft.authoring.wall_strokes[i].points
			for j in range(pts.size() - 1): draw_line(_screen(Layout.point(pts[j])), _screen(Layout.point(pts[j + 1])), Color(0.6, 0.75, 1, 0.65), 1, true)
	for i in range(_stroke.size() - 1): draw_line(_screen(Layout.point(_stroke[i])), _screen(Layout.point(_stroke[i + 1])), Color.WHITE, 2, true)

func _raise_preview_layers(node: Node) -> void:
	# The editor Control draws its floor at z=0; lift presentation children only.
	for child in node.get_children():
		if child is CanvasItem and not child.z_as_relative:
			child.z_index += 20
			child.z_as_relative = true
		_raise_preview_layers(child)
