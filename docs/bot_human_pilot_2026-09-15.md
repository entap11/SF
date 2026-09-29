# Human-behavior bot pilot — September 15, 2026

September 16 update: the [calibration checkpoint](bot_calibration_2026-09-16.md)
records the second policy and a timeout correction that supersedes the four-game
strength result below. This document preserves the first implementation checkpoint.

## Current checkpoint

The reliable bot clock, canonical tournament driver, observation/command boundary,
and first medium Balancer behavior pilot are implemented. The pilot still needs
human playtesting and strength calibration. It is **opt-in**.

This continues the [code review and roadmap](bot_human_behavior_review_2026-09-14.md).
Resume here without repeating the audit.

## Try it

From the repository root:

```sh
godot --path . -- --human-bot-pilot
```

Choose a **medium Balancer CPU in a two-seat conquest match**. Other styles, tiers,
flag modes, and matches with more than two active seats use the baseline. Existing
CPU disclosure remains in place. Start without the flag to use the normal policy.

Harnesses can set `human_behavior_enabled: true` on the profile before its first
tick. The tournament driver opts into the pilot. Profiles are pinned when a bot
starts; change settings before starting a new match.

## Implemented

### Reproducible simulation

- Bot schedules/opening windows use `GameState._sim_time_us`, so menu dwell does
  not expire opening strategies. No per-decision uptime or global RNG is used.
- Timing and choice samples use a match seed, seat, decision counter, and named
  purpose. Stable candidate ties use hive IDs.
- `OpsState.bot_runtime_by_seat` owns pinned profiles, cooldowns, observations,
  pending actions, and planning memory. Authority snapshots preserve it and
  normalize JSON seat keys on restoration.
- Maps/harnesses can supply `bot_seed` or `seed`; the current fallback is `1`.
  Automatic per-rematch seed distribution across network authority remains future
  work. The bot's `started` event records its seed/profile.
- Baseline candidates exclude blocked actions and known own-hive swarm cooldowns
  before selection.

### Medium Balancer pilot

The controller captures public facts, waits to process that observation, prepares
one command, then waits to execute it. Notice and motor delays are independently
seeded and rounded upward to the canonical 100ms tick. Execution checks ownership
and legality again through the simulation command adapter.

Observations copy public hive/route facts, visible lane pressure, nearby moving
units/swarms, and the bot's own swarm readiness. They contain no authoritative
hive/lane object references, hidden flags, queued enemy commands, or enemy
cooldowns. Incoming-force estimates currently use travel progress.

The pilot can:

- Expand or pressure a target and remember its progress.
- Build a supply route before an evenly matched attack.
- Reinforce a threatened hive, save an interrupted attack, and resume it if valid.
- Shift attention while orders continue, remember up to two additional commitments,
  and review one remembered commitment per observation.
- Withdraw from a stalled/exposed attack and avoid immediately retrying its target.
- Use friendly and neutral swarms through existing simulation validation.

This is a hand-authored prototype. Attention limits planning/review, while each
observation still copies the public board. Human gaze, regional memory, opponent
habits, and fitted error rates are future work. The pilot does not use the
baseline's deliberate worst-candidate mistakes.

### Measurement

The tournament driver now advances production `SimRunner`: bots, lane flow,
swarms, units, buffs, structure control, towers, barracks, and win rules. It disables
scene-node binding work in the headless harness. Running canonical ticks quickly
does not accelerate bot thinking relative to the match; scaled thinking is rejected.

JSON records engine version, map hash, seed, seat/team assignments, profiles,
decision traces, and final gameplay/runtime hashes. An unfinished evaluation is
excluded from win/draw rankings. Map suffixes are catalog variants; use
`active_seats` and `team_by_seat` to identify the actual matchup. Four-seat runs
currently use the existing 1+3 versus 2+4 teams, not FFA. Tournament setup uses the
standard map state; randomized structure-slot/power variants are not yet selected
by its CLI. Explicit tower/barracks fixtures exercise those simulation systems.

Reaction telemetry matches actions to the threatened hive or attacker, retains
unanswered and end-of-match-censored threats, excludes teammate attacks, and
preserves individual matched delays. Events without a target location are counted
as unlocated. This remains a relevant-action proxy, not proof of human attention
or intent. Untargeted buffs are excluded. Match schema: **9**; reaction format:
**2**. Keep older reaction formats separate when building calibration data.

The Turtle smoke test now exits with failure when an assertion fails. Its revised
stable-shell fixture supplies the ally and explicitly checks an unobstructed
neutral route; the old coordinates placed hive geometry across that route.
Behavior is checked over 64 deterministic decision opportunities.

## Validation

```sh
python3 tools/run_bot_behavior_regression.py
```

The gate runs behavior, style, progressive grace, telemetry hooks/report, and
authority-buff checks. It repeats two seat-swapped canonical matches and compares
their complete JSON outputs, then checks incomplete-horizon handling and rejection
of scaled thinking. Success requires correct exit codes, PASS markers, and no
engine/script errors. A failed rerun removes its stale success summary.

The September 15 gate passed on Godot 4.2; the final expanded behavior suite passed
**51 checks**. Artifacts are under `artifacts/bot-human-pilot-2026-09-15/`, including
an isolated implementation patch and source fingerprints. The suite checks delayed actions,
stale ownership, pending-command snapshot restoration, incoming reinforcements,
supply sequences, interrupted plans, remembered-front recovery, cooldowns,
mode/opt-in boundaries, relevant reaction metrics, swarm power consumption,
barracks production, and tower control. Repeated simulations also vary render-frame
cadence with identical canonical inputs. An additional combat fixture opens a
hostile lane and verifies tower firing and projectile hits on moving enemies.

Pending bot-command restoration is tested. This does not certify arbitrary
whole-match restoration of every older subsystem's private caches/array aliases.
Identical-input determinism does not imply rotation or hive-ID-permutation invariance.

## Evidence and next steps

The initial two-map, seat-swapped sample used Centerstrike CS2/CS3 and seed 4101.
Balancer lost all four games against medium Raider, both before and after adding
remembered concurrent commitments. The later games lasted longer; that does not
establish human likeness or adequate medium strength. This is why the candidate
remains opt-in. Avoid tuning solely to these four games.

1. Compare annotated human and pilot rounds: expansion tempo, idle hives, supply,
   defensive commitment, withdrawals, and repeated mistakes. Distinguish plausible
   pauses from tactical failures.
2. Calibrate this opponent across more maps/seeds and held-out human sessions.
   Turn observed failure patterns into focused regressions.
3. Run balanced replay/live playtests with disclosure. Measure perceived behavior
   and fun separately from wins before enabling the pilot by default.
4. Extend validated behavior to other personas and explicit structure, flag, team,
   and FFA strategies. Fit learned choices only if measured gaps justify them.

Human-data fitting, learned models, default rollout, and an indistinguishability
claim remain unfinished.
