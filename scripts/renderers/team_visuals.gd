class_name TeamVisuals
extends RefCounted

const NPC_COLOR := Color(0.52, 0.47, 0.82, 1.0)
const STRUCTURE_NPC_ACCENT_COLOR := Color(0.55, 0.50, 0.70, 1.0)

const WHITE_SAT_MAX: float = 0.32
const WHITE_VAL_MIN: float = 0.56
const WHITE_STRENGTH: float = 0.95

static func owner_color(owner_id: int) -> Color:
	match owner_id:
		1:
			return Color8(255, 210, 0)
		2:
			return Color8(229, 57, 53)
		3:
			return Color(0.2, 1.0, 0.35, 1.0)
		4:
			return Color8(30, 136, 229)
		_:
			return NPC_COLOR

static func structure_accent_color(owner_id: int) -> Color:
	if owner_id >= 1 and owner_id <= 4:
		return owner_color(owner_id)
	return STRUCTURE_NPC_ACCENT_COLOR

static func apply_white_projection_params(mat: ShaderMaterial, strength: float = WHITE_STRENGTH) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("white_sat_max", WHITE_SAT_MAX)
	mat.set_shader_parameter("white_val_min", WHITE_VAL_MIN)
	mat.set_shader_parameter("white_strength", strength)
