#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <release|release_debug> <godot-source-or-headers>" >&2
  exit 64
fi

target="$1"
godot_headers="$2"
if [[ ! -f "$godot_headers/version.py" ]] \
  || ! grep -q '^major = 4$' "$godot_headers/version.py" \
  || ! grep -q '^minor = 7$' "$godot_headers/version.py" \
  || ! grep -q '^patch = 1$' "$godot_headers/version.py" \
  || ! grep -q '^status = "stable"$' "$godot_headers/version.py"; then
  echo "The shared mobile release requires Godot 4.7.1 stable headers." >&2
  exit 65
fi
for header in core/extension/gdextension_interface.gen.h core/disabled_classes.gen.h; do
  if [[ ! -f "$godot_headers/$header" ]]; then
    echo "Missing generated Godot header: $header" >&2
    exit 66
  fi
done
plugin_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$plugin_dir"
mkdir -p bin

scons target="$target" arch=arm64 simulator=no godot_headers="$godot_headers"
scons target="$target" arch=arm64 simulator=yes godot_headers="$godot_headers"
scons target="$target" arch=x86_64 simulator=yes godot_headers="$godot_headers"

lipo -create \
  "bin/libswarmfront_secure_credentials.arm64-simulator.${target}.a" \
  "bin/libswarmfront_secure_credentials.x86_64-simulator.${target}.a" \
  -output "bin/libswarmfront_secure_credentials.simulator.${target}.a"

variant="$target"
if [[ "$target" == "release_debug" ]]; then
  variant="debug"
fi
output="swarmfront_secure_credentials.${variant}.xcframework"
rm -rf "$output"
xcodebuild -create-xcframework \
  -library "bin/libswarmfront_secure_credentials.arm64-ios.${target}.a" \
  -library "bin/libswarmfront_secure_credentials.simulator.${target}.a" \
  -output "$output"
