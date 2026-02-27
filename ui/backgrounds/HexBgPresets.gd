extends RefCounted
class_name HexBgPresets

static func has_preset(preset_name: StringName) -> bool:
	var key: String = String(preset_name).to_lower()
	return key == "store" or key == "hive" or key == "dash" or key == "popup"


static func get_preset(preset_name: StringName) -> Dictionary:
	var key: String = String(preset_name).to_lower()
	match key:
		"store":
			return _build_preset(
				Color(1.0, 0.77, 0.04, 1.0),
				0.030,
				1.65,
				2.8,
				0.40,
				1.05,
				false,
				5.8,
				0.025,
				0.003,
				13.0,
				11.0
			)
		"hive":
			return _build_preset(
				Color(1.0, 0.80, 0.06, 1.0),
				0.022,
				1.02,
				3.4,
				0.40,
				0.95,
				true,
				5.2,
				0.03,
				0.005,
				15.5,
				27.0
			)
		"dash":
			return _build_preset(
				Color(0.98, 0.77, 0.02, 1.0),
				0.015,
				0.50,
				2.4,
				0.28,
				0.55,
				false,
				6.0,
				0.02,
				0.002,
				17.0,
				3.0
			)
		"popup":
			return _build_preset(
				Color(0.99, 0.78, 0.03, 1.0),
				0.014,
				0.44,
				2.2,
				0.24,
				0.45,
				false,
				5.8,
				0.015,
				0.001,
				17.5,
				41.0
			)
		_:
			return {}


static func _build_preset(
		glow_color: Color,
		seam_width: float,
		seam_intensity: float,
		noise_scale: float,
		noise_amount: float,
		center_bias: float,
		pulse_enabled: bool,
		pulse_period: float,
		pulse_amount: float,
		flicker_amount: float,
		hex_scale: float,
		seed: float
	) -> Dictionary:
	var preset: Dictionary = {}
	preset["glow_color"] = glow_color
	preset["seam_width"] = seam_width
	preset["seam_intensity"] = seam_intensity
	preset["noise_scale"] = noise_scale
	preset["noise_amount"] = noise_amount
	preset["center_bias"] = center_bias
	preset["pulse_enabled"] = pulse_enabled
	preset["pulse_period"] = pulse_period
	preset["pulse_amount"] = pulse_amount
	preset["flicker_amount"] = flicker_amount
	preset["hex_scale"] = hex_scale
	preset["seed"] = seed
	return preset
