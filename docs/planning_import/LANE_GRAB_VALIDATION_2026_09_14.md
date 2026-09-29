# Lane grab validation after combat readability

The September 10 preview smoke check did not exercise picking or a complete
press/hold/pull/release. It could pass while a visible route could not be grabbed.
This follow-up covers the production picker, InputSystem, ArenaAPI, lane preview,
and the resulting OpsState retraction request in an isolated scene fixture.

## Corrections

- Picking uses the same shell/cap-adjusted endpoints as lane drawing and grab
  measurements. The old hive-center hit line could miss the visible route.
- Grab geometry covers the full acquired lane, independently of the contested
  battle front. Holding beyond the old front cannot count as a throw.
- Throw distance measures perpendicular distance to the lane axis. Moving along
  the lane does not become a throw by passing a segment endpoint.
- Both preview directions start at the owned source hive.
- Each update revalidates the originally acquired direction and its owner. A
  capture cannot transfer an existing gesture to a different direction.

The 160 ms hold, 44 local-pixel throw threshold (30 in the constrained tutorial),
and simulation retraction behavior are unchanged. Only OpsState mutates the live
lane state. Readability settings do not determine gesture ownership or validity.

## Repeatable checks

Run `bash scripts/dev/run_lane_grab_regression.sh` from the project root.
The release-readiness gate also runs this suite by default. Each process has a
timeout; missing PASS markers, nonzero exits, or script errors fail the suite.
Logs default to `/tmp/swarmfront_lane_grab_regression`.

The gesture test runs 116 cases across readability on/off, touch/mouse, and both
directions. It covers stationary holds beyond the former front, short pulls,
along-lane drags, positive/negative throws, the exact threshold, returning before
release, premature release, another finger, input locking, external retraction,
ownership changes, enemy-only lanes, one-way attacks, and friendly feeds.
It checks one command on successful release, no early/duplicate commands,
canonical send flags, preservation of the opposing and crossing lanes, source
anchoring, focus, and preview/route cleanup. Most cases include translation,
nonuniform scale, and rotation; the exact boundary case uses an unrotated axis to
avoid floating-point round-trip ambiguity. Timing advances the ephemeral press
timestamp and calls the production tick rather than waiting on a wall clock.

The suite also runs grab presentation, existing hive/command input controls,
combat readability, and battlefield screen-coordinate conversion checks.

For GPU captures, run:

```sh
godot --path . --rendering-method gl_compatibility \
  --script tools/lane_grab_gesture_smoke_test.gd -- \
  --capture-dir=/tmp/swarmfront_lane_grab_captures
```

This captures before, armed, throw-ready, and released for both directions. These
are isolated lane fixtures, not dense gameplay or physical-device evidence.

## September 14 evidence

The five-check regression suite passed on the installed Godot 4.2 engine. The
116-case gesture test also passed with Compatibility GPU rendering, producing
eight reviewed frames. The original picker failed acquisition in this fixture.
Running the original InputSystem against the corrected picker also failed the
stationary-hold, reverse-source-anchor, and capture-during-hold assertions. Thus
the new checks distinguish the repaired behavior from the previous code.

Evidence is saved in `SF/artifacts/lane-grab-2026-09-14`, including `review.html`,
captures, passing focused logs and the deliberately failing original-code logs.

The additional full gameplay MVP smoke run timed out on
`phase_reaches_running` at its existing 12-second limit (25 checks passed, one
failed). The same phase timeout recurred when rerun without the capture process.
This is an unresolved broader startup/readiness failure; no full-release pass is
claimed here, and the timeout has not been relaxed to obtain a pass.

## Physical iPhone acceptance — outstanding

Use the current build at its normal gameplay scale. Record device, build,
orientation and pass/fail, with a short screen recording of each failure.

1. Repeat grabs near the source, middle, and destination of one-way and opposing
   routes. The touched lane should visibly arm and bend from its owned source.
2. Repeat beside crossings and near every playfield edge in a crowded match.
   A completed throw retracts only the acquired owned direction.
3. Hold still, pull short, drag along the lane, and pull out then return before
   releasing. Each leaves the lane active and clears the preview on release.
4. Try a second finger, opening pause, and leaving/re-entering the app during a
   hold. There must be no unintended deletion or stuck highlight.
5. Confirm the finger does not hide the armed feedback, haptics are perceptible,
   and the preview follows reliably under load. Also complete the tutorial's
   constrained grab lesson, which uses its existing shorter threshold.

Automated success does not close this physical acceptance step. The fixture does
not test native touch cancellation, the full Shell event route, or live-network
retraction scheduling; those remain distinct integration/device checks.
