class_name LaneData
extends RefCounted

const SEGMENTS := 8

var id: int
var a_id: int
var b_id: int
var dir: int
var send_a: bool
var send_b: bool
var a_pressure: float
var b_pressure: float
var a_stream_len: float
var b_stream_len: float
var build_t: float
var establish_a: bool
var establish_b: bool
var establish_t0_ms: int
var spawn_accum_a_ms: float
var spawn_accum_b_ms: float
var retract_a: bool
var retract_b: bool
var last_impact_f: float
var a_seg: PackedInt32Array = PackedInt32Array()
var b_seg: PackedInt32Array = PackedInt32Array()
var seg_carry_ms: int = 0

func _init(
	p_id: int,
	p_a_id: int,
	p_b_id: int,
	p_dir: int,
	p_send_a: bool,
	p_send_b: bool,
	p_a_pressure: float = 0.0,
	p_b_pressure: float = 0.0,
	p_a_stream_len: float = 0.0,
	p_b_stream_len: float = 0.0,
	p_build_t: float = 1.0,
	p_last_impact_f: float = 0.5,
	p_establish_a: bool = false,
	p_establish_b: bool = false,
	p_establish_t0_ms: int = 0,
	p_spawn_accum_a_ms: float = 0.0,
	p_spawn_accum_b_ms: float = 0.0,
	p_retract_a: bool = false,
	p_retract_b: bool = false
) -> void:
	self.id = p_id
	self.a_id = p_a_id
	self.b_id = p_b_id
	self.dir = p_dir
	self.send_a = p_send_a
	self.send_b = p_send_b
	self.a_pressure = p_a_pressure
	self.b_pressure = p_b_pressure
	self.a_stream_len = p_a_stream_len
	self.b_stream_len = p_b_stream_len
	self.build_t = p_build_t
	self.last_impact_f = p_last_impact_f
	self.establish_a = p_establish_a
	self.establish_b = p_establish_b
	self.establish_t0_ms = p_establish_t0_ms
	self.spawn_accum_a_ms = p_spawn_accum_a_ms
	self.spawn_accum_b_ms = p_spawn_accum_b_ms
	self.retract_a = p_retract_a
	self.retract_b = p_retract_b
	_init_segments()

func is_built() -> bool:
	return build_t >= 0.999

func is_established(front_t: float = -1.0) -> bool:
	var t := front_t
	if t < 0.0:
		t = float(OpsState.lane_front_by_lane_id.get(id, 0.0))
	return t >= 0.999

func _init_segments() -> void:
	a_seg.resize(SEGMENTS)
	b_seg.resize(SEGMENTS)
	for i in range(SEGMENTS):
		a_seg[i] = 0
		b_seg[i] = 0
	seg_carry_ms = 0
