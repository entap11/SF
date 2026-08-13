#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 /absolute/path/to/godot-4.7.1-source" >&2
  exit 64
fi

godot_source_path=$1
plugin_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
output_dir="$plugin_dir/bin"
install_dir="$plugin_dir/../../../ios/plugins/swarmfront_secure_credentials"
version_file="$godot_source_path/version.py"

if [ ! -f "$version_file" ] \
  || ! grep -q '^major = 4$' "$version_file" \
  || ! grep -q '^minor = 7$' "$version_file" \
  || ! grep -q '^patch = 1$' "$version_file" \
  || ! grep -q '^status = "stable"$' "$version_file"; then
  echo "godot_source must be the Godot 4.7.1 stable source tree" >&2
  exit 65
fi

for generated_header in \
  core/extension/gdextension_interface.gen.h \
  core/disabled_classes.gen.h
do
  if [ ! -f "$godot_source_path/$generated_header" ]; then
    echo "missing generated Godot header: $generated_header" >&2
    exit 66
  fi
done

mkdir -p "$output_dir"
cd "$plugin_dir"
scons godot_source="$godot_source_path" target=release_debug arch=arm64 simulator=no
scons godot_source="$godot_source_path" target=release_debug arch=arm64 simulator=yes
scons godot_source="$godot_source_path" target=release_debug arch=x86_64 simulator=yes

simulator_library="$output_dir/libSwarmfrontSecureCredentials.arm64_x86_64-simulator.release_debug.a"
lipo -create \
  "$output_dir/libSwarmfrontSecureCredentials.arm64-simulator.release_debug.a" \
  "$output_dir/libSwarmfrontSecureCredentials.x86_64-simulator.release_debug.a" \
  -output "$simulator_library"

rm -rf "$output_dir/SwarmfrontSecureCredentials.xcframework"
xcodebuild -create-xcframework \
  -library "$output_dir/libSwarmfrontSecureCredentials.arm64-ios.release_debug.a" \
  -library "$simulator_library" \
  -output "$output_dir/SwarmfrontSecureCredentials.xcframework"

mkdir -p "$install_dir"
rm -rf "$install_dir/SwarmfrontSecureCredentials.xcframework"
cp -R "$output_dir/SwarmfrontSecureCredentials.xcframework" "$install_dir/"
cp "$plugin_dir/SwarmfrontSecureCredentials.gdip" "$install_dir/"
