# Selection and capture finish — September 24, 2026

Following approval of pressure v2, the owner authorized selection and capture as
the next visual pass. Both are integrated into the mobile working source.

Selection closes a small ivory marker onto the hive skirt in 0.12 seconds, then
holds steady. Release takes 0.10 seconds. The shell's white metal highlight is
less broad so team color and texture remain apparent. The same metal and edge
lighting now passes through growth/shrink transitions without a selection jump.

Capture immediately shows the canonical new owner and power. A 0.46-second fitted
sweep and brief contact light confirm the ownership change. A recapture replaces
the previous sweep; a subsequent tier transformation takes over. Existing capture
sound and floor effects remain as before. Pressure v2 is unchanged.

## Authority and lifecycle

The existing canonical render history supplies ownership edges. No new gameplay
state, capture rule, power threshold, input rule, lane geometry or collision area
was added or changed. Initial samples, viewer changes, state reconstruction,
noncanonical samples and stopped simulation reseed or cancel without replaying
historical captures. Neutral-to-player and player-to-player edges are eligible;
returning to neutral only clears the old effect.

Each hive has one reusable zero-child lighting component, one material and one
bounded rectangle. Selection stops processing once seated. At most six full
capture sweeps run simultaneously, admitted by stable hive ID; overflow gets the
short stationary confirmation. No particles, new textures, screen reads, shader
TIME or gameplay RNG are used by the new lighting.

Reduced motion uses an immediate selection marker and a stationary 0.16-second
capture confirmation. Disabled motion retains steady selection and immediate
ownership recoloring with no capture animation. Backgrounding, removals, scene
resets and motion-setting changes cancel transient effects. Parent opacity is
preserved, and all effects remain below power/lane-budget indicators.

## Validation

- Six targeted regression checks pass: pressure behavior, hostile commitment,
  growth transitions, picking, selection wiring, and the new interaction suite.
- New coverage includes duplicate samples, rapid recapture, neutral capture,
  state/viewer resets, backgrounding, tier-transition precedence, motion changes,
  stable simultaneous-capture admission, fixed material/node reuse and equivalent
  sampled poses under different update schedules.
- Native captures cover all three hive sizes in full, reduced and disabled motion.
- An eight-second running Campaign clip includes pressure, capture/recapture,
  selection release/reselection, selection moving to another hive, units and lanes.
  Selection goes through ArenaAPI; player commands go through OpsState intents.
  The harness never assigns gameplay power, ownership or units.
- SHA-256 verification covers 119 unchanged simulation/state and pressure sources
  against the start-of-pass snapshot.

Review: `../artifacts/hive-selection-capture-2026-09-24/index.html` relative to this
worktree. Match event evidence, native fixture stills, logs, source hashes and the
pre-change presentation files are retained alongside it.

Reproduce with the pinned Godot 4.7.1 executable:

```sh
python3 tools/run_hive_pressure_checks.py --godot /path/to/Godot --output /tmp/hive-effects/checks
python3 tools/run_hive_pressure_checks.py --godot /path/to/Godot --output /tmp/hive-effects/fixture --capture --test hive_interaction_visual_harness
python3 tools/run_hive_pressure_checks.py --godot /path/to/Godot --output /tmp/hive-effects/match --capture --interactions
python3 tools/build_hive_pressure_match_review.py /tmp/hive-effects/match
```

Runners isolate player data and disable hosted services. Native logs retain the
existing asset UID/Unicode warnings and the same 24-instance exit warning seen in
the preceding pressure match capture; no script/shader/resource errors were
reported. Forced rendering and synchronous readback make the movie visual evidence,
not a performance measurement. Physical iPhone/Android profiling and crowded-match
review remain the next validation step before broader menu work and beta handoff.
