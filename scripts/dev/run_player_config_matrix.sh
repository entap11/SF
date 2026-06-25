#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
REPORT_FILE="${PLAYER_CONFIG_MATRIX_REPORT:-res://artifacts/player_config_matrix/latest.json}"
RUNNER="res://tools/player_config_matrix_contract_test.gd"

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier)
      ARGS+=("--matrix-tier=${2:-}")
      shift 2
      ;;
    --tier=*)
      ARGS+=("--matrix-tier=${1#--tier=}")
      shift
      ;;
    --config)
      ARGS+=("--matrix-config=${2:-}")
      shift 2
      ;;
    --config=*)
      ARGS+=("--matrix-config=${1#--config=}")
      shift
      ;;
    --replay)
      ARGS+=("--matrix-config=${2:-}")
      shift 2
      ;;
    --replay=*)
      ARGS+=("--matrix-config=${1#--replay=}")
      shift
      ;;
    --seed)
      ARGS+=("--matrix-seed=${2:-}")
      shift 2
      ;;
    --seed=*)
      ARGS+=("--matrix-seed=${1#--seed=}")
      shift
      ;;
    --seed-runs)
      ARGS+=("--seed-runs=${2:-}")
      shift 2
      ;;
    --seed-runs=*)
      ARGS+=("--seed-runs=${1#--seed-runs=}")
      shift
      ;;
    --seconds)
      ARGS+=("--seconds=${2:-}")
      shift 2
      ;;
    --seconds=*)
      ARGS+=("--seconds=${1#--seconds=}")
      shift
      ;;
    --round-seconds)
      ARGS+=("--round-seconds=${2:-}")
      shift 2
      ;;
    --round-seconds=*)
      ARGS+=("--round-seconds=${1#--round-seconds=}")
      shift
      ;;
    --pairs)
      ARGS+=("--pairs=${2:-}")
      shift 2
      ;;
    --pairs=*)
      ARGS+=("--pairs=${1#--pairs=}")
      shift
      ;;
    --start-timeout-ms)
      ARGS+=("--start-timeout-ms=${2:-}")
      shift 2
      ;;
    --start-timeout-ms=*)
      ARGS+=("--start-timeout-ms=${1#--start-timeout-ms=}")
      shift
      ;;
    --list)
      ARGS+=("--matrix-list")
      shift
      ;;
    --boot-routes)
      RUNNER="res://tools/player_config_matrix_boot_runner.gd"
      REPORT_FILE="${PLAYER_CONFIG_MATRIX_BOOT_REPORT:-res://artifacts/player_config_matrix/boot_routes_latest.json}"
      shift
      ;;
    --soak-routes)
      RUNNER="res://tools/player_config_matrix_soak_runner.gd"
      REPORT_FILE="${PLAYER_CONFIG_MATRIX_SOAK_REPORT:-res://artifacts/player_config_matrix/soak_latest.json}"
      shift
      ;;
    --report)
      REPORT_FILE="${2:-}"
      shift 2
      ;;
    --report=*)
      REPORT_FILE="${1#--report=}"
      shift
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

ARGS+=("--matrix-report=${REPORT_FILE}")

"${GODOT_BIN}" --headless --path "${ROOT_DIR}" --script "${RUNNER}" -- "${ARGS[@]}"
