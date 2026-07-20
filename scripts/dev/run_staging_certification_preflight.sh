#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECK_ENVIRONMENT=0

usage() {
  cat <<'EOF'
Usage:
  scripts/dev/run_staging_certification_preflight.sh [--environment]

Checks repository-visible Public Modes staging guardrails. With --environment,
also inspects the current process environment and reports capability values plus
credential presence. Credential values are never printed.

An absent capability variable is reported as the code-defined false default.
Any enabled or malformed capability value fails the preflight.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment)
      CHECK_ENVIRONMENT=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "STAGING_PREFLIGHT_FAIL unknown_argument=$1"
      usage
      exit 2
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "STAGING_PREFLIGHT_FAIL missing_command=jq"
  exit 1
fi

canonical_filter='^enable_public_|^enable_rank_mutations$|^enable_crucible_wax_settlement$|^enable_contest_rewards$|^enable_bot_fallback$'
for config_path in \
  "${ROOT_DIR}/data/ops/ops_config_defaults.json" \
  "${ROOT_DIR}/data/ops/ops_config_remote_sample.json"; do
  if ! jq -e --arg filter "${canonical_filter}" '
    [.feature_flags | to_entries[] | select(.key | test($filter))]
    | length == 16 and all(.value == false)
  ' "${config_path}" >/dev/null; then
    echo "STAGING_PREFLIGHT_FAIL canonical_flags path=${config_path#"${ROOT_DIR}/"}"
    exit 1
  fi
  echo "STAGING_PREFLIGHT_PASS canonical_flags_false path=${config_path#"${ROOT_DIR}/"} count=16"
done

render_path="${ROOT_DIR}/render.yaml"
if [[ ! -f "${render_path}" ]]; then
  echo "STAGING_PREFLIGHT_FAIL missing_render_blueprint"
  exit 1
fi

auto_deploy_values="$(awk '/^[[:space:]]*autoDeploy:/ {print tolower($2)}' "${render_path}")"
if [[ -z "${auto_deploy_values}" ]] || grep -Evqx 'false([[:space:]]*false)*' <<<"${auto_deploy_values//$'\n'/ }"; then
  echo "STAGING_PREFLIGHT_FAIL render_auto_deploy"
  exit 1
fi
echo "STAGING_PREFLIGHT_PASS render_auto_deploy_false"

rank_blueprint_caps=(
  RANK_ECONOMY_MUTATIONS_ENABLED
  RANK_ECONOMY_RESET_ENABLED
  RANK_VERIFIED_MATCH_MUTATIONS_ENABLED
  RANK_PUBLIC_LEADERBOARDS_ENABLED
)
for cap in "${rank_blueprint_caps[@]}"; do
  value="$(awk -v key="${cap}" '
    $0 ~ "key: " key { found=1; next }
    found && $1 == "value:" { gsub(/\"/, "", $2); print tolower($2); exit }
  ' "${render_path}")"
  if [[ "${value}" != "false" ]]; then
    echo "STAGING_PREFLIGHT_FAIL render_cap name=${cap} state=${value:-missing}"
    exit 1
  fi
  echo "STAGING_PREFLIGHT_PASS render_cap_false name=${cap}"
done

if [[ "${CHECK_ENVIRONMENT}" == "1" ]]; then
  capability_names=(
    VS_AUTHENTICATED_1V1_SLICE_ENABLED
    VS_ECONOMY_MUTATIONS_ENABLED
    VS_ECONOMY_RESET_ENABLED
    VS_DURABLE_CORE_ENABLED
    VS_DURABLE_PUBLIC_1V1_ENABLED
    VS_ENABLE_PUBLIC_1V1
    VS_ENABLE_PUBLIC_3P_FFA
    VS_ENABLE_PUBLIC_2V2
    VS_ENABLE_PUBLIC_4P_FFA
    VS_ENABLE_PUBLIC_CTF
    VS_ENABLE_PUBLIC_HCTF
    VS_ENABLE_PUBLIC_CRUCIBLE
    VS_ENABLE_CRUCIBLE_WAX_SETTLEMENT
    VS_HCTF_LIVE_SECRECY_CERTIFIED
    VS_ENABLE_CTF_BOT_FALLBACK
    VS_ENABLE_RANK_MUTATIONS
    VS_ENABLE_PUBLIC_LEADERBOARDS
    VS_ENABLE_PUBLIC_CONTESTS
    VS_ENABLE_PUBLIC_TIME_PUZZLES
    VS_ENABLE_PUBLIC_GAUNTLET
    VS_ENABLE_PUBLIC_ASYNC_3MAP
    VS_ENABLE_PUBLIC_ASYNC_5MAP
    VS_ENABLE_CONTEST_REWARDS
    VS_ENABLE_REMOTE_OPS_CONFIG
    VS_MATCH_VERIFICATION_ENABLED
    VS_SPECTATOR_LIVE_ENABLED
    VS_SPECTATOR_PUBLIC_ENABLED
    RANK_ECONOMY_MUTATIONS_ENABLED
    RANK_ECONOMY_RESET_ENABLED
    RANK_VERIFIED_MATCH_MUTATIONS_ENABLED
    RANK_PUBLIC_LEADERBOARDS_ENABLED
  )
  capability_failures=0
  for name in "${capability_names[@]}"; do
    raw="${!name-}"
    if [[ -z "${raw}" ]]; then
      echo "STAGING_PREFLIGHT_CAP name=${name} state=absent effective_default=false"
      continue
    fi
    normalized="$(tr '[:upper:]' '[:lower:]' <<<"${raw}")"
    case "${normalized}" in
      false|0|no|off)
        echo "STAGING_PREFLIGHT_CAP name=${name} state=false"
        ;;
      true|1|yes|on)
        echo "STAGING_PREFLIGHT_CAP name=${name} state=enabled result=FAIL"
        capability_failures=$((capability_failures + 1))
        ;;
      *)
        echo "STAGING_PREFLIGHT_CAP name=${name} state=malformed result=FAIL"
        capability_failures=$((capability_failures + 1))
        ;;
    esac
  done

  credential_names=(
    DATABASE_URL
    VS_DATABASE_URL
    VS_ADMIN_TOKEN
    VS_MATCH_AUTHORITY_TOKEN
    VS_VERIFIER_WORKER_TOKEN
    VS_VERIFIER_PUBLIC_KEY_PEM
    VS_PLAYER_TOKEN_PUBLIC_KEY_PEM
    VS_RANK_SERVICE_TOKEN_PRIVATE_KEY_PEM
    RANK_API_TOKEN
    ENTAP_PLAYER_TOKEN_PRIVATE_KEY_PEM
    ENTAP_PLAYER_TOKEN_PUBLIC_KEY_PEM
    RANK_SERVICE_TOKEN_PUBLIC_KEY_PEM
    RANK_VERIFIER_PUBLIC_KEY_PEM
    MATCH_AUTHORITY_VERIFIER_PRIVATE_KEY_PEM
  )
  for name in "${credential_names[@]}"; do
    if [[ -n "${!name-}" ]]; then
      echo "STAGING_PREFLIGHT_CREDENTIAL name=${name} state=present value=REDACTED"
    else
      echo "STAGING_PREFLIGHT_CREDENTIAL name=${name} state=absent"
    fi
  done

  if [[ "${capability_failures}" -ne 0 ]]; then
    echo "STAGING_PREFLIGHT_FAIL environment_capabilities failures=${capability_failures}"
    exit 1
  fi
  echo "STAGING_PREFLIGHT_PASS environment_capabilities_false"
else
  echo "STAGING_PREFLIGHT_SKIP environment reason=not_requested"
fi

echo "STAGING_PREFLIGHT_PASS"
