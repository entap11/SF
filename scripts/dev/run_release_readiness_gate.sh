#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

MVP_GATE="${ROOT_DIR}/scripts/dev/run_mvp_smoke.sh"
BETA_OPS_GATE="${ROOT_DIR}/scripts/dev/run_beta_ops_gate.sh"
MATRIX_GATE="${ROOT_DIR}/scripts/dev/run_player_config_matrix_gate.sh"
SOAK_GATE="${ROOT_DIR}/scripts/dev/run_soak_gate.sh"
TF_PREFLIGHT="${ROOT_DIR}/tools/tf_preflight.sh"

RUN_MVP="${RELEASE_READINESS_RUN_MVP:-1}"
RUN_BETA_OPS="${RELEASE_READINESS_RUN_BETA_OPS:-0}"
RUN_MATRIX="${RELEASE_READINESS_RUN_MATRIX:-1}"
RUN_SOAK_GATE="${RELEASE_READINESS_RUN_SOAK_GATE:-0}"
RUN_TF_PREFLIGHT="${RELEASE_READINESS_RUN_TF_PREFLIGHT:-0}"

MATRIX_GATE_TIER="${RELEASE_READINESS_MATRIX_GATE:-fast}"
MATRIX_SEED="${RELEASE_READINESS_MATRIX_SEED:-123}"
MATRIX_SEED_RUNS="${RELEASE_READINESS_MATRIX_SEED_RUNS:-}"
MATRIX_NO_SOAK="${RELEASE_READINESS_MATRIX_NO_SOAK:-0}"

MVP_TIMEOUT_SECONDS="${RELEASE_READINESS_MVP_TIMEOUT_SECONDS:-180}"
BETA_OPS_TIMEOUT_SECONDS="${RELEASE_READINESS_BETA_OPS_TIMEOUT_SECONDS:-360}"
MATRIX_TIMEOUT_SECONDS="${RELEASE_READINESS_MATRIX_TIMEOUT_SECONDS:-}"
SOAK_GATE_TIMEOUT_SECONDS="${RELEASE_READINESS_SOAK_GATE_TIMEOUT_SECONDS:-2400}"
TF_PREFLIGHT_TIMEOUT_SECONDS="${RELEASE_READINESS_TF_PREFLIGHT_TIMEOUT_SECONDS:-600}"

usage() {
  cat <<'EOF'
Usage:
  scripts/dev/run_release_readiness_gate.sh [options]

Default stages:
  1. MVP smoke
  2. Player config matrix gate, fast tier

Options:
  --matrix-gate <fast|pr|nightly>  Player config matrix tier.
  --matrix-seed <n>                Base deterministic matrix seed.
  --matrix-seed-runs <n>           Number of matrix soak seed runs.
  --matrix-no-soak                 Run matrix contract + boot routes only.
  --skip-mvp                       Skip MVP smoke.
  --include-beta-ops               Also run scripts/dev/run_beta_ops_gate.sh.
  --skip-matrix                    Skip player config matrix.
  --include-soak-gate              Also run scripts/dev/run_soak_gate.sh.
  --include-tf-preflight           Also run tools/tf_preflight.sh.
  --help                           Show this help.

Default matrix timeout budgets:
  fast:    900 seconds
  pr:      2700 seconds
  nightly: 7200 seconds

Environment overrides:
  RELEASE_READINESS_RUN_MVP
  RELEASE_READINESS_RUN_BETA_OPS
  RELEASE_READINESS_RUN_MATRIX
  RELEASE_READINESS_RUN_SOAK_GATE
  RELEASE_READINESS_RUN_TF_PREFLIGHT
  RELEASE_READINESS_MATRIX_GATE
  RELEASE_READINESS_MATRIX_SEED
  RELEASE_READINESS_MATRIX_SEED_RUNS
  RELEASE_READINESS_MATRIX_NO_SOAK
  RELEASE_READINESS_MVP_TIMEOUT_SECONDS
  RELEASE_READINESS_BETA_OPS_TIMEOUT_SECONDS
  RELEASE_READINESS_MATRIX_TIMEOUT_SECONDS
  RELEASE_READINESS_SOAK_GATE_TIMEOUT_SECONDS
  RELEASE_READINESS_TF_PREFLIGHT_TIMEOUT_SECONDS
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --matrix-gate|--matrix-tier)
      MATRIX_GATE_TIER="${2:-}"
      shift 2
      ;;
    --matrix-gate=*|--matrix-tier=*)
      MATRIX_GATE_TIER="${1#*=}"
      shift
      ;;
    --matrix-seed)
      MATRIX_SEED="${2:-}"
      shift 2
      ;;
    --matrix-seed=*)
      MATRIX_SEED="${1#--matrix-seed=}"
      shift
      ;;
    --matrix-seed-runs)
      MATRIX_SEED_RUNS="${2:-}"
      shift 2
      ;;
    --matrix-seed-runs=*)
      MATRIX_SEED_RUNS="${1#--matrix-seed-runs=}"
      shift
      ;;
    --matrix-no-soak)
      MATRIX_NO_SOAK=1
      shift
      ;;
    --skip-mvp)
      RUN_MVP=0
      shift
      ;;
    --include-beta-ops)
      RUN_BETA_OPS=1
      shift
      ;;
    --skip-matrix)
      RUN_MATRIX=0
      shift
      ;;
    --include-soak-gate)
      RUN_SOAK_GATE=1
      shift
      ;;
    --include-tf-preflight)
      RUN_TF_PREFLIGHT=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "RELEASE_READINESS_FAIL unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

case "${MATRIX_GATE_TIER}" in
  fast)
    MATRIX_TIMEOUT_SECONDS="${MATRIX_TIMEOUT_SECONDS:-900}"
    ;;
  pr)
    # The PR tier runs the complete boot/runtime route matrix before two soak
    # seeds. On the supported work Mac the boot routes alone can take about 26
    # minutes, so a 30-minute wrapper can terminate healthy soak work. Keep the
    # full coverage and give the declared workload a bounded 45-minute budget.
    MATRIX_TIMEOUT_SECONDS="${MATRIX_TIMEOUT_SECONDS:-2700}"
    ;;
  nightly)
    MATRIX_TIMEOUT_SECONDS="${MATRIX_TIMEOUT_SECONDS:-7200}"
    ;;
  *)
    MATRIX_TIMEOUT_SECONDS="${MATRIX_TIMEOUT_SECONDS:-900}"
    ;;
esac

terminate_tree() {
  local pid="$1"
  local children=""
  children="$(pgrep -P "${pid}" 2>/dev/null || true)"
  for child in ${children}; do
    terminate_tree "${child}"
  done
  kill -TERM "${pid}" 2>/dev/null || true
}

run_stage() {
  local stage="$1"
  local timeout_seconds="$2"
  local started_seconds
  local elapsed_seconds
  local pid
  local rc
  shift
  shift
  echo "RELEASE_READINESS_STAGE_BEGIN ${stage} timeout_seconds=${timeout_seconds}: $*"
  set +e
  "$@" &
  pid=$!
  started_seconds="$(date +%s)"
  while kill -0 "${pid}" 2>/dev/null; do
    sleep 1
    elapsed_seconds="$(($(date +%s) - started_seconds))"
    if [[ "${timeout_seconds}" -gt 0 && "${elapsed_seconds}" -ge "${timeout_seconds}" ]]; then
      echo "RELEASE_READINESS_STAGE_TIMEOUT ${stage} seconds=${elapsed_seconds}"
      terminate_tree "${pid}"
      wait "${pid}" >/dev/null 2>&1 || true
      set -e
      exit 124
    fi
  done
  wait "${pid}"
  rc=$?
  set -e
  if [[ "${rc}" -ne 0 ]]; then
    echo "RELEASE_READINESS_STAGE_FAIL ${stage} rc=${rc}"
    exit "${rc}"
  fi
  echo "RELEASE_READINESS_STAGE_PASS ${stage}"
}

echo "RELEASE_READINESS_BEGIN matrix_gate=${MATRIX_GATE_TIER} matrix_seed=${MATRIX_SEED} matrix_seed_runs=${MATRIX_SEED_RUNS}"

if [[ "${RUN_MVP}" == "1" || "${RUN_MVP}" == "true" ]]; then
  run_stage mvp_smoke "${MVP_TIMEOUT_SECONDS}" "${MVP_GATE}"
else
  echo "RELEASE_READINESS_STAGE_SKIP mvp_smoke"
fi

if [[ "${RUN_BETA_OPS}" == "1" || "${RUN_BETA_OPS}" == "true" ]]; then
  run_stage beta_ops "${BETA_OPS_TIMEOUT_SECONDS}" "${BETA_OPS_GATE}"
else
  echo "RELEASE_READINESS_STAGE_SKIP beta_ops"
fi

if [[ "${RUN_MATRIX}" == "1" || "${RUN_MATRIX}" == "true" ]]; then
  matrix_args=(
    --gate "${MATRIX_GATE_TIER}"
    --seed "${MATRIX_SEED}"
  )
  if [[ -n "${MATRIX_SEED_RUNS}" ]]; then
    matrix_args+=(--seed-runs "${MATRIX_SEED_RUNS}")
  fi
  if [[ "${MATRIX_NO_SOAK}" == "1" || "${MATRIX_NO_SOAK}" == "true" ]]; then
    matrix_args+=(--no-soak)
  fi
  run_stage player_config_matrix "${MATRIX_TIMEOUT_SECONDS}" "${MATRIX_GATE}" "${matrix_args[@]}"
else
  echo "RELEASE_READINESS_STAGE_SKIP player_config_matrix"
fi

if [[ "${RUN_SOAK_GATE}" == "1" || "${RUN_SOAK_GATE}" == "true" ]]; then
  run_stage perf_soak "${SOAK_GATE_TIMEOUT_SECONDS}" "${SOAK_GATE}"
else
  echo "RELEASE_READINESS_STAGE_SKIP perf_soak"
fi

if [[ "${RUN_TF_PREFLIGHT}" == "1" || "${RUN_TF_PREFLIGHT}" == "true" ]]; then
  run_stage testflight_preflight "${TF_PREFLIGHT_TIMEOUT_SECONDS}" "${TF_PREFLIGHT}"
else
  echo "RELEASE_READINESS_STAGE_SKIP testflight_preflight"
fi

echo "RELEASE_READINESS_PASS"
