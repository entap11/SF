# Map Sketch Tracer

Godot editor plugin to trace iPad sketches into canonical Swarmfront map JSON.

## Enable
1. Open Project Settings > Plugins.
2. Enable "Map Sketch Tracer".
3. Dock appears on the right side.

## Workflow
1. Load a sketch image (PNG/JPG) from iPad export.
2. Use the grid overlay to place nodes.
3. Connect lanes between hives.
4. Validate, then export JSON to `res://maps/`.

## Controls
- Mouse wheel: zoom
- Middle mouse drag: pan
- Left click:
  - Select/Move: select node or lane; drag node to move
  - Place Node: place at snapped cell
  - Connect Lanes: click hive A then hive B
- Delete/Backspace: remove selected node or lane
- Right click: clear pending lane start

## Template
Use `addons/map_sketch_tracer/templates/SF_12x8_grid.png` as the iPad sketch template.

## Export Format
- `_schema` is first key and set to `swarmfront.map.v1.xy`.
- `width=12`, `height=8`.
- `entities[]` with `id`, `type`, `owner` (if applicable), `x`, `y`.
- `lanes[]` with `from_id`, `to_id`.

Exported JSON loads into the existing MapBuilder pipeline.
