class_name RewardMatchContext
extends RefCounted

const QUALITY_FAILURE_REASONS: Array[String] = [
	"cancelled",
	"canceled",
	"draw",
	"invalid",
	"no_contest",
	"refund",
	"refunded"
]

static func enrich(tree: SceneTree, base: Dictionary, winner_id: int, reason: String, ops_state: Node = null) -> Dictionary:
	var metadata: Dictionary = base.duplicate(true)
	for key in ["match_elapsed_ms", "elapsed_ms", "match_duration_ms", "duration_ms", "match_remaining_ms", "remaining_ms", "in_overtime", "overtime_active"]:
		if tree != null and tree.has_meta(key):
			metadata[key] = tree.get_meta(key)
	if ops_state != null:
		if not metadata.has("match_elapsed_ms"):
			metadata["match_elapsed_ms"] = maxi(0, int(ops_state.get("match_elapsed_ms")))
		if not metadata.has("match_duration_ms"):
			metadata["match_duration_ms"] = maxi(0, int(ops_state.get("match_duration_ms")))
		if not metadata.has("match_remaining_ms"):
			metadata["match_remaining_ms"] = maxi(0, int(ops_state.get("match_remaining_ms")))
		if not metadata.has("in_overtime"):
			metadata["in_overtime"] = bool(ops_state.get("in_overtime"))
	var elapsed_ms: int = maxi(0, int(metadata.get("match_elapsed_ms", metadata.get("elapsed_ms", 0))))
	metadata["duration_sec"] = float(elapsed_ms) / 1000.0
	metadata["winner_id"] = winner_id
	metadata["reason"] = reason
	var clean_reason: String = reason.strip_edges().to_lower().replace(" ", "_")
	var invalid_result: bool = winner_id <= 0 or clean_reason in QUALITY_FAILURE_REASONS
	metadata["completed"] = not invalid_result
	metadata["minimum_quality_met"] = not invalid_result
	metadata["no_contest"] = clean_reason in ["cancelled", "canceled", "draw", "no_contest"]
	metadata["refunded"] = clean_reason in ["refund", "refunded"]
	metadata["invalid_result"] = invalid_result
	metadata["desync"] = "desync" in clean_reason
	metadata["afk"] = "afk" in clean_reason
	metadata["early_quit"] = "early_quit" in clean_reason
	metadata["immediate_surrender"] = "immediate_surrender" in clean_reason
	return metadata
