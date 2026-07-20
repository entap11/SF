extends SceneTree

const Comparator := preload("res://scripts/state/public_contest_comparator.gd")

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/public_contests/comparator_golden_v1.json"))
	assert(parsed is Dictionary)
	for case_v in (parsed as Dictionary).get("cases", []):
		var case: Dictionary = case_v as Dictionary
		var scored: Dictionary = Comparator.score(str(case.get("comparator_id", "")),
			case.get("map_ids", []) as Array, case.get("metrics", {}) as Dictionary,
			case.get("attempt_policy", {}) as Dictionary)
		assert(bool(scored.get("ok", false)), "%s failed: %s" % [case.get("id", ""), scored])
		var expected: Dictionary = case.get("expected", {}) as Dictionary
		assert(int(scored.get("primary", 0)) == int(expected.get("primary", 0)))
		assert(int(scored.get("secondary", 0)) == int(expected.get("secondary", 0)))
		assert(int(scored.get("tertiary", 0)) == int(expected.get("tertiary", 0)))
		var result: Dictionary = scored.get("result", {}) as Dictionary
		for key in ["aggregate_elapsed_ticks", "stars", "completed_stage_count", "elapsed_ticks"]:
			if expected.has(key):
				assert(int(result.get(key, -1)) == int(expected.get(key, -2)))
	print("public_contest_comparator_smoke_test: PASS")
	quit(0)
