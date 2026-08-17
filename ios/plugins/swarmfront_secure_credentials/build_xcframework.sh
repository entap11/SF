#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <release|release_debug> <godot-source-or-headers>" >&2
  exit 64
fi

target="$1"
godot_headers="$2"
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
