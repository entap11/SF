#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
master="$repo_root/assets/branding/swarmfront_logo_1024.png"
icons_dir="$repo_root/icons"

if [ ! -f "$master" ]; then
	printf 'Missing canonical logo: %s\n' "$master" >&2
	exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
	printf 'sips is required to generate the iOS icon set.\n' >&2
	exit 1
fi

mkdir -p "$icons_dir"
cp "$master" "$icons_dir/appstore_1024x1024.png"

generate_icon() {
	filename=$1
	size=$2
	cp "$master" "$icons_dir/$filename"
	sips -z "$size" "$size" "$icons_dir/$filename" >/dev/null
}

generate_icon iphone_120x120.png 120
generate_icon iphone_180x180.png 180
generate_icon ipad_76x76.png 76
generate_icon ipad_152x152.png 152
generate_icon ipad_167x167.png 167
generate_icon spotlight_40x40.png 40
generate_icon spotlight_80x80.png 80
generate_icon settings_58x58.png 58
generate_icon settings_87x87.png 87
generate_icon notification_40x40.png 40
generate_icon notification_60x60.png 60

printf 'Generated Godot iOS icons from %s\n' "$master"
