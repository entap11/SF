# Medium-bot round robin — September 22, 2026

Status: complete. All 2,000 games passed validation; no gameplay or bot tuning was
performed during the sweep.

The owner authorized a broader baseline of the existing personalities after the
[Balancer v3 checkpoint](bot_human_continuation_2026-09-22.md). Friendly-lane speed,
production, combat rules and bot profiles remain unchanged during this evaluation.

## Declared schedule

- Five medium personalities: Balancer v3, Turtle, Raider, Greedy and Swarm Lord.
- Five fixed maps: Centerstrike CS2 and CS3, Closequarters SBASE, Corridors SBASE,
  and No Man's Land 444 Pinched Spine, all in their two-seat `1p` variants.
- Twenty distinct seeds, sampled uniformly without replacement from
  `[10000, 2147483647)` using Python `random.Random(20260922)`.
- Every distinct personality pairing on every map/seed, with both seat assignments.
- 2,000 games total; 200 games per pairing; 800 appearances per personality.
- Complete canonical matches, including the existing regulation/overtime rules.
  The 420-second harness horizon is only a guard; incomplete games fail validation.

The seed list and exact source hashes were saved before the sweep in `plan.json`.
The maps are a fixed, equally weighted panel, including two Centerstrike variants.
They are not sampled from the entire catalog. No default rollout or balance change
is part of this task.

## Execution and validation

Source is frozen in `SF/project-bot-balance-20260922`, based on `dc19dda` plus the
current bot changes. Process workers use separate Godot user-data directories.
The primary development checkout and player profile are not used for worker saves.
The sweep began with six workers, then drained the active batches and resumed
with eight to reduce runtime. The declared schedule, seeds, source and validation
were unchanged; completed batches were revalidated and reused. `worker_resize.json`
records that transition. The coordinator's earlier interruption is retained in
`run-six-workers.log`; it is not a failed game. `completion.json` reports elapsed
time for the resumed phase.

Godot is pinned to `4.7.1.stable.official.a13da4feb`. The full source fingerprint
covers 648 gameplay, data, scene and map files. Each batch must retain that source,
execute all 20 ordered pairings, select the intended policies, finish its games,
and produce internally consistent map, seed, team, clock and winner metadata.
Logs with script/engine errors fail even if the process exits successfully.
Validated raw JSON is compressed with its hash and exact command retained.
Resumption revalidates stored outputs rather than silently accepting an old file.

Preflight reproduced both previous Centerstrike/Balancer/Raider games across two
isolated user directories, with identical gameplay hashes, runtime hashes and
full decision traces. The prior checkpoint also matches after excluding the newly
requested board samples and ownership-change diagnostics. The validation checker
rejects missing pairings, wrong seeds, incomplete outcomes, wrong winners,
noncanonical clocks, shared user-data paths and missing controller starts.

The only GDScript extension for this sweep is in the tournament harness: count
net ownership changes after each canonical tick, record the last change time,
and report the actual user-data
directory. It reads simulation state and adds evaluation metadata.

## Measurements

Report wins/losses/draws, score (`wins + 0.5 × draws`), each pairing, each map,
seat assignment, match duration, command mix, rejected commands and repeated
rejection runs. First-minute samples describe lane use and productive hives with
no outgoing route; they do not establish that a useful legal route was available.

Keep three outcome categories separate: conquest wins, time-limit decisions and
actual draws. A time-ended match with no hive ownership change in its final 60
seconds is a stalemate proxy. A leader deliberately holding territory can satisfy
that definition, so it is a review cue, not proof that either bot is broken.
Ownership comparison uses the before/after state of each 100ms canonical tick;
multiple ownership transitions within one tick can cancel out in this measure.

Exploratory trace review during the sweep identified rapid reversals of friendly
feed direction. A report-only counter records opposite successful feeds on one
pair within five seconds; another order on that pair breaks the run. Three
reversals require four alternating orders. This diagnostic was added after seeing
the pattern and is a review cue, not a declared causal endpoint or a determination
that every redirect was unnecessary.

Reported score intervals bootstrap whole seeds 5,000 times with a fixed analysis
seed, keeping both seats, opponents and maps together. They describe seed
variability conditional on this map panel. Map selection uncertainty, human
opponents and other tiers are outside those intervals.

The current implementations retain their different observation and thinking
systems: only Balancer has the new delayed human-behavior policy. The results
measure their current playing strength, including those differences. They do not
establish human likeness or isolate personality preferences from implementation.

## Reproduce

From `project-unified-mobile-release`, with the frozen checkout retained:

```sh
export GODOT_BIN="$HOME/Library/Application Support/Swarmfront/toolchains/godot/4.7.1/Godot.app/Contents/MacOS/Godot"
python3 tools/run_bot_round_robin.py \
  --project ../project-bot-balance-20260922 \
  --artifacts ../artifacts/bot-round-robin-2026-09-22 \
  --workers 8 \
  --reference ../artifacts/bot-human-continuation-2026-09-22/regression/tournament_1.json
python3 tools/report_bot_round_robin.py ../artifacts/bot-round-robin-2026-09-22
```

Use `--partial` only for progress inspection. The final reporter requires the
completion manifest and exact full schedule coverage, and checks output hashes,
applied policy identities and unchanged per-persona profiles across maps/seeds.
Optional `--plot` produces PNG and SVG figures when matplotlib is installed.

## Findings

Each personality played 800 games. Score counts a win as one and a draw as half.

| Bot | Wins / losses / draws | Score | 95% interval across seeds |
| --- | --- | ---: | --- |
| Turtle | 720 / 80 / 0 | 90.0% | 88.4%–91.7% |
| Swarm Lord | 530 / 253 / 17 | 67.3% | 64.8%–69.7% |
| Greedy | 319 / 472 / 9 | 40.4% | 38.3%–42.4% |
| Balancer v3 | 246 / 529 / 25 | 32.3% | 30.6%–34.2% |
| Raider | 151 / 632 / 17 | 19.9% | 18.2%–21.5% |

Turtle leads on all five maps and wins 195 of its 200 games against Balancer.
This panel gives no reason to increase friendly-lane speed or production to make
Turtle competitive. The roster is not close to equal strength under the existing
rules. Map dependence is substantial: Raider scores 49.7% on Closequarters but
6.9% on Corridors; Swarm Lord scores 38.4% and 81.9% respectively. An overall
ranking alone hides those differences.

There are 1,665 conquest wins, 301 time-limit decisions and 34 draws. Only 28
matches meet the final-minute ownership proxy. The roster's strength differences
are therefore visible in decisive outcomes, not just prolonged territorial holds.

Raider's median first successful order is at 10.0 seconds, versus Turtle's 2.9.
The selected Corridors trace shows an 18.5-second Raider opening against Turtle's
2.9 seconds. On that 16-hive board, Raider's authored minimum attack power rises
from 10 to 15. That blocks earlier attacks while its initial reserve grows. This
identifies a constraint to investigate; it does not quantify how much of the
eventual loss comes from the delay.

Runs of at least three rapid feed reversals occur in 458 of Swarm Lord's games,
270 of Greedy's, 232 of Raider's and 59 of Turtle's. Balancer v3 has none under
this definition. The selected Raider trace alternates the donor between hives 3
and 15 repeatedly; the longest selected Greedy run contains 26 reversals. These
are concrete candidates for more persistent supply decisions. Strong scores and
plausible behavior need separate evaluation.

Balancer has 257 rejected orders (1.04%): 192 ownership failures, 63 capacity
failures and two other failures. Six matches contain at least three consecutive
rejections; the maximum is five. The selected capacity case should be reproduced
with its delayed observations before changing retry or reserve behavior. The
other controllers read live state when choosing their commands, so their zero
rejection counts are not an equivalent test of delayed decision quality.

## Next behavior work

Keep gameplay rates fixed. Reproduce Raider's opening threshold and the baseline
feed reversals in focused scenarios, then develop deliberate supply and plan
commitment for the remaining personalities while retaining their distinct
preferences. Review Balancer's delayed capacity failures and pressure plans.
Measure subsequent revisions against this baseline, with fresh maps/seeds for
confirmation. Final balance and perceived human likeness still need another pass
as the other personalities adopt the human-behavior controller and receive human
playtesting.

Evidence is in `SF/artifacts/bot-round-robin-2026-09-22/`:

- [Full report](../../artifacts/bot-round-robin-2026-09-22/report.md) and
  [matchup chart](../../artifacts/bot-round-robin-2026-09-22/matchup_summary.png).
- [Trace review](../../artifacts/bot-round-robin-2026-09-22/trace_review.md) and
  [recorded example](../../artifacts/bot-round-robin-2026-09-22/trace_example.png).
- `plan.json`, `completion.json`, compressed full results and per-batch manifests
  retain the schedule, hashes and commands. `final_checks.json` cross-checks the
  report and CSV totals, initial boards and frozen source.
- `evaluation.patch` and `evaluation_manifest.json` capture only this evaluation's
  changes after the prior bot checkpoint. Earlier bot work and unrelated UI work
  remain separate.
