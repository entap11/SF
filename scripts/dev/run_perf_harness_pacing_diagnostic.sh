#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
ARTIFACT_DIR="${PERF_PACING_DIAGNOSTIC_DIR:-${ROOT_DIR}/artifacts/perf_harness_pacing_diagnostic}"
HARNESS="res://scripts/tests/perf_benchmark_suite.gd"
SUITE="phase1_static_fixtures"
MODE="static_windowed_deterministic"
VARIANT="${PERF_PACING_DIAGNOSTIC_VARIANT:-default_awake_minimal}"
RUN_ID="${GITHUB_RUN_ID:-local}"
RUN_ATTEMPT="${GITHUB_RUN_ATTEMPT:-1}"

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
    printf 'display_precondition=%s\n' "${PERF_PACING_DISPLAY_PRECONDITION:-OBSERVE_ONLY}"
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
  local user_dir="SwarmfrontPerfPacingDiagnostic_${RUN_ID}_${RUN_ATTEMPT}_${label}"
  local lifecycle_path="${ARTIFACT_DIR}/${label}.process.json"
  local system_log_path="${ARTIFACT_DIR}/${label}.macos.log"
  local started_at
  local ended_at
  local godot_pid
  local rc
  local signal_number=0
  local signal_name=""

  started_at="$(date '+%Y-%m-%d %H:%M:%S')"
  set +e
  "${GODOT_BIN}" "$@" --path "${ROOT_DIR}" --script "${HARNESS}" -- \
    --sf-perf-harness \
    --diagnose-window-lifecycle \
    --perf-user-dir="${user_dir}" \
    --collection-level="${collection_level}" \
    --suite="${SUITE}" \
    --mode="${MODE}" \
    --output="res://${report_rel}" >"${log_path}" 2>&1 &
  godot_pid=$!
  printf 'PERF_PACING_DIAGNOSTIC_PROCESS label=%s pid=%s started_at=%s\n' "${label}" "${godot_pid}" "${started_at}"
  wait "${godot_pid}"
  rc=$?
  set -e
  ended_at="$(date '+%Y-%m-%d %H:%M:%S')"
  cat "${log_path}"

  if (( rc > 128 )); then
    signal_number=$((rc - 128))
    signal_name="$(kill -l "${signal_number}" 2>/dev/null || true)"
  fi
  jq -n \
    --arg label "${label}" \
    --arg variant "${VARIANT}" \
    --arg user_dir "${user_dir}" \
    --arg started_at "${started_at}" \
    --arg ended_at "${ended_at}" \
    --arg signal_name "${signal_name}" \
    --argjson pid "${godot_pid}" \
    --argjson process_rc "${rc}" \
    --argjson signal_number "${signal_number}" \
    '{
      label: $label,
      variant: $variant,
      user_dir: $user_dir,
      started_at: $started_at,
      ended_at: $ended_at,
      pid: $pid,
      process_rc: $process_rc,
      signal_number: $signal_number,
      signal_name: $signal_name
    }' >"${lifecycle_path}"
  if [[ "$(uname -s)" == "Darwin" ]] && command -v log >/dev/null 2>&1; then
    log show \
      --start "${started_at}" \
      --end "${ended_at}" \
      --style compact \
      --info \
      --debug \
      --predicate 'process == "Godot" OR process == "godot"' \
      >"${system_log_path}" 2>&1 || true
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "${label}" "${collection_level}" "${godot_pid}" "${rc}" "${signal_name}" >>"${ARTIFACT_DIR}/process_status.tsv"

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

case "${VARIANT}" in
  default_awake_minimal)
    capture_variant "${VARIANT}" MINIMAL
    ;;
  default_awake_repeat_minimal)
    capture_variant "${VARIANT}" MINIMAL
    ;;
  default_awake_full)
    capture_variant "${VARIANT}" FULL
    ;;
  vsync_disabled_full)
    capture_variant "${VARIANT}" FULL --disable-vsync
    ;;
  post_load_awake_minimal)
    run_focused_gate_load 2>&1 | tee "${ARTIFACT_DIR}/focused_gate_load.log"
    capture_variant "${VARIANT}" MINIMAL
    ;;
  *)
    echo "PERF_PACING_DIAGNOSTIC_FAIL reason=unknown_variant variant=${VARIANT}"
    exit 2
    ;;
esac

jq -s '{
  schema: "sf_perf_harness_pacing_diagnostic_isolated_v1",
  status: "CAPTURED",
  variants: .
}' \
  "${ARTIFACT_DIR}/${VARIANT}.summary.json" \
  >"${ARTIFACT_DIR}/matrix_summary.json"

echo "PERF_PACING_DIAGNOSTIC: PASS correctness_contracts=1 variant=${VARIANT} matrix=${ARTIFACT_DIR}/matrix_summary.json"
