# Authoritative Buff Simulation Contract

This contract describes gameplay state only. `OpsState`/`GameState` and their
simulation systems are the sole writers. UI, input, Arena presentation, and
renderers may submit stable intents and read snapshots; they never interpret or
mutate buff gameplay.

## Fixed-step phase order

For each 100 ms simulation step, the relevant order is:

1. Canonically scheduled commands due for the step are applied through
   `OpsState`, including buff activation and immediate activation side effects.
2. Match-clock and bot work runs.
3. Active effects validate targets and expire for the upcoming lane-flow tick.
   Target loss is evaluated before timer expiration, so source loss on a
   Supercharge expiration boundary forfeits the unreleased queue.
4. Lane flow increments `GameState.tick`, updates lanes, and commits normal hive
   production events. Effects satisfy `started_tick <= production_tick <
   expires_tick`; production on the expiration tick does not qualify.
5. Manual swarms update, then ordinary units move, encounter, arrive, and commit
   ownership/damage results.
6. Tower, structure-control, and barracks phases run.

An activation applied before lane flow influences production in that step.
Treacherous conversion occurs synchronously at activation, before movement and
encounter resolution, so an existing converted unit can move home during that
step. Once a production event commits, later ownership changes do not erase its
unit. Ownership loss terminates target-bound effects at the next effect phase.

## Production events

Every successful `UnitSystem` production entry point commits one transient,
simulation-owned event. Event identity is deterministic:

`simulation_tick : producer_kind : producer_id : producer_local_spawn_ordinal`

Producer kinds are `hive`, `barracks`, and `system`. Spawn reasons are
`normal_production`, `supercharge_release`, `pass_through`, and `scripted`.
Events are consumed synchronously and discarded at the next tick. Only their
produced units and resulting buff state survive in snapshots. Recommitting an
explicit event identity in the same tick is an idempotent no-op.

Supercharge listens only to a `hive` + `normal_production` event whose owner,
source hive, directed lane, lane generation, and destination match its frozen
target. Releases cannot recursively refill a queue.

## Cohorts and provenance

Diagnostic provenance—unit ID, production event ID, and production tick—does
not block aggregation. Units may merge only when all state that can change their
future behavior is compatible. Current compatibility includes speed, combat
allegiance, allegiance mode, and explicit impact override. Betrayed units never
merge.

Ordinary, enhanced-full, and enhanced-spent counts are subcohorts in one packet.
They may aggregate because their separate future combat strengths remain exact;
aggregation never flattens their impact state. Units with different speeds do
not merge.

## Supercharge inheritance

The queue is a bounded, ordered run list of inheritable cohort stamps. Each
qualifying normal production unit contributes exactly one bonus token carrying:

- stamped speed;
- ordinary, enhanced-full, or enhanced-spent impact class.

It does not carry production-event identity, recursion eligibility, pending
betrayal, manual-swarm state, or diagnostic provenance. Release preserves run
order and expands the queue into a deterministic nose-to-stinger train.

## Treacherous state and allegiance

Canonical ownership never changes. `original_owner_id` remains the provenance
owner. `combat_allegiance_id` changes to the activating side and is used only
for combat relationships. Betrayed units cannot reinforce or capture, receive
kill or landed-unit economic credit, be recalled/redirected/scooped, receive
production buffs, merge with normal units, or be converted again.

The state machine is:

`normal -> pending_betrayal -> committed_return -> arrived/removed`

Existing enemies transition directly to `committed_return`. New qualifying
normal hive production enters `pending_betrayal`. Clearance is authoritative
integer milli-pixels. Movement clamps at exactly 15,000 milli-pixels, turns once,
and discards unused movement for that step. A committed unit targets only its
stored origin hive and can damage but never capture or reinforce it.

Lane-targeted effects and betrayal stamps carry a simulation-owned lane
generation. Removing and recreating a lane—even with the same numeric lane
ID—invalidates the old effect without erasing already committed betrayal state.
