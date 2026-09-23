# Medium neutral-expansion experiment — September 22, 2026

Status: complete; neutral-expansion change retained. This is a single-variable follow-up to the
[2,000-game baseline](bot_round_robin_2026-09-22.md).

The owner authorized a bot balance pass after Turtle won 90% of the baseline.
Production, friendly-lane speed, combat and capture rules remain fixed.

## Hypothesis and change

The existing attack threshold applies board-size adjustments to both neutral and
enemy targets. On a sixteen-hive map, medium Raider must reach 15 power and Greedy
16 before opening either kind of lane, although their base reserves are 10 and 8.
Turtle can open at 5 on that board. This can leave Raider and Greedy waiting while
their opponent captures productive territory.

Enable `neutral_uses_base_attack_power` for medium Raider and Greedy. For neutral
targets only, cap the adjusted threshold at the profile's base reserve. Existing
lower thresholds stay lower. Enemy attacks, friendly feeding, swarms, command
timing, target scores and route commitment retain their current settings. The
option is absent from other personality/tier defaults. It applies to neutral
expansion throughout a match rather than adding an arbitrary opening timer.

The policy only chooses an intent. Simulation ownership, lane capacity, wall
checks and command application retain their existing authority.

## Declared comparison

Before candidate results, `SF/artifacts/bot-neutral-expansion-2026-09-22/experiment.json`
declares 600 paired games: the same five maps, first six sampled baseline seeds,
all twenty ordered personality pairings and both seat assignments. Reuse the
corresponding 600 saved control games, checking their hashes and provenance.
The frozen candidate uses Godot 4.7.1 and separate worker user-data directories.
Its full source fingerprint may differ from the control only in the baseline
policy and profile builder. The 180 games involving only unchanged Balancer,
Turtle and Swarm Lord must reproduce the complete control results exactly.

Keep the change only if focused scenarios and existing regression checks pass,
unchanged pairings reproduce, large-board neutral openings occur earlier, and
combined Raider/Greedy score improves. Report map and matchup regressions, remaining
imbalance, and behavior diagnostics. Do not treat this fixed-map subset as fresh
map validation or evidence of perceived human likeness.

## Checks

The neutral-expansion scenario failed against the old behavior for both affected
profiles, then passed all 33 assertions after the change. It checks base reserves,
enemy reserves, team ownership, blocked routes, unchanged compact-board choices,
the control option, and every personality/tier default. It is included in the
existing behavior regression command.

All seven behavior suites passed, including 79 runtime assertions and the 33 new
neutral-expansion assertions. Repeated canonical tournaments have identical full
results and decision traces. Horizon-limit handling and rejection of accelerated
evaluation clocks passed. Candidate preflight also reproduced its gameplay and
traces across two isolated worker user-data directories.

The original Corridors example (seed 1941614430, Raider in seat 1 against Turtle)
now opens at 3.3 seconds instead of 18.5. At 15.1 seconds Raider owns two hives
instead of one; Turtle owns three in both versions. Turtle still wins this
example, at 130.7 seconds instead of 95.5. The example establishes that the
opening delay was removed, not that this alone fixes the matchup. Raw commands
and first-minute territory samples are retained in `opening_example.json`.

## Results and decision

All 600 candidate games completed under the declared schedule. Their paired
controls use the same six seeds, five maps and swapped seats, with 240 appearances
per personality. These control percentages therefore differ slightly from the
full 2,000-game baseline. Score counts wins plus half of draws.

| Bot | Control wins / losses / draws | Candidate wins / losses / draws | Control score | Candidate score |
| --- | --- | --- | ---: | ---: |
| Turtle | 219 / 21 / 0 | 184 / 56 / 0 | 91.2% | 76.7% |
| Swarm Lord | 158 / 76 / 6 | 129 / 105 / 6 | 67.1% | 55.0% |
| Greedy | 94 / 143 / 3 | 153 / 84 / 3 | 39.8% | 64.4% |
| Raider | 43 / 192 / 5 | 104 / 131 / 5 | 19.0% | 44.4% |
| Balancer v3 | 74 / 156 / 10 | 18 / 212 / 10 | 32.9% | 9.6% |

Keep this as a behavior correction, not a declaration of balanced difficulty.
Both affected bots improve on every changed map; Closequarters is unchanged.
Their combined score improves by 25.0 percentage points. Raider's overall median
first neutral order moves from 9.9 to 3.35 seconds; Greedy's moves from 6.8 to 3.0.
On Corridors the medians move from 18.35 and 21.25 seconds to 3.35 and 3.0.

Against Turtle, Raider improves from 0/60 wins to 15/60; Greedy from 8/60 to 28/60.
Neither pairing draws. These are the matched subset results, not the full
baseline's 200-game matchup counts.

The improvement does not depend on more draws or quiet timeouts: both versions
have 12 draws. Conquest wins rise from 497 to 501, time-limit wins fall from 91 to
87, and the final-minute ownership proxy falls from 11 to 8 games. Median match
duration increases from 148.85 to 159.0 seconds.

All 180 games involving only unchanged Balancer, Turtle and Swarm Lord
reproduce complete results exactly. All 120 Closequarters games retain identical
gameplay and applied actions; only the new profile metadata and associated runtime
hash differ in affected profiles. Every paired game has the same initial board
and map hash. Only the expected medium Raider/Greedy profile option differs.

## Remaining problems

Balancer is now the clearest overall weakness. Its controller is unchanged, but
Raider and Greedy convert many former losses against it into wins. It still
executes the human-behavior pilot while the other four use live-state baseline
policies. This experiment does not establish which aspect of Balancer's decisions
causes the remaining gap. Its response to faster expansion and sustained pressure
needs direct trace review before changing its reserves, timing or attack plans.

Map specialization remains extreme. Greedy scores 93.8% and 95.8% on the two
Centerstrike maps; Turtle still scores 91.7% on Corridors and 95.8% on Pinched
Spine. The aggregate ranking hides these matchup problems. Other maps, tiers,
team modes and human opponents still require separate validation.

Supply-route oscillation also remains. Raider's quick reversals change from
49.2 to 48.1 per 100 feed orders; Greedy's from 35.2 to 32.8. Their raw counts
increase as their games contain more feeding. Balancer retains zero under this
diagnostic. These counts flag sequences for review; they do not prove that every
redirect is unnecessary. Supply commitment should be tested separately from this
reserve change, using the retained candidate as the next control.

No friendly-lane speed, production, combat, capture or reaction-timing changes
were needed for this correction.

## Retained evidence

`SF/artifacts/bot-neutral-expansion-2026-09-22/` contains the declared experiment,
source and engine fingerprints, all raw compressed results, seven-suite regression
logs, paired comparison, score plot, focused opening example and incremental
implementation patch. `comparison.md` includes every tested map and Raider/Greedy
opponent; `comparison.json` also retains paired seed-bootstrap intervals, outcome
transitions and behavior tallies. These intervals describe seed variability on
the fixed panel, not general map balance. Balancer's neutral-order timing is marked
unavailable because its applied-event metadata omits target ownership.

The candidate is frozen in `SF/project-bot-neutral-expansion-20260922`. See the
artifact `README.md` for reproduction commands; `capture_checkpoint.py` verifies
the development source matches the tested candidate, preserves the original
frozen control, and checks that the incremental patch can be reversed.
