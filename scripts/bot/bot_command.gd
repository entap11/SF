# Simulation command adapter. Revalidate the original actor after any thinking delay.
extends RefCounted

static func apply(ops: Node, seat: int, command: Dictionary) -> Dictionary:
	var state: GameState = ops.get("state")
	if state == null or int(ops.get("match_phase")) != 1 or bool(ops.get("input_locked")) or bool(ops.get("match_clock_paused")):
		return {"ok": false, "reason": "match_not_running"}
	var src := int(command.get("src", -1))
	var dst := int(command.get("dst", -1))
	var source: HiveData = state.find_hive_by_id(src)
	if seat < 1 or seat > 4 or source == null or int(source.owner_id) != seat:
		return {"ok": false, "reason": "ownership"}
	if state.find_hive_by_id(dst) == null or dst == src:
		return {"ok": false, "reason": "missing_hive"}
	var intent := str(command.get("intent", ""))
	if intent == "retract":
		if not state.is_outgoing_lane_active(src, dst):
			return {"ok": false, "reason": "not_enabled"}
		ops.call("retract_lane", src, dst, seat)
		return {"ok": true, "reason": "", "lane_id": int(state.lanes[state.lane_index_between(src, dst)].id)}
	if not ["attack", "feed", "swarm"].has(intent):
		return {"ok": false, "reason": "unsupported_intent"}
	return ops.call("apply_lane_intent", src, dst, intent)
