extends RefCounted
class_name LaneVisualHierarchy

const SETTINGS_ENABLED: String = "swarmfront/arena/lane_visual_hierarchy_enabled"
const STATE_EMBEDDED: String = "embedded"
const STATE_ACTIVE: String = "active"
const STATE_CONTESTED: String = "contested"
const PROFILE_TRANSITION_SEC: float = 0.20
const PULSE_HZ: float = 1.25

static func is_enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTINGS_ENABLED, false))

static func state_for_lane(lane: Dictionary) -> String:
	var explicit: String = str(lane.get("visual_state", "")).strip_edges().to_lower()
	if explicit in [STATE_EMBEDDED, STATE_ACTIVE, STATE_CONTESTED]:
		return explicit
	var send_a: bool = bool(lane.get("send_a", false))
	var send_b: bool = bool(lane.get("send_b", false))
	if bool(lane.get("contested", false)) or (send_a and send_b):
		return STATE_CONTESTED
	var intent: String = str(lane.get("intent", "")).strip_edges().to_lower()
	var emphasized: bool = bool(lane.get("visual_emphasis", false)) or bool(lane.get("selected", false))
	if emphasized or intent in ["active", "swarm", "heavy", "pressure", "emphasis"]:
		return STATE_ACTIVE
	return STATE_EMBEDDED

static func profile_for_state(state_name: String) -> Dictionary:
	match state_name:
		STATE_CONTESTED:
			return {
				"state": STATE_CONTESTED,
				"z_index": 9,
				"alpha": 0.98,
				"width": 13.0,
				"glow_alpha": 0.45,
				"brightness": 1.25,
				"saturation": 1.15,
				"tile_void_period": 1.0,
				"tile_void_keep": 1.0,
				"tile_void_phase": 0.0,
				"pulse_enabled": true
			}
		STATE_ACTIVE:
			return {
				"state": STATE_ACTIVE,
				"z_index": 3,
				"alpha": 0.78,
				"width": 9.5,
				"glow_alpha": 0.20,
				"brightness": 1.05,
				"saturation": 0.95,
				"tile_void_period": 1.0,
				"tile_void_keep": 1.0,
				"tile_void_phase": 0.0,
				"pulse_enabled": false
			}
		_:
			return {
				"state": STATE_EMBEDDED,
				"z_index": -14,
				"alpha": 0.10,
				"width": 2.8,
				"glow_alpha": 0.0,
				"brightness": 0.22,
				"saturation": 0.15,
				"tile_void_period": 2.0,
				"tile_void_keep": 1.0,
				"tile_void_phase": 0.0,
				"pulse_enabled": false
			}

static func sync_entry_profile(entry: Dictionary, lane: Dictionary, force_complete: bool = false) -> bool:
	var next_state: String = state_for_lane(lane)
	var prev_state: String = str(entry.get("visual_state", ""))
	if prev_state == next_state and entry.has("visual_profile_to"):
		return false
	var prev_profile: Dictionary = entry.get("visual_profile_current", profile_for_state(prev_state if not prev_state.is_empty() else next_state)) as Dictionary
	var next_profile: Dictionary = profile_for_state(next_state)
	entry["visual_state"] = next_state
	entry["visual_profile_from"] = prev_profile.duplicate(true)
	entry["visual_profile_to"] = next_profile.duplicate(true)
	entry["visual_profile_current"] = next_profile.duplicate(true) if force_complete or prev_state.is_empty() else prev_profile.duplicate(true)
	entry["visual_profile_t"] = 1.0 if force_complete or prev_state.is_empty() else 0.0
	return true

static func legacy_profile(legacy_z_index: int, legacy_width: float) -> Dictionary:
	return {
		"state": "legacy",
		"z_index": legacy_z_index,
		"alpha": 1.0,
		"width": legacy_width,
		"glow_alpha": 0.0,
		"brightness": 1.0,
		"saturation": 1.0,
		"tile_void_period": 1.0,
		"tile_void_keep": 1.0,
		"tile_void_phase": 0.0,
		"pulse_enabled": false
	}

static func resolve_entry_profile(entry: Dictionary, delta: float) -> Dictionary:
	var from_profile: Dictionary = entry.get("visual_profile_from", profile_for_state(STATE_EMBEDDED)) as Dictionary
	var to_profile: Dictionary = entry.get("visual_profile_to", profile_for_state(STATE_EMBEDDED)) as Dictionary
	var t: float = clampf(float(entry.get("visual_profile_t", 1.0)), 0.0, 1.0)
	if t < 1.0:
		t = clampf(t + (delta / maxf(0.001, PROFILE_TRANSITION_SEC)), 0.0, 1.0)
		entry["visual_profile_t"] = t
	var current: Dictionary = interpolate_profiles(from_profile, to_profile, t)
	entry["visual_profile_current"] = current
	return current

static func interpolate_profiles(from_profile: Dictionary, to_profile: Dictionary, t: float) -> Dictionary:
	return {
		"state": str(to_profile.get("state", STATE_EMBEDDED)),
		"z_index": int(to_profile.get("z_index", -5)),
		"alpha": lerpf(float(from_profile.get("alpha", 1.0)), float(to_profile.get("alpha", 1.0)), t),
		"width": lerpf(float(from_profile.get("width", 12.6)), float(to_profile.get("width", 12.6)), t),
		"glow_alpha": lerpf(float(from_profile.get("glow_alpha", 0.0)), float(to_profile.get("glow_alpha", 0.0)), t),
		"brightness": lerpf(float(from_profile.get("brightness", 1.0)), float(to_profile.get("brightness", 1.0)), t),
		"saturation": lerpf(float(from_profile.get("saturation", 1.0)), float(to_profile.get("saturation", 1.0)), t),
		"tile_void_period": float(to_profile.get("tile_void_period", 1.0)),
		"tile_void_keep": float(to_profile.get("tile_void_keep", 1.0)),
		"tile_void_phase": float(to_profile.get("tile_void_phase", 0.0)),
		"pulse_enabled": bool(to_profile.get("pulse_enabled", false))
	}

static func apply_profile_to_color(color: Color, profile: Dictionary, now_ms: int) -> Color:
	var alpha: float = clampf(float(profile.get("alpha", 1.0)), 0.0, 1.0)
	if bool(profile.get("pulse_enabled", false)):
		var pulse_t: float = 0.5 + 0.5 * sin((float(now_ms) / 1000.0) * TAU * PULSE_HZ)
		alpha *= lerpf(0.86, 1.0, pulse_t)
	var glow: float = clampf(float(profile.get("glow_alpha", 0.0)), 0.0, 1.0)
	var brightness: float = clampf(float(profile.get("brightness", 1.0)), 0.0, 1.5)
	var saturation: float = clampf(float(profile.get("saturation", 1.0)), 0.0, 1.4)
	var lum: float = (color.r * 0.299) + (color.g * 0.587) + (color.b * 0.114)
	var r: float = lerpf(lum, color.r, saturation)
	var g: float = lerpf(lum, color.g, saturation)
	var b: float = lerpf(lum, color.b, saturation)
	var brighten: float = brightness + (glow * 0.18)
	return Color(
		clampf((r * brighten) + (glow * 0.04), 0.0, 1.0),
		clampf((g * brighten) + (glow * 0.04), 0.0, 1.0),
		clampf((b * brighten) + (glow * 0.04), 0.0, 1.0),
		color.a * alpha
	)
