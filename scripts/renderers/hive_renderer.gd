class_name HiveRenderer
extends Node2D

const SFLog := preload("res://scripts/util/sf_log.gd")
const MapSchema := preload("res://scripts/maps/map_schema.gd")
const HiveNodeScene := preload("res://scenes/hive/HiveNode.tscn")
const HiveGrowthRules := preload("res://scripts/sim/hive_growth_rules.gd")
const SpriteRegistry := preload("res://scripts/renderers/sprite_registry.gd")
const CosmeticThemeDB := preload("res://scripts/cosmetics/cosmetic_theme_db.gd")
const TeamVisuals := preload("res://scripts/renderers/team_visuals.gd")
const MatchShadowControllerScript := preload("res://scripts/renderers/match_shadow_controller.gd")

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
const HIVE_FALLBACK_VISUAL_SCALE: float = 1.60
const HIVE_FALLBACK_WIDTH_SCALE: float = 0.90

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
var _drag_target_hive_id: int = -1
var _drag_target_valid: bool = false
var _drag_target_reason: String = ""
var _sprite_registry: SpriteRegistry = null
var _growth_projection_by_id: Dictionary = {}
var _growth_history_armed: bool = false
var _growth_model_iid: int = -1
var _app_lifecycle: Node = null
var _match_shadow_controller: RefCounted = null

func setup(state_ref: Object, sel_ref: Object, arena_ref: Node2D) -> void:
	_cancel_all_growth_transitions("renderer_setup")
	_reset_growth_history()
	state = state_ref
	sel = sel_ref
	arena = arena_ref
	_dirty = true
	_last_render_version = -1
	_ensure_match_shadow_controller(true)
	_connect_selection_signal()
	_bind_app_lifecycle()
	call_deferred("_prewarm_hive_sprite_cache")
	queue_redraw()

func set_model(m: Dictionary) -> void:
	SFLog.log_once("hive_renderer_set_model_stack", "HiveRenderer set_model called by:\n%s" % [str(get_stack())], SFLog.Level.TRACE)
	_ensure_match_shadow_controller()
	if _match_shadow_controller != null:
		_match_shadow_controller.call("update_from_render_model", m)
	var growth_context_by_id: Dictionary = _growth_contexts_for_model(m)
	model = m
	_sync_hive_nodes(m, growth_context_by_id)
	_commit_growth_projection(m)
	_dirty = true
	queue_redraw()

func clear_all() -> void:
	_cancel_all_growth_transitions("renderer_clear")
	_reset_growth_history()
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

func get_buff_target_probe(hive_id: int) -> Dictionary:
	var node: Node = get_hive_node_by_id(hive_id)
	if not (node is Node2D) or not is_instance_valid(node) or node.is_queued_for_deletion():
		return {"ok": false, "reason": "render_node_missing", "hive_id": hive_id}
	var canvas_item: CanvasItem = node as CanvasItem
	if not canvas_item.visible or not canvas_item.is_visible_in_tree():
		return {"ok": false, "reason": "render_node_hidden", "hive_id": hive_id}
	var node_2d: Node2D = node as Node2D
	var base_radius: float = maxf(1.0, float(node.get("radius_px")))
	var map_parent: Node2D = get_parent() as Node2D
	if map_parent == null:
		return {"ok": false, "reason": "map_parent_missing", "hive_id": hive_id}
	# Probe the unanimated HiveNode root and authored base radius. Presentation
	# children, selector scale, textures, and collision shapes never feed back
	# into acquisition geometry.
	var center_world: Vector2 = node_2d.global_position
	var edge_world: Vector2 = node_2d.to_global(Vector2(base_radius, 0.0))
	var ring_center_world: Vector2 = node_2d.to_global(Vector2(0.0, base_radius))
	var center_local: Vector2 = map_parent.to_local(center_world)
	var edge_local: Vector2 = map_parent.to_local(edge_world)
	return {
		"ok": true,
		"hive_id": hive_id,
		"center_arena_local": center_local,
		"radius_edge_arena_local": edge_local,
		"ring_center_arena_local": map_parent.to_local(ring_center_world),
		"base_radius_arena_local": center_local.distance_to(edge_local),
		"render_instance_id": node.get_instance_id()
	}

func get_hive_nodes_by_id_safe() -> Dictionary:
	return hive_nodes_by_id

func get_match_shadow_debug_snapshot() -> Dictionary:
	if _match_shadow_controller == null:
		return {"enabled": false, "material_count": 0}
	return _match_shadow_controller.call("debug_snapshot") as Dictionary

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

func set_drag_target_hive(hive_id: int, valid: bool, reason: String = "") -> void:
	if hive_id == _drag_target_hive_id and valid == _drag_target_valid and reason == _drag_target_reason:
		return
	_clear_drag_target_node()
	_drag_target_hive_id = hive_id
	_drag_target_valid = valid
	_drag_target_reason = reason
	_apply_drag_target_node()

func clear_drag_target_hive() -> void:
	_clear_drag_target_node()
	_drag_target_hive_id = -1
	_drag_target_valid = false
	_drag_target_reason = ""

func _clear_drag_target_node() -> void:
	if _drag_target_hive_id <= 0:
		return
	var old := get_hive_node_by_id(_drag_target_hive_id)
	if old != null and old.has_method("set_target_hint"):
		old.call("set_target_hint", false, false)

func _apply_drag_target_node() -> void:
	if _drag_target_hive_id <= 0:
		return
	var node := get_hive_node_by_id(_drag_target_hive_id)
	if node != null and node.has_method("set_target_hint"):
		node.call("set_target_hint", true, _drag_target_valid)

func _connect_selection_signal() -> void:
	if arena == null:
		return
	if not ("api" in arena):
		return
	var arena_api: Object = arena.api
	if arena_api == null:
		return
	var cb := Callable(self, "_on_selected_hive_changed")
	if not arena_api.is_connected("selected_hive_changed", cb):
		arena_api.connect("selected_hive_changed", cb)
	_apply_selection(_current_selected_hive_id(arena_api))

func _current_selected_hive_id(arena_api: Object) -> int:
	var api_selected_id: int = int(arena_api.selected_hive_id) if arena_api != null else -1
	if api_selected_id > 0:
		return api_selected_id
	if sel != null:
		var selected_v: Variant = sel.get("selected_hive_id")
		if selected_v != null:
			var selection_selected_id: int = int(selected_v)
			if selection_selected_id > 0:
				return selection_selected_id
	return api_selected_id

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
	return TeamVisuals.owner_color(player_id)

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
	var arena_api: Object = arena.api
	if input_sys == null or arena_api == null:
		return
	# Primary input path is Arena._unhandled_input -> InputSystem.handle_pointer_event.
	# Avoid binding click/release here to prevent duplicate press/release processing.
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
		if SFLog.LOGGING_ENABLED and SFLog.verbose_sim:
			print("HIVE: arena_ref=", arena)
		_last_render_version = arena.render_version

	var font: Font = UITypography.fallback_font()
	var font_size: int = POWER_LABEL_FONT_SIZE

	var cell: float = float(cell_px)
	var radius: float = cell * 0.42

	if arena != null:
		var cell_v: Variant = (arena as Node).get("CELL_SIZE")
		cell = float(cell_v) if cell_v != null else 64.0

		var radius_v: Variant = (arena as Node).get("HIVE_RADIUS_PX")
		radius = float(radius_v) if radius_v != null else cell * 0.42

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
		var growth_tier: int = int(hd.get("growth_tier", hd.get("lane_budget_max", HiveGrowthRules.TIER_SMALL)))
		_draw_hive_visual(pos, radius, owner_id, color, kind, growth_tier)
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

	if SFLog.LOGGING_ENABLED and SFLog.verbose_sim:
		print("HIVE: arena_ref=", arena)
	_last_render_version = arena.render_version

	var font: Font = UITypography.fallback_font()
	var font_size: int = POWER_LABEL_FONT_SIZE

	var cell: float = 64.0
	var radius: float = cell * 0.42

	var cell_v: Variant = (arena as Node).get("CELL_SIZE")
	cell = float(cell_v) if cell_v != null else 64.0
	var radius_v: Variant = (arena as Node).get("HIVE_RADIUS_PX")
	radius = float(radius_v) if radius_v != null else cell * 0.42

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
		var growth_tier: int = int(state.call("lanes_allowed_for_power", pwr)) if state.has_method("lanes_allowed_for_power") else HiveGrowthRules.TIER_SMALL
		_draw_hive_visual(pos, radius, owner_id, color, kind, growth_tier)

		if font != null:
			var text := str(pwr)
			var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var text_pos: Vector2 = pos - (size * 0.5) + Vector2(0.0, size.y * 0.35)
			var text_color := _power_label_color(owner_id, color)
			draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

func _sync_hive_nodes(rm: Dictionary, growth_context_by_id: Dictionary = {}) -> void:
	var cell: float = float(rm.get("cell_size", cell_px))
	if cell <= 0.0:
		cell = float(cell_px)
	if arena != null:
		var cell_v: Variant = (arena as Node).get("CELL_SIZE")
		if cell_v != null:
			cell = float(cell_v)
	var hives: Array = rm.get("hives", []) as Array
	var viewer_owner_id: int = int(rm.get("viewer_owner_id", 0))
	var distress_motion_mode: String = _distress_motion_mode()
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
		var pos: Vector2 = _grid_to_world(gx, gy, cell)
		node.position = pos
		node.hive_id = id
		var owner_id: int = 0
		if hd.has("owner"):
			owner_id = MapSchema.owner_to_owner_id(str(hd.get("owner", "")))
		elif hd.has("owner_id"):
			owner_id = int(hd.get("owner_id"))
		node.owner_id = owner_id
		var pwr: int = int(hd.get("pwr", hd.get("power", 0)))
		var budget_state: Dictionary = _lane_budget_for_hive(id, pwr, hd)
		var lane_budget_used: int = int(budget_state.get("used", 0))
		var lane_budget_max: int = int(budget_state.get("max", 3))
		var growth_tier: int = clampi(
			int(hd.get("growth_tier", lane_budget_max)),
			HiveGrowthRules.TIER_SMALL,
			HiveGrowthRules.TIER_LARGE
		)
		var radius: float = cell * 0.42
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
			node.call(
				"apply_render",
				owner_id,
				pwr,
				radius,
				color,
				POWER_LABEL_FONT_SIZE,
				kind,
				lane_budget_used,
				lane_budget_max,
				growth_tier,
				growth_context_by_id.get(id, {}) as Dictionary
			)
		else:
			node.set("owner_id", owner_id)
		if node.has_method("apply_match_shadow_presentation"):
			var shadow_presentation: Dictionary = {"enabled": false}
			if _match_shadow_controller != null:
				shadow_presentation = _match_shadow_controller.call(
					"presentation_for_tier",
					growth_tier
				) as Dictionary
			node.call("apply_match_shadow_presentation", shadow_presentation)
		if node.has_method("set_capture_flag_marker"):
			node.call(
				"set_capture_flag_marker",
				bool(hd.get("is_capture_flag", false)),
				int(hd.get("capture_flag_owner_id", 0)),
				bool(hd.get("capture_flag_hidden", false))
			)
		if node.has_method("set_activated"):
			node.call("set_activated", bool(hd.get("capture_flag_move_target", false)))
		if node.has_method("set_swarm_cooldown"):
			node.call(
				"set_swarm_cooldown",
				int(hd.get("swarm_cooldown_remaining_ms", 0)),
				int(hd.get("swarm_cooldown_total_ms", 5000))
			)
		if node.has_method("apply_distress_presentation"):
			node.call(
				"apply_distress_presentation",
				viewer_owner_id,
				bool(hd.get("hostile_capture_pressure", false)),
				color,
				distress_motion_mode
			)
		if node.has_method("set_selected"):
			node.call("set_selected", id == _selected_hive_id, _selected_color)
		if node.has_method("set_target_hint"):
			node.call("set_target_hint", id == _drag_target_hive_id, _drag_target_valid)
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
			if node.has_method("cancel_growth_transition"):
				node.call("cancel_growth_transition", "hive_removed")
			node.queue_free()
		hive_nodes_by_id.erase(key)
	_notify_buff_target_render_nodes_changed()

func _clear_hive_nodes() -> void:
	_clear_buff_target_presentation("hive_renderer_clear")
	for key in hive_nodes_by_id.keys():
		var node: Node2D = hive_nodes_by_id.get(key, null)
		if node != null:
			if node.has_method("cancel_growth_transition"):
				node.call("cancel_growth_transition", "hive_renderer_clear")
			node.queue_free()
	hive_nodes_by_id.clear()
	_drag_target_hive_id = -1
	_drag_target_valid = false
	_drag_target_reason = ""

func _growth_contexts_for_model(rm: Dictionary) -> Dictionary:
	var contexts: Dictionary = {}
	if not _is_canonical_growth_model(rm):
		if _growth_history_armed:
			_cancel_all_growth_transitions("noncanonical_model")
		_reset_growth_history()
		return contexts
	var iid: int = int(rm.get("iid", -1))
	if _growth_model_iid != -1 and iid != _growth_model_iid:
		_cancel_all_growth_transitions("state_instance_changed")
		_reset_growth_history()
	if not _growth_history_armed:
		return contexts
	var mode: String = _growth_motion_mode()
	if mode == "none":
		return contexts
	var hives: Array = rm.get("hives", []) as Array
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		var hive_id: int = _resolve_hive_id(hive.get("id", 0))
		if hive_id <= 0 or not _growth_projection_by_id.has(hive_id):
			continue
		if not hive_nodes_by_id.has(hive_id):
			continue
		var previous: Dictionary = _growth_projection_by_id[hive_id] as Dictionary
		var old_tier: int = int(previous.get("tier", HiveGrowthRules.TIER_SMALL))
		var new_tier: int = int(hive.get("growth_tier", old_tier))
		if new_tier <= old_tier:
			continue
		var old_budget: int = int(previous.get("lane_budget_max", old_tier))
		var new_budget: int = int(hive.get("lane_budget_max", new_tier))
		contexts[hive_id] = {
			"play": true,
			"mode": mode,
			"old_tier": old_tier,
			"new_tier": new_tier,
			"old_lane_budget_max": old_budget,
			"new_lane_budget_max": new_budget,
			"unlocked_slot_index": new_budget - 1 if new_budget > old_budget else -1
		}
	return contexts

func _commit_growth_projection(rm: Dictionary) -> void:
	if not _is_canonical_growth_model(rm):
		return
	var next_projection: Dictionary = {}
	var hives: Array = rm.get("hives", []) as Array
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		var hive_id: int = _resolve_hive_id(hive.get("id", 0))
		if hive_id <= 0:
			continue
		var tier: int = clampi(
			int(hive.get("growth_tier", HiveGrowthRules.TIER_SMALL)),
			HiveGrowthRules.TIER_SMALL,
			HiveGrowthRules.TIER_LARGE
		)
		next_projection[hive_id] = {
			"tier": tier,
			"lane_budget_max": int(hive.get("lane_budget_max", tier))
		}
	_growth_projection_by_id = next_projection
	_growth_model_iid = int(rm.get("iid", -1))
	_growth_history_armed = true

func _is_canonical_growth_model(rm: Dictionary) -> bool:
	if not rm.has("iid") or typeof(rm.get("hives", null)) != TYPE_ARRAY:
		return false
	for hive_any in rm.get("hives", []) as Array:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		if not (hive_any as Dictionary).has("growth_tier"):
			return false
	return true

func _reset_growth_history() -> void:
	_growth_projection_by_id.clear()
	_growth_history_armed = false
	_growth_model_iid = -1

func _growth_motion_mode() -> String:
	if not animations_enabled:
		return "none"
	if _app_lifecycle != null and _app_lifecycle.has_method("is_backgrounded"):
		if bool(_app_lifecycle.call("is_backgrounded")):
			return "none"
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager != null and profile_manager.has_method("is_gpu_vfx_enabled"):
		if not bool(profile_manager.call("is_gpu_vfx_enabled")):
			return "reduced"
	return "full"

func _distress_motion_mode() -> String:
	return _growth_motion_mode()

func _cancel_all_growth_transitions(reason: String) -> void:
	for node_any in hive_nodes_by_id.values():
		var node: Node = node_any as Node
		if node != null and is_instance_valid(node) and node.has_method("cancel_growth_transition"):
			node.call("cancel_growth_transition", reason)

func _bind_app_lifecycle() -> void:
	_app_lifecycle = get_node_or_null("/root/AppLifecycle")
	if _app_lifecycle == null or not _app_lifecycle.has_signal("app_backgrounded"):
		return
	var background_callback := Callable(self, "_on_app_backgrounded")
	if not _app_lifecycle.is_connected("app_backgrounded", background_callback):
		_app_lifecycle.connect("app_backgrounded", background_callback)
	var foreground_callback := Callable(self, "_on_app_foregrounded")
	if (
		_app_lifecycle.has_signal("app_foregrounded")
		and not _app_lifecycle.is_connected("app_foregrounded", foreground_callback)
	):
		_app_lifecycle.connect("app_foregrounded", foreground_callback)

func _on_app_backgrounded(_reason: String, _paused_at_msec: int, _paused_at_unix: int) -> void:
	_cancel_all_growth_transitions("app_backgrounded")
	_set_all_distress_lifecycle_suspended(true)

func _on_app_foregrounded(_reason: String, _elapsed_msec: int, _resumed_at_unix: int) -> void:
	_set_all_distress_lifecycle_suspended(false)

func _set_all_distress_lifecycle_suspended(suspended: bool) -> void:
	for node_any in hive_nodes_by_id.values():
		var node: Node = node_any as Node
		if (
			node != null
			and is_instance_valid(node)
			and node.has_method("set_distress_lifecycle_suspended")
		):
			node.call("set_distress_lifecycle_suspended", suspended)

func get_growth_debug_snapshot() -> Dictionary:
	var active_count: int = 0
	for node_any in hive_nodes_by_id.values():
		var node: Node = node_any as Node
		if node == null or not node.has_method("get_growth_transition_debug_snapshot"):
			continue
		var snapshot: Dictionary = node.call("get_growth_transition_debug_snapshot") as Dictionary
		if bool(snapshot.get("active", false)):
			active_count += 1
	return {
		"history_armed": _growth_history_armed,
		"model_iid": _growth_model_iid,
		"projection_count": _growth_projection_by_id.size(),
		"active_count": active_count
	}

func get_distress_debug_snapshot() -> Dictionary:
	var active_count: int = 0
	var imminent_count: int = 0
	var max_child_count: int = 0
	var by_hive: Dictionary = {}
	for hive_id_any in hive_nodes_by_id.keys():
		var node: Node = hive_nodes_by_id.get(hive_id_any, null) as Node
		if node == null or not node.has_method("get_distress_debug_snapshot"):
			continue
		var snapshot: Dictionary = node.call("get_distress_debug_snapshot") as Dictionary
		by_hive[int(hive_id_any)] = snapshot
		var state_name: String = str(snapshot.get("state", "normal"))
		if state_name != "normal":
			active_count += 1
		if state_name == "imminent":
			imminent_count += 1
		max_child_count = maxi(max_child_count, int(snapshot.get("child_count", 0)))
	return {
		"active_count": active_count,
		"imminent_count": imminent_count,
		"hive_count": by_hive.size(),
		"max_component_child_count": max_child_count,
		"by_hive": by_hive
	}

func _buff_target_controller() -> Node:
	var map_parent: Node = get_parent()
	if map_parent == null:
		return null
	return map_parent.get_node_or_null("BuffHiveTargetPresentation")

func _notify_buff_target_render_nodes_changed() -> void:
	var controller: Node = _buff_target_controller()
	if controller != null and controller.has_method("notify_render_nodes_changed"):
		controller.call("notify_render_nodes_changed")

func _clear_buff_target_presentation(reason: String) -> void:
	var controller: Node = _buff_target_controller()
	if controller != null and controller.has_method("clear"):
		controller.call("clear", -1, true, reason)

func _resolve_hive_id(raw: Variant) -> int:
	if raw is int:
		return int(raw)
	var s := str(raw)
	if s.is_valid_int():
		return int(s)
	return 0

func _lane_budget_for_hive(hive_id: int, power: int, hd: Dictionary) -> Dictionary:
	var max_budget: int = int(hd.get("lane_budget_max", hd.get("budget", -1)))
	var used_budget: int = int(hd.get("lane_budget_used", hd.get("active_outgoing", -1)))
	if max_budget < 0:
		if state != null and state.has_method("lanes_allowed_for_power"):
			max_budget = int(state.call("lanes_allowed_for_power", power))
		else:
			max_budget = _fallback_lanes_allowed_for_power(power)
	if used_budget < 0:
		if state != null and state.has_method("outgoing_active_count"):
			used_budget = int(state.call("outgoing_active_count", hive_id))
		elif state != null and state.has_method("count_active_outgoing"):
			used_budget = int(state.call("count_active_outgoing", hive_id))
		else:
			used_budget = _count_active_outgoing_from_model(hive_id)
	return {
		"used": maxi(0, used_budget),
		"max": maxi(0, max_budget)
	}

func _fallback_lanes_allowed_for_power(power: int) -> int:
	return HiveGrowthRules.lane_budget_for_power(power)

func _count_active_outgoing_from_model(hive_id: int) -> int:
	var lanes_v: Variant = model.get("lanes", [])
	if typeof(lanes_v) != TYPE_ARRAY:
		return 0
	var count: int = 0
	for lane_v in lanes_v as Array:
		if typeof(lane_v) != TYPE_DICTIONARY:
			continue
		var lane: Dictionary = lane_v as Dictionary
		var a_id: int = int(lane.get("a_id", -1))
		var b_id: int = int(lane.get("b_id", -1))
		if a_id == hive_id and bool(lane.get("send_a", false)):
			count += 1
		if b_id == hive_id and bool(lane.get("send_b", false)):
			count += 1
	return count

func _draw_hive_visual(pos: Vector2, radius: float, owner_id: int, color: Color, kind: String, growth_tier: int = HiveGrowthRules.TIER_SMALL) -> void:
	var visual_radius := radius * HIVE_FALLBACK_VISUAL_SCALE
	var tex: Texture2D = null
	var registry := _get_sprite_registry()
	if registry != null:
		var resolved: Dictionary = CosmeticThemeDB.resolve_hive_sprite_for_tier(owner_id, kind, growth_tier, registry)
		tex = resolved.get("texture", null) as Texture2D
	if tex != null:
		var size := Vector2(visual_radius * 2.0 * HIVE_FALLBACK_WIDTH_SCALE, visual_radius * 2.0)
		var rect := Rect2(pos - size * 0.5, size)
		draw_texture_rect(tex, rect, false, _fallback_sprite_tint(owner_id))
	else:
		draw_circle(pos, visual_radius, color)

func _fallback_sprite_tint(owner_id: int) -> Color:
	if owner_id <= 0:
		return TeamVisuals.NPC_COLOR
	var tint: Color = TeamVisuals.owner_color(owner_id)
	tint.a = 1.0
	return tint

func _get_sprite_registry() -> SpriteRegistry:
	if _sprite_registry == null:
		_sprite_registry = SpriteRegistry.get_instance()
	return _sprite_registry

func _ensure_match_shadow_controller(reconfigure: bool = false) -> void:
	if _match_shadow_controller == null:
		_match_shadow_controller = MatchShadowControllerScript.new()
		reconfigure = true
	if reconfigure:
		_match_shadow_controller.call("configure")

func _prewarm_hive_sprite_cache() -> void:
	var registry := _get_sprite_registry()
	if registry == null:
		return
	registry.prewarm_hive_textures()

func _grid_to_world(gx: float, gy: float, cell: float) -> Vector2:
	var cell_px := cell
	var origin := Vector2.ZERO
	# Match Arena's authored-coordinate default when setup has not bound arena yet.
	var center_offset: float = 0.0
	if arena != null:
		var spec: Variant = arena.get("grid_spec")
		if spec != null:
			cell_px = float(spec.cell_size)
			origin = spec.origin
		if arena.has_method("get_grid_coord_render_offset"):
			center_offset = float(arena.call("get_grid_coord_render_offset"))
	return origin + Vector2((gx + center_offset) * cell_px, (gy + center_offset) * cell_px)
