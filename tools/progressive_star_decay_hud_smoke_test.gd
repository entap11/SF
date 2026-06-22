extends SceneTree

const ProgressiveStarDecayHudScript := preload("res://scripts/ui/progressive_star_decay_hud.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var thresholds: Dictionary = {
		"four_star_ms": 1000,
		"three_star_ms": 2000,
		"two_star_ms": 4000
	}
	_assert_decay(ProgressiveStarDecayHudScript.decay_fractions_for_elapsed(0, thresholds), [0.0, 0.0, 0.0, 0.0], "starts full")
	_assert_decay(ProgressiveStarDecayHudScript.decay_fractions_for_elapsed(500, thresholds), [0.0, 0.0, 0.0, 0.5], "fourth star decays first")
	_assert_decay(ProgressiveStarDecayHudScript.decay_fractions_for_elapsed(1500, thresholds), [0.0, 0.0, 0.5, 1.0], "third star decays second")
	_assert_decay(ProgressiveStarDecayHudScript.decay_fractions_for_elapsed(3000, thresholds), [0.0, 0.5, 1.0, 1.0], "second star decays third")
	_assert_decay(ProgressiveStarDecayHudScript.decay_fractions_for_elapsed(9000, thresholds), [0.0, 1.0, 1.0, 1.0], "one pass star remains")
	var hud: Control = ProgressiveStarDecayHudScript.new()
	hud.size = Vector2(360, 64)
	root.add_child(hud)
	hud.call("configure", thresholds, 1500)
	await process_frame
	if not is_instance_valid(hud):
		_fail("HUD should instantiate")
		return
	print("PROGRESSIVE_STAR_DECAY_HUD_SMOKE: PASS")
	quit(0)


func _assert_decay(actual: Array, expected: Array, label: String) -> void:
	if actual.size() != expected.size():
		_fail("%s size mismatch" % label)
		return
	for i in range(expected.size()):
		var a: float = float(actual[i])
		var e: float = float(expected[i])
		if absf(a - e) > 0.001:
			_fail("%s index %d expected %.3f got %.3f" % [label, i, e, a])
			return


func _fail(message: String) -> void:
	push_error("PROGRESSIVE_STAR_DECAY_HUD_SMOKE: %s" % message)
	quit(1)
