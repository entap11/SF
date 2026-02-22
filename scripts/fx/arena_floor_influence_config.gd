class_name ArenaFloorInfluenceConfig
extends Resource

@export var enabled: bool = true
@export var disable_on_apple_forward_plus: bool = false
@export var force_enable_on_apple: bool = false

enum UpdateMode {
	EVENT_DRIVEN,
	FIXED_HZ
}

enum BlendMode {
	WEIGHTED_BLEND,
	DOMINANT_COLOR
}

enum GrowthCurve {
	LINEAR,
	EASE_OUT,
	EASE_IN_OUT
}

@export var influence_tex_size: int = 256
@export var update_mode: int = UpdateMode.EVENT_DRIVEN
@export var update_hz: float = 6.0
@export var global_maturity_seconds: float = 120.0
@export var initial_maturity_floor: float = 0.18
@export var max_influence_per_pixel: float = 1.2
@export var blend_mode: int = BlendMode.WEIGHTED_BLEND
@export var neutral_floor_strength: float = 0.92
@export var noise_strength: float = 0.08
@export var noise_scroll_speed: float = 0.04
@export var edge_glow_strength: float = 0.22
@export var edge_glow_threshold: float = 0.34
@export var circuit_emphasis: float = 0.75
@export var circuit_threshold: float = 0.60
@export var circuit_softness: float = 0.22
@export var circuit_edge_emphasis: float = 0.85
@export var circuit_edge_threshold: float = 0.045
@export var circuit_edge_softness: float = 0.045
@export var circuit_background_leak: float = 0.08
@export var territory_threshold: float = 0.18
@export var territory_softness: float = 0.24
@export var dominance_threshold: float = 0.48
@export var wire_base_strength: float = 0.22
@export var wire_pulse_strength: float = 0.45
@export var wire_pulse_speed: float = 2.2
@export var wire_phase_scale: float = 8.0

@export var hive_radius_px: float = 14.0
@export var hive_strength: float = 0.40
@export var hive_power_min: float = 20.0
@export var hive_power_full: float = 120.0
@export var hive_power_radius_scale_max: float = 1.8
@export var hive_power_strength_scale_max: float = 1.6
@export var hive_area_radius_scale_min: float = 1.9
@export var hive_area_radius_scale_max: float = 3.2
@export var hive_area_strength_scale_min: float = 0.16
@export var hive_area_strength_scale_max: float = 0.52
@export var tower_radius_px: float = 26.0
@export var tower_strength: float = 0.90
@export var barracks_radius_px: float = 24.0
@export var barracks_strength: float = 0.82
@export var structure_area_radius_scale: float = 2.2
@export var structure_area_strength_scale: float = 0.42

@export var growth_curve: int = GrowthCurve.EASE_OUT

@export var capture_pulse_enabled: bool = true
@export var capture_pulse_radius_boost: float = 10.0
@export var capture_pulse_strength_boost: float = 0.38
@export var capture_pulse_duration_sec: float = 1.20

@export var show_influence_debug: bool = false
@export var debug_influence_preview: bool = false
@export var debug_magenta_probe: bool = false
@export var debug_magenta_probe_duration_sec: float = 1.2

@export var player_colors: Array[Color] = [
	Color(0.95, 0.85, 0.20, 1.0),
	Color(0.90, 0.22, 0.22, 1.0),
	Color(0.20, 0.62, 0.26, 1.0),
	Color(0.22, 0.52, 0.95, 1.0)
]

func sanitized_texture_size() -> int:
	var size_value: int = influence_tex_size
	if size_value <= 64:
		return 64
	if size_value <= 128:
		return 128
	if size_value <= 256:
		return 256
	if size_value <= 512:
		return 512
	return 1024
