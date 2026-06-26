extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var rank_state: Node = root.get_node_or_null("RankState")
	if rank_state == null or not rank_state.has_method("intent_register_player"):
		_fail("RankState missing")
		return
	if rank_state.has_method("_configure_transport"):
		rank_state.call("_configure_transport")
	var call_sign: String = "GdClient%04d" % int(Time.get_ticks_msec() % 10000)
	var result: Dictionary = rank_state.call(
		"intent_register_player",
		"",
		call_sign,
		"NA",
		[],
		{"smoke": "godot_client"},
		true
	) as Dictionary
	if not bool(result.get("ok", false)):
		_fail("registration failed %s" % str(result))
		return
	var player: Dictionary = result.get("player", {}) as Dictionary
	var entap_id: String = str(player.get("entap_id", ""))
	if entap_id.length() != 7:
		_fail("invalid entap_id %s" % entap_id)
		return
	print("RANK_STAGING_CLIENT_SMOKE: PASS %s %s" % [str(player.get("call_sign", "")), entap_id])
	quit(0)

func _fail(message: String) -> void:
	push_error("RANK_STAGING_CLIENT_SMOKE: %s" % message)
	quit(1)
