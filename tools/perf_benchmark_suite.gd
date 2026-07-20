extends SceneTree

const REPLACEMENT := "res://scripts/tests/perf_benchmark_suite.gd"


func _init() -> void:
	call_deferred("_refuse")


func _refuse() -> void:
	print("perf_benchmark_suite_legacy: %s" % JSON.stringify({
		"status": "DEPRECATED",
		"pass": false,
		"replacement": REPLACEMENT,
		"reason": "legacy runner output is unversioned and cannot satisfy deterministic fixture, isolation, or schema-v3 evidence contracts",
		"command": "godot --headless --path . --script %s -- --sf-perf-harness --suite=quick --mode=canonical_sim_headless" % REPLACEMENT,
		"forensic_alternatives": [
			"res://scripts/tests/rhythmic_lag_isolation.gd",
			"res://scripts/dev/soak_perf_runner.gd"
		]
	}))
	quit(2)
