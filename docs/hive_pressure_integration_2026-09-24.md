# Hive pressure v2 integration — September 24, 2026

The owner authorized the next sprint deliverable: integrate the stronger pressure
treatment and verify it in a running match. `HiveDistressLight` now uses the v2
crown rim, warm vents, warning pulse and four fixed ember paths in production.
The shader respects inherited CanvasItem tint/opacity so parent fades still work.

## Ownership and bounds

Only presentation drawing and material setup changed. The pressure classifiers,
hold/recovery timers, rupture classification, viewer filtering, capture resets,
growth suppression and lifecycle handling remain unchanged. Comparison against
the saved pre-change component confirms that its retained behavioral methods
are identical. SHA-256 checks also confirm that all 117 captured simulation,
systems, OpsState/state and pressure-rule source files are unchanged by this pass.

The draw path uses one reusable ShaderMaterial, one local rectangle and no child
nodes, particles, screen textures, simulation RNG or per-frame geometry arrays.
Reduced/static motion disables the new pulse, ignition flash and ember travel;
the existing pressure envelope and expiry remain active. Debug capacity now
reports four embers and zero fragments instead of the retired polygon renderer's
particle limits. The original v1/v2 studies remain runnable and each reuses the
base component's material.

## Validation and review

- Five targeted checks: pressure rules/lifecycle, canonical hostile commitment,
  growth transitions, hive picking and selection presentation.
- The pressure check also runs with the native renderer, including reduced/static
  shader parameters, warning expiry, idle processing and material reuse.
- The comparison study checks 576 matched presentation samples in each of full,
  reduced and static motion, with native shader compilation and captured stills.
- The match capture launches the real Campaign Center Axis level, Shell, Arena,
  SimRunner and turtle bot. It issues ordinary local-player lane intents and reads
  the renderer's pressure events; it never sets hive power, ownership or units,
  and never injects pressure. The eight-second clip starts on actual hostile
  pressure and includes live units, lane traffic and ownership changes.

Review: `../artifacts/hive-pressure-integration-2026-09-24/index.html` relative to
this worktree. Logs, match events, baseline component and source hashes sit beside
the review. The earlier exploratory capture log records an exit-resource error;
the final capture explicitly releases simulation bindings and drains scene exit.

Reproduce with the pinned Godot 4.7.1 executable:

```sh
python3 tools/run_hive_pressure_checks.py --godot /path/to/Godot --output /tmp/pressure-checks
python3 tools/run_hive_pressure_checks.py --godot /path/to/Godot --output /tmp/pressure-native --capture --test hive_distress_light_smoke_test
python3 tools/run_hive_pressure_checks.py --godot /path/to/Godot --output /tmp/pressure-match --capture
python3 tools/build_hive_pressure_match_review.py /tmp/pressure-match
```

These runners isolate player data and disable hosted services. Capture uses a
fixed presentation delta, forced draws and synchronous screenshot readback;
video playback rate is not a performance measurement. Existing asset UID fallback
and Unicode diagnostics are retained in native logs. Physical iPhone/Android
frame pacing and a dense overlapping-effects review remain open before beta
handoff. No new mobile build or store upload is included in this integration.

Owner approved the integrated pressure treatment. The subsequent
[selection and capture pass](hive_selection_capture_2026-09-24.md) is now integrated;
combined phone review remains the next validation step in the mobile UX sprint.
