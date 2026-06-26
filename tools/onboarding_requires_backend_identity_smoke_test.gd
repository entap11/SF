extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("swarmfront/rank/backend_url", "")
	ProjectSettings.set_setting("swarmfront/rank/backend_token", "")
	var rank_state: Node = root.get_node_or_null("RankState")
	if rank_state != null and rank_state.has_method("_configure_transport"):
		rank_state.call("_configure_transport")

	var profile_manager: Node = root.get_node_or_null("ProfileManager")
	if profile_manager == null:
		_fail("ProfileManager missing")
		return
	if profile_manager.has_method("ensure_loaded"):
		profile_manager.call("ensure_loaded")
	if profile_manager.has_method("smoke_force_identity_state"):
		var forced: bool = bool(profile_manager.call("smoke_force_identity_state", "", "", "StaleSmoke", true, true))
		if not forced:
			_fail("could not force stale identity state")
			return
	else:
		_fail("ProfileManager missing smoke_force_identity_state")
		return

	var scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		_fail("MainMenu scene missing")
		return
	var menu: Node = scene.instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	if menu.has_method("_bind_onboarding_gate"):
		menu.call("_bind_onboarding_gate")
		await process_frame
	var overlay: Control = menu.get_node_or_null("ProfileFirstRunOverlay") as Control
	if overlay == null:
		_fail("ProfileFirstRunOverlay missing")
		return
	if not overlay.visible:
		var has_identity: bool = bool(profile_manager.call("has_authoritative_identity")) if profile_manager.has_method("has_authoritative_identity") else false
		var profile_id: String = str(profile_manager.call("get_user_id")) if profile_manager.has_method("get_user_id") else ""
		var entap_id: String = str(profile_manager.call("get_entap_id")) if profile_manager.has_method("get_entap_id") else ""
		_fail("onboarded profile without backend identity should show onboarding overlay; has_identity=%s id=%s entap_id=%s" % [str(has_identity), profile_id, entap_id])
		return
	print("ONBOARDING_REQUIRES_BACKEND_IDENTITY_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("ONBOARDING_REQUIRES_BACKEND_IDENTITY_SMOKE: %s" % message)
	quit(1)
