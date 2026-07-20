#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 /absolute/path/to/godot-4.2.2-source" >&2
  exit 64
fi

godot_source_path=$1
plugin_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
output_dir="$plugin_dir/bin"
install_dir="$plugin_dir/../../../ios/plugins/swarmfront_secure_credentials"

cd "$plugin_dir"
scons godot_source="$godot_source_path" target=release_debug arch=arm64 simulator=no
scons godot_source="$godot_source_path" target=release_debug arch=arm64 simulator=yes

rm -rf "$output_dir/SwarmfrontSecureCredentials.xcframework"
xcodebuild -create-xcframework \
  -library "$output_dir/libSwarmfrontSecureCredentials.arm64-ios.release_debug.a" \
  -library "$output_dir/libSwarmfrontSecureCredentials.arm64-simulator.release_debug.a" \
  -output "$output_dir/SwarmfrontSecureCredentials.xcframework"

mkdir -p "$install_dir"
cp -R "$output_dir/SwarmfrontSecureCredentials.xcframework" "$install_dir/"
cp "$plugin_dir/SwarmfrontSecureCredentials.gdip" "$install_dir/"
