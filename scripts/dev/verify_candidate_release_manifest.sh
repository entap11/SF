#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST_PATH="${1:-${ROOT_DIR}/docs/architecture/render_reactivation/candidate-sf-4.7.1-b409fc9-20260817.2.json}"

if [[ ! -f "${MANIFEST_PATH}" ]]; then
  echo "CANDIDATE_MANIFEST_FAIL reason=missing_manifest path=${MANIFEST_PATH}"
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "CANDIDATE_MANIFEST_FAIL reason=jq_missing"
  exit 1
fi

canonical="$(jq -S -c . "${MANIFEST_PATH}")"
on_disk="$(tr -d '\n' <"${MANIFEST_PATH}")"
if [[ "${canonical}" != "${on_disk}" ]]; then
  echo "CANDIDATE_MANIFEST_FAIL reason=noncanonical_json"
  exit 1
fi

expected_digest="$(jq -r '.manifest_sha256' "${MANIFEST_PATH}")"
actual_digest="$(jq -S -c 'del(.manifest_sha256)' "${MANIFEST_PATH}" | shasum -a 256 | awk '{print $1}')"
if [[ ! "${expected_digest}" =~ ^[0-9a-f]{64}$ || "${actual_digest}" != "${expected_digest}" ]]; then
  echo "CANDIDATE_MANIFEST_FAIL reason=self_digest_mismatch expected=${expected_digest} actual=${actual_digest}"
  exit 1
fi

if ! jq -e '
  .manifest_schema_version == 1 and
  .approval.state == "approved_for_certification_deployment" and
  .approval.scope == "all_off_certification_deployment_only" and
  .repository.clean_tree_assertion == true and
  (.repository.sha | test("^[0-9a-f]{40}$")) and
  (.known_limitations | length > 0) and
  (.all_off_configuration.declared_false_capabilities | length > 0) and
  ([.all_off_configuration.declared_false_capabilities[]] | unique | length) ==
    (.all_off_configuration.declared_false_capabilities | length)
' "${MANIFEST_PATH}" >/dev/null; then
  echo "CANDIDATE_MANIFEST_FAIL reason=required_contract"
  exit 1
fi

if jq -e '
  paths(scalars) as $path |
  ($path | map(tostring) | join(".")) as $key |
  $key | test("(^|\\.)(private_key|token|database_url|device_id|pii)(\\.|$)"; "i")
' "${MANIFEST_PATH}" >/dev/null; then
  echo "CANDIDATE_MANIFEST_FAIL reason=prohibited_secret_or_identifier_field"
  exit 1
fi

source_sha="$(jq -r '.repository.sha' "${MANIFEST_PATH}")"
if ! git -C "${ROOT_DIR}" cat-file -e "${source_sha}^{commit}" 2>/dev/null; then
  echo "CANDIDATE_MANIFEST_FAIL reason=source_commit_missing sha=${source_sha}"
  exit 1
fi

while IFS=$'\t' read -r relative_path declared_sha; do
  absolute_path="${ROOT_DIR}/${relative_path}"
  if [[ ! -f "${absolute_path}" ]]; then
    echo "CANDIDATE_MANIFEST_FAIL reason=bound_file_missing path=${relative_path}"
    exit 1
  fi
  observed_sha="$(shasum -a 256 "${absolute_path}" | awk '{print $1}')"
  if [[ "${observed_sha}" != "${declared_sha}" ]]; then
    echo "CANDIDATE_MANIFEST_FAIL reason=bound_file_hash path=${relative_path} expected=${declared_sha} actual=${observed_sha}"
    exit 1
  fi
done < <(jq -r '
  [
    [.client.android.apk_path, .client.android.apk_sha256],
    [.client.ios.executable_path, .client.ios.executable_sha256],
    [.client.ios.pck_path, .client.ios.pck_sha256],
    [.content.map.path, .content.map.sha256],
    [.content.ruleset.path, .content.ruleset.sha256],
    [.tests.physical_evidence_path, .tests.physical_evidence_sha256]
  ][] | @tsv
' "${MANIFEST_PATH}")

echo "CANDIDATE_MANIFEST_PASS candidate_id=$(jq -r '.candidate_id' "${MANIFEST_PATH}") sha256=${actual_digest} source=${source_sha}"
