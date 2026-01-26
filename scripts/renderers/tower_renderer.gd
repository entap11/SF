# NOTE: Minimal tower visualization (placeholder).
# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
class_name TowerRenderer
extends Node2D

const SFLog := preload("res://scripts/util/sf_log.gd")
const HiveRenderer := preload("res://scripts/renderers/hive_renderer.gd")
const SpriteRegistry := preload("res://scripts/renderers/sprite_registry.gd")

const TOWER_SPIKE_PX: float = 8.0
const LOG_INTERVAL_MS: int = 1000

var model: Dictionary = {}
var towers: Array = []
var _last_set_log_ms: int = 0
var _logged_tower_ids: Dictionary = {}
var _sprite_registry: SpriteRegistry = null

func _ready() -> void:
	SFLog.info("TOWER_RENDERER_READY", {"path": str(get_path())})

func set_model(m: Dictionary) -> void:
	model = m
	var towers_v: Variant = model.get("towers", [])
	towers = towers_v as Array if typeof(towers_v) == TYPE_ARRAY else []
	if towers.is_empty():
		_logged_tower_ids.clear()
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_set_log_ms >= LOG_INTERVAL_MS:
		_last_set_log_ms = now_ms
		SFLog.log_on_change_payload("TOWER_RENDERER_SET", towers.size(), {"count": towers.size()})
	_log_new_towers()
	queue_redraw()

func _draw() -> void:
	if towers.is_empty():
		return
	for tower_any in towers:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var td: Dictionary = tower_any as Dictionary
		var pos: Vector2 = _tower_world_pos(td)
		var owner_id: int = int(td.get("owner_id", 0))
		var active: bool = bool(td.get("active", owner_id != 0))
		var owner_key := SpriteRegistry.owner_key(owner_id)
		var state_key := "active" if active else "base"
		var key := "tower.%s.%s" % [state_key, owner_key]
		var tex: Texture2D = null
		var registry := _get_sprite_registry()
		if registry != null:
			tex = registry.get_tex(key)
		if tex != null:
			var size_px := TOWER_SPIKE_PX * 2.0
			var size := Vector2(size_px, size_px)
			var rect := Rect2(pos - size * 0.5, size)
			draw_texture_rect(tex, rect, false)
		else:
			var color: Color = HiveRenderer._owner_color(owner_id)
			color.a = 0.9
			var tip: Vector2 = pos + Vector2(0.0, -TOWER_SPIKE_PX)
			draw_line(pos, tip, color, 2.0)
			draw_line(pos + Vector2(-2.0, 0.0), pos + Vector2(2.0, 0.0), color, 1.0)

func _tower_world_pos(td: Dictionary) -> Vector2:
	var pos_v: Variant = td.get("pos_px", null)
	if pos_v is Vector2:
		return pos_v as Vector2
	var gp_v: Variant = td.get("grid_pos", Vector2i.ZERO)
	var gp: Vector2i = Vector2i.ZERO
	if gp_v is Vector2i:
		gp = gp_v as Vector2i
	elif gp_v is Array:
		var gp_arr: Array = gp_v as Array
		if gp_arr.size() >= 2:
			gp = Vector2i(int(gp_arr[0]), int(gp_arr[1]))
	var cell_size: float = float(model.get("cell_size", 64))
	return Vector2((float(gp.x) + 0.5) * cell_size, (float(gp.y) + 0.5) * cell_size)

func _log_new_towers() -> void:
	for tower_any in towers:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var td: Dictionary = tower_any as Dictionary
		var tower_id: int = int(td.get("id", -1))
		if tower_id <= 0 or _logged_tower_ids.has(tower_id):
			continue
		_logged_tower_ids[tower_id] = true
		var gp_v: Variant = td.get("grid_pos", Vector2i.ZERO)
		var gp: Vector2i = Vector2i.ZERO
		if gp_v is Vector2i:
			gp = gp_v as Vector2i
		elif gp_v is Array:
			var gp_arr: Array = gp_v as Array
			if gp_arr.size() >= 2:
				gp = Vector2i(int(gp_arr[0]), int(gp_arr[1]))
		var pos: Vector2 = _tower_world_pos(td)
		SFLog.info("TOWER_RENDER_CREATE", {"id": tower_id, "grid_pos": gp, "world_pos": pos})

func _get_sprite_registry() -> SpriteRegistry:
	if _sprite_registry == null:
		_sprite_registry = SpriteRegistry.get_instance()
	return _sprite_registry
