#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MATRIX_RUNNER="${ROOT_DIR}/scripts/dev/run_player_config_matrix.sh"

GATE="${PLAYER_CONFIG_MATRIX_GATE:-fast}"
SEED="${PLAYER_CONFIG_MATRIX_SEED:-123}"
SEED_RUNS="${PLAYER_CONFIG_MATRIX_SEED_RUNS:-}"
SOAK_SECONDS="${PLAYER_CONFIG_MATRIX_SOAK_SECONDS:-}"
SOAK_ROUND_SECONDS="${PLAYER_CONFIG_MATRIX_SOAK_ROUND_SECONDS:-}"
SOAK_PAIRS="${PLAYER_CONFIG_MATRIX_SOAK_PAIRS:-1}"
START_TIMEOUT_MS="${PLAYER_CONFIG_MATRIX_START_TIMEOUT_MS:-45000}"
RUN_SOAK="${PLAYER_CONFIG_MATRIX_RUN_SOAK:-1}"

usage() {
  cat <<'EOF'
Usage:
  scripts/dev/run_player_config_matrix_gate.sh [--gate fast|pr|nightly] [options]

Options:
  --gate <tier>              Matrix tier to run: fast, pr, or nightly.
  --seed <n>                 Base deterministic seed.
  --seed-runs <n>            Number of sequential seeds for soak routes.
  --seconds <n>              Soak seconds per config.
  --round-seconds <n>        Soak round seconds.
  --pairs <n>                Soak active lane-intent pair count.
  --start-timeout-ms <n>     Soak match-start timeout.
  --no-soak                  Run contract and boot routes only.
  --help                     Show this help.

Default soak settings:
  fast:    seed-runs=1, seconds=10, round-seconds=10
  pr:      seed-runs=2, seconds=20, round-seconds=10
  nightly: seed-runs=3, seconds=45, round-seconds=10

Environment overrides:
  PLAYER_CONFIG_MATRIX_GATE
  PLAYER_CONFIG_MATRIX_SEED
  PLAYER_CONFIG_MATRIX_SEED_RUNS
  PLAYER_CONFIG_MATRIX_SOAK_SECONDS
  PLAYER_CONFIG_MATRIX_SOAK_ROUND_SECONDS
  PLAYER_CONFIG_MATRIX_SOAK_PAIRS
  PLAYER_CONFIG_MATRIX_START_TIMEOUT_MS
  PLAYER_CONFIG_MATRIX_RUN_SOAK
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gate|--tier)
      GATE="${2:-}"
      shift 2
      ;;
    --gate=*|--tier=*)
      GATE="${1#*=}"
      shift
      ;;
    --seed)
      SEED="${2:-}"
      shift 2
      ;;
    --seed=*)
      SEED="${1#--seed=}"
      shift
      ;;
    --seed-runs)
      SEED_RUNS="${2:-}"
      shift 2
      ;;
    --seed-runs=*)
      SEED_RUNS="${1#--seed-runs=}"
      shift
      ;;
    --seconds|--soak-seconds)
      SOAK_SECONDS="${2:-}"
      shift 2
      ;;
    --seconds=*|--soak-seconds=*)
      SOAK_SECONDS="${1#*=}"
      shift
      ;;
    --round-seconds|--soak-round-seconds)
      SOAK_ROUND_SECONDS="${2:-}"
      shift 2
      ;;
    --round-seconds=*|--soak-round-seconds=*)
      SOAK_ROUND_SECONDS="${1#*=}"
      shift
      ;;
    --pairs|--soak-pairs)
      SOAK_PAIRS="${2:-}"
      shift 2
      ;;
    --pairs=*|--soak-pairs=*)
      SOAK_PAIRS="${1#*=}"
      shift
      ;;
    --start-timeout-ms|--soak-start-timeout-ms)
      START_TIMEOUT_MS="${2:-}"
      shift 2
      ;;
    --start-timeout-ms=*|--soak-start-timeout-ms=*)
      START_TIMEOUT_MS="${1#*=}"
      shift
      ;;
    --no-soak)
      RUN_SOAK=0
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "PLAYER_CONFIG_MATRIX_GATE_FAIL unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

case "${GATE}" in
  fast)
    SEED_RUNS="${SEED_RUNS:-1}"
    SOAK_SECONDS="${SOAK_SECONDS:-10}"
    SOAK_ROUND_SECONDS="${SOAK_ROUND_SECONDS:-10}"
    ;;
  pr)
    SEED_RUNS="${SEED_RUNS:-2}"
    SOAK_SECONDS="${SOAK_SECONDS:-20}"
    SOAK_ROUND_SECONDS="${SOAK_ROUND_SECONDS:-10}"
    ;;
  nightly)
    SEED_RUNS="${SEED_RUNS:-3}"
    SOAK_SECONDS="${SOAK_SECONDS:-45}"
    SOAK_ROUND_SECONDS="${SOAK_ROUND_SECONDS:-10}"
    ;;
  *)
    echo "PLAYER_CONFIG_MATRIX_GATE_FAIL unsupported gate: ${GATE}"
    usage
    exit 2
    ;;
esac

run_stage() {
  local stage="$1"
  shift
  echo "PLAYER_CONFIG_MATRIX_GATE_STAGE_BEGIN ${stage}: $*"
  set +e
  "$@"
  local rc=$?
  set -e
  if [[ "${rc}" -ne 0 ]]; then
    echo "PLAYER_CONFIG_MATRIX_GATE_STAGE_FAIL ${stage} rc=${rc}"
    exit "${rc}"
  fi
  echo "PLAYER_CONFIG_MATRIX_GATE_STAGE_PASS ${stage}"
}

echo "PLAYER_CONFIG_MATRIX_GATE_BEGIN gate=${GATE} seed=${SEED} seed_runs=${SEED_RUNS} soak=${RUN_SOAK}"

run_stage contract \
  "${MATRIX_RUNNER}" --tier "${GATE}" --seed "${SEED}"

run_stage boot_routes \
  "${MATRIX_RUNNER}" --boot-routes --tier "${GATE}" --seed "${SEED}"

if [[ "${RUN_SOAK}" == "1" || "${RUN_SOAK}" == "true" ]]; then
  run_stage soak_routes \
    "${MATRIX_RUNNER}" --soak-routes --soak-tier "${GATE}" --seed "${SEED}" \
      --seed-runs "${SEED_RUNS}" --seconds "${SOAK_SECONDS}" \
      --round-seconds "${SOAK_ROUND_SECONDS}" --pairs "${SOAK_PAIRS}" \
      --start-timeout-ms "${START_TIMEOUT_MS}"
fi

echo "PLAYER_CONFIG_MATRIX_GATE_PASS gate=${GATE}"
