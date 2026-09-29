# Battlefield space pass — 2026-09-10

Approved scope: reclaim unused space above and below the battlefield while retaining the existing in-game ad placement and power bar. Put the menu and ad in one row when they fit; reserve a separate power-bar row. Retain device safe areas and space needed by visible bottom controls.

This is presentation layout only. Shell owns the shared screen geometry; Arena consumes it for the existing ad surface and docks the visible power bar above the playfield. The Shell camera fits width and height separately so the map fills the newly available space without clipping either side; input continues to use the inverse camera transform. A fixed visual cell of padding at each vertical edge accommodates fully upgraded hives and their labels, and the floor extends into that padding without expanding the active grid or influence bounds. Resize and bottom-control visibility changes refit the camera. This introduces vertical scaling of the battlefield art. OpsState/SimState remain the sole gameplay authority. Ad requests, policy, monetization behavior and game rules are unchanged. Other suggested combat readability changes are outside this pass.

Validation: geometry checks for compact/stacked headers, safe areas, and bottom controls; actual Shell early and saved dense-match captures; fast release readiness gate. Desktop evidence does not establish physical iPhone validation. Capture/test profiles are isolated from the player's save data.

Evidence and a patch relative to the starting working tree: `../../../artifacts/hud-space-pass-2026-09-10/`.

## Result

- At 1080×1920: header reduced from 336 to 224 pixels; unused bottom gutter reduced from 40 to 16. Battlefield height increases from 1544 to 1680 pixels (+8.8%).
- Menu remains 225×110; in-game ad remains 720×90. Narrow supported layouts stack the ad. The visible power-bar frame has its own row.
- Eight final runtime captures include early play, a dense battle, enemy inspection, three screen sizes, and visible buff/Jukebox footer fixtures. Dense capture: 77 units, six maxed hives per player, 26 attack directions at 71.7 seconds. It resumes the earlier 70.2-second snapshot through OpsState and advances 1.5 seconds to settle the normal presentation pipeline.
- Actual scene checks pass for menu/ad separation, power-bar separation, full-height camera fit, screen-to-world conversion, all 16 hive picks at each of three screen sizes, and bottom-control exclusion. The authoritative state hash is unchanged across paused inspection and resizing.
- Focused `match_hud_layout`, `input_controls`, and `floor_influence` smoke tests pass. Fast release-readiness gate passes: MVP 26/26, matrix contract, eight valid boot configurations, and soak routes. Five unsupported boot configurations are expected skips. The first MVP run, concurrent with capture, timed out waiting for RUNNING; the separate retry passes.
- Patch whitespace, review HTML/JavaScript structure, and archive integrity checks pass. Implementation is complete; physical iPhone validation remains outstanding. No commit or deployment was performed.
