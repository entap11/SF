# Simple Syrup owner playtest — September 28, 2026

## Calibration decision

The owner completed both phone games and reported that the opponents felt
different and required different play within the same game. Both were easy for
the owner to beat. The owner's explicit direction is to develop medium bots for
the intended general audience; do not raise their strength to match the owner's
skill. Preserve this checkpoint's approachable challenge and distinct styles.

Use this session to examine purposeful decisions, personality and opportunities
for player adaptation. Owner win rate, opening speed, supply management and
finishing technique are not medium-tier performance targets. An expert finding
and exploiting a weakness does not by itself make that weakness a defect.
Review suspected bugs separately from deliberate limitations. Any future expert
challenge belongs in a separately evaluated difficulty tier, if requested.

No bot policy, timing, difficulty, map or gameplay rule changes follow from this
session. This is a design direction and a retained reference, not a finding that
two owner games establish population-wide balance.

## Verified recordings

Retrieved both completed recordings from the installed iPhone app. Both used
build `2026092801`, Godot 4.7.1, Simple Syrup, seed `9282026`, human seat 1,
CPU seat 2, medium difficulty, conquest and an empty buff loadout.
The effective profiles and embedded source manifest match the intended build.

| Recording | Balancer | Raider |
| --- | --- | --- |
| Effective policy | `human_balancer_v3` | `baseline_v3` |
| Result | Human win | Human win |
| Simulation duration | 104.8 seconds | 112.0 seconds |
| Human intents with matching public observations | 19 | 23 |
| Bot commands applied | 13 | 8 |
| Pilot choice witnesses | 60 | Not emitted by baseline |
| Sampled replay frames | 210 | 224 |
| Rejected commands / dropped witnesses | 0 / 0 | 0 / 0 |

Each human also retracted one lane. Those retractions are recorded separately
from the intent/context counts above; Balancer's 13 commands include two
retractions. Command counts describe these matches, not an activity target.

Source fingerprint:
`2503725b39c621a7b3c16bf332ee166ebd7f32ee7c39712688c96e3f23d1a159`.
Map SHA-256:
`03e332c6e96aa17773c47bb7093a16500f5994105da89bb9f4fdad4e354bba14`.
Implementation checkpoint: `43eb6fb` on `codex/bot-phone-simple-syrup-20260928`.

Local evidence: `SF/artifacts/bot-phone-2026-09-28/owner-session/` contains
`summary.json`, `review.py`, `review.json`, transfer evidence and both recordings.
The review script validates setup, policy, source/map identity, completion,
intent/context matching and monotonic board samples, then extracts commands and
sampled ownership changes. Run `python3 review.py` in that directory to reproduce.
Raw recordings remain local; the report does not include account identifiers.

## Concrete differences

Hive references: 1 is the human's bottom home, 2 lower-left, 3 lower-right,
4 center, 5 upper-left, 6 upper-right, and 7 the CPU's top home.
Times below use simulation seconds.

Both human openings were similar: open 1→2, then 1→5 within the first two
seconds, and feed 2→5 around 11 seconds. The paths diverged afterward:

| Decision sequence | Against Balancer | Against Raider |
| --- | --- | --- |
| Human use of the upper-left foothold | At 16.3s, attack CPU home 5→7; at 24.0s, add 5→6. | At 18.7s, reverse supply 5→2; at 20.3s, feed 2→1. |
| Human development of the lower-right | Open 1→3 at 28.2s; first sampled human ownership at 37.7s. | Open 1→3 at 21.1s and 2→3 at 23.5s; first sampled human ownership at 29.1s, then open 3→4 at 30.1s. |
| CPU pressure and support | Open 6→3 at 33.2s; send defensive swarms on that route at 40.9s and 49.7s. Lower-right changes from human to CPU in the samples by 42.7s. | Open routes from 6 toward 5 at 25.4s, 3 at 27.5s and 4 at 47.3s; later swarm toward 4 at 72.7s, 3 at 79.0s and 5 at 89.7s. |

Balancer also retracts 3→4 at 47.7s after its plan records `source_threatened`,
then reinforces 3 again at 49.7s. This gives a concrete sequence of expansion,
defense and withdrawal to preserve as a review example. It does not establish
that every decision was optimal or that every new supply feature was exercised.

Raider opens its second expansion at 5.5s versus Balancer's 10.6s, then keeps
using the upper-right as an attack source. Its applied events show persistent
pressure, including three late swarms. The baseline has no pilot observation or
plan-memory witnesses, so this review does not invent a hidden rationale for it.

The owner's different supply choices and route priorities are observable and
consistent with the reported need to adapt. The logs alone cannot establish why
the owner chose each move or isolate personality from controller differences.
This was one game per opponent in a fixed order, on one map and one seat.

Both finishes also contain chains of human swarms: 5→4→3 at 95.4–97.7s against
Balancer, and 3→1→4→6 at 98.7–101.9s against Raider. These are useful examples of
experienced execution; matching that execution is not a requirement for medium.

## Next evaluation

Keep these profiles and Simple Syrup as the reference. The next difficulty
sample should include newer and intermediate players, with opponent order
varied across players. Record experience level, challenge, readable opponent
behavior and enjoyment separately from victory. Review whether players can
recognize an opponent's tendencies, adapt and recover from mistakes.

Use the owner's future sessions for tactical interpretation and obvious bugs.
Do not optimize every persona toward the owner's strategy or automatically fix
every exploitable opening. Keep any behavior candidate separate from this
reference and evaluate its effect on the intended audience before changing
medium strength. No numeric target win rate is established by this session.

## Telemetry interpretation

Replay frames sample the board approximately every 500ms. Ownership timestamps
above identify the first matching sample, not exact captures. The last sample
precedes the final capture; completion and the winner come from terminal
metadata. Simulation duration is `recorded_sim_ms`, not wall-clock `duration_s`.
The generic `map_id` is `unknown_map` for this evaluation entry; identify the map
using the verified evaluation path/hash. Human command observations and pilot
witnesses have explicit times. Some generic swarm source-power fields use
defaults; use their public observations when interpreting the source state.
