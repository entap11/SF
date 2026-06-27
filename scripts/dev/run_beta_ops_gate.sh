#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"

SMOKES=(
  "res://tools/beta_ops_runtime_parse_smoke_test.gd"
  "res://tools/ops_config_fetch_success_smoke_test.gd"
  "res://tools/ops_config_fetch_fail_fallback_smoke_test.gd"
  "res://tools/ops_config_malformed_fallback_smoke_test.gd"
  "res://tools/ops_config_force_update_smoke_test.gd"
  "res://tools/ops_config_maintenance_smoke_test.gd"
  "res://tools/ops_config_sample_validate_smoke_test.gd"
  "res://tools/honey_rewards_ops_gate_smoke_test.gd"
  "res://tools/config_snapshot_determinism_smoke_test.gd"
  "res://tools/ops_config_no_runtime_sim_access_smoke_test.gd"
  "res://tools/analytics_client_queue_smoke_test.gd"
  "res://tools/analytics_auto_flush_smoke_test.gd"
  "res://tools/analytics_match_config_contract_smoke_test.gd"
  "res://tools/support_diagnostics_payload_smoke_test.gd"
  "res://tools/ops_console_config_tab_smoke_test.gd"
)

echo "BETA_OPS_GATE_BEGIN smoke_count=${#SMOKES[@]}"
for smoke in "${SMOKES[@]}"; do
  echo "BETA_OPS_GATE_STAGE_BEGIN ${smoke}"
  "${GODOT_BIN}" --headless --path "${ROOT_DIR}" --script "${smoke}"
  echo "BETA_OPS_GATE_STAGE_PASS ${smoke}"
done
echo "BETA_OPS_GATE_PASS"
