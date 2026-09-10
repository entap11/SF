# Combat readability pass

Authorized behavior: readable directional routes and endpoints; equally accessible friendly/enemy hive inspection; selection-centered connection emphasis; visible incoming threats; quieter floor, hive and unit presentation; protected hive numbers and HUD placement; stable crossings. Re-enable lane hierarchy with revised priorities and compare crowded gameplay.

Authority: OpsState/GameState remain the only gameplay state. Render helpers consume canonical render samples and existing UI selection. Enemy inspection never becomes command ownership. Gameplay growth, unit counts, speed, targeting geometry, lane budgets, ownership and capture rules are unchanged.

Scope: presentation renderers, ephemeral selection handling and focused regression/capture tools. No backend, economy, map topology or match-rule changes. No claim of device validation from desktop captures.

Acceptance: touch and mouse can inspect either owner; inspecting an enemy emits no gameplay action; friendly commands and lane grabs retain their existing behavior. Selected routes have visible endpoints and stable crossing priority. Threats include hostile units remaining in flight after route retraction. Readability must not mutate canonical render input. Re-run focused input, geometry, rendering and fast readiness checks. Capture early/dense/late, friendly focus and enemy focus, with exact-state A/B frames where practical.

Evidence: `SF/artifacts/gameplay-capture-2026-09-10` is the original baseline. `SF/artifacts/readability-pass-2026-09-10` holds pre-edit source copies, validation logs and comparison captures. Initial gameplay stress case: six maxed hives per player, 26 attacking directions, 78 units at approximately 70 seconds.

Completed: continuous outlined routes, circle origins and arrow destinations, separate opposing tracks, stable crossing gaps, inspection of either owner, connected-hive emphasis, retained in-flight threat markers, quieter presentation, opaque white power badges, and HUD space above the battlefield. Existing command gestures remain intact. Both presentation settings are enabled in project.godot; disabling combat readability restores the previous rendering path, while enemy inspection and the reserved HUD space remain available.

Validation: ten focused smoke checks passed. The fast release-readiness gate passed contract, eight boot configurations, and three soak configurations; five deliberately invalid configurations have no runtime boot route. The MVP gate passed again after final presentation changes. Headless floor testing cannot read GPU pixels; the Compatibility renderer captures provide visible floor evidence. No physical iPhone validation was performed.

Final evidence: nine 1080×1920 captures at approximately 3, 12, 66, 70 and 130 seconds, including four comparison frames at the same paused state. The comparison contains 92 units, six maxed hives per player and 26 attack directions. Friendly hive 11 and enemy hive 6 both isolate their connections. The canonical hash stayed `2011e0c47756caf52cea56d6f5a70af715abbdf318689a71185662555986d0d8` across rendering and inspection changes. A six-second video samples the running enemy-inspection view. `SF/artifacts/readability-pass-2026-09-10/review.html` embeds the complete review; the adjacent patch isolates this pass from pre-existing working-tree edits.
