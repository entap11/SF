extends SceneTree

const REPLACEMENT := "res://scripts/tools/perf_compare.gd"


func _init() -> void:
	call_deferred("_refuse")


func _refuse() -> void:
	print("perf_compare_legacy: %s" % JSON.stringify({
		"status": "DEPRECATED",
		"pass": false,
		"replacement": REPLACEMENT,
		"reason": "legacy comparator does not validate result schema v3 or comparison fingerprints",
		"command": "godot --headless --path . --script %s -- res://baseline.json res://current.json" % REPLACEMENT
	}))
	quit(2)
