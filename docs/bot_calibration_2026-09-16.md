# Balancer behavior calibration — September 16, 2026

## Checkpoint

The second medium Balancer pilot addresses unnecessary defensive swarms, unused
rear hives, slow expansion from newly captured hives, and abandoned counterattacks.
Its notice, motor, thinking, opening, and plan-review timings are unchanged.
The pilot remains opt-in for two-seat conquest.

This continues the [first pilot](bot_human_pilot_2026-09-15.md) and
[behavior roadmap](bot_human_behavior_review_2026-09-14.md).

## What the loss traces showed

Of 140 applied pilot commands in the previous four-game sample, 81 were defensive.
The policy repeatedly reacted to low reserve power without accounting for ongoing
friendly supply or the unit collisions caused by an outgoing counterattack. Some
reinforcement swarms also pulled donors below the game's 10/25-power lane-capacity
thresholds. Unavailable defenders could monopolize attention indefinitely.

Expansion had two other avoidable bottlenecks: a newly captured, supplied hive
waited for the normal attack-power threshold, and idle rear hives had no routine
way to support an existing front. Remembering a target also prevented another
hive from concentrating on it. Stalled attacks were withdrawn even when they were
still countering an incoming enemy stream.

These are tactical failure explanations from code and traces, not measured human
preferences. The next playtest must assess whether the resulting behavior feels
believable and enjoyable.

## Implemented behavior

- Estimate continuing pressure using observed friendly supply and opposing
  counterstreams, alongside nearby moving forces.
- Reject threatened donors and swarms whose initial withdrawal would reduce the
  donor's lane-capacity tier. Prefer an unused reserve hive for reinforcement.
- Release a blocked defense at its normal review point; let idle backline supply
  proceed while an attack or defense is waiting.
- Feed toward the nearest non-allied frontier, avoiding immediate reciprocal
  routes and excessive feeding into one hive.
- Let a supplied frontier expand or a threatened hive counterattack from four
  power, through the existing legal command path. One-power contested captures
  wait for reserve rather than repeatedly losing ownership before execution.
- Allow a second source to join pressure on a remembered enemy target.
- Preserve a stalled outgoing counterstream while reviewing other commitments.

The policy is `human_balancer_v2`. Its memory still belongs to OpsState, and every
command still passes simulation validation after the existing observation and
execution delays. No unit, growth, lane-capacity, swarm, or victory rules changed.

## Corrected evaluation clock

The extended runs exposed a clock-domain error: deterministic SimRunner time was
compared with an OpsState deadline based on process uptime. A nominal five-minute
match could end after roughly 160–175 seconds, and results could depend on when
the game ran inside the process.

Deterministic stepping now uses the canonical remaining match duration. Live
wall-clock handling remains as before. A regression runs the complete tied match
and requires the existing 300-second regulation plus 60-second overtime.

**The previous four-game result is superseded:** three games ended early by this
incorrect timeout; one ended by conquest. Its decision traces remain useful for
diagnosis, but 0/4 is not a valid completed-match strength estimate. The preliminary
September 16 `control.json` and `development.json` also predate this correction.
Use only the validated `*_final.json` comparison for current strength evidence.

## Paired evaluation

The frozen first policy is retained in
[human_balancer_v1.gd](../tools/fixtures/bot/human_balancer_v1.gd). Both policies run
through the same corrected simulation, scheduler, observation, and command path.
The control is a policy comparison, not a recreation of the old timer bug.

Each arm uses 36 complete games:

- Centerstrike CS2, Closequarters SBASE, and Corridors SBASE (`1p` map variants).
- Medium Raider, Turtle, and Greedy opponents.
- Seeds 4101 and 4102, with both seat assignments for every matchup.

Reproduce it from the repository root:

```sh
python3 tools/run_bot_calibration.py --artifacts artifacts/bot-calibration
python3 tools/run_bot_behavior_regression.py --artifacts artifacts/bot-behavior-regression
```

The calibration command checks every requested matchup, completed outcomes,
controller selection, equal map/team/timing configuration, and source fingerprints
before writing a comparison. It rejects engine errors even if Godot exits zero.
Artifacts include decision traces, board samples every five simulation seconds,
source hashes, logs, and a comparison report.

The final behavior regression gate passed on Godot 4.2: **66 runtime checks**, all
six smoke suites, identical JSON/decision traces for repeated seat-swapped matches,
incomplete-horizon handling, and rejection of scaled thinking. Runtime checks
include the full regulation/overtime clock, supply development, lane-capacity
preservation, supported expansion, concentration, and fragile counterattacks.

### Final results

| Opponent | Frozen v1: W / L / D | Final v2: W / L / D |
| --- | --- | --- |
| Raider | 7 / 5 / 0 | 10 / 2 / 0 |
| Turtle | 0 / 12 / 0 | 0 / 12 / 0 |
| Greedy | 5 / 6 / 1 | 5 / 6 / 1 |
| **Total** | **12 / 23 / 1** | **15 / 20 / 1** |

By map, wins increased from 1 to 2 on Centerstrike and 6 to 8 on Corridors;
Closequarters remained 5 wins, 6 losses, and 1 draw.

| Descriptive behavior measure | Frozen v1 | Final v2 |
| --- | --- | --- |
| First-minute owned-hive samples with power >= 10 and no outgoing route | 11.1% | 5.1% |
| First-minute active routes / available lane capacity | 57.3% | 63.8% |
| Applied commands per game in the first minute | 8.47 | 9.17 |
| Defensive share of applied commands across complete games | 43.8% | 18.4% |
| Rejected share of attempted commands | 0.64% | 2.57% |
| Minimum scheduled observation-to-execution delay | 500ms | 500ms |

Idle samples use all owned hives as the denominator. Whole-game command shares
span matches of different lengths; they are not direct strength or human-likeness
scores. The final candidate had 23 ownership and 5 budget rejections, compared
with 6 and 1 in the control. Rejection rates remain a monitoring item as the bot
acts on more contested fronts. Simulation validation rejected those stale or
unavailable commands normally.

All 72 final games completed. The additional complete 36-game control repeat was
identical, including decision traces and hashes. Final evidence is under
`artifacts/bot-calibration-2026-09-16/`; the comparison includes source fingerprints
captured during evaluation and a separate hash of its report generator. Rejected
commands are included in future calibration summaries alongside wins and usage.

One intermediate version permitted counterattacks from one power. The broader
trace audit caught repeated ownership failures on Closequarters: contested hives
changed hands before the normal delayed command could execute. The final policy
waits for four power before that counterattack. The failed iteration is retained
under `exploratory_v2_fragile_counterattacks/`; its headline win improvement alone
was insufficient to accept it.
That intermediate version recorded 508 ownership failures. The final version
reduced them to 23; the worst individual Closequarters case fell from 109 to zero
under the same seed and timings. Its one extra win was not retained at the expense
of repeated futile commands.

## Limits

The pressure estimate counts streams rather than predicting exact future arrivals.
The swarm reserve check covers initial withdrawal; it does not predict every
possible chained-swarm cost. Frontier distance is geometric, so complex walls can
still produce poor supply choices. Attention and delays remain authored settings,
not distributions fitted to players. The fallback live match seed is still 1.

This sample is a tactical regression comparison. It does not establish strength
against human players, equal performance across all maps, or indistinguishability.
Structures, flag modes, team play, other personas/tiers, and default rollout remain
separate milestones. Sampled idle/usage statistics are descriptive: not every
available lane is strategically useful.

## Next steps: playtest this checkpoint

1. Launch `godot --path . -- --human-bot-pilot` and open **Jukebox**. Its current
   launch path defaults to a medium Balancer. Choose a two-seat conquest map such
   as Centerstrike CS2 (`centerstrike2`), Closequarters (`closequarters1`), or
   Corridors (`corridors1`). Existing CPU disclosure stays visible.
2. Play on the three evaluated maps, switching starting sides where available.
   Note the match/map and approximate time of any odd pause, repetitive action,
   weak defense, or failure to exploit an opening. Also note sequences that felt
   purposeful and rate challenge, believability, and fun separately.
3. Review those moments against the saved match telemetry under `user://matches`.
   On this Mac, with the current project settings, that is
   `~/Library/Application Support/Godot/app_userdata/Swarmfront/matches`.
4. Turn repeatable failures into focused scenarios, then evaluate the next change
   on additional seeds/maps and sessions from other players before default rollout.
   Prioritize supply-route use against Turtle: in a reviewed Centerstrike match,
   both sides owned five hives at one minute, but the pilot used six outgoing routes
   to Turtle's eleven. Further work should improve which routes it prepares within
   its existing action delays.

Future work should resume from this checkpoint and its saved traces rather than
repeat the initial audit.
