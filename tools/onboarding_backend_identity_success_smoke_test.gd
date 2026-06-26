extends SceneTree

class FakeRankState:
	extends Node
	var calls: Array[Dictionary] = []

	func intent_register_player(
			player_id: String,
			call_sign: String,
			region: String = "",
			friends: Array = [],
			install_metadata: Dictionary = {},
			authoritative_required: bool = false
		) -> Dictionary:
		calls.append({
			"player_id": player_id,
			"call_sign": call_sign,
			"region": region,
			"friends": friends.duplicate(),
			"install_metadata": install_metadata.duplicate(true),
			"authoritative_required": authoritative_required
		})
		return {
			"ok": true,
			"player": {
				"id": "018f0000-0000-7000-8000-000000000123",
				"player_id": "018f0000-0000-7000-8000-000000000123",
				"entap_id": "AAA 777",
				"call_sign": call_sign,
				"display_name": call_sign
			}
		}

var _original_rank_state: Node = null
var _fake_rank_state: FakeRankState = null

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
	profile_manager.set("_call_sign", "BetaSmoke")
	profile_manager.set("_user_id", "")
	profile_manager.set("_display_name", "BetaSmoke")
	profile_manager.set("_handle_chosen", false)
	profile_manager.set("_onboarding_complete", false)

	_original_rank_state = root.get_node_or_null("RankState")
	if _original_rank_state != null:
		_original_rank_state.name = "RankStateOriginal"
	_fake_rank_state = FakeRankState.new()
	_fake_rank_state.name = "RankState"
	root.add_child(_fake_rank_state)
	await process_frame

	var scene: PackedScene = load("res://scenes/ui/onboarding/onboarding_panel.tscn") as PackedScene
	if scene == null:
		_fail("Onboarding scene missing")
		return
	var panel: Control = scene.instantiate() as Control
	root.add_child(panel)
	await process_frame
	var input: LineEdit = panel.get_node_or_null("VBox/DisplayNameInput") as LineEdit
	if input == null:
		_fail("handle input missing")
		return
	input.text = "BetaSmoke_%04d" % int(Time.get_ticks_msec() % 10000)
	panel.call("_on_continue_pressed")
	await process_frame

	if _fake_rank_state.calls.size() != 1:
		_fail("backend registration should be called once")
		return
	var call: Dictionary = _fake_rank_state.calls[0]
	if not str(call.get("player_id", "")).strip_edges().is_empty():
		_fail("onboarding should not send client-generated player id")
		return
	if not bool(call.get("authoritative_required", false)):
		_fail("onboarding should require authoritative backend registration")
		return
	if str(profile_manager.call("get_user_id")) != "018f0000-0000-7000-8000-000000000123":
		_fail("ProfileManager did not cache backend UUIDv7")
		return
	if str(profile_manager.call("get_entap_id")) != "AAA 777":
		_fail("ProfileManager did not cache backend ENTaP ID")
		return
	if not bool(profile_manager.call("is_onboarding_complete")):
		_fail("onboarding should complete after backend identity")
		return
	print("ONBOARDING_BACKEND_IDENTITY_SUCCESS_SMOKE: PASS")
	_cleanup()
	quit(0)

func _fail(message: String) -> void:
	push_error("ONBOARDING_BACKEND_IDENTITY_SUCCESS_SMOKE: %s" % message)
	_cleanup()
	quit(1)

func _cleanup() -> void:
	if _fake_rank_state != null and is_instance_valid(_fake_rank_state):
		_fake_rank_state.queue_free()
	if _original_rank_state != null and is_instance_valid(_original_rank_state):
		_original_rank_state.name = "RankState"
