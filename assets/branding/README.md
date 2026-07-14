# Swarmfront branding

`swarmfront_logo_1024.png` is the canonical raster logo for Swarmfront. Use this
repo-relative source for Godot, Blender, marketing renders, and other derived
assets. Do not use the original Desktop copy as a production dependency.

The PNG files under `res://icons/` are app-export derivatives generated from
this 1024 x 1024 master.

Run `tools/generate_ios_icons.sh` on macOS after replacing the master. It
regenerates every image referenced by the Godot iOS export preset.
