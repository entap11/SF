class_name HiveRenderer
extends Node2D

const SFLog := preload("res://scripts/util/sf_log.gd")
const MapSchema := preload("res://scripts/maps/map_schema.gd")
const HiveNodeScene := preload("res://scenes/hive/HiveNode.tscn")
const SpriteRegistry := preload("res://scripts/renderers/sprite_registry.gd")
const HiveVisual := preload("res://scripts/hive/hive_visual.gd")

var state: Object
var sel: Object
var arena: Node2D
var model: Dictionary = {}
var hive_nodes_by_id: Dictionary = {}

const POWER_LABEL_FONT_SIZE := 14
const POWER_LABEL_COLOR := Color(1.0, 1.0, 1.0)
const P1_TEXT_COLOR := Color(0.0, 0.0, 0.0)
const P2_TEXT_COLOR := Color(1.0, 1.0, 1.0)
const HIVE_COLOR_LOG_LIMIT := 10

@export var cell_px: float = 64.0
@export var animations_enabled := true

const HEARTBEAT_HZ := 20.0
const HEARTBEAT_DT := 1.0 / HEARTBEAT_HZ
var _heartbeat_accum := 0.0
var _last_render_version := -1
var _dirty: bool = true
var _color_log_remaining := 0
var _color_log_hive_ids: Dictionary = {}
var _color_log_key := ""
var _selected_hive_id: int = -1
var _selected_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _sprite_registry: SpriteRegistry = null

func setup(state_ref: Object, sel_ref: Object, arena_ref: Node2D) -> void:
	state = state_ref
	sel = sel_ref
	arena = arena_ref
	_dirty = true
	_last_render_version = -1
	_connect_selection_signal()
	queue_redraw()

func set_model(m: Dictionary) -> void:
	SFLog.log_once("hive_renderer_set_model_stack", "HiveRenderer set_model called by:\n%s" % [str(get_stack())], SFLog.Level.TRACE)
	model = m
	_sync_hive_nodes(m)
	_dirty = true
	queue_redraw()

func clear_all() -> void:
	model = {}
	_dirty = true
	queue_redraw()
	_clear_hive_nodes()
	SFLog.log_once("hive_renderer_cleared", "HiveRenderer: cleared", SFLog.Level.DEBUG)

func get_hive_nodes_by_id() -> Dictionary:
	return hive_nodes_by_id

func get_hive_node_by_id(hive_id: int) -> Node:
	if hive_nodes_by_id.has(hive_id):
		return hive_nodes_by_id[hive_id]
	return null

func get_hive_nodes() -> Array:
	var out: Array = []
	for key in hive_nodes_by_id.keys():
		out.append(hive_nodes_by_id[key])
	return out

func get_hive_ids() -> Array[int]:
	var out: Array[int] = []
	for key in hive_nodes_by_id.keys():
		out.append(int(key))
	return out

func get_hive_center_local(hive_id: int) -> Vector2:
	var n := get_hive_node_by_id(hive_id)
	if n == null:
		return Vector2.INF
	return n.position

func get_hive_nodes_by_id_safe() -> Dictionary:
	return hive_nodes_by_id

func set_selected_hive(hive_id: int, color: Color) -> void:
	if hive_id == _selected_hive_id and color == _selected_color:
		return
	var prev_id := _selected_hive_id
	_selected_hive_id = hive_id
	_selected_color = color
	if prev_id > 0:
		var old := get_hive_node_by_id(prev_id)
		if old != null and old.has_method("set_selected"):
			old.call("set_selected", false, color)
	if _selected_hive_id > 0:
		var n := get_hive_node_by_id(_selected_hive_id)
		if n != null and n.has_method("set_selected"):
			n.call("set_selected", true, color)

func clear_selected_hive() -> void:
	if _selected_hive_id > 0:
		var n := get_hive_node_by_id(_selected_hive_id)
		if n != null and n.has_method("set_selected"):
			n.call("set_selected", false, Color.WHITE)
	_selected_hive_id = -1

func _connect_selection_signal() -> void:
	if arena == null:
		return
	if not ("api" in arena):
		return
	var arena_api: ArenaAPI = arena.api
	if arena_api == null:
		return
	var cb := Callable(self, "_on_selected_hive_changed")
	if not arena_api.is_connected("selected_hive_changed", cb):
		arena_api.connect("selected_hive_changed", cb)
	_apply_selection(arena_api.selected_hive_id)

func _on_selected_hive_changed(selected_id: int) -> void:
	_apply_selection(selected_id)

func _apply_selection(selected_id: int) -> void:
	_selected_hive_id = selected_id
	for node in hive_nodes_by_id.values():
		if node == null:
			continue
		if not node.has_method("set_selected"):
			continue
		var hid := -1
		if node.has_method("get"):
			var v: Variant = node.get("hive_id")
			if v != null:
				hid = int(v)
		elif "hive_id" in node:
			hid = int(node.hive_id)
		var owner_id := 0
		if node.has_method("get"):
			var owner_v: Variant = node.get("owner_id")
			if owner_v != null:
				owner_id = int(owner_v)
		var color := _team_color_for_player(owner_id)
		if hid == selected_id:
			_selected_color = color
		node.call("set_selected", hid == selected_id, color)

static func _team_color_for_player(player_id: int) -> Color:
	return HiveVisual._team_color_for_player(player_id)

static func _owner_color(owner_id: int) -> Color:
	return _team_color_for_player(owner_id)

static func _power_label_color(owner_id: int, owner_color: Color) -> Color:
	if owner_id == 1:
		return P1_TEXT_COLOR
	if owner_id == 2:
		return P2_TEXT_COLOR
	return owner_color

func _hive_ids_key(hives: Array) -> String:
	var ids: Array[String] = []
	for hive in hives:
		if typeof(hive) != TYPE_DICTIONARY:
			continue
		var hd: Dictionary = hive as Dictionary
		ids.append(str(hd.get("id", "")))
	ids.sort()
	return "|".join(ids)

func _reset_color_log_if_needed(hives: Array) -> void:
	var key := _hive_ids_key(hives)
	if key == _color_log_key:
		return
	_color_log_key = key
	_color_log_remaining = HIVE_COLOR_LOG_LIMIT
	_color_log_hive_ids.clear()

func _bind_node_signals(node: Area2D) -> void:
	if arena == null:
		return
	if not ("input_system" in arena) or not ("api" in arena):
		return
	var input_sys: Object = arena.input_system
	var arena_api: ArenaAPI = arena.api
	if input_sys == null or arena_api == null:
		return
	if node.has_signal("hive_clicked"):
		var cb := Callable(input_sys, "_handle_hive_clicked").bind(arena_api)
		if not node.is_connected("hive_clicked", cb):
			node.connect("hive_clicked", cb)
	if node.has_signal("hive_released"):
		var cb2 := Callable(input_sys, "_handle_hive_released").bind(arena_api)
		if not node.is_connected("hive_released", cb2):
			node.connect("hive_released", cb2)
	if node.has_signal("hive_hovered"):
		var cb3 := Callable(input_sys, "handle_hive_hovered")
		if not node.is_connected("hive_hovered", cb3):
			node.connect("hive_hovered", cb3)
	if node.has_signal("hive_unhovered"):
		var cb4 := Callable(input_sys, "handle_hive_unhovered")
		if not node.is_connected("hive_unhovered", cb4):
			node.connect("hive_unhovered", cb4)

func _process(delta: float) -> void:
	if arena == null:
		return
	var rv_v: Variant = (arena as Node).get("render_version")
	var rv: int = int(rv_v) if rv_v != null else 0

	var heartbeat := false
	if animations_enabled:
		_heartbeat_accum += delta
		if _heartbeat_accum >= HEARTBEAT_DT:
			_heartbeat_accum = fmod(_heartbeat_accum, HEARTBEAT_DT)
			heartbeat = true

	if _dirty or rv != _last_render_version or heartbeat:
		_last_render_version = rv
		_dirty = false
		queue_redraw()

func _draw() -> void:
	if not hive_nodes_by_id.is_empty():
		return
	# IMPORTANT:
	# - If we have a model, draw it.
	# - If we don't, fall back to state-based drawing so the game can still render.
	if not model.is_empty():
		_draw_model()
	else:
		_draw_state()

func _draw_model() -> void:
	if arena != null:
		if SFLog.LOGGING_ENABLED:
			print("HIVE: arena_ref=", arena)
		_last_render_version = arena.render_version

	var font: Font = ThemeDB.fallback_font
	var font_size: int = POWER_LABEL_FONT_SIZE

	var cell: float = float(cell_px)
	var radius: float = cell * 0.28

	if arena != null:
		var cell_v: Variant = (arena as Node).get("CELL_SIZE")
		cell = float(cell_v) if cell_v != null else 64.0

		var radius_v: Variant = (arena as Node).get("HIVE_RADIUS_PX")
		radius = float(radius_v) if radius_v != null else cell * 0.28

	var hives: Array = model.get("hives", []) as Array
	for hive in hives:
		if typeof(hive) != TYPE_DICTIONARY:
			continue

		var hd: Dictionary = hive as Dictionary

		var gx: float = float(hd.get("x", 0.0))
		var gy: float = float(hd.get("y", 0.0))
		if hd.has("grid_pos") and typeof(hd["grid_pos"]) == TYPE_ARRAY:
			var gp: Array = hd["grid_pos"] as Array
			if gp.size() >= 2:
				gx = float(gp[0])
				gy = float(gp[1])

		var pos: Vector2 = _grid_to_world(gx, gy, cell)

		var color: Color = Color(1, 1, 1, 1)
		var owner_id: int = 0
		if hd.has("owner"):
			owner_id = MapSchema.owner_to_owner_id(str(hd.get("owner", "")))
		elif hd.has("owner_id"):
			owner_id = int(hd.get("owner_id"))
		var kind: String = str(hd.get("kind", "Hive"))
		var pwr: int = int(hd.get("pwr", hd.get("power", 0)))
		color = _team_color_for_player(owner_id)
		_draw_hive_visual(pos, radius, owner_id, color, kind, pwr)
		var text_color := _power_label_color(owner_id, color)
		if font != null:
			var text: String = str(pwr)
			var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var text_pos: Vector2 = pos - (size * 0.5) + Vector2(0.0, size.y * 0.35)
			draw_string(
				font,
				text_pos,
				text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				text_color
			)

func _draw_state() -> void:
	# Minimal, resilient fallback: if state has hives, draw circles + pwr.
	# We support a few common field shapes so a refactor elsewhere doesn't blank the world.
	if state == null or arena == null:
		return

	if SFLog.LOGGING_ENABLED:
		print("HIVE: arena_ref=", arena)
	_last_render_version = arena.render_version

	var font: Font = ThemeDB.fallback_font
	var font_size: int = POWER_LABEL_FONT_SIZE

	var cell: float = 64.0
	var radius: float = cell * 0.28

	var cell_v: Variant = (arena as Node).get("CELL_SIZE")
	cell = float(cell_v) if cell_v != null else 64.0
	var radius_v: Variant = (arena as Node).get("HIVE_RADIUS_PX")
	radius = float(radius_v) if radius_v != null else cell * 0.28

	# Try to iterate something hive-like.
	var hive_list: Array = []
	if "hives" in state:
		hive_list = state.hives
	elif state.has_method("get_hives"):
		hive_list = state.get_hives()

	for h in hive_list:
		# Support either Dictionary or an object-like hive with properties.
		var gx: float = 0.0
		var gy: float = 0.0
		var owner_id: int = 0
		var pwr: int = 0
		var kind: String = "Hive"

		if typeof(h) == TYPE_DICTIONARY:
			var hd: Dictionary = h as Dictionary
			gx = float(hd.get("x", hd.get("gx", 0.0)))
			gy = float(hd.get("y", hd.get("gy", 0.0)))
			if hd.has("grid_pos") and typeof(hd["grid_pos"]) == TYPE_ARRAY:
				var gp: Array = hd["grid_pos"] as Array
				if gp.size() >= 2:
					gx = float(gp[0])
					gy = float(gp[1])

			owner_id = int(hd.get("owner_id", 0))
			pwr = int(hd.get("pwr", hd.get("power", 0)))
			kind = str(hd.get("kind", "Hive"))
		else:
			# Best-effort object fields
			if "gx" in h:
				gx = float(h.gx)
			elif "x" in h:
				gx = float(h.x)
			if "gy" in h:
				gy = float(h.gy)
			elif "y" in h:
				gy = float(h.y)
			if "owner_id" in h:
				owner_id = int(h.owner_id)
			if "pwr" in h:
				pwr = int(h.pwr)
			elif "power" in h:
				pwr = int(h.power)
			if "kind" in h:
				kind = str(h.kind)

		var pos: Vector2 = _grid_to_world(gx, gy, cell)

		var color: Color = Color(1, 1, 1, 1)
		color = _team_color_for_player(owner_id)
		_draw_hive_visual(pos, radius, owner_id, color, kind, pwr)

		if font != null:
			var text := str(pwr)
			var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var text_pos: Vector2 = pos - (size * 0.5) + Vector2(0.0, size.y * 0.35)
			var text_color := _power_label_color(owner_id, color)
			draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

func _sync_hive_nodes(rm: Dictionary) -> void:
	var cell: float = float(rm.get("cell_size", cell_px))
	if cell <= 0.0:
		cell = float(cell_px)
	if arena != null:
		var cell_v: Variant = (arena as Node).get("CELL_SIZE")
		if cell_v != null:
			cell = float(cell_v)
	var hives: Array = rm.get("hives", []) as Array
	_reset_color_log_if_needed(hives)
	var seen: Dictionary = {}
	for hive in hives:
		if typeof(hive) != TYPE_DICTIONARY:
			continue
		var hd: Dictionary = hive as Dictionary
		var id: int = _resolve_hive_id(hd.get("id", 0))
		if id <= 0:
			continue
		seen[id] = true
		var gx: float = float(hd.get("x", 0.0))
		var gy: float = float(hd.get("y", 0.0))
		if hd.has("grid_pos") and typeof(hd["grid_pos"]) == TYPE_ARRAY:
			var gp: Array = hd["grid_pos"] as Array
			if gp.size() >= 2:
				gx = float(gp[0])
				gy = float(gp[1])
		var node = hive_nodes_by_id.get(id, null)
		var spawned := false
		if node == null:
			node = HiveNodeScene.instantiate()
			if node == null:
				continue
			node.name = "HiveNode_%s" % id
			add_child(node)
			hive_nodes_by_id[id] = node
			spawned = true
		if node is Node:
			if not node.is_in_group("hive_pick"):
				node.add_to_group("hive_pick")
			node.set_meta("hive_id", id)
		if node is Area2D:
			_bind_node_signals(node as Area2D)
		var pos := Vector2.ZERO
		if arena != null and arena.grid_spec != null:
			pos = arena.grid_spec.grid_to_world(Vector2i(int(gx), int(gy)))
		else:
			pos = _grid_to_world(gx, gy, cell)
		node.position = pos
		node.hive_id = id
		var owner_id: int = 0
		if hd.has("owner"):
			owner_id = MapSchema.owner_to_owner_id(str(hd.get("owner", "")))
		elif hd.has("owner_id"):
			owner_id = int(hd.get("owner_id"))
		node.owner_id = owner_id
		var pwr: int = int(hd.get("pwr", hd.get("power", 0)))
		var radius: float = cell * 0.28
		if arena != null:
			var radius_v: Variant = (arena as Node).get("HIVE_RADIUS_PX")
			if radius_v != null:
				radius = float(radius_v)
		var color: Color = Color(1, 1, 1, 1)
		color = _team_color_for_player(owner_id)
		var kind: String = str(hd.get("kind", "Hive"))
		if _color_log_remaining > 0 and not _color_log_hive_ids.has(id):
			_color_log_remaining -= 1
			_color_log_hive_ids[id] = true
			SFLog.info("HIVE_COLOR_APPLIED", {
				"hive_id": id,
				"owner_id": owner_id,
				"color": color
			})
		if node.has_method("apply_render"):
			node.call("apply_render", owner_id, pwr, radius, color, POWER_LABEL_FONT_SIZE, kind)
		else:
			node.set("owner_id", owner_id)
		if node.has_method("set_selected"):
			node.call("set_selected", id == _selected_hive_id, _selected_color)
		if spawned:
			SFLog.trace("HIVE_SPAWN", {
				"hive_id": id,
				"owner_id": owner_id,
				"local_pos": node.position,
				"global_pos": node.global_position
			})
	var to_remove: Array = []
	for key in hive_nodes_by_id.keys():
		if not seen.has(key):
			to_remove.append(key)
	for key in to_remove:
		var node: Node2D = hive_nodes_by_id.get(key, null)
		if node != null:
			node.queue_free()
		hive_nodes_by_id.erase(key)

func _clear_hive_nodes() -> void:
	for key in hive_nodes_by_id.keys():
		var node: Node2D = hive_nodes_by_id.get(key, null)
		if node != null:
			node.queue_free()
	hive_nodes_by_id.clear()

func _resolve_hive_id(raw: Variant) -> int:
	if raw is int:
		return int(raw)
	var s := str(raw)
	if s.is_valid_int():
		return int(s)
	return 0

func _draw_hive_visual(pos: Vector2, radius: float, owner_id: int, color: Color, kind: String, power: int = 0) -> void:
	var tex: Texture2D = null
	var registry := _get_sprite_registry()
	if registry != null:
		var kind_key := SpriteRegistry.hive_kind_key(kind)
		if power >= 1 and power <= 9:
			kind_key = "small"
		var key := "hive.%s.%s" % [
			kind_key,
			SpriteRegistry.owner_key(owner_id)
		]
		tex = registry.get_tex(key)
	if tex != null:
		var size := Vector2(radius * 2.0, radius * 2.0)
		var rect := Rect2(pos - size * 0.5, size)
		draw_texture_rect(tex, rect, false)
	else:
		draw_circle(pos, radius, color)

func _get_sprite_registry() -> SpriteRegistry:
	if _sprite_registry == null:
		_sprite_registry = SpriteRegistry.get_instance()
	return _sprite_registry

func _grid_to_world(gx: float, gy: float, cell: float) -> Vector2:
	var cell_px := cell
	var origin := Vector2.ZERO
	if arena != null:
		var spec: Variant = arena.get("grid_spec")
		if spec != null:
			cell_px = float(spec.cell_size)
			origin = spec.origin
	return origin + Vector2((gx + 0.5) * cell_px, (gy + 0.5) * cell_px)
