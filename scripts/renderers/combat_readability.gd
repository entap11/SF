extends RefCounted
## Disposable presentation derived only from canonical render samples and UI focus.

const SETTING := "swarmfront/arena/combat_readability_enabled"

static func is_enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, false))

static func owner_of(hive: Dictionary) -> int:
	return int(hive.get("owner_id", hive.get("owner", 0)))

static func allied(a: int, b: int, teams: Dictionary) -> bool:
	return a > 0 and b > 0 and int(teams.get(a, a)) == int(teams.get(b, b))

static func unit_source(unit: Dictionary) -> int:
	return int(unit.get("from_id", unit.get("from", unit.get("src_id", -1))))

static func unit_target(unit: Dictionary) -> int:
	return int(unit.get("to_id", unit.get("to", unit.get("dst_id", -1))))

static func build_context(rm: Dictionary, focus_hive: int, focus_lane: int, teams: Dictionary) -> Dictionary:
	var hives: Dictionary = {}
	for entry in rm.get("hives", []):
		if entry is Dictionary:
			hives[int(entry.get("id", 0))] = entry
	if not hives.has(focus_hive):
		focus_hive = -1
	var connections: Dictionary = {}
	var threats: Dictionary = {}
	var focused_lanes: Dictionary = {}
	for lane in rm.get("lanes", []):
		var a: int = int(lane.get("a_id", lane.get("from", 0)))
		var b: int = int(lane.get("b_id", lane.get("to", 0)))
		var id: int = int(lane.get("lane_id", lane.get("id", -1)))
		if not hives.has(a) or not hives.has(b):
			continue
		var send_a: bool = bool(lane.get("send_a", false))
		var send_b: bool = bool(lane.get("send_b", false))
		if not send_a and not send_b:
			continue
		if a == focus_hive or b == focus_hive or id == focus_lane:
			connections[a] = true
			connections[b] = true
			focused_lanes[id] = true
		if send_a:
			_add_threat(threats, a, b, owner_of(hives[a]), hives, teams)
		if send_b:
			_add_threat(threats, b, a, owner_of(hives[b]), hives, teams)
	# In-flight units retain their own owner even if their source changes hands.
	for unit in rm.get("units", []):
		if not unit is Dictionary:
			continue
		var src: int = unit_source(unit)
		var dst: int = unit_target(unit)
		_add_threat(threats, src, dst, int(unit.get("owner_id", 0)), hives, teams)
		if src == focus_hive or dst == focus_hive:
			connections[src] = true
			connections[dst] = true
	return {"focus_hive": focus_hive, "focus_lane": focus_lane, "connections": connections,
		"focused_lanes": focused_lanes, "threats": threats, "hives": hives,
		"teams": teams, "viewer": int(rm.get("viewer_owner_id", 1))}

static func _add_threat(out: Dictionary, src: int, dst: int, owner: int, hives: Dictionary, teams: Dictionary) -> void:
	if src <= 0 or not hives.has(src) or not hives.has(dst) or owner <= 0:
		return
	if allied(owner, owner_of(hives[dst]), teams):
		return
	var incoming: Dictionary = out.get(dst, {})
	incoming["%d:%d" % [src, owner]] = {"source": src, "owner": owner}
	out[dst] = incoming

static func unit_alpha(unit: Dictionary, context: Dictionary) -> float:
	var focus: int = int(context.get("focus_hive", -1))
	var lane: int = int(context.get("focus_lane", -1))
	if focus <= 0 and lane <= 0:
		return 1.0
	if (focus > 0 and (unit_source(unit) == focus or unit_target(unit) == focus)) or (lane > 0 and int(unit.get("lane_id", -1)) == lane):
		return 1.0
	var target: Dictionary = (context.get("hives", {}) as Dictionary).get(unit_target(unit), {})
	var teams: Dictionary = context.get("teams", {})
	var owner: int = int(unit.get("owner_id", 0))
	if allied(owner_of(target), int(context.get("viewer", 1)), teams) and not allied(owner, owner_of(target), teams):
		return 0.72
	return 0.28
