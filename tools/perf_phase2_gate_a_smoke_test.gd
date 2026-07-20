extends SceneTree

const PROGRAM_PATH := "res://data/perf/harness_v1_completion_program.json"
const EXPECTED_PHASES: Array[String] = [
	"P2_A_PROGRAM_CONTRACT",
	"P2_B_MOVING_UNIT_SCALE",
	"P2_C_UPGRADE_AND_SWARM_STRESS",
	"P2_D_BATTLEFIELD_UI_STRESS",
	"P2_E_LIFECYCLE_SOAK",
	"P2_F_FEATURE_ISOLATION",
	"P2_G_BASELINES_AND_EXIT"
]
const REQUIRED_EXCLUSIONS: Array[String] = [
	"3-player fixtures",
	"4-player fixtures",
	"multi-map async fixtures",
	"multi-stage async fixtures",
	"performance optimization"
]

var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var program: Dictionary = _load_program()
	_expect(not program.is_empty(), "completion program must load")
	if not program.is_empty():
		_expect(str(program.get("program_schema", "")) == "sf_perf_harness_v1_completion_program_v1", "program schema must fail closed")
		_expect(int(program.get("program_version", 0)) == 1, "program version must be explicit")
		_expect(str(program.get("status", "")) == "IMPLEMENTATION_APPROVED", "program approval status must be explicit")
		_expect(program.get("phase_order", []) == EXPECTED_PHASES, "phase order must be exact")
		_validate_phases(program.get("phases", []))
		_validate_exclusions(program.get("explicit_exclusions", []))
		_expect((program.get("global_stop_conditions", []) as Array).size() >= 6, "global stop conditions must remain explicit")
		_expect((program.get("external_evidence_only", []) as Array).has("device thermals"), "device thermals must not be fabricated in-engine")
	var plan_text: String = FileAccess.get_file_as_string("res://docs/swarmfront_performance_harness_v1_completion_plan.md")
	_expect(plan_text.contains("No third harness is permitted"), "plan must preserve canonical harness ownership")
	_expect(plan_text.contains("No merge or deployment is part of this sprint"), "plan must stop before integration")
	if _failures.is_empty():
		print("PERF_PHASE2_GATE_A_SMOKE: PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error("PERF_PHASE2_GATE_A_SMOKE: %s" % failure)
		quit(1)

func _load_program() -> Dictionary:
	if not FileAccess.file_exists(PROGRAM_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROGRAM_PATH))
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}

func _validate_phases(phases_any: Variant) -> void:
	_expect(typeof(phases_any) == TYPE_ARRAY, "phases must be an array")
	if typeof(phases_any) != TYPE_ARRAY:
		return
	var phases: Array = phases_any as Array
	_expect(phases.size() == EXPECTED_PHASES.size(), "phase count must be exact")
	var seen: Dictionary = {}
	for phase_any in phases:
		_expect(typeof(phase_any) == TYPE_DICTIONARY, "each phase must be a dictionary")
		if typeof(phase_any) != TYPE_DICTIONARY:
			continue
		var phase: Dictionary = phase_any as Dictionary
		var phase_id: String = str(phase.get("phase_id", ""))
		_expect(EXPECTED_PHASES.has(phase_id), "phase id must be approved: %s" % phase_id)
		_expect(not seen.has(phase_id), "phase id must be unique: %s" % phase_id)
		seen[phase_id] = true
		var status: String = str(phase.get("status", ""))
		if phase_id == "P2_A_PROGRAM_CONTRACT":
			_expect(status == "IMPLEMENTED", "P2-A must be implemented")
		else:
			_expect(status == "PLANNED", "%s must not be pre-approved" % phase_id)

func _validate_exclusions(exclusions_any: Variant) -> void:
	_expect(typeof(exclusions_any) == TYPE_ARRAY, "explicit exclusions must be an array")
	if typeof(exclusions_any) != TYPE_ARRAY:
		return
	var exclusions: Array = exclusions_any as Array
	for required in REQUIRED_EXCLUSIONS:
		_expect(exclusions.has(required), "missing exclusion: %s" % required)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
