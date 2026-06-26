extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = root.get_node_or_null("AdManager")
	if manager == null:
		_fail("AdManager autoload missing")
		return
	ProjectSettings.set_setting("swarmfront/ads/fake_ads", false)
	var policy: Dictionary = manager.call("get_policy", "smoke_in_game", "in_game") as Dictionary
	if not bool(policy.get("allowed", false)):
		_fail("in_game placement should be allowed")
		return
	if bool(policy.get("personalized_ads_allowed", true)):
		_fail("personalized ads should default off")
		return
	var no_provider: Dictionary = manager.call("request_ad", "smoke_in_game", "in_game") as Dictionary
	if bool(no_provider.get("filled", false)):
		_fail("manager should not fill without provider or fake ads")
		return
	var unsupported: Dictionary = manager.call("request_ad", "bad_slot", "unsupported") as Dictionary
	if bool(unsupported.get("filled", false)):
		_fail("unsupported placement should not fill")
		return
	ProjectSettings.set_setting("swarmfront/ads/fake_ads", true)
	var fake_fill: Dictionary = manager.call("request_ad", "fake_slot", "post_match") as Dictionary
	if not bool(fake_fill.get("filled", false)):
		_fail("fake ads should fill approved placement")
		return
	var impression: Dictionary = manager.call("record_impression", "fake_slot") as Dictionary
	if not bool(impression.get("ok", false)):
		_fail("filled fake slot should accept impression")
		return
	var tap: Dictionary = manager.call("record_tap", "fake_slot") as Dictionary
	if not bool(tap.get("ok", false)):
		_fail("filled fake slot should accept tap")
		return
	var state: Dictionary = manager.call("get_slot_state", "fake_slot") as Dictionary
	if int(state.get("impressions", 0)) != 1 or int(state.get("taps", 0)) != 1:
		_fail("slot counters did not persist")
		return
	ProjectSettings.set_setting("swarmfront/ads/fake_ads", false)
	print("AD_MANAGER_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("AD_MANAGER_SMOKE: %s" % message)
	quit(1)
