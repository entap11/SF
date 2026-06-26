extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var rank_state: Node = root.get_node_or_null("RankState")
	if rank_state == null or not rank_state.has_method("intent_register_player"):
		_fail("RankState missing")
		return
	ProjectSettings.set_setting("swarmfront/rank/backend_url", "")
	ProjectSettings.set_setting("swarmfront/rank/backend_token", "")
	if rank_state.has_method("_configure_transport"):
		rank_state.call("_configure_transport")
	var result: Dictionary = rank_state.call(
		"intent_register_player",
		"",
		"BetaSmoke_%04d" % int(Time.get_ticks_msec() % 10000),
		"NA",
		[],
		{"smoke": "authoritative_required"},
		true
	) as Dictionary
	if bool(result.get("ok", false)):
		_fail("authoritative registration should not fall back locally without backend")
		return
	var reason: String = str(result.get("reason", result.get("err", ""))).strip_edges()
	if reason != "rank_backend_not_configured" and reason != "rank_backend_unavailable":
		_fail("unexpected failure reason: %s" % reason)
		return
	print("RANK_AUTHORITATIVE_REGISTRATION_REQUIRED_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("RANK_AUTHORITATIVE_REGISTRATION_REQUIRED_SMOKE: %s" % message)
	quit(1)
