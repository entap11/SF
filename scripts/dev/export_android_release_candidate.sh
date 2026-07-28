#!/usr/bin/env bash
set -euo pipefail

task_root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
task_godot_bin="${GODOT_BIN:-godot}"
task_keytool_bin="${KEYTOOL_BIN:-}"
task_output_dir="${ANDROID_RC_OUTPUT_DIR:-${task_root_dir}/artifacts/android/release}"

: "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?Set GODOT_ANDROID_KEYSTORE_RELEASE_PATH to a keystore outside the repository.}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?Set GODOT_ANDROID_KEYSTORE_RELEASE_USER to the release key alias.}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?Set GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD without committing it.}"

if [[ ! -f "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH}" ]]; then
	echo "Release keystore not found: ${GODOT_ANDROID_KEYSTORE_RELEASE_PATH}" >&2
	exit 1
fi

task_godot_version="$("${task_godot_bin}" --version | head -n 1)"
case "${task_godot_version}" in
	4.7.1.*) ;;
	*)
		echo "Godot 4.7.1 is required; found ${task_godot_version}." >&2
		exit 1
		;;
esac

if [[ -z "${task_keytool_bin}" && -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/keytool" ]]; then
	task_keytool_bin="${JAVA_HOME}/bin/keytool"
fi
if [[ -z "${task_keytool_bin}" ]]; then
	task_keytool_bin="$(command -v keytool || true)"
fi
if [[ -z "${task_keytool_bin}" || ! -x "${task_keytool_bin}" ]]; then
	echo "keytool was not found. Set KEYTOOL_BIN or JAVA_HOME to JDK 17." >&2
	exit 1
fi

"${task_keytool_bin}" -list \
	-keystore "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH}" \
	-storepass:env GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD \
	-alias "${GODOT_ANDROID_KEYSTORE_RELEASE_USER}" >/dev/null

mkdir -p "${task_output_dir}"

"${task_godot_bin}" --headless --path "${task_root_dir}" \
	--export-release "Android Release Candidate" \
	"${task_output_dir}/swarmfront-0.1.2-rc1.aab"

"${task_godot_bin}" --headless --path "${task_root_dir}" \
	--export-release "Android Release Emulator" \
	"${task_output_dir}/swarmfront-0.1.2-rc1-emulator.apk"

printf 'AAB: %s\n' "${task_output_dir}/swarmfront-0.1.2-rc1.aab"
printf 'APK: %s\n' "${task_output_dir}/swarmfront-0.1.2-rc1-emulator.apk"
