# Hive pressure quality study — September 24

Update: v2 is now integrated into the working mobile source following owner
authorization. See [production integration and live-match evidence](hive_pressure_integration_2026-09-24.md).
The sections below preserve the study and review history.

The current effect consists of a tall polygonal plume, sparks and fragments. Its
hard edges and large reach make it read as a generic overlay and can compete with
power labels. The proposed treatment places a hot rim directly on the crown,
releases pressure through short feathered vents and uses four restrained embers
for rupture. The heat fades cleanly when the existing pressure timer clears.

The comparison uses Godot 4.7.1 and identical fixture events on both sides, with
close-up and compact views. The candidate subclasses the production component;
only drawing/material setup changes. Every captured step compares pressure state,
intensity, hold time, rupture counters and surge index with the current component.
All drawing fits one fixed rectangle and allocates no child nodes or emitters.

Review: `../artifacts/hive-pressure-2026-09-24/index.html` (local artifact).
The page includes full-speed/slow playback and frame stepping over active hostile
decline, two tier-loss cases and recovery. Existing art is used in a controlled
layout, not a running match. No pressure simulation rules or production pressure
drawing have been changed. This is the next visual candidate for review after the
approved tier transformation integration.

Reproduce with `tools/run_hive_pressure_study.py` and
`tools/build_hive_pressure_review.py`. Physical-phone profiling is still needed
before a production pressure replacement.

## Revision 2 — combat recognition

The owner liked the first direction but found it too subtle during battle. The
second candidate increases ignition contrast, doubles the visible vent reach,
broadens the vents, increases ember size and adds a two-pulse-per-second rhythm
while pressure is active. Warm amber/orange light with white-hot peaks separates
the warning from the team-colored hive body. The vents splay around a protected
centre so the power number remains legible. Major rupture retains the stronger
burst; recovery still follows the inherited timing.

The revised comparison places the preserved first candidate on the left and the
stronger treatment on the right. Both compact views now include moving traffic
and crossing lanes. This is a synthetic readability fixture, not a running match
or evidence of human recognition speed.

Review: `../artifacts/hive-pressure-2026-09-24-v2/index.html`.
The original video remains at the original path. `pressure_v1.gd` and its shader
preserve the first candidate for a direct comparison. Reproduction commands now
produce revision 2. Pass `--motion reduced` or `--motion none` to inspect the
steady alternatives; the added pulse and ignition flash are full-motion only.

The production pressure renderer and all simulation files remain unchanged. The
candidate still uses the same rectangle, one shader material, no child nodes,
and four fixed ember paths. It reuses the existing shimmer for plume width;
brightness does not add draw calls, particles or screen-space effects. The added
pulse is sampled from the existing presentation clock. Both candidates still
match pressure state, hold time, intensity, counters and surge index on every
sample, in full, reduced and static motion. Physical-phone profiling remains part
of production validation.
