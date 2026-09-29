# ADR 005 — Adaptive Bot v3 Runtime Contract

Status: Accepted for implementation  
Date: 2026-08-07

## Context

The production bot currently schedules from wall time and applies lane intents
directly from `BotSystem`. Tournament and match-authority tools duplicate part
of that scheduling behavior. The baseline policy is deterministic only when
its caller supplies deterministic time and ordering. Bots also cannot request
the authoritative lane-retract operation used by human players.

Adaptive Bot v3 must add cognition without creating a second gameplay state or
a second gameplay command protocol.

## Characterization evidence

- Production previously owned a wall-clock scheduler in `BotSystem`.
- Tournament and golden generation each owned a separate scheduler and
  cooldown implementation.
- The style smoke test could overwrite a failure exit with success; it now
  aggregates assertions and exits once.
- `baseline_v2` had no retract output; retract is introduced only through the
  new primitive action/gateway path.
- The checked-in `normal_match_canonical` performance artifact contains 30
  `bot_system` phase samples: 0.09 ms minimum, 0.099 ms mean, 0.12 ms p95, and
  0.12 ms maximum on its recorded host. This is a system-phase baseline, not
  an isolated candidate-evaluation budget. No planner budget is inferred from
  it; mobile profiling remains required before v3.2 search work.

## Decision

### Authority boundary

`OpsState` / `GameState` remain the only gameplay authority. Bot code may read
state and emit commands. It may not mutate hives, power, ownership, units,
lanes, capture state, objectives, production, or buffs directly.

### Runtime ownership

`BotRunner` is the sole normal-runtime mutator of `BotRuntimeState`.

`BotCommandGateway` translates internal bot actions into existing canonical
gameplay command shapes, publishes or applies them through the configured
command sink, and reports the authoritative result to `BotRunner`. Only then
may `BotRunner` update cognition, cooldowns, and planning state.

Authority snapshot restoration may replace serialized bot runtime state before
`BotRunner` resumes. No other system may patch live cognition.

### Decision and action contracts

`BotDecision` has exactly two outcomes:

- `ACT`
- `DEFER`

Plan cancellation and reconsideration are internal `BotMind` transitions, not
decision-interface outputs.

Internal action names do not create new wire commands:

| Internal action | Existing canonical command |
| --- | --- |
| `OPEN_ROUTE` attack | `lane_intent` with `intent=attack` |
| `OPEN_ROUTE` feed | `lane_intent` with `intent=feed` |
| `SWARM` | `lane_intent` with `intent=swarm` |
| `RETRACT_ROUTE` | `lane_retract` |

Planning metadata belongs to a diagnostic `BotDecisionTrace`, not the
authoritative gameplay command.

### Shared platform milestone

`BotRunner` and `BotCommandGateway` are one platform deliverable. Production,
tournament, golden generation, and cognition audit configure this shared
runtime rather than reimplementing scheduling or action execution.

### Tick contract

Bot cognition uses integer authoritative simulation time. Every adaptive
reaction distinguishes:

1. `event_tick`
2. `observable_tick`
3. `decision_tick`
4. `issued_tick`
5. `execute_tick`

The mode contract freezes command lead. Player-visible response time includes
perception latency, reaction latency, and command lead.

No gameplay decision may depend on wall clock, render state, frame rate,
machine speed, dictionary iteration order, or elapsed CPU time.

### Replay and audit

Canonical replay consumes recorded gameplay commands. It does not regenerate
historical cognition.

Cognition audit separately regenerates internal bot actions from the pinned
policy, decision profile, seed, legal observations, and opponent command
history. It compares deterministic action fingerprints rather than raw command
dictionaries, because transport metadata may contain wall-clock timestamps and
server-generated identifiers.

### Runtime serialization

Authority snapshots include versioned `bot_runtime_by_seat` plus a deterministic
runtime hash. A restore at tick K must produce the same future bot-action
fingerprints as uninterrupted execution.

Serialized collections are bounded and use deterministic ordering and overflow
rules. Planning limits are operation-count limits, never wall-time limits.

### Profile contract

A match freezes a normalized, decision-affecting profile and hash. Display,
telemetry, and cosmetic fields do not enter decision hash or RNG seed material.
Capability, persona, mode-objective, and future ghost configuration remain
separate axes.

### Baseline migration

The existing policy is frozen as `baseline_v2`. It is the characterization
oracle and rollout fallback while Adaptive Bot v3 is introduced. Canonical
historical replay remains command-based, so indefinite runtime support for the
old cognition implementation is not required.

`adaptive_v3.0` explicitly uses `baseline_v2` as `baseline_fallback_v1` for
ordinary proactive moves until intentional planning ships in v3.1. The
fallback is deterministic, versioned in its trigger code, and visible in the
decision trace; it is never silent or selected from an ambient build default.

## Delivery order

1. ADR and baseline characterization.
2. Shared deterministic runtime plus command gateway.
3. Snapshot-safe cognition.
4. `adaptive_v3.0`: perceive, wait, retract, and reallocate.
5. `adaptive_v3.1`: persistent intent and plans.
6. `adaptive_v3.2`: analytical foresight.
7. `adaptive_v3.3`: stagnation and opponent adaptation.
8. `adaptive_v3.4`: bounded imperfection and personas.
9. Ghost telemetry and fitting.

## First product proof

`adaptive_v3.0` succeeds when the bot sees a losing lane, waits a believable
amount of authoritative time, retracts it, and deliberately uses the freed
capacity elsewhere.

## Automated certification

Run the merge-blocking bot gate from the project root:

```bash
scripts/dev/run_bot_v3_gate.sh
```

The release-readiness entry point runs this stage by default. The certification
matrix covers repeated seeds, collection reordering, 30/60/headless frame
pumps over the fixed simulation step, direct-runner/production parity,
snapshot continuation, visibility isolation, illegal-action rejection,
bounded cognition, shadow non-mutation, and a configurable host observation
cost ceiling.

## Shadow rollout

Shadow mode does not alter the match contract. It is enabled for normal Arena
matches by the project setting:

```ini
swarmfront/bots/adaptive_shadow_enabled=true
```

Runtime or cohort code may still override it with:

```gdscript
OpsState.set_bot_adaptive_shadow_enabled(true)
```

`BotSystem` then runs a second non-authoritative `adaptive_v3.0` runner before
the actual bot. Shadow actions are never sent to `BotCommandGateway`, shadow
cognition is never stored in the authority snapshot, and each shadow outcome
is paired with the actual outcome. Shadow records use the same `match_id` as
human and bot intent telemetry, and include explicit `match_start` and
`match_end` records so decisions can be joined to match context and outcome.
Bounded in-memory evidence is available via
`OpsState.get_bot_shadow_events_snapshot()` and batched JSONL evidence is
written to `user://bot_shadow_decisions_v3.jsonl`. Pending evidence is flushed
at match end, app background, Arena exit, OpsState exit, and before match reset.

## Consequences

- Bot intelligence remains compatible with the single authoritative state.
- Runtime, tournament, and verification behavior cannot drift through copied
  schedulers.
- Cognitive state can survive rollback and recovery.
- Bot actions reuse the established gameplay command protocol.
- Each adaptive release has a visible, playable product claim.
