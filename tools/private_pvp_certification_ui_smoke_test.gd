extends SceneTree

const Policy := preload("res://scripts/state/private_pvp_certification_policy.gd")
const LOBBY_SCENE_PATH: String = "res://scenes/ui/VsLobby.tscn"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(Policy.is_free_private_1v1("1V1", false), "free private 1v1 should be eligible")
	_expect(Policy.is_free_private_1v1("PVP", false), "free private PVP alias should be eligible")
	_expect(not Policy.is_free_private_1v1("1V1", true), "paid 1v1 must remain gated")
	_expect(not Policy.is_free_private_1v1("2V2", false), "non-1v1 modes must remain gated")
	_test_export_feature_boundaries()

	var scene: PackedScene = load(LOBBY_SCENE_PATH) as PackedScene
	_expect(scene != null, "VsLobby scene should load")
	if scene == null:
		_finish()
		return
	var lobby: Control = scene.instantiate() as Control
	_expect(lobby != null, "VsLobby should instantiate")
	if lobby == null:
		_finish()
		return
	root.add_child(lobby)
	await process_frame
	lobby.call("_apply_private_pvp_certification_ui", true)
	lobby.call("configure", "1V1", 1, 0, true, {"human_pvp": true})

	var create_button: Button = lobby.get_node("Panel/VBox/Buttons/SmsInvite") as Button
	var join_row: HBoxContainer = lobby.get_node("Panel/VBox/JoinRow") as HBoxContainer
	var join_button: Button = lobby.get_node("Panel/VBox/JoinRow/JoinButton") as Button
	_expect(create_button.visible and create_button.text == "Create Invite", "certification build should expose create invite")
	_expect(create_button.get_theme_font_size("font_size") == 135, "create invite text should be three times its ordinary size")
	_expect(join_row.visible and join_button.visible, "certification build should expose invite-code join")
	var invite_label: Label = lobby.get_node("Panel/VBox/Invite") as Label
	_expect(invite_label.get_theme_font_size("font_size") == 90, "displayed invite code should be twice its previous size")
	_expect(not bool(lobby.get("_auto_start_quick_search")), "certification lobby must not auto-start public quick match")
	var lobby_source: String = FileAccess.get_file_as_string("res://scripts/ui/vs_lobby.gd")
	_expect(lobby_source.contains("invite_label.visible = _private_pvp_certification_enabled"), "host invite code should remain visible while waiting")

	lobby.set("_session_id", "cert_session")
	lobby.call("_sync_join_row_visibility")
	_expect(not join_row.visible, "join controls should hide after entering a session")

	lobby.set("_session_id", "")
	lobby.call("_apply_private_pvp_certification_ui", false)
	_expect(not create_button.visible and not join_row.visible, "ordinary builds should keep private controls hidden")
	_expect(create_button.get_theme_font_size("font_size") == 45, "ordinary invite text should retain its baseline size")
	_finish()


func _test_export_feature_boundaries() -> void:
	var presets: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	var ios_store: String = _preset_block(presets, "iOS")
	var ios_cert: String = _preset_block(presets, "iOS Private PvP Certification")
	var android_device: String = _preset_block(presets, "Android Release Device")
	var android_store: String = _preset_block(presets, "Android Release Candidate")
	_expect(ios_store.contains("custom_features=\"\""), "general iOS export must omit certification feature")
	_expect(ios_cert.contains("private_pvp_certification") and ios_cert.contains("private_pvp_diagnostics"), "iOS certification export must carry private PvP and diagnostic features")
	_expect(android_device.contains("private_pvp_certification") and android_device.contains("private_pvp_diagnostics"), "Android device export must carry private PvP and diagnostic features")
	_expect(android_store.contains("custom_features=\"\""), "Android store AAB must omit certification feature")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/state/vs_pvp_runtime.gd")
	_expect(runtime_source.contains("OS.has_feature(FEATURE_PRIVATE_PVP_DIAGNOSTICS)"), "diagnostic exports should opt into the existing bounded runtime telemetry")
	_expect(runtime_source.contains("first_hash_mismatch_authority_snapshot"), "diagnostic exports should retain the first divergent authority snapshot")
	_expect(runtime_source.contains("call_deferred("), "first divergent snapshot persistence must remain outside the authoritative tick")
	var menu_source: String = FileAccess.get_file_as_string("res://scripts/ui/main_menu.gd")
	_expect(menu_source.contains("PrivatePvpCertificationPolicy.allows_rollout_bypass(mode_id, paid)"), "main menu should permit only the explicit certification bypass")
	_expect(menu_source.contains("const HONEY_WIDGET_TOP_OFFSET: float = 35.0"), "main-menu Honey placement handoff should remain restored")
	_expect(menu_source.contains("const TIER_WIDGET_TOP_OFFSET: float = 35.0"), "main-menu rank/tier placement handoff should remain restored")
	_expect(menu_source.contains("const MM_BACKGROUND_EXTRA_SIDE_PX: float = 40.0"), "main-menu banner placement handoff should remain restored")
	_expect(menu_source.contains("const MM_WELCOME_HANDLE_TOP_PX: float = 420.0"), "main-menu Welcome placement handoff should remain restored")
	_expect(menu_source.contains("const HIVE_BUTTON_CENTER_Y: float = 70.0"), "main-menu Hive button placement handoff should remain restored")
	_expect(menu_source.contains("const BOTTOM_NAV_ROW_SEPARATION: float = 32.0"), "main-menu bottom navigation row placement handoff should remain restored")
	_expect(menu_source.contains("const BOTTOM_NAV_BOTTOM_LIFT: float = 45.0"), "main-menu bottom navigation lift should remain restored")


func _preset_block(source: String, preset_name: String) -> String:
	var marker: String = "name=\"%s\"" % preset_name
	var marker_at: int = source.find(marker)
	if marker_at < 0:
		return ""
	var block_start: int = source.rfind("[preset.", marker_at)
	var block_end: int = source.find("\n[preset.", marker_at)
	if block_end < 0:
		block_end = source.length()
	return source.substr(block_start, block_end - block_start)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PRIVATE_PVP_CERTIFICATION_UI_SMOKE: %s" % message)


func _finish() -> void:
	if not _failed:
		print("PRIVATE_PVP_CERTIFICATION_UI_SMOKE: PASS")
	quit(1 if _failed else 0)
