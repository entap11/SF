class_name TestBackendPolicy
extends RefCounted

const ALLOW_LIVE_ENV: String = "SF_ALLOW_LIVE_BACKEND_TESTS"

static func automated_test_process() -> bool:
	for arg_any in OS.get_cmdline_args():
		var arg: String = str(arg_any).strip_edges().to_lower()
		if arg == "--script" or arg.ends_with(".gd") or "smoke_test" in arg or "/scripts/dev/" in arg:
			return true
	return false

static func request_allowed(url: String) -> bool:
	if performance_harness_active():
		return false
	return request_allowed_for_runtime(
		url,
		automated_test_process(),
		OS.get_environment(ALLOW_LIVE_ENV)
	)

static func performance_harness_active() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	return loop is SceneTree and bool((loop as SceneTree).get_meta("sf_perf_harness_active", false))

static func request_allowed_for_runtime(url: String, is_automated_test: bool, allow_live_value: String) -> bool:
	if not is_automated_test:
		return true
	if is_loopback_url(url):
		return true
	return allow_live_value.strip_edges() == "1"

static func is_loopback_url(url: String) -> bool:
	var clean: String = url.strip_edges().to_lower()
	var scheme_index: int = clean.find("://")
	if scheme_index >= 0:
		clean = clean.substr(scheme_index + 3)
	clean = clean.get_slice("/", 0)
	if clean.begins_with("["):
		var closing: int = clean.find("]")
		clean = clean.substr(1, closing - 1) if closing > 0 else clean
	else:
		clean = clean.get_slice(":", 0)
	return clean == "localhost" or clean == "::1" or clean.begins_with("127.")
