#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
ARTIFACT_DIR="${PERF_PACING_DIAGNOSTIC_DIR:-${ROOT_DIR}/artifacts/perf_harness_pacing_diagnostic}"
HARNESS="res://scripts/tests/perf_benchmark_suite.gd"
SUITE="phase1_static_fixtures"
MODE="static_windowed_deterministic"

mkdir -p "${ARTIFACT_DIR}"

capture_host_state() {
  local destination="${ARTIFACT_DIR}/host_state.txt"
  {
    date -u '+utc=%Y-%m-%dT%H:%M:%SZ'
    printf 'git_commit=%s\n' "$(git -C "${ROOT_DIR}" rev-parse HEAD)"
    printf 'git_branch=%s\n' "$(git -C "${ROOT_DIR}" branch --show-current)"
    printf 'git_dirty=%s\n' "$(test -n "$(git -C "${ROOT_DIR}" status --porcelain)" && printf true || printf false)"
    printf 'godot_version=%s\n' "$("${GODOT_BIN}" --version)"
    printf 'machine_arch=%s\n' "$(uname -m)"
    uname -a
    uptime
    sw_vers
    pmset -g custom
    system_profiler SPDisplaysDataType SPPowerDataType
  } >"${destination}" 2>&1
}

validate_report_contract() {
  local report_path="$1"
  jq -e '
    .run_status == "COMPLETED" and
    .integrity_status == "PASS" and
    .determinism.pass == true and
    .isolation.pass == true and
    .backend_isolation.pass == true and
    .scenario_count == 6 and
    ([.scenarios[].integrity_failures | length] | all(. == 0))
  ' "${report_path}" >/dev/null
}

capture_variant() {
  local label="$1"
  local collection_level="$2"
  shift 2
  local report_rel="artifacts/perf_harness_pacing_diagnostic/${label}.json"
  local report_path="${ROOT_DIR}/${report_rel}"
  local log_path="${ARTIFACT_DIR}/${label}.log"
  local summary_path="${ARTIFACT_DIR}/${label}.summary.json"
  local user_dir="SwarmfrontPerfPacingDiagnostic_${label}"
  local rc

  set +e
  "${GODOT_BIN}" "$@" --path "${ROOT_DIR}" --script "${HARNESS}" -- \
    --sf-perf-harness \
    --perf-user-dir="${user_dir}" \
    --collection-level="${collection_level}" \
    --suite="${SUITE}" \
    --mode="${MODE}" \
    --output="res://${report_rel}" 2>&1 | tee "${log_path}"
  rc=${PIPESTATUS[0]}
  set -e

  if [[ ! -f "${report_path}" ]]; then
    echo "PERF_PACING_DIAGNOSTIC_FAIL label=${label} reason=report_missing rc=${rc}"
    return 2
  fi
  if ! validate_report_contract "${report_path}"; then
    echo "PERF_PACING_DIAGNOSTIC_FAIL label=${label} reason=correctness_contract rc=${rc}"
    return 2
  fi
  if [[ "${collection_level}" == "FULL" ]]; then
    jq -e 'all(.scenarios[]; .collection.retention.raw_sample_capture == true and .collection.retention.retained_raw_sample_count == 300)' "${report_path}" >/dev/null
  fi

  jq --arg label "${label}" --argjson process_rc "${rc}" '{
    label: $label,
    process_rc: $process_rc,
    pass,
    run_status,
    integrity_status,
    collection_level,
    git,
    godot,
    machine,
    renderer,
    viewport,
    pacing,
    determinism_pass: .determinism.pass,
    isolation_pass: .isolation.pass,
    backend_isolation_pass: .backend_isolation.pass,
    scenarios: [.scenarios[] | {
      scenario_id,
      repetition_index,
      pass,
      average_frame_ms,
      p95_frame_ms,
      p99_frame_ms,
      max_frame_ms,
      hitch_count,
      failed_gates,
      environment_compatibility_hash,
      fixture_config_hash
    }]
  }' "${report_path}" >"${summary_path}"
  printf '%s\t%s\t%s\n' "${label}" "${collection_level}" "${rc}" >>"${ARTIFACT_DIR}/process_status.tsv"
  echo "PERF_PACING_DIAGNOSTIC_CAPTURE label=${label} collection=${collection_level} performance_rc=${rc} correctness=PASS"
}

run_focused_gate_load() {
  local gates=(
    tools/perf_gate_a_smoke_test.gd
    tools/perf_gate_b_smoke_test.gd
    tools/perf_gate_c_smoke_test.gd
    tools/perf_gate_d_smoke_test.gd
    tools/perf_gate_e_smoke_test.gd
    tools/perf_gate_f_smoke_test.gd
    tools/perf_phase1_gate_a_smoke_test.gd
    tools/perf_phase1_gate_b_smoke_test.gd
    tools/perf_phase1_gate_c_smoke_test.gd
    tools/perf_phase1_gate_d_smoke_test.gd
    tools/perf_phase1_gate_e_smoke_test.gd
    tools/perf_phase1_gate_f_smoke_test.gd
    tools/perf_phase2_gate_a_smoke_test.gd
    tools/perf_phase2_gate_b_smoke_test.gd
    tools/perf_phase2_gate_c_smoke_test.gd
    tools/perf_phase2_gate_d_smoke_test.gd
    tools/perf_phase2_gate_e_smoke_test.gd
    tools/perf_phase2_gate_f_smoke_test.gd
    tools/perf_phase2_gate_g_smoke_test.gd
  )
  local gate
  for gate in "${gates[@]}"; do
    "${GODOT_BIN}" --headless --path "${ROOT_DIR}" --script "res://${gate}"
  done
}

rm -f "${ARTIFACT_DIR}/process_status.tsv"
capture_host_state
capture_variant default_first_minimal MINIMAL
capture_variant default_repeat_minimal MINIMAL
capture_variant default_raw_full FULL
capture_variant vsync_disabled_full FULL --disable-vsync
run_focused_gate_load 2>&1 | tee "${ARTIFACT_DIR}/focused_gate_load.log"
capture_variant default_post_load_minimal MINIMAL

jq -s '{
  schema: "sf_perf_harness_pacing_diagnostic_matrix_v1",
  status: "CAPTURED",
  variants: .
}' \
  "${ARTIFACT_DIR}/default_first_minimal.summary.json" \
  "${ARTIFACT_DIR}/default_repeat_minimal.summary.json" \
  "${ARTIFACT_DIR}/default_raw_full.summary.json" \
  "${ARTIFACT_DIR}/vsync_disabled_full.summary.json" \
  "${ARTIFACT_DIR}/default_post_load_minimal.summary.json" \
  >"${ARTIFACT_DIR}/matrix_summary.json"

echo "PERF_PACING_DIAGNOSTIC: PASS correctness_contracts=5 matrix=${ARTIFACT_DIR}/matrix_summary.json"
