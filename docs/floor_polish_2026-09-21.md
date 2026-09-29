# Graphite floor and ambient circuits

Owner-approved scope: quieter floor artwork with fewer circuit lines that light
up randomly. Hive art, indicators, growth, shrinkage and pressure effects remain
the next separate discussion.

The standard floor now uses a native SVG graphite surface with a subtle metallic
gradient and perimeter seams. A bounded render-only layer draws 16 sparse circuit
paths around the edges, leaving the center quiet. Paths fade up and down over
3.6 seconds; one new pulse begins every 2.8 seconds, so at most two are active.
The stable pseudo-random schedule uses presentation time and does not consume
the game's random stream or depend on frame count.

The new material needs only an 18% readability veil, compared with 76% over the
old detailed texture. Custom floor selections retain their own artwork and the
existing veil; the new circuits appear only on the standard floor. The dormant
territory-influence feature gate is unchanged. Ambient glows convey no ownership,
range, attack or scoring information.

Existing GPU VFX and floor-graphics preferences suppress animated glows; the
static traces remain. Backgrounding suspends their presentation clock. Rendering
uses one reusable layer, without per-pulse nodes, textures or materials.

Validation: focused schedule/geometry/settings checks; existing floor-influence
bounds check; battlefield screen-angle input check; real-Shell match captures
at two fixed glow phases and selection/menu/results checks. Physical iPhone and
Android visual/performance review remains pending.

Captures live in the outer workspace at `artifacts/floor-polish-2026-09-21`.
