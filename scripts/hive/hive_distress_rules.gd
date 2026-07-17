class_name HiveDistressRules
extends RefCounted

const HiveGrowthRules := preload("res://scripts/sim/hive_growth_rules.gd")

# Presentation-only policy. None of these values alter authoritative hive power,
# growth, capture, ownership, or lane rules.
const PRESSURE_TRIGGER_MAX_POWER: int = 5
const PRESSURE_HOLD_SEC: float = 0.65

const PRESSURE_RESET: String = "reset"
const PRESSURE_TRIGGER: String = "trigger"
const PRESSURE_HOLD: String = "hold"
const PRESSURE_CLEAR: String = "clear"

const BURST_NONE: String = "none"
const BURST_MINOR_RUPTURE: String = "minor_rupture"
const BURST_MAJOR_RUPTURE: String = "major_rupture"
const BURST_CRITICAL_ENTRY: String = "critical_entry"

const MINOR_DURATION_SEC: float = 0.64
const MINOR_HANDOFF_SEC: float = 0.50
const MINOR_HEIGHT_SCALE: float = 1.42
const MINOR_RING_COUNT: int = 1
const MINOR_SPARK_COUNT: int = 6
const MINOR_FRAGMENT_COUNT: int = 2
const MINOR_PLUME_LAYERS: int = 2

const MAJOR_DURATION_SEC: float = 1.02
const MAJOR_HANDOFF_SEC: float = 0.82
const MAJOR_HEIGHT_SCALE: float = 2.22
const MAJOR_RING_COUNT: int = 2
const MAJOR_SPARK_COUNT: int = 12
const MAJOR_FRAGMENT_COUNT: int = 4
const MAJOR_PLUME_LAYERS: int = 3

const CRITICAL_ENTRY_DURATION_SEC: float = 0.48
const CRITICAL_ENTRY_HANDOFF_SEC: float = 0.42
const CRITICAL_ENTRY_HEIGHT_SCALE: float = 1.96
const CRITICAL_ENTRY_RING_COUNT: int = 1
const CRITICAL_ENTRY_SPARK_COUNT: int = 8
const CRITICAL_ENTRY_FRAGMENT_COUNT: int = 2
const CRITICAL_ENTRY_PLUME_LAYERS: int = 2

const CRITICAL_SURGE_MIN_INTERVAL_SEC: float = 0.35
const CRITICAL_SURGE_MAX_INTERVAL_SEC: float = 0.90
const CRITICAL_SURGE_MIN_DURATION_SEC: float = 0.25
const CRITICAL_SURGE_MAX_DURATION_SEC: float = 0.45
const CRITICAL_SURGE_HEIGHT_SCALE: float = 2.50
const CRITICAL_MAX_SPARKS: int = 8
const CRITICAL_MAX_FRAGMENTS: int = 3
const CRITICAL_MAX_ACTIVE_PULSES: int = 2

static func classify_pressure_transition(
	history_valid: bool,
	viewer_owner_id: int,
	old_owner_id: int,
	new_owner_id: int,
	old_power: int,
	new_power: int,
	hostile_capture_pressure: bool
) -> String:
	# This is a disposable presentation classification over consecutive
	# canonical render samples. It never becomes simulation state.
	if not history_valid or old_owner_id != new_owner_id:
		return PRESSURE_RESET
	if viewer_owner_id <= 0 or new_owner_id != viewer_owner_id:
		return PRESSURE_CLEAR
	if not hostile_capture_pressure or new_power > old_power:
		return PRESSURE_CLEAR
	if (
		new_power < old_power
		and new_power > 0
		and new_power <= PRESSURE_TRIGGER_MAX_POWER
	):
		return PRESSURE_TRIGGER
	return PRESSURE_HOLD

static func classify_tier_rupture(old_tier: int, new_tier: int) -> String:
	var previous: int = clampi(
		old_tier,
		HiveGrowthRules.TIER_SMALL,
		HiveGrowthRules.TIER_LARGE
	)
	var current: int = clampi(
		new_tier,
		HiveGrowthRules.TIER_SMALL,
		HiveGrowthRules.TIER_LARGE
	)
	if current >= previous:
		return BURST_NONE
	if current <= HiveGrowthRules.TIER_SMALL:
		return BURST_MAJOR_RUPTURE
	if previous >= HiveGrowthRules.TIER_LARGE and current <= HiveGrowthRules.TIER_MEDIUM:
		return BURST_MINOR_RUPTURE
	return BURST_NONE

static func profile_for_burst(burst_kind: String) -> Dictionary:
	match burst_kind:
		BURST_MINOR_RUPTURE:
			return _profile(
				MINOR_DURATION_SEC,
				MINOR_HANDOFF_SEC,
				MINOR_HEIGHT_SCALE,
				MINOR_RING_COUNT,
				MINOR_SPARK_COUNT,
				MINOR_FRAGMENT_COUNT,
				MINOR_PLUME_LAYERS
			)
		BURST_MAJOR_RUPTURE:
			return _profile(
				MAJOR_DURATION_SEC,
				MAJOR_HANDOFF_SEC,
				MAJOR_HEIGHT_SCALE,
				MAJOR_RING_COUNT,
				MAJOR_SPARK_COUNT,
				MAJOR_FRAGMENT_COUNT,
				MAJOR_PLUME_LAYERS
			)
		BURST_CRITICAL_ENTRY:
			return _profile(
				CRITICAL_ENTRY_DURATION_SEC,
				CRITICAL_ENTRY_HANDOFF_SEC,
				CRITICAL_ENTRY_HEIGHT_SCALE,
				CRITICAL_ENTRY_RING_COUNT,
				CRITICAL_ENTRY_SPARK_COUNT,
				CRITICAL_ENTRY_FRAGMENT_COUNT,
				CRITICAL_ENTRY_PLUME_LAYERS
			)
	return {}

static func _profile(
	duration_sec: float,
	handoff_sec: float,
	height_scale: float,
	ring_count: int,
	spark_count: int,
	fragment_count: int,
	plume_layers: int
) -> Dictionary:
	return {
		"duration_sec": duration_sec,
		"critical_handoff_sec": handoff_sec,
		"height_scale": height_scale,
		"ring_count": ring_count,
		"spark_count": spark_count,
		"fragment_count": fragment_count,
		"plume_layers": plume_layers
	}
