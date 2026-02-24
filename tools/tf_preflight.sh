#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
EXPORT_PRESET_FILE="$ROOT_DIR/export_presets.cfg"
IOS_TEMPLATE="$HOME/Library/Application Support/Godot/export_templates/4.2.2.stable/ios.zip"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; }
info() { echo "INFO: $1"; }

FAILURES=0

if [[ -x "$GODOT_BIN" ]]; then
  pass "Godot binary found at $GODOT_BIN"
else
  fail "Godot binary missing at $GODOT_BIN"
  FAILURES=$((FAILURES + 1))
fi

if [[ -f "$EXPORT_PRESET_FILE" ]]; then
  pass "export_presets.cfg present"
else
  fail "export_presets.cfg missing"
  FAILURES=$((FAILURES + 1))
fi

TEAM_ID=""
if [[ -f "$EXPORT_PRESET_FILE" ]]; then
  TEAM_ID="$(rg -n 'application/app_store_team_id=' "$EXPORT_PRESET_FILE" | sed -E 's/.*=\"(.*)\"/\1/' | head -n 1 || true)"
  if [[ -n "$TEAM_ID" ]]; then
    pass "App Store Team ID configured ($TEAM_ID)"
  else
    fail "App Store Team ID is empty in export_presets.cfg"
    FAILURES=$((FAILURES + 1))
  fi
fi

if [[ -f "$IOS_TEMPLATE" ]]; then
  pass "iOS export template installed"
else
  fail "iOS export template missing ($IOS_TEMPLATE)"
  FAILURES=$((FAILURES + 1))
fi

CODESIGN_COUNT="$(security find-identity -v -p codesigning 2>/dev/null | rg -c '\"Apple (Development|Distribution)' || true)"
if [[ "$CODESIGN_COUNT" -gt 0 ]]; then
  pass "Code signing identities available ($CODESIGN_COUNT)"
else
  fail "No Apple code-sign identities found in keychain"
  FAILURES=$((FAILURES + 1))
fi

run_smoke() {
  local script_path="$1"
  local label="$2"
  if "$GODOT_BIN" --headless --path "$ROOT_DIR" --script "$script_path" >/tmp/sf_tf_preflight.log 2>&1; then
    pass "$label"
  else
    fail "$label"
    tail -n 40 /tmp/sf_tf_preflight.log || true
    FAILURES=$((FAILURES + 1))
  fi
}

if [[ -x "$GODOT_BIN" ]]; then
  run_smoke "res://tools/economy_buff_smoke_test.gd" "Economy/Buff smoke"
  run_smoke "res://tools/swarm_pass_smoke_test.gd" "SwarmPass smoke"
  run_smoke "res://tools/rank_system_smoke_test.gd" "Rank smoke"
fi

if [[ "$FAILURES" -eq 0 ]]; then
  pass "TestFlight preflight clean"
  exit 0
fi

fail "TestFlight preflight has $FAILURES blocker(s)"
exit 1

