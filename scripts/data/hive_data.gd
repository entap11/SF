class_name HiveData
extends RefCounted

var id: int
var grid_pos: Vector2i
var render_grid_pos: Vector2
var owner_id: int
var power: int
var kind: String
var radius_px: float
var spawn_accum_ms: float
var idle_accum_ms: float
var shock_ms: float
var spawn_rr_index: int
var pass_rr_index: int
var pass_preferred_targets: Array[int]

func _init(
	p_id: int,
	p_grid_pos: Vector2i,
	p_owner_id: int,
	p_power: int,
	p_kind: String = "Hive",
	p_radius_px: float = 0.0,
	p_render_grid_pos: Vector2 = Vector2.INF
) -> void:
	self.id = p_id
	self.grid_pos = p_grid_pos
	if is_finite(p_render_grid_pos.x) and is_finite(p_render_grid_pos.y):
		self.render_grid_pos = p_render_grid_pos
	else:
		self.render_grid_pos = Vector2(float(p_grid_pos.x), float(p_grid_pos.y))
	self.owner_id = p_owner_id
	self.power = p_power
	self.kind = p_kind
	self.radius_px = float(p_radius_px)
	self.spawn_accum_ms = 0.0
	self.idle_accum_ms = 0.0
	self.shock_ms = 0.0
	self.spawn_rr_index = 0
	self.pass_rr_index = 0
	self.pass_preferred_targets = []
