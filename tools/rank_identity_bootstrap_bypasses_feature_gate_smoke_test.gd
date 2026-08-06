extends SceneTree

const RankStateScript := preload("res://scripts/state/rank_state.gd")

class FakeIdentityTransport extends RefCounted:
	var calls: Array[Dictionary] = []

	func configure(base_url: String, timeout_sec: float, auth_token: String) -> void:
		calls.append({
			"kind": "configure",
			"base_url": base_url,
			"timeout_sec": timeout_sec,
			"auth_token": auth_token
		})

	func call_action(action: String, payload: Dictionary) -> Dictionary:
		calls.append({"kind": "action", "action": action, "payload": payload.duplicate(true)})
		return {"ok": false, "err": "call_sign_not_unique"}

class TestRankState extends RankStateScript:
	var fake_transport := FakeIdentityTransport.new()

	func _new_rank_transport() -> Variant:
		return fake_transport

var _failed: bool = false
var _original_backend_url: Variant
var _rank_state: TestRankState

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_original_backend_url = ProjectSettings.get_setting("swarmfront/rank/backend_url", "")
	ProjectSettings.set_setting("swarmfront/rank/backend_url", "https://identity.example.test/v1/rank")
	var ops_config: Node = root.get_node_or_null("OpsConfig")
	if ops_config == null:
		return _fail("OpsConfig missing")
	ops_config.call("force_config_for_smoke", {
		"schema_version": 1,
		"config_version": "identity-bootstrap-rank-off",
		"feature_flags": {"enable_rank_backend": false}
	}, "remote_fresh")
	_rank_state = TestRankState.new()
	var result: Dictionary = _rank_state.intent_register_player(
		"",
		"Android_test",
		"NA",
		[],
		{"platform": "Android"},
		true
	) as Dictionary
	if str(result.get("err", "")) != "call_sign_not_unique":
		return _fail("identity authority domain result was not preserved: %s" % str(result))
	if _rank_state.fake_transport.calls.size() != 2:
		return _fail("identity transport should be configured and called exactly once")
	var configure_call: Dictionary = _rank_state.fake_transport.calls[0]
	if str(configure_call.get("base_url", "")) != "https://identity.example.test/v1/rank":
		return _fail("identity transport used the wrong backend URL")
	var action_call: Dictionary = _rank_state.fake_transport.calls[1]
	if str(action_call.get("action", "")) != "register_player":
		return _fail("identity bootstrap used the wrong action")
	var payload: Dictionary = action_call.get("payload", {}) as Dictionary
	if payload.has("id") or payload.has("player_id"):
		return _fail("identity bootstrap must not send a client-generated player ID")
	if str(payload.get("call_sign", "")) != "Android_test":
		return _fail("identity bootstrap did not preserve the call sign")
	print("RANK_IDENTITY_BOOTSTRAP_BYPASSES_FEATURE_GATE_SMOKE: PASS")
	_cleanup()
	quit(0)

func _fail(message: String) -> void:
	_failed = true
	push_error("RANK_IDENTITY_BOOTSTRAP_BYPASSES_FEATURE_GATE_SMOKE: %s" % message)
	_cleanup()
	quit(1)

func _cleanup() -> void:
	ProjectSettings.set_setting("swarmfront/rank/backend_url", _original_backend_url)
	if _rank_state != null and is_instance_valid(_rank_state):
		_rank_state.free()
