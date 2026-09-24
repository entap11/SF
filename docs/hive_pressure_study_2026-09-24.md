# Hive pressure quality study — September 24

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
