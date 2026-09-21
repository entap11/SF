extends RefCounted

# Exit intents route through existing match services. UI never settles stakes.
static func context(tree: SceneTree) -> Dictionary:
	var ops: Node = tree.root.get_node("OpsState")
	var session: String = str(tree.get_meta("vs_handshake_session_id", ""))
	return {
		"finished": bool(ops.call("is_ending_or_ended")),
		"session_id": session,
		"live": not session.is_empty(),
		"paid": float(tree.get_meta("vs_price_usd", 0)) > 0.0,
		"crucible": preload("res://scripts/state/crucible_ruleset_policy.gd").is_crucible_tree(tree),
		"crucible_match_id": str(tree.get_meta("crucible_match_id", "")),
		"campaign": tree.has_meta("campaign_level_id"),
		"player_id": tree.root.get_node("ProfileManager").call("get_user_id")
	}

static func warning(data: Dictionary) -> String:
	if bool(data.get("finished", false)):
		return "This match has finished. Return to the menu?"
	if bool(data.get("paid", false)) or bool(data.get("crucible", false)):
		return "Quitting now forfeits this game and your stake. Are you sure you want to leave?"
	if bool(data.get("live", false)):
		return "Quitting now gives up this match. You cannot pause a live multiplayer game. Leave the match?"
	if bool(data.get("campaign", false)):
		return "Quit this attempt? You won't unlock the next level or earn a time or stingers. Your previous progress is kept."
	return "Quit this match? This unfinished attempt won't earn a result."

static func request_leave(data: Dictionary, handshake: Node, crucible: Node) -> Dictionary:
	if bool(data.get("finished", false)):
		return {"ok": true}
	var session: String = str(data.get("session_id", ""))
	if not session.is_empty():
		# Includes durable public matches, whose service owns forfeiture/settlement.
		return handshake.call("leave_session", session, str(data.get("player_id", ""))) as Dictionary
	if bool(data.get("crucible", false)):
		return crucible.call("intent_record_lifecycle", str(data.get("crucible_match_id", "")), "voluntary_quit", str(data.get("player_id", "")), {"source": "match_menu"}) as Dictionary
	if bool(data.get("paid", false)):
		return {"ok": false, "err": "missing_match_authority"}
	return {"ok": true}
