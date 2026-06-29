extends SceneTree

const DEBUG_PROFILE_ID := "018f2b2c-1234-7abc-8def-123456789abc"
const DEBUG_ENTAP_ID := "SFP 501"

class FakeUnavailableRankState:
	extends Node
	var calls: int = 0

	func intent_register_player(
			player_id: String,
			call_sign: String,
			region: String = "",
			friends: Array = [],
			install_metadata: Dictionary = {},
			authoritative_required: bool = false
		) -> Dictionary:
		calls += 1
		return {"ok": false, "reason": "rank_backend_unavailable"}

var _original_rank_state: Node = null
var _fake_rank_state: FakeUnavailableRankState = null
var _guide_prompt_requested: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var profile_manager: Node = root.get_node_or_null("ProfileManager")
	if profile_manager == null:
		_fail("ProfileManager missing")
		return
	if profile_manager.has_method("ensure_loaded"):
		profile_manager.call("ensure_loaded")
	profile_manager.set("_id", "")
	profile_manager.set("_entap_id", "")
	profile_manager.set("_call_sign", "OfflineSmoke")
	profile_manager.set("_user_id", "")
	profile_manager.set("_display_name", "OfflineSmoke")
	profile_manager.set("_handle_chosen", false)
	profile_manager.set("_onboarding_complete", false)

	_original_rank_state = root.get_node_or_null("RankState")
	if _original_rank_state != null:
		_original_rank_state.name = "RankStateOriginal"
	_fake_rank_state = FakeUnavailableRankState.new()
	_fake_rank_state.name = "RankState"
	root.add_child(_fake_rank_state)
	await process_frame

	var scene: PackedScene = load("res://scenes/ui/onboarding/onboarding_panel.tscn") as PackedScene
	if scene == null:
		_fail("Onboarding scene missing")
		return
	var panel: Control = scene.instantiate() as Control
	root.add_child(panel)
	if panel.has_signal("onboarding_guide_prompt_requested"):
		panel.connect("onboarding_guide_prompt_requested", func() -> void:
			_guide_prompt_requested = true
		)
	await process_frame

	var input: LineEdit = panel.get_node_or_null("VBox/DisplayNameInput") as LineEdit
	if input == null:
		_fail("call sign input missing")
		return
	input.text = "OfflineSmoke"
	var age_input: LineEdit = panel.get_node_or_null("VBox/AgeSpin") as LineEdit
	if age_input == null:
		_fail("age input missing")
		return
	age_input.text = "18"
	panel.call("_on_continue_pressed")
	await process_frame

	if _fake_rank_state.calls != 1:
		_fail("backend registration should be attempted once before debug fallback")
		return
	if str(profile_manager.call("get_user_id")) != DEBUG_PROFILE_ID:
		_fail("debug offline fallback did not cache debug UUIDv7")
		return
	if str(profile_manager.call("get_entap_id")) != DEBUG_ENTAP_ID:
		_fail("debug offline fallback did not cache debug ENTaP ID")
		return
	if str(profile_manager.call("get_call_sign")) != "OfflineSmoke":
		_fail("debug offline fallback did not preserve call sign")
		return
	if not bool(profile_manager.call("is_onboarding_complete")):
		_fail("debug offline fallback should complete onboarding")
		return
	if not _guide_prompt_requested:
		_fail("debug offline fallback should request guide prompt")
		return
	print("ONBOARDING_DEBUG_OFFLINE_UNBLOCK_SMOKE: PASS")
	_cleanup()
	quit(0)

func _fail(message: String) -> void:
	push_error("ONBOARDING_DEBUG_OFFLINE_UNBLOCK_SMOKE: %s" % message)
	_cleanup()
	quit(1)

func _cleanup() -> void:
	if _fake_rank_state != null and is_instance_valid(_fake_rank_state):
		_fake_rank_state.queue_free()
	if _original_rank_state != null and is_instance_valid(_original_rank_state):
		_original_rank_state.name = "RankState"
