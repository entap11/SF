# Battlefield Screen-Angle Readability Test

This is a debug-only, presentation-only A/B experiment. It rotates the active SubViewport camera; it does not rotate the Arena, MapRoot, gameplay nodes, HUD, or authoritative state.

## How to see it

1. Run the project from the Godot editor or another debug build.
2. On the shell menu, press **ANGLE A/B TEST** directly under **Mode: 2v2**.
3. Choose and launch a map. The match begins at the unchanged 0° baseline.
4. Use the **BATTLEFIELD SCREEN ANGLE** panel at the upper-right of the shell HUD.
5. Select `-4°`, `-2°`, `0°`, `+2°`, or `+4°`.
6. Use **A/B** to switch between 0° and the last non-zero candidate without resetting the match. Its initial candidate is `+2°`.

The status must say `LIVE`. `WAITING FOR MATCH` means the shell has no active Arena camera yet.

For a non-debug build, opt in explicitly with `SF_BATTLEFIELD_SCREEN_ANGLE_STUDY=1`. Set it to `0` to force the study UI off.

## Best experiential comparison

Use the same live match state and alternate no faster than every 15–30 seconds. Start at 0°, choose one direction at 2°, then try 4° only if the effect is too subtle. Avoid changing camera framing, art, or scale during the comparison.

At each angle, deliberately perform this sequence:

1. Tap several crowded and isolated hives.
2. Create and reverse lanes with short and long drags.
3. Perform grab-throw deletion near the playfield edge.
4. Drag a hive-targeting buff and a lane/global-targeting buff.
5. Interact near the top and bottom HUD boundaries.
6. Observe whether lane direction, hive footprint, tall-structure overlap, and swarm flow are easier to parse.

Record a screen capture if possible. The strongest evidence is fewer hesitations or corrections while identifying a target or lane—not simply preferring the tilted image in a still frame.

## Automated proof

Run:

```sh
godot --headless --path . --script tools/battlefield_screen_angle_input_smoke_test.gd
godot --headless --path . --script tools/battlefield_screen_angle_shell_smoke_test.gd
```

The input test checks `-4°`, `-2°`, `0°`, `+2°`, and `+4°` round trips for hive taps, lane hits, drag press/move/release, buff targets, screen-to-world physics queries, and the HUD/SubViewport rejection boundary. The shell test proves that A/B changes only camera roll, restores the original camera settings, leaves MapRoot coordinates unchanged, and routes the live panel through the shell controller.

## Safety and rollback

- Baseline `0°` restores the camera's original rotation and `ignore_rotation` values.
- Input uses the SubViewport canvas transform inverse; shell buff targeting uses the full container/canvas/map transform chain.
- HUD input remains in root-screen coordinates outside the world SubViewport.
- No gameplay or simulation state is mutated by the study.

To remove the experiment completely, revert:

- `scenes/Shell.tscn`
- `scripts/shell.gd`
- `scripts/ui/pvp_debug_overlay.gd`
- `tools/battlefield_screen_angle_input_smoke_test.gd`
- `tools/battlefield_screen_angle_shell_smoke_test.gd`
- this document
