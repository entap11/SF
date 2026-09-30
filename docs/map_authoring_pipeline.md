# Sketch-to-map authoring

Authorized September 21, 2026: interpret rough drawings as layout intent, produce
continuous finished walls, and require equivalent multiplayer starting positions.

## Contract

- `map_usage` is explicitly `campaign`, `multiplayer`, or `both`, independent of
  the legacy `1p`/`2p` filename convention. Missing usage means unclassified legacy
  content, never a multiplayer certification.
- Multiplayer/both exports must pass geometric symmetry and player-orbit checks.
  Hives, powers, neutral resources, structures, slots, wall segments and initial
  starts participate. Every player must be reachable from every other by an
  allowed symmetry that preserves the entire layout and permutes owners.
- The runtime loader verifies the complete legal-connection graph under each
  symmetry using a local simulation instance. Visually matched geometry alone
  cannot certify unequal gameplay connections.
- Author one sector and generate its counterparts. Wall cleanup happens once,
  before reflection/rotation. Endpoints are retained so intentional gaps survive.
- Final wall segments are the gameplay input; continuous wall rendering is a
  read-only projection. No renderer may move a hive or change blocking geometry.
- Campaign-only layouts may be asymmetric. A shared battlefield's encounter
  setup is separate from its base layout and must be revalidated for multiplayer
  after changing ownership/power. Geometry alone is not a balance claim.
- Existing maps are reference material until re-authored. Keep their geometry and
  IDs intact. Wall-map public rollout remains sandboxed. This work does not enable
  public wall maps or alter live competitive catalogs.
- New selectors can call `MapLoader.list_maps("campaign")` or
  `MapLoader.list_maps("multiplayer")` for explicitly designated, runtime-valid
  maps. `MapModeRules.map_supports_usage` checks designation/layout eligibility;
  loading/exporting additionally checks actual simulation connections.

## Implementation boundary

Upgrade the existing Godot tracer to the native grid, wall strokes, explicit usage,
symmetry generation, saveable drafts and gameplay/finished previews. Reuse the
existing finalizer and loader for validated deterministic exports. Add a Rink Rat
pilot with equivalent corner starts and continuous wall art; use Swirly to check
junction handling. Preserve the original references.

The pilot keeps all 13 reference hive cells. Its source arc starts at (4.7, 2.8)
and ends at (2, 13), with exact generated counterparts. The longer reference arc
intersected the simulation's downward-offset hive ports differently above and
below the board. Shorter top/bottom arcs and longer side tips make the complete
initial legal-connection graph equivalent. The original mirrored arc is retained
as a regression case: geometric validation passes, runtime validation rejects it.

The first symmetry presets are mirror X, mirror Y, half-turn, both mirrors, and
quarter-turn. Quarter-turn requires a square playable layout that fits the board.
Hives retain integer or half-cell coordinates, matching the existing runtime.
Structure slots use integer cells. The drawing template labels zero-based cell
centers `(0,0)` through `(17,27)`; the outside border begins at `(-0.5,-0.5)`.
Reject out-of-bounds input before export rather than silently dropping it.
Three-player 120-degree geometry cannot be represented exactly by this lattice;
it must not be approximated and certified.

Paired random structure slots can carry the same nonempty `symmetry_group`.
With matching allowed types, the setup randomizer chooses the same type for the
entire group from the shared seed. Legacy ungrouped slots retain their existing
selection behavior. The contract checks group membership, controls and entity
structures as well as standalone structure arrays.
Compact-node import preserves explicit structure controls, ownership and power.
Simulation structure centers use precise authoritative hive positions, matching
the rendered control-triangle centroid instead of flooring half-cell hives.

The September 29 Simple Syrup pass adds two retained drafts and four unpublished
exports. See [the review](simple_syrup_map_review_2026-09-29.md) for playable
commands, actual match captures and verification evidence.

## Acceptance evidence

Reject an unequal wall, shifted counterpart, unequal start power, asymmetric
resource/slot, missing designation, and visually symmetric but inequivalent
starts. Accept asymmetric campaign content. Verify deterministic sector expansion,
stroke endpoint retention, actual loader round-trip, and unchanged simulation
connectivity after a visual-only renderer replacement. Capture actual Godot wall
previews at phone scale, with a gameplay-overlay toggle.

## Verification — September 21, 2026

Runtime: pinned Godot `4.7.1.stable.official.a13da4feb`. Tests use an isolated
project/user-data directory with service URLs cleared; no live profile is used.

- `run_map_authoring_gate.sh`: pass (symmetry, studio, finalizer, wall renderer).
  Covers deterministic output/freshness, geometric and actual connection
  asymmetry rejection, native-grid enforcement, campaign asymmetry, atomic export,
  retained drafts/undo/redo, continuous paths/junctions and unchanged simulation
  geometry after rendering.
- Real editor plugin boot: pass with `Engine.is_editor_hint() == true`, pilot
  runtime validation and 26 legal connections. Standalone graphical studio: pass.
- Existing map lane availability (16 maps), map layout rules and PvP 1v1 map
  contract checks: pass.
- Required fast release run: authoring, all five lane/input/presentation checks,
  MVP (26 checks), soak-launch contract and matrix contract (15 pass, 13 skipped)
  pass. Matrix boot finishes with seven configurations passing, one failing and
  five skipped: the 2v2 stage-race arena misses its startup deadline. The same
  route passes on targeted repeat in both this branch and untouched base; both
  emit the existing unit-color shader compiler diagnostic. The original full
  gate therefore remains recorded as failed, not a clean release certification.
  The skipped fast soak stage was subsequently run with its exact standard
  settings: all three selected routes pass (seed 123, one pair, ten seconds).
- `map_mode_contract_smoke_test.gd` and `map_public_alias_smoke_test.gd` reproduce
  the same failures on untouched base commit `c758b75`: Corkscrew owner 2 has no
  opening lane; the alias test has 17 stale catalog/tutorial expectations.
  Original maps/catalog policy are preserved rather than weakening the checks.
- Actual OpenGL Godot captures: `wall-comparison.png`,
  `wall-comparison-barriers.png`, and `map-studio.png` in the local
  `SF/artifacts/map-authoring-2026-09-21/` evidence directory. Comparison panels
  are approximately phone width; hive markers are schematic. This is desktop
  implementation evidence, not a supported-device or competitive-balance pilot.

The drawing template generator was run with Pillow 11.3.0 and system Helvetica;
Godot regenerated import metadata. The compiled map's byte-for-byte freshness is
enforced by the symmetry smoke test.
