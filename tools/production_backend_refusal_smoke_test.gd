extends SceneTree

const TestBackendPolicyScript := preload("res://scripts/state/test_backend_policy.gd")
const VsTransportScript := preload("res://scripts/state/vs_handshake_transport_http.gd")
const RankTransportScript := preload("res://scripts/state/rank_transport_http.gd")

var _failed: bool = false

func _init() -> void:
	_expect(not TestBackendPolicyScript.request_allowed_for_runtime("https://production.example/v1", true, ""), "production-looking URL was accepted by default")
	_expect(TestBackendPolicyScript.request_allowed_for_runtime("http://127.0.0.1:8791/v1", true, ""), "IPv4 loopback fixture was rejected")
	_expect(TestBackendPolicyScript.request_allowed_for_runtime("http://localhost:8791/v1", true, ""), "localhost fixture was rejected")
	_expect(TestBackendPolicyScript.request_allowed_for_runtime("http://[::1]:8791/v1", true, ""), "IPv6 loopback fixture was rejected")
	_expect(TestBackendPolicyScript.request_allowed_for_runtime("https://staging.example/v1", true, "1"), "explicit live-test opt-in was rejected")
	_expect(TestBackendPolicyScript.request_allowed_for_runtime("https://production.example/v1", false, ""), "normal non-test client networking was changed")

	OS.set_environment("SF_ALLOW_LIVE_BACKEND_TESTS", "")
	var vs_transport = VsTransportScript.new()
	vs_transport.configure("https://production.example/v1")
	var vs_result: Dictionary = vs_transport.call_action("health", {}) as Dictionary
	_expect(str(vs_result.get("code", "")) == "unsafe_test_backend", "VS transport did not refuse production URL")
	_expect(not bool(vs_result.get("network_attempted", true)), "VS refusal occurred after network activity")
	var rank_transport = RankTransportScript.new()
	rank_transport.configure("https://production.example/v1/rank")
	var rank_result: Dictionary = rank_transport.call_action("get_snapshot", {}) as Dictionary
	_expect(str(rank_result.get("code", "")) == "unsafe_test_backend", "Rank transport did not refuse production URL")
	_expect(not bool(rank_result.get("network_attempted", true)), "Rank refusal occurred after network activity")

	if not _failed:
		print("PRODUCTION_BACKEND_REFUSAL_SMOKE: PASS")
	quit(1 if _failed else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PRODUCTION_BACKEND_REFUSAL_SMOKE: %s" % message)
