#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
RUN_CONFIGURED_BACKEND="${TF_PREFLIGHT_RUN_CONFIGURED_BACKEND:-0}"
EXPORT_PRESET_FILE="$ROOT_DIR/export_presets.cfg"
GODOT_VERSION="4.2.stable"
if [[ -x "$GODOT_BIN" ]]; then
  GODOT_VERSION="$("$GODOT_BIN" --version | head -n 1 | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?\.stable).*/\1/')"
fi
IOS_TEMPLATE="$HOME/Library/Application Support/Godot/export_templates/$GODOT_VERSION/ios.zip"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; }
info() { echo "INFO: $1"; }

FAILURES=0

if [[ -x "$GODOT_BIN" ]]; then
  pass "Godot binary found at $GODOT_BIN ($GODOT_VERSION)"
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
  shift 2
  if "$GODOT_BIN" --headless --path "$ROOT_DIR" --script "$script_path" "$@" >/tmp/sf_tf_preflight.log 2>&1; then
    pass "$label"
  else
    fail "$label"
    tail -n 40 /tmp/sf_tf_preflight.log || true
    FAILURES=$((FAILURES + 1))
  fi
}

if [[ -x "$GODOT_BIN" ]]; then
  if "$GODOT_BIN" --headless --editor --quit --path "$ROOT_DIR" >/tmp/sf_tf_preflight_import.log 2>&1; then
    pass "Godot project import"
  else
    fail "Godot project import"
    tail -n 40 /tmp/sf_tf_preflight_import.log || true
    FAILURES=$((FAILURES + 1))
  fi
fi

VS_BACKEND_URL=""
if [[ -f "$ROOT_DIR/project.godot" ]]; then
  VS_BACKEND_URL="$(rg -n '^vs/backend_url=' "$ROOT_DIR/project.godot" | sed -E 's/.*=\"(.*)\"/\1/' | head -n 1 || true)"
  if [[ -z "$VS_BACKEND_URL" ]]; then
    fail "VS backend URL is empty; TestFlight two-device PvP will fail closed"
    FAILURES=$((FAILURES + 1))
  elif [[ "$VS_BACKEND_URL" == http://127.* || "$VS_BACKEND_URL" == http://localhost* || "$VS_BACKEND_URL" == http://0.0.0.0* ]]; then
    fail "VS backend URL is local-only ($VS_BACKEND_URL)"
    FAILURES=$((FAILURES + 1))
  elif [[ "$VS_BACKEND_URL" != https://* ]]; then
    fail "VS backend URL must be HTTPS for iOS/TestFlight ($VS_BACKEND_URL)"
    FAILURES=$((FAILURES + 1))
  else
    pass "VS backend URL is release-shaped ($VS_BACKEND_URL)"
  fi
fi

if [[ -x "$GODOT_BIN" ]]; then
  run_smoke "res://scripts/dev/vs_pvp_smoke.gd" "VS debug local PvP smoke" "--vs-smoke-local"
  run_smoke "res://scripts/dev/vs_pvp_smoke.gd" "VS release guard refuses fake multiplayer" "--vs-smoke-release-guard"
  if [[ ("$RUN_CONFIGURED_BACKEND" == "1" || "$RUN_CONFIGURED_BACKEND" == "true") \
      && -n "$VS_BACKEND_URL" && "$VS_BACKEND_URL" == https://* ]]; then
    run_smoke "res://scripts/dev/vs_pvp_smoke.gd" "VS configured backend PvP smoke" "--vs-smoke-backend-url=$VS_BACKEND_URL"
  else
    info "Configured backend PvP smoke skipped (set TF_PREFLIGHT_RUN_CONFIGURED_BACKEND=1 only under separate live-service authorization)"
  fi
  run_smoke "res://tools/economy_layer_smoke_test.gd" "Economy authority smoke"
  run_smoke "res://tools/honey_progression_smoke_test.gd" "Honey progression smoke"
  run_smoke "res://tools/battle_pass_progression_smoke_test.gd" "Battle Path progression smoke"
  run_smoke "res://tools/rank_system_smoke_test.gd" "Rank smoke"
  run_smoke "res://tools/tutorial_flow_smoke_test.gd" "Tutorial flow smoke"
fi

if [[ "$FAILURES" -eq 0 ]]; then
  pass "TestFlight preflight clean"
  exit 0
fi

fail "TestFlight preflight has $FAILURES blocker(s)"
exit 1
