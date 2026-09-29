# Human-behavior pilot continuation — September 22, 2026

Continues the [September 16 checkpoint](bot_calibration_2026-09-16.md).
The owner reaffirmed that the goal is more human-like behavior. Match strength is
a regression measure; it does not establish believable decisions or enjoyable play.

## Behavior change

The medium Balancer now uses spare lane capacity to reinforce an existing front.
Previously, routine supply excluded a donor as soon as it had one outgoing route,
even when it could legally support another hive involved in an attack. The saved
Centerstrike/Turtle trace suggested inspecting that restriction; a focused legal
scenario reproduces the hesitation with the frozen v2 policy.

The candidate, `human_balancer_v3`, permits that additional supply only when the
destination has an active route to a non-allied hive. It retains the existing
power, capacity, threat, cooldown, distance, recipient-power and incoming-supply
checks. It neither replaces the current attack plan nor resets its review deadline.
An inactive front alone does not justify another route from an already busy donor.

The scenario verifies the old hesitation, useful support, unchanged observation
and gameplay during planning, preserved plan and routes, unavailable capacity,
threatened donors, cooldowns, and absence of duplicate or reciprocal supply.
Orders still pass through the existing delayed observation and validated command
pipeline. Notice, motor, thinking, opening and review timings are unchanged.
Growth, lane capacity, combat, swarm and victory rules are unchanged.

This remains an opt-in **medium Balancer in two-seat conquest**. It does not extend
the pilot to other personalities, tiers, or objective/team modes. Start a new
match when comparing policy revisions; continuation across different code/policy
versions is not certified.

## Snapshot trace repair

The untouched checkpoint's exact pending-command trace test failed on the pinned
Godot 4.7.1 runtime: JSON restoration changed timestamp representations from, for
example, `400` to `400.0`. Gameplay hashes matched, but the emitted traces differed.
Command telemetry now normalizes its three scheduling timestamps to integer
milliseconds. The existing exact comparison passes without relaxing its assertion.
Both calibration arms use this repair and the same simulation/scheduler.

## Reproducible evaluation

[Frozen v2](../tools/fixtures/bot/human_balancer_v2.gd) is a byte-for-byte copy of
the policy at source checkpoint `dc19dda`. Its SHA-256 is
`f8b9f9ab4c0b32d4606b413e6c8fd4d699b85891fc21a49b3a6e46dc853c9b64`.
The original v1 fixture and `--pilot-control` option remain available.

Run from `project-unified-mobile-release` with the pinned runtime:

```sh
export GODOT_BIN="$HOME/Library/Application Support/Swarmfront/toolchains/godot/4.7.1/Godot.app/Contents/MacOS/Godot"
python3 tools/run_bot_behavior_regression.py --artifacts ../artifacts/bot-human-continuation-2026-09-22/regression
python3 tools/run_bot_calibration.py --control-policy v2 --artifacts ../artifacts/bot-human-continuation-2026-09-22/calibration
python3 tools/run_bot_calibration.py --control-policy v2 --seed 5201 --iterations 1 --map-ids MAP_centerstrike__CS3__1p,MAP_nomansland__444__v01_pinched_spine__1p --artifacts ../artifacts/bot-human-continuation-2026-09-22/heldout-final
```

The main schedule is the previous three maps, three medium opponents, two seeds
and both seats: 36 games per arm. The separate schedule uses Centerstrike CS3 and
No Man's Land 444 Pinched Spine, seed 5201, all three opponents and both seats:
12 games per arm. Those maps and that seed were selected before viewing candidate
match results. They are outside the previous three-map calibration set; CS3 was
used in the older v1 pilot, so it is not wholly unseen by the project.

Initial Corkscrew/Swirly and SN6/GBASE requests were rejected before any games ran.
The read-only map probe found unavailable opening lanes on Corkscrew/Swirly and
unavailable catalog paths for SN6/GBASE. Failed attempts remain in `heldout/` and
`heldout-nomansland/`; `map-probe.log` records the accepted replacement maps.

Calibration verifies complete match coverage, actual applied policy tags, matched
engines/clocks/timings, unchanged source fingerprints, and artifact hashes before
writing a comparison. Manifests now record the selected control and schedule.

The regression gate passes all six suites, including **79 runtime checks**, exact
snapshot trace restoration, repeated complete match JSON/trace equality, incomplete
horizon reporting, and rejection of scaled thinking. The frozen v2 control repeats
the September 16 main-schedule result: 15 wins, 20 losses and one draw.

On the separate 12-game schedule, v2 records 3 wins / 9 losses and v3 records
5 wins / 7 losses. Centerstrike CS3 stays at 2 wins / 4 losses; Pinched Spine
improves from 1 win / 5 losses to 3 wins / 3 losses. Both policies lose all four
Turtle games. Rejections rise from 2 to 6, with at most one consecutive rejection
in either arm. First-minute lane use rises from 68.5% to 71.4%; applied commands
per game in that minute rise from 12.83 to 13.08. These are descriptive samples,
not a human-likeness score or proof of general strength.

One fixed review case is Pinched Spine, seed 5201, Balancer in seat one against
Turtle. Both policies open supply 2→10 at 36.9 seconds. At 38.5 seconds, v3 also
opens 2→9, supporting hive 9's ongoing expansion toward hive 5. Its observation
was captured at 37.8 seconds. V2 does not add that support. Both still lose the
match: this sequence demonstrates the changed behavior independently of a win.
Exact actions, board samples and per-match rejection clusters are retained in
`review_cases.json`, generated by `review_results.py` beside the evidence.

All **96 comparison games** completed and both paired validations passed.

| Schedule | Frozen v2 W / L / D | Candidate v3 W / L / D |
| --- | --- | --- |
| Previous three maps, seeds 4101–4102 | 15 / 20 / 1 | 15 / 20 / 1 |
| Additional two maps, seed 5201 | 3 / 9 / 0 | 5 / 7 / 0 |
| Total | 18 / 29 / 1 | 20 / 27 / 1 |

On the main schedule, first-minute lane use rises from 63.8% to 66.9%, with
9.17 versus 10.19 applied commands per game in that minute. Routine development
orders increase from 24 to 67 over the full schedule. Rejections decrease from
28 to 11 (10 ownership and one unavailable lane); the longest consecutive
rejection run decreases from three to two. Minimum scheduled observation-to-action
delay is 500ms in both arms. The fraction of owned-hive samples with at least ten
power and no outgoing route increases from 5.1% to 5.9%, despite higher overall
lane use. Extra supply does not resolve every idle-hive case.

Across both schedules, rejections decrease from 30 to 17. Turtle remains unbeaten
in all 16 games per arm. The change is retained as an opt-in behavior improvement
with a reproduced scenario, broader support use and no loss in aggregate match
results, rather than a completed Turtle counterstrategy. The comparison does not
establish statistical significance or a measured gain in perceived human likeness.

Source changes are in `project-unified-mobile-release`, based on `dc19dda` on
`codex/single-player-campaign`. Evidence is in
`SF/artifacts/bot-human-continuation-2026-09-22/`, including source fingerprints,
the isolated implementation patch, full traces, comparison reports and the review
case extraction. No build was distributed and the pilot was not enabled by default.

## Next human evaluation

Review support decisions in context, then play against the pilot with CPU
disclosure. Record the map, seat, policy, approximate match time and a short note
when support looks purposeful, a pause looks implausible, a front is overfed, or a
plan is abandoned without a useful replacement. Rate challenge, believability and
fun separately. Retain the matching telemetry under `user://matches`.

The new Campaign/Jukebox catalog constrains available encounters, so the old
September 16 instruction to choose any evaluated map from Jukebox no longer
describes this checkout. The pilot flag still selects the medium Balancer policy
when the selected encounter meets its scope. A dedicated evaluation launch flow
for arbitrary maps should use session setup and the same simulation commands;
do not bypass campaign unlocks or change published challenge conditions to test.

No new annotated human sessions were available for this change. A successful
scenario and stable match results justify an experimental checkpoint, not a claim
that players perceive it as human. Human playtesting, timing fitted to players,
other personas/modes and default rollout remain unfinished. Resume with these
scenarios and traces rather than repeating the original audit.
