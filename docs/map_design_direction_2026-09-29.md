# Map design direction — September 29, 2026

This records the owner's response to the map audit and supersedes its initial design recommendations where they differ. The original runtime measurements remain evidence about the current implementation, not a verdict on the intended designs. This document records direction; it does not claim that repairs, new layouts, or playtests have been completed.

## Shared requirements

- Preserve each map's intended decisions and character. Diagnose drawing intake, coordinate conversion, setup, and runtime geometry before redesigning a concept that may have translated incorrectly.
- Lane visibility is an acceptance criterion. Check the exposed lane between actual hive silhouettes, connection direction, moving units, and touch selection at phone scale and across hive growth tiers. Center-to-center distance alone is insufficient.
- Keep Knife Fight intimate: the owner's analogy is Bristol versus No Man's Land's Daytona. Improve readable spacing without turning close combat into a long-distance map.
- The owner considers current smaller hive art slightly too small. Do not solve every spacing problem by shrinking hives further; evaluate spacing with an agreed readable hive size. A global size adjustment is not specified by this brief.
- For symmetric multiplayer layouts, equivalent geometry must survive import, connection checks, ownership assignments, NPC/player power, structure type/power, and control-hive selection. Validate the resolved match setup, not just the source JSON.
- Intentional asymmetry is permitted where justified by the design: Tri Tip is a three-player FFA example. Judge its compensation through access, travel/capture timing, pressure, and seat-rotated playtests rather than requiring identical opening degrees.
- Async is a valid destination for maps that do not suit live multiplayer. Geometric seat symmetry is not required there. Reachability, readable play, and a fun challenge still matter. Retain the required consistent challenge/setup for comparable async attempts.
- Wall polishing must improve continuous paths, joins, tips, and gaps. Any change to a blocking segment is a gameplay geometry change and needs connection/reachability validation.

## Family directions

| Map/family | Owner direction and concrete work |
|---|---|
| Simple Syrup — Structures | Preserve symmetry. Author paired legal structure regions in either the triangle formed by the start and its two side hives, or the triangle formed by those side hives and the center NPC. Both tower and barracks are valid choices. Populate counterpart slots with matching types/powers/control relationships; using both types is possible with one matching pair in each triangle class. |
| Roundabout | Preserve the distinct ring/open-center concept. Run through polishing for a cleaner layout and equivalent play, followed by three-seat tests. Do not classify it as finished merely because its initial opening metrics are close. |
| No Man's Land 444-1 | Keep the useful baseline; prototype 454 and 343, interpreted as left/center/right hive counts. More center hives should offer alternatives to immediate conflict: fight, build, or avoid early confrontation. Compare this with 545's scarcer contested spine. |
| No Man's Land 545-1 | Prototype symmetric wall separators between center hives, long enough to remove selected spine/long connections and reduce lane clutter. Preserve useful expansion/attack choices and full reachability. Decide whether to keep the map after testing the reduced graph. |
| No Man's Land family / 545-2 | Treat these as a layout plus encounter-parameter family, not fixed ownership puzzles. Support intended configurations with 1, 2, 3, 4, or 5 starting hives where the layout permits, plus NPC power, player power, towers, and barracks. Starts may differ between configurations but should be equivalent across seats in a symmetric multiplayer configuration. Few starts/strong NPCs support slow buildup; many starts/weak NPCs/structures support rapid greedy expansion. Diagnose setup execution before changing the concept. |
| Knife Fight 1 | Preserve small, intimate combat. Prioritize visible lane spacing, then correct the recorded neutral-connection mismatch. |
| Knife Fight 2 | Preserve the adjacent-start dilemma. Review spacing/visibility while retaining its compact, low-branching topology. |
| Knife Fight 2 Close | Keep the four-player concept; inspect lane visibility and spacing. |
| Knife Fight 3 / 3 Close | Recover intended symmetry and assess spacing. Correct the measured connection differences without losing close-range pressure. |
| Knife Fight 4 | Previous pacing review remains: very long forced opening through walls. Apply the family readability requirement; no new decision to remove this variant. |
| Close Quarters 1 | Rebalance cardinal seats and space hives so lanes remain visible. |
| Close Quarters 2 / 3 | Treat missing hives as a likely intake/convention problem to investigate. Restore the intended drawn variants through a documented coordinate conversion; do not independently clamp the three rejected points or invent replacement layouts. Then rebalance and check spacing. The owner's original 18×28 grid can resolve intent if source artifacts do not. |
| Quad Fight | Preserve the promising four-player concept. Make starts/play symmetric and simplify using fewer hives, walls, or a combination. Compare prototypes rather than discarding the map for its current density. |
| Delta / barracks / towers | Preserve the three-player FFA family. Develop a three-way layout that fits the board and test equivalent expansion/control timing. Account for integer/half-grid conversion instead of stretching a triangle to fill the rectangular board. Recheck the structure variants after the base geometry. |
| Centerstrike 1–3 | Preserve the layouts' potential; polish and check spacing at a readable hive size. The owner specifically reaffirmed Centerstrike 1; prior variant recommendations remain provisional. |
| Corridors | Prior opening/structure access and central-density findings remain; apply the shared spacing and wall-polishing requirements. No new owner-specific redesign was supplied. |
| Laneclimb | Prior crossover-seat and pacing review remains. Do not label it overly complex merely because it has many hives. |
| Race | Polish and playtest with async as a plausible destination. The owner has not enjoyed earlier live play; do not promote it on symmetry checks alone. |
| Rink Rat 1 / 2 | Preserve the concept and use the preserved authoring pilot as a starting point. Improve the wall appearance substantially and validate resulting starts/connections. Carry variant 2's intended setup forward on the repaired geometry. |
| Corkscrew | Recover intended symmetry/translation, restore reachability, and polish. Try a small number of 1v1 playtests to assess fun; async is a likely alternative, not a final assignment. |
| Swirly | Same repair-and-test approach as Corkscrew. Preserve intended concept while correcting wall translation and trapped starts. Compare 1v1 suitability with async. |
| Iron Cross | Repair connectivity and polish; likely async, with live suitability left to playtesting. |
| Tri Tip | Preserve a non-round, non-triangular three-player FFA concept with intentionally different middle/outer positions. Restore the middle player's protected expansion as compensation for central pressure. Repair translated connections and test whether the tradeoff is fair. Do not replace it with three identical spokes simply to satisfy geometric symmetry. |

## Implementation findings that refine the audit

### Drawing coordinates

`scripts/maps/map_loader.gd`, `_load_v1xy`, rejects entities when `x >= width` or `y >= height`. On the current 18×28 model, positions at exactly x=18 or y=28 are excluded. CQ2/3 contain `(18,0)`, `(0,28)`, and `(18,28)`; those three entities are skipped and the variants collapse to the same eight-hive runtime geometry as CQ1.

This establishes what the loader does, not whether the original drawing was wrong. A drawing that labels outer grid lines, uses one-based cells, or uses a different origin needs an explicit conversion. Determine the actual source convention before transforming coordinates; do not blindly shift or clamp the whole collection.

### Variable starts and structures

`scripts/maps/map_applier.gd` applies mode adaptation, progressive scaling, optional start-slot randomization, and setup power/structure changes before creating gameplay state. The first audit inspected the authored loader output and initial local GameState, not this full resolved-setup matrix.

`scripts/state/match_setup_randomizer.gd`, `apply_start_slots`, shuffles declared slots and assigns at most one such slot to each active seat. It does not provide a general requested-count-per-player parameter. The current 545-2 source has no `start_slots`, so this operation leaves its authored top-versus-bottom ownership intact. NPC/player power and structure choices are implemented separately. These observations identify a setup contract to verify/complete; they do not prove every game mode uses the same setup path.

Before the first repair pass, mixed structure selection hashed all slots independently. Equivalent slot positions alone therefore did not guarantee matching tower/barracks counterparts. The [Simple Syrup pass](simple_syrup_map_review_2026-09-29.md) adds explicit symmetric groups in setup; ungrouped legacy slots keep their previous behavior.

### Simple Syrup structure regions

For the current hive IDs:

| Region | Bottom-player triangle | Top-player counterpart |
|---|---|---|
| In front of the start | 1, 2, 3 | 7, 5, 6 |
| Toward the center NPC | 2, 3, 4 | 5, 6, 4 |

These replace the current left/right triangles `(2,4,5)` and `(3,4,6)` as the design direction. Generate matching counterpart placements from one source; verify actual structure controls. Current centroid generation rounds to integer cells and setup slot conversion casts to integers, so independently snapping half-cell centroids can break symmetry. Resolve placement on the supported grid explicitly rather than assuming source symmetry survives rounding.

### Tri Tip identity

The current source has starts at `(3,14)`, `(9,14)`, and `(15,14)` and a neutral at `(9,27)` behind the center start. This supports the owner's recollection of the intended protected central expansion. The current graph isolates that neutral and separates all starts from neutral expansion, so the intended compensation is not implemented by the loaded connections.

## Execution order and acceptance

1. Resolve drawing-coordinate intake and the geometry-to-runtime comparison. Recover the preserved designer work in isolation; keep current public maps unchanged until repaired candidates are reviewable.
2. Use Simple Syrup Structures as the first paired-structure example and Roundabout as the first three-player polishing example. Produce before/after phone-scale previews and connection comparisons.
3. Establish visible-lane spacing on Knife Fight 1/2/2 Close and Close Quarters, preserving their close-combat identities. Test actual lanes at normal and grown hive sizes.
4. Build the No Man's Land layout/setup matrix: 444, new 454/343, and a wall-limited 545; test resolved starts, powers, and structures, not just map files.
5. Repair and polish the remaining walls and three-player concepts. Playtest live/async candidates before selecting their destination.

For each candidate, retain the original, a clear before/after preview, the resulting connection graph, the resolved setup, and the playtest finding. Separate functional correctness, readability, pacing, and measured seat advantage. No numerical win-rate or visibility threshold has been approved yet; avoid inventing a certification threshold.

All implementation continues to obey the single-state rule: setup publishes agreed inputs; authoritative simulation owns gameplay state; UI/rendering consume state and emit intents. This brief authorizes the requested design direction, not unrelated changes to simulation rules or global balance constants.
