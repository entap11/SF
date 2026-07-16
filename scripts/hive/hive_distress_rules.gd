class_name HiveDistressRules
extends RefCounted

# Presentation-only calibration values. These do not alter capture rules.
const CRITICAL_ENTER_POWER: int = 6
const CRITICAL_EXIT_POWER: int = 9
const IMMINENT_ENTER_POWER: int = 3
const IMMINENT_EXIT_POWER: int = 5

const STATE_NORMAL: int = 0
const STATE_CRITICAL: int = 1
const STATE_IMMINENT: int = 2

static func next_state(
	previous_state: int,
	viewer_owner_id: int,
	hive_owner_id: int,
	power: int,
	hostile_capture_pressure: bool
) -> int:
	if (
		viewer_owner_id <= 0
		or hive_owner_id != viewer_owner_id
		or not hostile_capture_pressure
	):
		return STATE_NORMAL

	var safe_power: int = maxi(0, power)
	match previous_state:
		STATE_IMMINENT:
			if safe_power < IMMINENT_EXIT_POWER:
				return STATE_IMMINENT
			if safe_power < CRITICAL_EXIT_POWER:
				return STATE_CRITICAL
			return STATE_NORMAL
		STATE_CRITICAL:
			if safe_power <= IMMINENT_ENTER_POWER:
				return STATE_IMMINENT
			if safe_power < CRITICAL_EXIT_POWER:
				return STATE_CRITICAL
			return STATE_NORMAL
		_:
			if safe_power <= IMMINENT_ENTER_POWER:
				return STATE_IMMINENT
			if safe_power <= CRITICAL_ENTER_POWER:
				return STATE_CRITICAL
			return STATE_NORMAL

static func severity_for_power(power: int) -> float:
	return clampf(
		float((CRITICAL_ENTER_POWER + 1) - maxi(0, power))
		/ float(CRITICAL_ENTER_POWER),
		0.0,
		1.0
	)

static func state_name(state: int) -> String:
	match state:
		STATE_CRITICAL:
			return "critical"
		STATE_IMMINENT:
			return "imminent"
		_:
			return "normal"
