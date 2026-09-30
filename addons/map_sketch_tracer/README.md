# Map Studio / Sketch Tracer

Draw on `templates/SF_18x28_grid.png`. Hive dots specify exact cells; wall strokes
specify the intended route. Export a PNG/JPG from the drawing app. Keep deliberate
openings as separate strokes. The previous 12×8 template is historical.
Labels mark zero-based cell centers `(0,0)` through `(17,27)`, not grid borders.
Hive placement snaps to half-cells to preserve existing layouts; structure slots
snap to whole cells. Legal-connection previews use the same precise hive positions
as the simulation.
Regenerate the SVG/PNG with `python3 tools/generate_map_grid.py` (requires Pillow;
`--font` selects a local font on platforms without Helvetica).

Enable **Map Sketch Tracer** in Godot's **Project Settings → Plugins**, or launch
the standalone studio:

```sh
godot --path . --script res://tools/map_studio.gd
```

Use the repository's pinned Godot runtime (4.7.1), not an older system `godot`.

1. Load the sketch. For a screenshot with margins, choose **Align sketch** and
   click opposite corners of its grid. The image crop is retained in the draft.
2. Choose **Campaign**, **Multiplayer**, or **Both**. This is independent of player
   count and legacy `1p` filenames. Multiplayer/Both require equivalent starts.
3. Choose a symmetry preset and trace **one sector**. Generated counterparts use
   the same cleaned stroke and exact reflections/rotations. When interpreting a
   full drawing with unequal counterparts, choose the playable canonical sector;
   do not trace both conflicting versions as independent walls.
4. Place player/neutral hives or structure slots. Draw curved walls by dragging;
   straight walls by dragging between endpoints; corner walls by clicking points
   and pressing Enter. Smooth cleanup keeps endpoints and intentional openings.
5. Compare **Sketch + corrections**, **Clean layout**, and **Finished walls**.
   Toggle **Barriers** and **Legal connections** to inspect gameplay geometry.
6. Save the editable draft. It retains source strokes and sketch alignment;
   compiled JSON is disposable output. Undo/redo and a recoverable local autosave
   are available. **Restore draft** restores the last autosave.
7. Validate and export. Export stages the file, validates it through the actual
   runtime loader and opening checks, and atomically replaces the destination
   only if all checks pass. A failed export leaves the previous map intact.

Mouse wheel zooms, middle-drag pans, **Fit board** resets the view. Select/Move
moves source hives or slots. Delete removes a selected source hive, slot or wall; Undo restores
it. Changing a seed changes its generated counterparts together.

**Rink Rat pilot** loads `map_sources/rink_rat_symmetry.draft.json`. It retains the
original 13 hive coordinates but moves starting ownership to four equivalent
corners. The original map remains unchanged. The pilot stays in the wall sandbox.

CLI compilation uses the same compiler and finalizer:

```sh
godot --headless --path . --script res://tools/map_authoring_finalize.gd -- \
  --input=res://map_sources/rink_rat_symmetry.draft.json \
  --output=res://maps/_future/rink_rat/MAP_rink_rat__SYMMETRY_PILOT__4p.json
```

Run `scripts/dev/run_map_authoring_gate.sh` with `GODOT_BIN` set to the pinned
runtime. `tools/map_wall_preview.gd` shows old walls, continuous rendering with
unchanged barriers, and the cleaned symmetric pilot. Set
`SF_MAP_AUTHORING_CAPTURE_DIR` to an existing directory to capture and exit; add
`SF_MAP_BARRIER_OVERLAY=1` for the exact blocking overlay.

Current presets: mirror X/Y, half-turn, both mirrors, quarter-turn. Three-player
120° symmetry is blocked because the current integer/half-cell hive lattice cannot encode
it exactly. This is a validation limit, not permission to approximate fairness.
Legacy maps without a designation are explicitly unclassified in the usage API;
this authoring update does not certify or silently rewrite the live catalog.
