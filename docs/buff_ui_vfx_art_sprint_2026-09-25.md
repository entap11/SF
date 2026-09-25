# Buff sprint — UI, VFX, catalog art, testing and tuning

Status: active-roster icon art complete. All six new or completed families are
approved and integrated; all 36 active tier entries have distinct appropriate
icons. The older-icon cleanup is integrated. Buff UI/VFX is in progress, with
the first dramatic Freeze Lane preview ready; menu VFX/UI/UX is step 4.

## Restart checkpoint — September 25

The owner requested a commit/push before restarting the computer. Resume on
`codex/single-player-campaign` in `project-unified-mobile-release`.
All approved icon art and the first Freeze Lane implementation are saved in
source. The latest Freeze Lane animation is ready for visual review; remaining
buff presentation, phone testing and tuning are still open. Menu VFX/UI/UX follows
as step 4, using the saved menu artwork-fit changes as its baseline.

HTML/PDF/video reviews and full test logs remain on this computer under
`../artifacts/buff-polish-2026-09-25/`, `../artifacts/buff-art-review-2026-09-25/`
and `../artifacts/menu-artwork-fit-2026-09-25/`; these artifact directories are
outside the Git worktree. Use Godot 4.7.1 for subsequent checks.

## Authorized sequence

1. Polish older buff icons: remove baked-in backgrounds and normalize framing,
   preserving the existing motifs and Classic purple / Premium red / Elite gold.
2. Buff UI/VFX: review phone-size catalog/loadout/strips and develop readable
   targeting, activation, active-time and expiry feedback, starting with Freeze Lane.
3. Buff testing and tuning: verify mechanics and presentation, then collect device
   evidence and propose balance changes from observed results.
4. Menu VFX/UI/UX: the owner explicitly added this as the next step after buffs.
   Continue from the existing menu artwork-fit and readability work, covering
   navigation, interaction feedback, transitions and the remaining menu surfaces.

The owner approved this sequence on September 25: "OK, let's do that, and then
the next step, 4 will be the menu VFX/UI/UX...". Existing menu edits in this
worktree remain the baseline for step 4.

Owner direction (September 25): make buffs the next sprint, covering UI/VFX,
catalog art, testing and tuning. Begin by completing missing buff icons. Decide
the concepts together before rendering. Both lane buff sets, Shock Immunity and
Supercharge Queue are accepted and integrated. After reviewing the two global
concepts, the owner directed continuation; use the shown three-hive globe for
Global Shock Immunity and retain the existing globe-and-bee Global Hive Shield.
The owner prefers an accessible
visual review over Markdown; use the HTML/PDF review in
`../artifacts/buff-art-review-2026-09-25/` relative to the project root.

## Tier art direction

The owner confirmed the existing palette:

| Tier | Color | Asset suffix |
| --- | --- | --- |
| Classic | Purple/violet | `classic` |
| Premium | Red | `prem` |
| Elite | Yellow/gold | `elite` |

Preserve the existing circular metal medallion style. Each buff needs its own
recognizable motif, with a consistent composition across its three tier colors.
Global and single-target effects must remain visually distinguishable.

## Initial catalog and art audit

Baseline: unified mobile source `13633b2`. The authoritative active roster in
`scripts/state/buff_definitions.gd` contains **12 buff families / 36 tier entries**.
`scripts/state/buff_catalog.gd` permits shared art and unrelated fallback icons,
so an existing file path alone does not establish complete art coverage.

| Active buff | Classic | Premium | Elite | Art work needed |
| --- | --- | --- | --- | --- |
| Swarm Damage | Existing | Existing | Existing | None |
| Hive Impact Damage | Existing | Existing | Existing | None |
| Unit Speed | Existing | Existing | Existing | None |
| Single Production Boost | Existing | Existing | Existing | None |
| Global Production Boost | Existing | Existing | Existing | None |
| Hive Shield Single | Existing | Existing | Existing | None |
| Hive Shield Global | Fallback | Fallback | Existing | Two variants of existing global shield |
| Shock Immunity | Shared shield | Shared shield | Shared global shield | Dedicated motif, three tiers |
| Global Shock Immunity | Shared single shield | Shared single shield | Shared global shield | Dedicated global motif, three tiers |
| Supercharge Queue | Shared production | Shared production | Shared production | Dedicated queue/release motif, three tiers |
| Freeze Lane | Fallback | Fallback | Tower range art | Dedicated freeze motif, three tiers |
| Treacherous Lane | Tower double-tap art | Fallback | Tower double-tap art | Dedicated reversal motif, three tiers |

This leaves **17 individual tier icons** to create for the active roster:
2 global shield variants plus 5 families with 3 tiers each. Nineteen active
entries already have appropriate art.

Progress since this baseline: the owner approved all three Freeze Lane icons,
now saved unchanged as `lane_freeze_classic.png`, `lane_freeze_prem.png` and
`lane_freeze_elite.png` in `assets/sprites/sf_skin_v1/buffs/`. The catalog now uses
these instead of tower art/fallbacks. The owner also approved all three
Treacherous Lane icons, saved as `lane_treacherous_classic.png`,
`lane_treacherous_prem.png` and `lane_treacherous_elite.png` in the same directory
and mapped to that buff. Single-hive Shock Immunity is also approved and uses
`hive_shock_immunity_classic.png`, `hive_shock_immunity_prem.png` and
`hive_shock_immunity_elite.png` instead of shared shield art.
Supercharge Queue is also accepted and uses `hive_supercharge_queue_classic.png`,
`hive_supercharge_queue_prem.png` and `hive_supercharge_queue_elite.png`.
**All 36 active entries now have appropriate art wired into the catalog.** The
owner accepted the final Global Shock Immunity and Global Hive Shield sets:
"yup, they are good". The five new PNGs were copied unchanged; the existing Elite
Global Hive Shield was retained. Global Shock Immunity now uses its dedicated
`hive_global_shock_immunity` stem. No active-tier art gaps remain.

The initial asset audit found **eight complete three-tier families**, three
partial families and one utility icon. Two complete families (global unit speed
and local unit damage) are outside the current active mappings. Partial tower
double-tap and tower range art also survives. Counting art families therefore
differs from counting active buffs. The owner's recalled 17-buff roster is not
established by the active definitions; retain this discrepancy for roster
reconciliation rather than silently adding or retiring gameplay buffs.

## Concept decisions

- [x] Confirm tier colors with owner.
- [x] Owner likes the shown single-hive Shock Immunity concept (September 25).
- [x] Owner approved all three single-hive Shock Immunity variants: "Yup, love it."
- [x] Proceed with the shown three-hive globe and deflected bolt for Global Shock
  Immunity after the owner's direction to continue (September 25).
- [x] Owner likes the shown Supercharge Queue concept (September 25).
- [x] Owner accepted the three-color Supercharge set and moved on: "OK, next?"
- [x] Choose Freeze Lane motif: dominant icy-white snowflake, with a short frozen
  lane and frozen bee as secondary detail. Owner requested the same composition
  in Classic purple, Premium red and Elite gold (September 25).
- [x] Owner approved all three Freeze Lane variants: "those look good. Keep them."
- [x] Choose Treacherous Lane motif: owner likes a dominant U-turn arrow with
  bees returning toward their own hive as secondary detail (September 25).
- [x] Owner approved all three Treacherous Lane variants: "those are cool. Keep them."
- [x] Retain the existing globe-and-bee Global Hive Shield composition; complete
  its missing Classic/Premium variants after the owner's direction to continue.
- [x] Render all selected concepts and prepare three-tier HTML/PDF reviews.
- [x] Obtain visual acceptance of the final global sets, integrate their five
  new icons and verify the complete active catalog (36 unique sprites).

Freeze Lane review set: all three PNG variants are saved in
`../artifacts/buff-art-review-2026-09-25/freeze-lane-v1/` relative to the project
root, with `index.html` and `freeze-lane-tiers.pdf` for side-by-side review and
30 / 48 / 64-pixel comparisons. Built-in image generation produced one Classic
base followed by two color-only edits. Prompt provenance is in `generation.json`
and the HTML's expandable generation details. The owner has approved the set;
all three files are preserved in the runtime asset directory and the catalog
maps Freeze Lane to its own `lane_freeze` family.

Treacherous Lane review set: one Classic base and two color-only tier edits are
saved in `../artifacts/buff-art-review-2026-09-25/treacherous-lane-v1/` relative to
the project root. The HTML/PDF review includes all three tiers and 30 / 48 / 64
pixel previews. Prompt provenance is in `generation.json` and the HTML. The
owner has approved all three rendered variants. They are preserved in runtime
assets and replace the live catalog's tower placeholders.

Single-hive Shock Immunity review set: the previously liked Classic concept and
its matching Premium red / Elite gold variants are saved in
`../artifacts/buff-art-review-2026-09-25/shock-immunity-v1/`. HTML and PDF provide
the three-tier comparison and small-size previews; PNGs and generation prompts
are preserved in the same directory. The owner approved all three tier variants;
they are copied unchanged into runtime assets and replace the shared shield art
in the catalog.

Supercharge Queue review set: the previously liked Classic concept and its
matching Premium red / Elite gold variants are saved in
`../artifacts/buff-art-review-2026-09-25/supercharge-queue-v1/`. HTML/PDF provide
the three-tier comparison and 30 / 48 / 64-pixel previews; PNGs and generation
prompts are preserved alongside them. The owner accepted the set and moved on;
all three files are copied unchanged into runtime assets and replace the
production-boost art in the catalog.

Final global review sets: `global-shock-immunity-v1/` and
`global-hive-shield-v1/` under the same artifact directory contain all six PNGs,
HTML/PDF comparisons, and generation provenance. The pre-existing Elite Global
Hive Shield is retained unchanged. `final-global-sets/index.html` and
`final-global-sets/global-buff-tiers.pdf` combine both sets with 30 / 48 / 64-pixel
previews. All five new tier icons are approved and integrated. The complete
12-family / 36-icon sheet is `catalog-complete/index.html`, with a standalone
`catalog-complete/buff-icon-catalog.pdf`. The HTML lets the owner switch between
30 / 48 / 64 / 120-pixel previews.

Supercharge explanation for concept review: select one eligible outgoing lane.
Normal hive production continues to send bees, while each qualifying produced
bee also banks one bonus bee (up to the existing cap of 128). At expiry the bonus
queue releases automatically as a tight train. Charge duration is 5 / 7 / 9
seconds for Classic / Premium / Elite. Losing the source hive, lane or sending
direction before release forfeits the queue. The art should communicate a bonus
wave accumulating; it must not imply that ordinary traffic stops while charging.

## Art completion and next pass

Godot 4.7.1 imported the approved assets. The existing sprite-mapping smoke test
passes with `entries=36 unique_sprites=36`. The catalog exported from runtime
also has 12 families, all three tiers per family, no tower fallback and 36 unique
image paths. Evidence is under `catalog-complete/` in the review directory.
Import reported an unrelated duplicate font UID; the smoke log retains the
three previously observed Unicode parsing warnings after PASS.

The owner authorized the consistency pass on older assets. Eleven images were
cleaned with built-in image generation, retaining their motifs and tier colors:
Hive Impact Damage Classic/Elite, all three Swarm Damage tiers, Global Production
Boost Classic/Premium, all three Single Production Boost tiers, and Global Hive
Shield Elite. They now use square RGBA canvases with genuine transparent outer
backgrounds. The originals and generated replacements are both preserved under
`../artifacts/buff-polish-2026-09-25/before/` and `after/`. These replacements are
copied unchanged into runtime assets. The previous accepted Elite shield motif
is retained; its formerly opaque outer background is now removed.

The accessible review is `../artifacts/buff-polish-2026-09-25/index.html`, with
before/after views, 30/48/64/112-pixel controls, light/dark backdrops, a PDF, the
Freeze Lane video and the four-step sequence. Generation prompts and source paths
are in its expandable details and `generation.json`.

Next: review the native Freeze Lane treatment, check the icons in the actual
catalog, loadout and player/opponent buff strips at phone size, and extend readable
targeting, activation, active-time and expiry feedback to the other buffs.
Follow with mechanics/device testing
and evidence-based balance proposals. `scripts/shell.gd` currently keeps
`MATCH_BUFF_TARGETING_ENABLED` false; preserve that setting during this art pass
and use the existing controlled targeting harness for the next device review.

The archived `docs/planning_import/Swarmfront_Buff_Catalogue.pdf` is a broad draft
wish list, not a 17-entry active roster. Roster reconciliation therefore remains
an explicit planning item; this pass completes the 12 currently active families.

## Freeze Lane UI/VFX implementation

The owner chose a more dramatic effect over the restrained concept. The new
`BuffFreezeLanePresentation` reads canonical effect snapshots and draws a frost
burst, translucent lane ice, crystal edges, a snowflake/countdown marker and a
brief shatter/thaw. Units and hives render above the effect. The countdown and
expiry use simulation ticks; wall-clock time cannot end an effect. Target loss,
replacement, match end and scene teardown clear the presentation. Reduced VFX
retains the static ice/marker and omits animated burst/thaw. Existing targeting
and canonical success feedback remain connected through their current paths.

The player buff strip had obsolete generic 10/15/20-second fill durations.
Arena now supplies the canonical effect duration; the strip uses that value,
with the catalog duration as a compatibility fallback. Snapshot application
copies slot dictionaries before adding presentation fields.

The native video is `freeze-preview/freeze-lane.mp4` under the polish artifact.
It uses the production effect renderer and staged snapshots with illustrative
unit motion; it demonstrates presentation, not a complete match or physical-device
playtest. The source harness is `tools/buff_freeze_visual_harness.gd` and uses
the existing isolated/offline capture runner. The production buff-targeting gate
remains false. Other buff VFX, full catalog/loadout/strip phone review, physical
testing and balance tuning are still open before step 4.

The focused validation adds freeze projection/lifecycle/authority checks and
actual-duration fill checks. Existing mechanics fixtures exposed test-only
lifecycle issues: state/system reference cycles were not released, and cross-mode
OpsState fixtures were outside the scene tree. Their setup/cleanup now respects those lifetimes;
no assertion or gameplay rule is relaxed. All nine focused suites pass with no
engine errors in the final runs. Final results are in
`../artifacts/buff-polish-2026-09-25/checks/results.json`.

## Sprint work and completion evidence

| Workstream | Scope and evidence |
| --- | --- |
| Catalog art | Reconcile the roster; complete every approved family/tier; review a labeled contact sheet and actual-size HUD/catalog previews; replace placeholder/shared mappings with the correct selected art. |
| UI | Review catalog descriptions, tier/scope recognition, inventory/loadout, player/opponent strips, targeting, activation, remaining duration, expiry, rejection and refill feedback. |
| VFX | Establish distinct activation, sustained-effect and expiry cues for each effect and scope; validate overlapping effects, crowded scenes, reduced motion and phone performance. |
| Testing | Check all buff/tier mappings and meaningful visual coverage; run existing authoritative mechanics, activation/targeting and UI checks; collect combined iPhone/Android evidence. |
| Tuning | Record observed effectiveness and counterplay across representative maps, modes and tiers; propose explicit balance adjustments and retest approved changes. |

OpsState/SimState and simulation systems remain the only gameplay writers.
Presentation reads canonical state and emits intents. This sprint plan and art
pass do not change buff rules, duration constants or balance values.
