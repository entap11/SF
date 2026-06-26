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
				"id": "018f0000-0000-7000-8000-000000000001",
				"player_id": "018f0000-0000-7000-8000-000000000001",
				"entap_id": "AAA 123",
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
	if profile_manager != null:
		if profile_manager.has_method("ensure_loaded"):
			profile_manager.call("ensure_loaded")
		profile_manager.set("_id", "")
		profile_manager.set("_entap_id", "")
		profile_manager.set("_call_sign", "RankSmoke")
		profile_manager.set("_user_id", "")
		profile_manager.set("_display_name", "RankSmoke")
	_original_rank_state = root.get_node_or_null("RankState")
	if _original_rank_state != null:
		_original_rank_state.name = "RankStateOriginal"
	_fake_rank_state = FakeRankState.new()
	_fake_rank_state.name = "RankState"
	root.add_child(_fake_rank_state)
	await process_frame

	var scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		_fail("MainMenu scene missing")
		return
	var menu: Node = scene.instantiate()
	root.add_child(menu)
	await process_frame
	if not menu.has_method("_ensure_profile_registered_for_rank"):
		_fail("registration hook missing")
		return
	menu.call("_ensure_profile_registered_for_rank")
	await process_frame
	if _fake_rank_state.calls.size() < 1:
		_fail("rank registration was not called")
		return
	var call: Dictionary = _fake_rank_state.calls[0]
	if not str(call.get("player_id", "")).strip_edges().is_empty():
		_fail("beta registration should not send a client-generated player id")
		return
	if str(call.get("call_sign", "")).strip_edges().is_empty():
		_fail("registered call sign is empty")
		return
	print("ONBOARDING_RANK_REGISTRATION_SMOKE: PASS")
	_cleanup()
	quit(0)

func _fail(message: String) -> void:
	push_error("ONBOARDING_RANK_REGISTRATION_SMOKE: %s" % message)
	_cleanup()
	quit(1)

func _cleanup() -> void:
	if _fake_rank_state != null and is_instance_valid(_fake_rank_state):
		_fake_rank_state.queue_free()
	if _original_rank_state != null and is_instance_valid(_original_rank_state):
		_original_rank_state.name = "RankState"
